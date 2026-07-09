import 'package:flutter/material.dart';
import '../models/result.dart';
import '../models/student.dart';
import '../services/firestore_service.dart';
import 'student_report_screen.dart';

/// Shows a student's profile and all their test results.
class StudentProfileScreen extends StatelessWidget {
  final Student student;
  const StudentProfileScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(student.name),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          // ── Student info card ──────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            padding: const EdgeInsets.all(16),
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
                  radius: 32,
                  backgroundColor: Colors.indigo.shade700,
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      const SizedBox(height: 4),
                      _InfoRow(
                          icon: Icons.badge_outlined,
                          text:
                              'Admission No: ${student.admissionNo}'),
                      _InfoRow(
                          icon: Icons.class_outlined,
                          text: 'Class: ${student.studentClass}'),
                      _InfoRow(
                          icon: Icons.format_list_numbered,
                          text: 'Roll No: ${student.rollNo}'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Section title ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Row(
              children: [
                const Icon(Icons.assignment_outlined,
                    size: 18, color: Colors.indigo),
                const SizedBox(width: 6),
                Text('Test Results',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // ── Results list ───────────────────────────────────
          Expanded(
            child: StreamBuilder<List<TestResult>>(
              stream: firestore
                  .streamResultsForStudent(student.studentId),
              builder: (context, snap) {
                if (snap.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                final results = snap.data ?? [];
                if (results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 64,
                            color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No test results yet.',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(height: 8),
                        Text(
                          'Results will appear here once\ntests are published.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(14, 4, 14, 20),
                  itemCount: results.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) =>
                      _ResultCard(result: results[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Small info row with icon
// ─────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Result card in the list
// ─────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final TestResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudentReportScreen(result: result),
        ),
      ),
      child: Container(
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
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Test name + grade badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      result.testName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                  _GradeBadge(result.overallGrade),
                ],
              ),
              const SizedBox(height: 10),

              // Score + percentage pills
              Row(
                children: [
                  _ScorePill(
                    icon: Icons.score,
                    label: 'Score',
                    value:
                        '${result.totalCorrect}/${result.totalQuestions}',
                    color: Colors.indigo,
                  ),
                  const SizedBox(width: 8),
                  _ScorePill(
                    icon: Icons.percent,
                    label: 'Percentage',
                    value:
                        '${result.overallPercentage.toStringAsFixed(1)}%',
                    color: Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Subject chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: result.subjectScores.entries.map((e) {
                  final s = e.value;
                  final color = _subjectColor(e.key);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: color.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${_shortSubject(e.key)}: ${s.correct}/${s.total}',
                      style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Tap to view full report',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400)),
                  Icon(Icons.chevron_right,
                      size: 16, color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
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

  String _shortSubject(String s) {
    switch (s.toLowerCase()) {
      case 'mathematics':
        return 'Math';
      case 'physics':
        return 'Phy';
      case 'chemistry':
        return 'Chem';
      case 'mat':
        return 'MAT';
      default:
        return s.length > 4 ? s.substring(0, 4) : s;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Score pill
// ─────────────────────────────────────────────────────────────
class _ScorePill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _ScorePill(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: color)),
              Text(label,
                  style: TextStyle(
                      fontSize: 9, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Grade badge
// ─────────────────────────────────────────────────────────────
class _GradeBadge extends StatelessWidget {
  final String grade;
  const _GradeBadge(this.grade);

  @override
  Widget build(BuildContext context) {
    final color = _gradeColor(grade);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(grade,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14)),
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
