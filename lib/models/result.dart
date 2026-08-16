/// A raw OMR result from the `results` collection.
/// Fields: subject_QN = "R" (correct) or letter (wrong)
/// Also has: name, studentId, testId, testName
class SubjectScore {
  final String subject;
  final int correct;
  final int total;
  final Map<String, String> answers; // Q1 -> "R" or letter

  SubjectScore({
    required this.subject,
    required this.correct,
    required this.total,
    required this.answers,
  });

  double get percentage => total == 0 ? 0 : (correct / total) * 100;
  String get grade {
    final p = percentage;
    if (p >= 90) return 'A+';
    if (p >= 80) return 'A';
    if (p >= 70) return 'B+';
    if (p >= 60) return 'B';
    if (p >= 50) return 'C';
    if (p >= 40) return 'D';
    return 'F';
  }
}

/// One question from an OMR result's `questionReview` map — the student's
/// actual selected letter, the correct letter, and the status. Used for OMR
/// tests that have no rich `questionpapers` link (letters only).
class OmrAnswer {
  final int number;
  final String selected;
  final String correct;
  final String status; // "correct" | "wrong" | "unmarked"

  OmrAnswer({
    required this.number,
    required this.selected,
    required this.correct,
    required this.status,
  });
}

class TestResult {
  final String docId;
  final String studentId;
  final String studentName;
  final String testId;
  final String testName;
  final Map<String, SubjectScore> subjectScores;
  final Map<String, String> rawAnswers;
  final List<OmrAnswer> omrAnswers;
  final double omrScore;

  TestResult({
    required this.docId,
    required this.studentId,
    required this.studentName,
    required this.testId,
    required this.testName,
    required this.subjectScores,
    required this.rawAnswers,
    this.omrAnswers = const [],
    this.omrScore = 0,
  });

  bool get hasOmrReview => omrAnswers.isNotEmpty;

  int get totalCorrect => subjectScores.isNotEmpty
      ? subjectScores.values.fold(0, (sum, s) => sum + s.correct)
      : omrAnswers.where((q) => q.status == 'correct').length;
  int get totalQuestions => subjectScores.isNotEmpty
      ? subjectScores.values.fold(0, (sum, s) => sum + s.total)
      : omrAnswers.length;
  double get overallPercentage =>
      totalQuestions == 0 ? 0 : (totalCorrect / totalQuestions) * 100;
  String get overallGrade {
    final p = overallPercentage;
    if (p >= 90) return 'A+';
    if (p >= 80) return 'A';
    if (p >= 70) return 'B+';
    if (p >= 60) return 'B';
    if (p >= 50) return 'C';
    if (p >= 40) return 'D';
    return 'F';
  }

  /// Parse a results doc from Firestore
  factory TestResult.fromDoc(String docId, Map<String, dynamic> data) {
    final studentId = data['studentId']?.toString() ?? '';
    final studentName = data['name']?.toString() ?? '';
    final testId = data['testId']?.toString() ?? '';
    final testName = data['testName']?.toString() ?? '';

    // Collect all subject_QN fields
    final rawAnswers = <String, String>{};
    final subjectAnswers = <String, Map<String, String>>{};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value?.toString() ?? '';

      // Skip non-question fields
      if (['studentId', 'name', 'testId', 'testName', 'sectionId']
          .contains(key)) continue;

      // Parse "Subject_QN" format e.g. "Mathematics_Q1"
      final parts = key.split('_');
      if (parts.length >= 2) {
        // Subject is everything before last part
        final qPart = parts.last; // e.g. "Q1"
        if (qPart.startsWith('Q')) {
          final subject = parts
              .sublist(0, parts.length - 1)
              .join('_'); // e.g. "Mathematics"
          subjectAnswers.putIfAbsent(subject, () => {})[qPart] = value;
          rawAnswers[key] = value;
        }
      }
    }

    // Build SubjectScore for each subject
    final subjectScores = <String, SubjectScore>{};
    for (final subjectEntry in subjectAnswers.entries) {
      final subject = subjectEntry.key;
      final answers = subjectEntry.value;
      final correct = answers.values.where((v) => v == 'R').length;
      subjectScores[subject] = SubjectScore(
        subject: subject,
        correct: correct,
        total: answers.length,
        answers: answers,
      );
    }

    // OMR letter-level review (selected/correct/status per question), written by
    // the Test Manager for tests without a rich questionpapers link.
    final omrAnswers = <OmrAnswer>[];
    final reviewRaw = data['questionReview'];
    if (reviewRaw is Map) {
      reviewRaw.forEach((k, v) {
        if (v is! Map) {
          return;
        }
        omrAnswers.add(OmrAnswer(
          number: int.tryParse(k.toString()) ?? 0,
          selected: (v['selected'] ?? '').toString(),
          correct: (v['correct'] ?? '').toString(),
          status: (v['status'] ?? '').toString(),
        ));
      });
      omrAnswers.sort((a, b) => a.number.compareTo(b.number));
    }
    // `score` may be a number (num) or a string ("51.0") depending on the writer,
    // so resolve it defensively — a bad cast here would crash the whole results
    // stream and hide every result, not just this one.
    final scoreRaw = data['score'];
    final double omrScore = scoreRaw is num
        ? scoreRaw.toDouble()
        : double.tryParse(scoreRaw?.toString() ?? '') ?? 0;

    return TestResult(
      docId: docId,
      studentId: studentId,
      studentName: studentName,
      testId: testId,
      testName: testName,
      subjectScores: subjectScores,
      rawAnswers: rawAnswers,
      omrAnswers: omrAnswers,
      omrScore: omrScore,
    );
  }
}
