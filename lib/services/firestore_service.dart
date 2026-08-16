import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/question_paper.dart';
import '../models/student_report.dart';
import '../models/result.dart';
import '../models/staff_role.dart';
import '../models/student.dart';
import '../models/test_info.dart';

enum ClaimResult { success, notFound, alreadyClaimed, noPhoneOnRecord }

class ResultWithTestInfo {
  final TestResult result;
  final TestInfo? testInfo;
  ResultWithTestInfo(this.result, this.testInfo);
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _students =>
      _db.collection('students');
  CollectionReference<Map<String, dynamic>> get _studentReports =>
      _db.collection('studentReports');
  CollectionReference<Map<String, dynamic>> get _results =>
      _db.collection('results');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _tests =>
      _db.collection('tests');
  CollectionReference<Map<String, dynamic>> get _questionPapers =>
      _db.collection('questionpapers');

  Future<void> saveFcmToken(String uid, String token) {
    return _users.doc(uid).set(
      {'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  CollectionReference<Map<String, dynamic>> get _parentsToken =>
      _db.collection('parents_token');

  /// Stores the parent's FCM token in `parents_token/{uid}` — the collection the
  /// Python OMR Test Manager reads to notify parents. Preserves an existing
  /// valid token: it only writes when there is no stored token yet, or when
  /// Firebase has issued a genuinely different one (avoids needless overwrites).
  Future<void> saveParentToken(
    String uid,
    String token, {
    String phoneNumber = '',
    String email = '',
  }) async {
    if (uid.isEmpty || token.isEmpty) return;
    final ref = _parentsToken.doc(uid);
    final snap = await ref.get();
    final existing = (snap.data()?['fcmToken'] ?? '').toString();
    if (snap.exists && existing == token) {
      return; // Same valid token already stored — do not overwrite.
    }
    await ref.set({
      'uid': uid,
      if (phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
      if (email.isNotEmpty) 'email': email,
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<ClaimResult> claimStudent({
    required String uid,
    required String schoolCode,
    required String admissionNo,
    required String phoneNumber,
  }) async {
    final snap = await _students
        .where('schoolCode', isEqualTo: schoolCode.trim().toUpperCase())
        .where('admissionNo', isEqualTo: admissionNo.trim())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return ClaimResult.notFound;

    final doc = snap.docs.first;
    final data = doc.data();

    final storedPhone = (data['phoneNumber'] ?? '').toString().trim();
    if (storedPhone.isEmpty) return ClaimResult.noPhoneOnRecord;
    if (storedPhone != phoneNumber.trim()) return ClaimResult.notFound;

    final existingIds = List<String>.from(data['parentIds'] ?? []);
    final existingUids = List<String>.from(data['parentUids'] ?? []);
    if (existingIds.contains(uid) || existingUids.contains(uid)) {
      return ClaimResult.alreadyClaimed;
    }

    await doc.reference.update({
      'parentIds': FieldValue.arrayUnion([uid]),
    });
    return ClaimResult.success;
  }

  Future<void> unclaimStudent(String uid, String studentDocId) async {
    await _students.doc(studentDocId).update({
      'parentIds': FieldValue.arrayRemove([uid]),
    });
  }

  Stream<List<Student>> streamClaimedStudents(String uid) {
    return _students
        .where('parentIds', arrayContains: uid)
        .snapshots()
        .asyncMap((snapshot) async {
      final students = snapshot.docs.map(Student.fromDoc).toList();
      final validStudents = <Student>[];

      for (final student in students) {
        if (student.phoneNumber.trim().isEmpty) {
          await unclaimStudent(uid, student.docId);
        } else {
          validStudents.add(student);
        }
      }
      return validStudents;
    });
  }

  Stream<List<StudentReport>> streamPublishedReports(List<String> studentIds) {
    if (studentIds.isEmpty) return Stream.value(const []);
    final ids = studentIds.length > 30 ? studentIds.sublist(0, 30) : studentIds;
    return _studentReports
        .where('studentId', whereIn: ids)
        .where('published', isEqualTo: true)
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(StudentReport.fromDoc).toList());
  }

  Future<List<TestResult>> fetchResultsForStudent(String studentId) async {
    final snap = await _results.where('studentId', isEqualTo: studentId).get();
    return snap.docs.map((d) => TestResult.fromDoc(d.id, d.data())).toList()
      ..sort((a, b) => b.testName.compareTo(a.testName));
  }

  /// Stream results for a student with robust fallback logic (New + Old + Legacy formats)
  /// REUSED by both Parent and Admin pages for identical data.
  Stream<List<TestResult>> streamResultsForStudent(Student student) {
    final String sid = student.studentId;
    final String adm = student.admissionNo;
    final String name = student.name;

    debugPrint('DEBUG: [streamResultsForStudent] Beginning lookup for: ${student.name}');
    debugPrint('DEBUG:   - Student ID: $sid');
    debugPrint('DEBUG:   - Admission No: $adm');

    // Use the students collection snapshot as a trigger for reactivity, 
    // or just use a periodic stream if results are added.
    // Ideally, we'd combine multiple specific queries.
    
    // For now, let's use the most reliable reactive way for specific lookups:
    // We listen to the student's primary ID query and fetch fallbacks when it updates or periodically.
    return _results.where('studentId', isEqualTo: sid).snapshots().asyncMap((q1) async {
      debugPrint('DEBUG: [streamResultsForStudent] Query (studentId==$sid) found ${q1.docs.length} docs');

      // Fallbacks
      final q2 = await _results.where('roll_no', isEqualTo: adm).get();
      debugPrint('DEBUG: [streamResultsForStudent] Query (roll_no==$adm) found ${q2.docs.length} docs');
      
      final q3 = await _results.where('admissionNo', isEqualTo: adm).get();
      debugPrint('DEBUG: [streamResultsForStudent] Query (admissionNo==$adm) found ${q3.docs.length} docs');

      final q4 = await _results.where('name', isEqualTo: name).get();
      debugPrint('DEBUG: [streamResultsForStudent] Query (name==$name) found ${q4.docs.length} docs');

      final Map<String, TestResult> resultsMap = {};
      
      // Order of priority: name < roll_no < admissionNo < studentId
      for (var doc in q4.docs) resultsMap[doc.id] = TestResult.fromDoc(doc.id, doc.data());
      for (var doc in q2.docs) resultsMap[doc.id] = TestResult.fromDoc(doc.id, doc.data());
      for (var doc in q3.docs) resultsMap[doc.id] = TestResult.fromDoc(doc.id, doc.data());
      for (var doc in q1.docs) resultsMap[doc.id] = TestResult.fromDoc(doc.id, doc.data());

      final finalResults = resultsMap.values.toList()
        ..sort((a, b) => b.testName.compareTo(a.testName));

      debugPrint('DEBUG: [streamResultsForStudent] Final Merged Count for ${student.name}: ${finalResults.length}');
      return finalResults;
    });
  }

  // Same robust logic for StudentReport
  Stream<List<StudentReport>> streamRobustReportsForStudent(Student student) {
    final String sid = student.studentId;
    final String adm = student.admissionNo;
    final String name = student.name;

    debugPrint('DEBUG: [streamRobustReportsForStudent] Fetching reports for ${student.name}');

    return _studentReports.snapshots().map((_) => []).asyncMap((_) async {
      final snapshots = await Future.wait([
        _studentReports.where('studentId', isEqualTo: sid).get(),
        _studentReports.where('roll_no', isEqualTo: adm).get(),
        _studentReports.where('admissionNo', isEqualTo: adm).get(),
        _studentReports.where('name', isEqualTo: name).get(),
      ]);
      
      final Map<String, StudentReport> reportsMap = {};
      for (var doc in snapshots[3].docs) reportsMap[doc.id] = StudentReport.fromDoc(doc);
      for (var doc in snapshots[1].docs) reportsMap[doc.id] = StudentReport.fromDoc(doc);
      for (var doc in snapshots[2].docs) reportsMap[doc.id] = StudentReport.fromDoc(doc);
      for (var doc in snapshots[0].docs) reportsMap[doc.id] = StudentReport.fromDoc(doc);
      
      final list = reportsMap.values.toList()
        ..sort((a, b) {
          final da = a.publishedAt ?? DateTime(0);
          final db = b.publishedAt ?? DateTime(0);
          return db.compareTo(da);
        });
      
      debugPrint('DEBUG: [streamRobustReportsForStudent] Found ${list.length} reports for ${student.name}');
      return list;
    });
  }

  Future<TestInfo?> getTest(String testId) async {
    if (testId.isEmpty) return null;
    final doc = await _tests.doc(testId).get();
    if (!doc.exists) return null;
    return TestInfo.fromDoc(doc);
  }

  Future<QuestionPaper?> getQuestionPaper(String questionPaperId) async {
    if (questionPaperId.isEmpty) return null;
    final doc = await _questionPapers.doc(questionPaperId).get();
    if (!doc.exists) return null;
    return QuestionPaper.fromDoc(doc);
  }

  Future<TestResult?> getResult(String testId, String studentId) async {
    final doc = await _results.doc('${testId}_$studentId').get();
    if (!doc.exists) return null;
    return TestResult.fromDoc(doc.id, doc.data()!);
  }

  Future<List<ResultWithTestInfo>> fetchAllResultsWithTestInfo(
    String studentId,
  ) async {
    final results = await fetchResultsForStudent(studentId);
    final paired = await Future.wait(results.map((r) async {
      final info = await getTest(r.testId);
      return ResultWithTestInfo(r, info);
    }));
    paired.sort((a, b) {
      final da = a.testInfo?.parsedDate;
      final db = b.testInfo?.parsedDate;
      if (da == null && db == null) return 0;
      if (da == null) return -1;
      if (db == null) return 1;
      return da.compareTo(db);
    });
    return paired;
  }

  Future<List<StaffRole>> findStaffRolesForEmail(String email) async {
    if (email.isEmpty) return [];
    final searchEmail = email.trim().toLowerCase();
    final List<StaffRole> roles = [];

    try {
      final staffSnap = await _db.collectionGroup('staff').get();
      for (final doc in staffSnap.docs) {
        final res = await _verifyStaffDoc(doc, searchEmail);
        if (res != null) roles.add(res);
      }

      if (roles.isEmpty) {
        final schoolsSnap = await _db.collection('schools').get();
        for (final schoolDoc in schoolsSnap.docs) {
          final staffColSnap = await schoolDoc.reference.collection('staff').get();
          for (final staffDoc in staffColSnap.docs) {
            final res = await _verifyStaffDoc(staffDoc, searchEmail, schoolDoc: schoolDoc);
            if (res != null) roles.add(res);
          }
        }
      }
    } catch (e) {
      debugPrint('DEBUG: Error finding staff roles: $e');
    }
    return roles;
  }

  Future<StaffRole?> _verifyStaffDoc(
    DocumentSnapshot<Map<String, dynamic>> staffDoc,
    String searchEmail, {
    DocumentSnapshot<Map<String, dynamic>>? schoolDoc,
  }) async {
    final data = staffDoc.data() ?? {};
    final docEmail = (data['email'] ?? '').toString().trim().toLowerCase();
    final role = (data['role'] ?? '').toString().trim().toLowerCase();
    final status = (data['status'] ?? '').toString().trim().toLowerCase();

    if (docEmail != searchEmail) return null;
    if (status != 'active') return null;
    if (role != 'admin' && role != 'staff' && role != 'teacher') return null;

    DocumentSnapshot<Map<String, dynamic>>? finalSchoolDoc = schoolDoc;
    if (finalSchoolDoc == null) {
      final schoolRef = staffDoc.reference.parent.parent;
      if (schoolRef != null) {
        finalSchoolDoc = await schoolRef.get();
      }
    }

    if (finalSchoolDoc == null || !finalSchoolDoc.exists) return null;

    return StaffRole.fromDocs(staffDoc: staffDoc, schoolDoc: finalSchoolDoc);
  }

  Stream<List<Student>> streamStudentsBySections(List<String> sectionIds) {
    if (sectionIds.isEmpty) return Stream.value([]);

    return _students.where('sectionId', whereIn: sectionIds).snapshots().map((s) {
      final students = s.docs.map(Student.fromDoc).toList();
      return students..sort((a, b) => a.name.compareTo(b.name));
    });
  }

  Stream<List<StudentReport>> streamAllReportsForStudent(String studentId) {
    return _studentReports.where('studentId', isEqualTo: studentId).snapshots().map((s) {
      final reports = s.docs.map(StudentReport.fromDoc).toList()
        ..sort((a, b) {
          final da = a.publishedAt ?? DateTime(0);
          final db = b.publishedAt ?? DateTime(0);
          return db.compareTo(da);
        });
      return reports;
    });
  }

  /// Loads a single report by its document id ("{testId}_{studentId}").
  /// Used by push-notification navigation. Firestore security rules still
  /// enforce that the parent may only read a report for a student they claimed.
  Future<StudentReport?> getReportById(String reportId) async {
    if (reportId.isEmpty) return null;
    final doc = await _studentReports.doc(reportId).get();
    if (!doc.exists) return null;
    return StudentReport.fromDoc(doc);
  }

  /// Stamps a report as viewed by the given parent uid.
  Future<void> markReportViewed(StudentReport report, String uid) async {
    if (report.docId.isEmpty) return;
    await _studentReports.doc(report.docId).set(
      {
        'viewedAt': FieldValue.serverTimestamp(),
        'viewedBy': uid,
        'status': 'viewed',
      },
      SetOptions(merge: true),
    );
  }
}
