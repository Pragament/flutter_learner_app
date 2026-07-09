import 'package:cloud_firestore/cloud_firestore.dart';

/// A parent-facing test report from the `studentReports` collection.
///
/// Real fields already in Firestore:
///   name              : "AVUSALI SRESHTA"
///   studentId         : "6912aa8a3058bd21b7f7578f"  ← FK to students.studentId
///   testId            : "6912c320b9488e3c00ee8514"
///   testName          : "RHS State 6A IIT Nov 7 2025"
///   totalMarks        : 55
///   overallGrade      : "E or F"
///   overallRank       : 12
///   overallPercentile : 7.69
///   mathematics / mathematicsGrade / mathematicsRank / ... (per subject)
///
/// Fields WE ADD (not yet in Firestore — migration script needed):
///   published   : false          ← teacher flips to true → n8n starts reminders
///   publishedAt : null
///   viewedAt    : null           ← app writes this when parent opens the report
///   viewedBy    : null           ← uid of parent who viewed
///   status      : "pending"      ← "pending" | "published" | "viewed"
///   parentPhone : ""             ← for SMS/WhatsApp reminders
class Report {
  final String docId;
  final String studentId;
  final String studentName;
  final String testId;
  final String testName;
  final int totalMarks;
  final String overallGrade;
  final int overallRank;
  final double overallPercentile;

  // Subject scores
  final String mathematics;
  final String mathematicsGrade;
  final String mathematicsRank;
  final String physics;
  final String physicsGrade;
  final String chemistry;
  final String chemistryGrade;
  final String mat;
  final String matGrade;

  // Fields we add
  final bool published;
  final DateTime? publishedAt;
  final DateTime? viewedAt;
  final String status; // "pending" | "published" | "viewed"

  Report({
    required this.docId,
    required this.studentId,
    required this.studentName,
    required this.testId,
    required this.testName,
    required this.totalMarks,
    required this.overallGrade,
    required this.overallRank,
    required this.overallPercentile,
    required this.mathematics,
    required this.mathematicsGrade,
    required this.mathematicsRank,
    required this.physics,
    required this.physicsGrade,
    required this.chemistry,
    required this.chemistryGrade,
    required this.mat,
    required this.matGrade,
    required this.published,
    required this.publishedAt,
    required this.viewedAt,
    required this.status,
  });

  bool get isViewed => viewedAt != null;
  bool get isPublished => published;

  factory Report.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Report(
      docId: doc.id,
      studentId: (d['studentId'] ?? '').toString(),
      studentName: (d['name'] ?? '').toString(),
      testId: (d['testId'] ?? '').toString(),
      testName: (d['testName'] ?? 'Report').toString(),
      totalMarks: (d['totalMarks'] as num?)?.toInt() ?? 0,
      overallGrade: (d['overallGrade'] ?? '').toString(),
      overallRank: (d['overallRank'] as num?)?.toInt() ?? 0,
      overallPercentile: (d['overallPercentile'] as num?)?.toDouble() ?? 0.0,
      mathematics: (d['mathematics'] ?? '').toString(),
      mathematicsGrade: (d['mathematicsGrade'] ?? '').toString(),
      mathematicsRank: (d['mathematicsRank'] ?? '').toString(),
      physics: (d['physics'] ?? '').toString(),
      physicsGrade: (d['physicsGrade'] ?? '').toString(),
      chemistry: (d['chemistry'] ?? '').toString(),
      chemistryGrade: (d['chemistryGrade'] ?? '').toString(),
      mat: (d['mat'] ?? '').toString(),
      matGrade: (d['matGrade'] ?? '').toString(),
      // newly added fields — default safely if not yet in doc
      published: (d['published'] as bool?) ?? false,
      publishedAt: (d['publishedAt'] as Timestamp?)?.toDate(),
      viewedAt: (d['viewedAt'] as Timestamp?)?.toDate(),
      status: (d['status'] ?? 'pending').toString(),
    );
  }
}
