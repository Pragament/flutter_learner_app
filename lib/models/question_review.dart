import 'question_paper.dart';
import 'result.dart';

/// A single question, joined with how this student answered it —
/// built by matching `results` doc fields like "Physics_Q28" against
/// a `QuestionPaper`'s "Physics_28" lookup key.
class QuestionReview {
  final int questionNumber;
  final String subject;
  final String chapter;
  final String topic;
  final String subtopic;
  final String questionText;
  final List<QuestionOption> options;
  final String correctLabel;
  final String rawAnswer; // "R", "S", or a letter (A/B/C/D)
  final String explanation;

  QuestionReview({
    required this.questionNumber,
    required this.subject,
    required this.chapter,
    required this.topic,
    required this.subtopic,
    required this.questionText,
    required this.options,
    required this.correctLabel,
    required this.rawAnswer,
    required this.explanation,
  });

  bool get isCorrect => rawAnswer == 'R';
  bool get isSkipped => rawAnswer == 'S' || rawAnswer.trim().isEmpty;
  bool get isWrong => !isCorrect && !isSkipped;

  /// The letter the student actually marked — resolves 'R' to the
  /// correct letter itself, since a correct answer's raw value is 'R',
  /// not the letter that was marked.
  String get yourAnswerLabel => isCorrect ? correctLabel : rawAnswer;

  String get yourAnswerText {
    if (isSkipped) return 'Skipped';
    final match = options.where((o) => o.label == yourAnswerLabel);
    if (match.isEmpty) return yourAnswerLabel;
    return '$yourAnswerLabel. ${match.first.text}';
  }

  String get correctAnswerText {
    final match = options.where((o) => o.label == correctLabel);
    if (match.isEmpty) return correctLabel;
    return '$correctLabel. ${match.first.text}';
  }
}

final _qFieldPattern = RegExp(r'^(.*)_Q(\d+)$');

/// Joins a parsed `TestResult`'s raw per-question answers against a
/// `QuestionPaper`'s question bank, producing a full reviewable list
/// sorted by question number.
List<QuestionReview> buildQuestionReviews(
  TestResult result,
  QuestionPaper paper,
) {
  final items = <QuestionReview>[];
  result.rawAnswers.forEach((rawKey, value) {
    final match = _qFieldPattern.firstMatch(rawKey);
    if (match == null) return;
    final subjectFromKey = match.group(1)!;
    final num = int.tryParse(match.group(2)!) ?? 0;
    final lookupKey = '${subjectFromKey}_$num';
    final detail = paper.questionsByKey[lookupKey];
    if (detail == null) return;

    items.add(QuestionReview(
      questionNumber: num,
      subject: detail.subject.isNotEmpty ? detail.subject : subjectFromKey,
      chapter: detail.chapter,
      topic: detail.topic,
      subtopic: detail.subtopic,
      questionText: detail.questionText,
      options: detail.options,
      correctLabel: detail.correctLabel,
      rawAnswer: value,
      explanation: detail.explanation,
    ));
  });
  items.sort((a, b) => a.questionNumber.compareTo(b.questionNumber));
  return items;
}

/// Builds a letters-only review for OMR results that have no `questionpapers`
/// link. Maps each `OmrAnswer` (selected/correct/status) onto the same
/// `QuestionReview` shape so it renders with the existing question card —
/// just without question text, options, or explanation.
List<QuestionReview> buildOmrQuestionReviews(TestResult result) {
  return result.omrAnswers.map((a) {
    // rawAnswer drives the card's status: "R" = correct, "" = unmarked/skipped,
    // otherwise the student's selected letter (a wrong answer).
    final raw = a.status == 'correct'
        ? 'R'
        : a.status == 'unmarked'
            ? ''
            : a.selected;
    return QuestionReview(
      questionNumber: a.number,
      subject: '',
      chapter: '',
      topic: '',
      subtopic: '',
      questionText: '',
      options: const [],
      correctLabel: a.correct,
      rawAnswer: raw,
      explanation: '',
    );
  }).toList();
}
