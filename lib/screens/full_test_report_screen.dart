import 'package:flutter/material.dart';
import '../models/question_paper.dart';
import '../models/question_review.dart';
import '../models/result.dart';
import '../models/test_info.dart';
import '../services/firestore_service.dart';

/// Full per-test report: overall stats, per-subject breakdown, and a
/// question-by-question review with the actual question text, options,
/// and explanation — joined from `tests` + `questionpapers` against the
/// student's raw `results` answers.
class FullTestReportScreen extends StatelessWidget {
  final TestResult result;
  const FullTestReportScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(result.testName, style: const TextStyle(fontSize: 15)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: FutureBuilder<TestInfo?>(
        future: firestore.getTest(result.testId),
        builder: (context, testSnap) {
          if (testSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final testInfo = testSnap.data;

          return FutureBuilder<QuestionPaper?>(
            future: testInfo == null
                ? Future.value(null)
                : firestore.getQuestionPaper(testInfo.questionPaperId),
            builder: (context, paperSnap) {
              if (paperSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final paper = paperSnap.data;
              final reviews =
                  paper != null ? buildQuestionReviews(result, paper) : null;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderCard(result: result),
                    const SizedBox(height: 12),
                    _OverallStatsRow(result: result),
                    const SizedBox(height: 16),
                    ...result.subjectScores.entries
                        .map((e) => _SubjectCard(subject: e.key, score: e.value)),
                    const SizedBox(height: 20),
                    Text('Question Review',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (reviews == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Question-by-question review is not available for this test '
                          '(missing question paper link).',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    else if (reviews.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text('No matching questions found.',
                            style: TextStyle(color: Colors.grey.shade600)),
                      )
                    else
                      ...reviews.map((r) => _QuestionCard(review: r)),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final TestResult result;
  const _HeaderCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.indigo.shade700,
            child: Text(
              result.studentName.isNotEmpty
                  ? result.studentName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.studentName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 2),
                Text(result.testName,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverallStatsRow extends StatelessWidget {
  final TestResult result;
  const _OverallStatsRow({required this.result});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Score',
            value: '${result.totalCorrect}/${result.totalQuestions}',
            icon: Icons.score,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Percentage',
            value: '${result.overallPercentage.toStringAsFixed(1)}%',
            icon: Icons.percent,
            color: Colors.teal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Grade',
            value: result.overallGrade,
            icon: Icons.military_tech,
            color: _gradeColor(result.overallGrade),
          ),
        ),
      ],
    );
  }

  Color _gradeColor(String g) {
    switch (g) {
      case 'A+':
      case 'A':
        return Colors.green.shade700;
      case 'B+':
      case 'B':
        return Colors.blue.shade700;
      case 'C':
        return Colors.orange.shade700;
      case 'D':
        return Colors.deepOrange.shade700;
      default:
        return Colors.red.shade700;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final String subject;
  final SubjectScore score;
  const _SubjectCard({required this.subject, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = _subjectColor(subject);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Text(subject,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 15)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${score.correct}/${score.total}  •  ${score.percentage.toStringAsFixed(0)}%  •  ${score.grade}',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Color _subjectColor(String s) {
    switch (s.toLowerCase()) {
      case 'mathematics':
        return Colors.blue.shade700;
      case 'physics':
        return Colors.orange.shade700;
      case 'chemistry':
        return Colors.green.shade700;
      case 'mat':
        return Colors.purple.shade700;
      default:
        return Colors.indigo.shade700;
    }
  }
}

class _QuestionCard extends StatelessWidget {
  final QuestionReview review;
  const _QuestionCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;
    if (review.isCorrect) {
      statusColor = Colors.green.shade700;
      statusLabel = 'Correct';
      statusIcon = Icons.check_circle;
    } else if (review.isSkipped) {
      statusColor = Colors.grey.shade600;
      statusLabel = 'Skipped';
      statusIcon = Icons.remove_circle_outline;
    } else {
      statusColor = Colors.red.shade700;
      statusLabel = 'Wrong';
      statusIcon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 5,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Question ${review.questionNumber}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                Icon(statusIcon, size: 15, color: statusColor),
                const SizedBox(width: 4),
                Text(statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [review.subject, review.chapter, review.topic, review.subtopic]
                  .where((s) => s.isNotEmpty)
                  .join(' › '),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(review.questionText,
                style: const TextStyle(fontSize: 14, height: 1.35)),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                      text: 'Your Answer: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12.5)),
                  TextSpan(
                    text: review.yourAnswerText,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: review.isCorrect
                            ? Colors.green.shade700
                            : review.isSkipped
                                ? Colors.grey.shade600
                                : Colors.red.shade700),
                  ),
                ],
              ),
            ),
            if (!review.isCorrect) ...[
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                        text: 'Correct Answer: ',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12.5)),
                    TextSpan(
                      text: review.correctAnswerText,
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            ...review.options.map((o) => _OptionRow(
                  option: o,
                  isYourAnswer: o.label == review.yourAnswerLabel && !review.isSkipped,
                )),
            if (review.explanation.isNotEmpty) ...[
              const SizedBox(height: 4),
              _ExplanationTile(text: review.explanation),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final QuestionOption option;
  final bool isYourAnswer;
  const _OptionRow({required this.option, required this.isYourAnswer});

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color border = Colors.grey.shade200;
    Color fg = Colors.black87;
    if (option.isCorrect) {
      bg = Colors.green.shade50;
      border = Colors.green.shade300;
      fg = Colors.green.shade800;
    } else if (isYourAnswer) {
      bg = Colors.red.shade50;
      border = Colors.red.shade300;
      fg = Colors.red.shade800;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('${option.label}.',
              style: TextStyle(fontWeight: FontWeight.bold, color: fg, fontSize: 12.5)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(option.text,
                style: TextStyle(color: fg, fontSize: 12.5)),
          ),
          if (option.isCorrect)
            Icon(Icons.check, size: 14, color: Colors.green.shade700)
          else if (isYourAnswer)
            Icon(Icons.close, size: 14, color: Colors.red.shade700),
        ],
      ),
    );
  }
}

class _ExplanationTile extends StatelessWidget {
  final String text;
  const _ExplanationTile({required this.text});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 6),
        title: Text('View Explanation',
            style: TextStyle(fontSize: 12.5, color: Colors.indigo.shade700)),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(text,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }
}
