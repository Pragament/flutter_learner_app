import 'package:flutter/material.dart';
import '../models/result.dart';

/// Rich report page shown when parent taps a test result.
/// Matches the technikh.com report style with subject breakdown,
/// per-question grid (Correct / Wrong / Skipped), and overall stats.
class StudentReportScreen extends StatelessWidget {
  final TestResult result;
  const StudentReportScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(result.testName,
            style: const TextStyle(fontSize: 15)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Student name banner ──────────────────────────────
            _StudentBanner(result: result),
            const SizedBox(height: 12),

            // ── Overall stats row ────────────────────────────────
            _OverallStatsRow(result: result),
            const SizedBox(height: 16),

            // ── Subject cards ────────────────────────────────────
            ...result.subjectScores.entries.map((e) =>
                _SubjectCard(subject: e.key, score: e.value)),

            // ── Legend ───────────────────────────────────────────
            const SizedBox(height: 4),
            _Legend(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Student Banner
// ─────────────────────────────────────────────────────────────
class _StudentBanner extends StatelessWidget {
  final TestResult result;
  const _StudentBanner({required this.result});

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
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Overall Stats Row
// ─────────────────────────────────────────────────────────────
class _OverallStatsRow extends StatelessWidget {
  final TestResult result;
  const _OverallStatsRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final grade = result.overallGrade;
    final gradeColor = _gradeColor(grade);

    return Row(
      children: [
        // Score box
        Expanded(
          child: _StatCard(
            label: 'Total Score',
            value: '${result.totalCorrect}/${result.totalQuestions}',
            icon: Icons.score,
            color: Colors.indigo,
          ),
        ),
        const SizedBox(width: 10),
        // Percentage box
        Expanded(
          child: _StatCard(
            label: 'Percentage',
            value: '${result.overallPercentage.toStringAsFixed(1)}%',
            icon: Icons.percent,
            color: Colors.teal,
          ),
        ),
        const SizedBox(width: 10),
        // Grade box
        Expanded(
          child: _StatCard(
            label: 'Grade',
            value: grade,
            icon: Icons.military_tech,
            color: gradeColor,
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
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Subject Card
// ─────────────────────────────────────────────────────────────
class _SubjectCard extends StatelessWidget {
  final String subject;
  final SubjectScore score;
  const _SubjectCard({required this.subject, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = _subjectColor(subject);

    // Sort questions numerically
    final sortedAnswers = score.answers.entries.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a.key.replaceAll('Q', '')) ?? 0;
        final bNum = int.tryParse(b.key.replaceAll('Q', '')) ?? 0;
        return aNum.compareTo(bNum);
      });

    // Count answer types
    final correct = sortedAnswers.where((e) => e.value == 'R').length;
    final skipped = sortedAnswers.where((e) => e.value == 'S').length;
    final wrong = sortedAnswers.length - correct - skipped;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Subject header ──────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 10),
                Text(subject,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 15)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${score.correct}/${score.total}  •  ${score.percentage.toStringAsFixed(0)}%  •  ${score.grade}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color),
                  ),
                ),
              ],
            ),
          ),

          // ── Mini stats row ──────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _MiniStat(
                    count: correct,
                    label: 'Correct',
                    color: Colors.green.shade600),
                const SizedBox(width: 16),
                _MiniStat(
                    count: wrong,
                    label: 'Wrong',
                    color: Colors.red.shade600),
                const SizedBox(width: 16),
                _MiniStat(
                    count: skipped,
                    label: 'Skipped',
                    color: Colors.grey.shade500),
                const Spacer(),
              ],
            ),
          ),

          // ── Progress bar ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score.total == 0
                    ? 0
                    : score.correct / score.total,
                backgroundColor: Colors.grey.shade200,
                color: color,
                minHeight: 7,
              ),
            ),
          ),

          // ── Question grid ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sortedAnswers.map((entry) {
                final type = _answerType(entry.value);
                final qNum = entry.key.replaceAll('Q', '');

                Color bg, border, fg;
                IconData icon;

                switch (type) {
                  case _AType.correct:
                    bg = Colors.green.shade50;
                    border = Colors.green.shade300;
                    fg = Colors.green.shade700;
                    icon = Icons.check;
                    break;
                  case _AType.skipped:
                    bg = Colors.grey.shade100;
                    border = Colors.grey.shade400;
                    fg = Colors.grey.shade600;
                    icon = Icons.remove;
                    break;
                  case _AType.wrong:
                    bg = Colors.red.shade50;
                    border = Colors.red.shade300;
                    fg = Colors.red.shade700;
                    icon = Icons.close;
                    break;
                }

                return Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Q$qNum',
                          style:
                              TextStyle(fontSize: 9, color: fg)),
                      Icon(icon, size: 16, color: fg),
                    ],
                  ),
                );
              }).toList(),
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

  _AType _answerType(String v) {
    if (v == 'R') return _AType.correct;
    if (v == 'S') return _AType.skipped;
    return _AType.wrong;
  }
}

enum _AType { correct, skipped, wrong }

// ─────────────────────────────────────────────────────────────
// Mini stat (Correct / Wrong / Skipped count)
// ─────────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _MiniStat(
      {required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('$count $label',
            style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Legend
// ─────────────────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(color: Colors.green.shade300, label: 'Correct'),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.red.shade300, label: 'Wrong'),
        const SizedBox(width: 16),
        _LegendItem(color: Colors.grey.shade400, label: 'Skipped'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                border: Border.all(color: color),
                borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }
}
