import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report.dart';
import '../models/result.dart';
import '../models/student.dart';

enum ClaimResult { success, notFound, alreadyClaimed, noPhoneOnRecord }

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

  Future<void> saveFcmToken(String uid, String token) {
    return _users.doc(uid).set(
      {'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// Claim student using schoolCode + admissionNo + phoneNumber
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

  /// Stream claimed students
  Stream<List<Student>> streamClaimedStudents(String uid) {
    return _students
        .where('parentIds', arrayContains: uid)
        .snapshots()
        .map((s) => s.docs.map(Student.fromDoc).toList());
  }

  /// Stream published reports for claimed students
  Stream<List<Report>> streamPublishedReports(List<String> studentIds) {
    if (studentIds.isEmpty) return Stream.value(const []);
    final ids =
        studentIds.length > 30 ? studentIds.sublist(0, 30) : studentIds;
    return _studentReports
        .where('studentId', whereIn: ids)
        .where('published', isEqualTo: true)
        .orderBy('publishedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(Report.fromDoc).toList());
  }

  /// Fetch ALL results for a student using their studentId
  /// Results collection has docs with studentId field
  Future<List<TestResult>> fetchResultsForStudent(String studentId) async {
    final snap = await _results
        .where('studentId', isEqualTo: studentId)
        .get();
    return snap.docs
        .map((d) => TestResult.fromDoc(d.id, d.data()))
        .toList()
      ..sort((a, b) => b.testName.compareTo(a.testName));
  }

  /// Stream results for a student (real-time)
  Stream<List<TestResult>> streamResultsForStudent(String studentId) {
    return _results
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((s) => s.docs
            .map((d) => TestResult.fromDoc(d.id, d.data()))
            .toList()
          ..sort((a, b) => b.testName.compareTo(a.testName)));
  }

  Future<void> markReportViewed(Report report, String uid) async {
    if (report.isViewed) return;
    await _studentReports.doc(report.docId).update({
      'viewedAt': FieldValue.serverTimestamp(),
      'viewedBy': uid,
      'status': 'viewed',
    });
  }
}
