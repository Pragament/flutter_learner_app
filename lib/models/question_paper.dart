import 'package:cloud_firestore/cloud_firestore.dart';

/// A single answer option (A/B/C/D) for a question.
class QuestionOption {
  final String label;
  final String text;
  final bool isCorrect;

  QuestionOption({
    required this.label,
    required this.text,
    required this.isCorrect,
  });
}

/// One question from a `questionpapers` document, with its options,
/// taxonomy (subject/chapter/topic/subtopic), and explanation.
class QuestionDetail {
  final String questionText;
  final String subject;
  final String chapter;
  final String topic;
  final String subtopic;
  final String explanation;
  final List<QuestionOption> options;
  final String correctLabel;

  QuestionDetail({
    required this.questionText,
    required this.subject,
    required this.chapter,
    required this.topic,
    required this.subtopic,
    required this.explanation,
    required this.options,
    required this.correctLabel,
  });

  factory QuestionDetail.fromMap(Map<String, dynamic> q) {
    const labels = ['A', 'B', 'C', 'D'];
    final options = <QuestionOption>[];
    for (var i = 0; i < labels.length; i++) {
      final raw = q['Option ${i + 1}'];
      if (raw is! Map) continue;
      final opt = Map<String, dynamic>.from(raw);
      options.add(QuestionOption(
        label: labels[i],
        text: (opt['optionText'] ?? '').toString(),
        isCorrect: opt['correct'] == true,
      ));
    }
    final correct = options.where((o) => o.isCorrect);
    final correctLabel = correct.isNotEmpty ? correct.first.label : '';

    return QuestionDetail(
      questionText: (q['Question'] ?? '').toString(),
      subject: (q['Subject'] ?? '').toString(),
      chapter: (q['Chapter'] ?? '').toString(),
      topic: (q['Topic'] ?? '').toString(),
      subtopic: (q['Subtopic'] ?? '').toString(),
      explanation: (q['feedbackCorrectAnswer'] ?? '').toString(),
      options: options,
      correctLabel: correctLabel,
    );
  }
}

/// A full question paper — questions keyed by their
/// `subjectname_questionnumber` value (e.g. "Physics_28"), which is the
/// exact join key back to a `results` doc's `Physics_Q28` field (minus the Q).
class QuestionPaper {
  final String questionPaperId;
  final Map<String, QuestionDetail> questionsByKey;

  QuestionPaper({
    required this.questionPaperId,
    required this.questionsByKey,
  });

  factory QuestionPaper.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final rawQuestions = (d['questions'] as List?) ?? [];
    final map = <String, QuestionDetail>{};
    for (final item in rawQuestions) {
      if (item is! Map) continue;
      final q = Map<String, dynamic>.from(item);
      final key = (q['subjectname_questionnumber'] ?? '').toString();
      if (key.isEmpty) continue;
      map[key] = QuestionDetail.fromMap(q);
    }
    return QuestionPaper(questionPaperId: doc.id, questionsByKey: map);
  }
}
