import 'package:flutter/material.dart';
import '../models/result.dart';

/// Shows question-wise breakdown for a single test result.
class ResultDetailScreen extends StatelessWidget {
  final TestResult result;
  const ResultDetailScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(result.testName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.studentName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatBox(
                            label: 'Total Score',
                            value:
                                '${result.totalCorrect}/${result.totalQuestions}'),
                        _StatBox(
                            label: 'Percentage',
                            value:
                                '${result.overallPercentage.toStringAsFixed(1)}%'),
                        _StatBox(
                            label: 'Grade',
                            value: result.overallGrade,
                            color: _gradeColor(result.overallGrade)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Per subject breakdown
            ...result.subjectScores.entries.map((entry) {
              final subject = entry.key;
              final score = entry.value;
              return _SubjectSection(subject: subject, score: score);
            }),
          ],
        ),
      ),
    );
  }

  Color _gradeColor(String g) {
    switch (g) {
      case 'A+':
      case 'A':
        return Colors.green;
      case 'B+':
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
}

/// Returns the answer type for a given answer value.
/// R = correct, S = skipped, anything else (A/B/C/D) = wrong
enum _AnswerType { correct, skipped, wrong }

_AnswerType _getAnswerType(String value) {
  if (value == 'R') return _AnswerType.correct;
  if (value == 'S') return _AnswerType.skipped;
  return _AnswerType.wrong;
}

class _SubjectSection extends StatelessWidget {
  final String subject;
  final SubjectScore score;
  const _SubjectSection({required this.subject, required this.score});

  @override
  Widget build(BuildContext context) {
    // Sort questions by number
    final sortedAnswers = score.answers.entries.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.key.replaceAll('Q', '')) ?? 0;
        final bNum = int.tryParse(b.key.replaceAll('Q', '')) ?? 0;
        return aNum.compareTo(bNum);
      });

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subject header
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _subjectColor(subject).withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Text(subject,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _subjectColor(subject),
                        fontSize: 15)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _subjectColor(subject).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${score.correct}/${score.total}  •  ${score.percentage.toStringAsFixed(0)}%  •  ${score.grade}',
                    style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: _subjectColor(subject),
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score.total == 0 ? 0 : score.correct / score.total,
                backgroundColor: Colors.grey.shade200,
                color: _subjectColor(subject),
                minHeight: 6,
              ),
            ),
          ),

          // Question grid
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sortedAnswers.map((entry) {
                final answerType = _getAnswerType(entry.value);
                final qNum = entry.key.replaceAll('Q', '');

                // Colors based on answer type
                Color bgColor;
                Color borderColor;
                Color textColor;
                IconData icon;

                switch (answerType) {
                  case _AnswerType.correct:
                    bgColor = Colors.green.shade50;
                    borderColor = Colors.green.shade300;
                    textColor = Colors.green.shade700;
                    icon = Icons.check;
                    break;
                  case _AnswerType.skipped:
                    bgColor = Colors.grey.shade100;
                    borderColor = Colors.grey.shade400;
                    textColor = Colors.grey.shade600;
                    icon = Icons.remove;
                    break;
                  case _AnswerType.wrong:
                    bgColor = Colors.red.shade50;
                    borderColor = Colors.red.shade300;
                    textColor = Colors.red.shade700;
                    icon = Icons.close;
                    break;
                }

                return Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Q$qNum',
                        style: TextStyle(fontSize: 9, color: textColor),
                      ),
                      Icon(icon, size: 16, color: textColor),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Legend
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                // Correct
                Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                const Text('Correct',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 12),
                // Wrong
                Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                const Text('Wrong',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 12),
                // Skipped
                Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                const Text('Skipped',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _subjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
        return Colors.blue;
      case 'physics':
        return Colors.orange;
      case 'chemistry':
        return Colors.green;
      case 'mat':
        return Colors.purple;
      default:
        return Colors.indigo;
    }
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatBox({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 20, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
