import 'package:flutter/material.dart';

import '../models/student_report.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Opens a report and stamps viewedAt — the cron stop signal.
class ReportViewScreen extends StatefulWidget {
  final StudentReport report;
  const ReportViewScreen({super.key, required this.report});

  @override
  State<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends State<ReportViewScreen> {
  final _firestore = FirestoreService();
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    final uid = _auth.currentUser?.uid ?? '';
    _firestore.markReportViewed(widget.report, uid);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return Scaffold(
      appBar: AppBar(title: Text(r.testName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.testName,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text('Student: ${r.studentName}',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StatBox(label: 'Total Marks',
                            value: r.totalMarks.toString()),
                        _StatBox(label: 'Grade', value: r.overallGrade),
                        _StatBox(label: 'Rank',
                            value: r.overallRank > 0
                                ? '#${r.overallRank}'
                                : '-'),
                        _StatBox(
                          label: 'Percentile',
                          value: r.overallPercentile > 0
                              ? '${r.overallPercentile.toStringAsFixed(1)}%'
                              : '-',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Text('Subject Breakdown',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            // Subject rows — only show if value is non-empty
            if (r.mathematics.isNotEmpty)
              _SubjectRow('Mathematics', r.mathematics, r.mathematicsGrade,
                  r.mathematicsRank),
            if (r.physics.isNotEmpty)
              _SubjectRow('Physics', r.physics, r.physicsGrade, ''),
            if (r.chemistry.isNotEmpty)
              _SubjectRow('Chemistry', r.chemistry, r.chemistryGrade, ''),
            if (r.mat.isNotEmpty)
              _SubjectRow('MAT', r.mat, r.matGrade, ''),

            if (r.mathematics.isEmpty &&
                r.physics.isEmpty &&
                r.chemistry.isEmpty &&
                r.mat.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Subject-wise breakdown not available.',
                    style: TextStyle(color: Colors.grey)),
              ),

            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Text('Marked as viewed',
                    style: TextStyle(color: Colors.green.shade700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey)),
      ],
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final String subject;
  final String marks;
  final String grade;
  final String rank;
  const _SubjectRow(this.subject, this.marks, this.grade, this.rank);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(subject),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (marks.isNotEmpty) _Chip(marks),
            if (grade.isNotEmpty) _Chip(grade),
            if (rank.isNotEmpty) _Chip('Rank $rank'),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onPrimaryContainer)),
    );
  }
}
