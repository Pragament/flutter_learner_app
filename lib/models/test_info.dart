import 'package:cloud_firestore/cloud_firestore.dart';

/// A `tests` document — links a test to its question paper for
/// building a detailed, question-by-question report.
class TestInfo {
  final String testId;
  final String testName;
  final String questionPaperId;
  final String sectionId;
  final String testDate;

  TestInfo({
    required this.testId,
    required this.testName,
    required this.questionPaperId,
    required this.sectionId,
    required this.testDate,
  });

  DateTime? get parsedDate => DateTime.tryParse(testDate);

  factory TestInfo.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return TestInfo(
      testId: doc.id,
      testName: (d['testName'] ?? '').toString(),
      // Firestore field is "questionPaperID" (capital ID), not the
      // camelCase "questionPaperId" you'd otherwise expect.
      questionPaperId: (d['questionPaperID'] ?? '').toString(),
      sectionId: (d['sectionId'] ?? '').toString(),
      testDate: (d['testDate'] ?? '').toString(),
    );
  }
}
