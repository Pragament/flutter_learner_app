import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/firestore_service.dart';
import 'full_test_report_screen.dart';

/// Aggregated progress for one subject across every test taken —
/// percentages kept in chronological order so `trend` can compare the
/// two most recent tests.
class _SubjectAgg {
  int tests = 0;
  int correct = 0;
  int wrong = 0;
  int skipped = 0;
  int questions = 0;
  final List<double> percentagesChrono = [];

  double get average => percentagesChrono.isEmpty
      ? 0
      : percentagesChrono.reduce((a, b) => a + b) / percentagesChrono.length;
  double get best => percentagesChrono.isEmpty
      ? 0
      : percentagesChrono.reduce((a, b) => a > b ? a : b);
  double get latest => percentagesChrono.isEmpty ? 0 : percentagesChrono.last;
  double? get trend => percentagesChrono.length < 2
      ? null
      : percentagesChrono.last -
          percentagesChrono[percentagesChrono.length - 2];
}

/// Progress-over-time report for a student: summary stats, a per-subject
/// trend table, a score-over-time chart, and a tappable list of every
/// test taken.
class MonthlyReportScreen extends StatelessWidget {
  final Student student;
  const MonthlyReportScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text('${student.name} — Progress'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: FutureBuilder<List<ResultWithTestInfo>>(
        future: firestore.fetchAllResultsWithTestInfo(student.studentId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snap.data ?? [];
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.show_chart, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No tests taken yet.',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          final overallPercentages =
              entries.map((e) => e.result.overallPercentage).toList();
          final average =
              overallPercentages.reduce((a, b) => a + b) / entries.length;
          final best = overallPercentages.reduce((a, b) => a > b ? a : b);
          final latest = overallPercentages.last;

          final subjectAgg = <String, _SubjectAgg>{};
          for (final entry in entries) {
            for (final se in entry.result.subjectScores.entries) {
              final agg = subjectAgg.putIfAbsent(se.key, () => _SubjectAgg());
              agg.tests++;
              agg.correct += se.value.correct;
              agg.questions += se.value.total;
              agg.skipped +=
                  se.value.answers.values.where((v) => v == 'S').length;
              agg.wrong += se.value.answers.values
                  .where((v) => v != 'R' && v != 'S')
                  .length;
              agg.percentagesChrono.add(se.value.percentage);
            }
          }
          final subjectEntries = subjectAgg.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));

          String strongest = '-';
          String weakest = '-';
          if (subjectEntries.isNotEmpty) {
            final sorted = [...subjectEntries]
              ..sort((a, b) => b.value.average.compareTo(a.value.average));
            strongest = sorted.first.key;
            weakest = sorted.last.key;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryGrid(
                  testsTaken: entries.length,
                  average: average,
                  best: best,
                  latest: latest,
                  strongest: strongest,
                  weakest: weakest,
                ),
                const SizedBox(height: 20),
                Text('Progress Across Tests',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _ProgressChart(entries: entries),
                const SizedBox(height: 20),
                Text('Subject-wise Progress',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _SubjectTrendTable(subjectEntries: subjectEntries),
                const SizedBox(height: 20),
                Text('All Tests',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...entries.reversed.map((e) => _TestRow(entry: e)),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  final int testsTaken;
  final double average;
  final double best;
  final double latest;
  final String strongest;
  final String weakest;
  const _SummaryGrid({
    required this.testsTaken,
    required this.average,
    required this.best,
    required this.latest,
    required this.strongest,
    required this.weakest,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.3,
      children: [
        _SummaryTile(label: 'Tests Taken', value: '$testsTaken', color: Colors.indigo),
        _SummaryTile(
            label: 'Average', value: '${average.toStringAsFixed(0)}%', color: Colors.teal),
        _SummaryTile(
            label: 'Best', value: '${best.toStringAsFixed(0)}%', color: Colors.green),
        _SummaryTile(
            label: 'Latest', value: '${latest.toStringAsFixed(0)}%', color: Colors.blue),
        _SummaryTile(label: 'Strongest', value: strongest, color: Colors.purple, small: true),
        _SummaryTile(
            label: 'Needs Attention', value: weakest, color: Colors.deepOrange, small: true),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool small;
  const _SummaryTile(
      {required this.label, required this.value, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: small ? 14 : 18,
                  color: color)),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _ProgressChart extends StatelessWidget {
  final List<ResultWithTestInfo> entries;
  const _ProgressChart({required this.entries});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < entries.length; i++)
        FlSpot(i.toDouble(), entries[i].result.overallPercentage),
    ];

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            horizontalInterval: 20,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                reservedSize: 32,
                getTitlesWidget: (v, meta) => Text('${v.toInt()}%',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: entries.length > 6 ? (entries.length / 5).ceilToDouble() : 1,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${i + 1}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchCallback: (event, response) {
              if (!event.isInterestedForInteractions) return;
              final spot = response?.lineBarSpots?.firstOrNull;
              if (spot == null) return;
              final i = spot.x.toInt();
              if (i < 0 || i >= entries.length) return;
              if (event is FlTapUpEvent) {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FullTestReportScreen(result: entries[i].result),
                ));
              }
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.indigo,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.indigo.withOpacity(0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectTrendTable extends StatelessWidget {
  final List<MapEntry<String, _SubjectAgg>> subjectEntries;
  const _SubjectTrendTable({required this.subjectEntries});

  @override
  Widget build(BuildContext context) {
    if (subjectEntries.isEmpty) {
      return Text('No subject data yet.', style: TextStyle(color: Colors.grey.shade600));
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18,
          columns: const [
            DataColumn(label: Text('Subject')),
            DataColumn(label: Text('Tests')),
            DataColumn(label: Text('Avg')),
            DataColumn(label: Text('Best')),
            DataColumn(label: Text('Latest')),
            DataColumn(label: Text('Trend')),
          ],
          rows: subjectEntries.map((e) {
            final agg = e.value;
            final trend = agg.trend;
            return DataRow(cells: [
              DataCell(Text(e.key)),
              DataCell(Text('${agg.tests}')),
              DataCell(Text('${agg.average.toStringAsFixed(1)}%')),
              DataCell(Text('${agg.best.toStringAsFixed(1)}%')),
              DataCell(Text('${agg.latest.toStringAsFixed(1)}%')),
              DataCell(
                trend == null
                    ? const Text('-')
                    : Text(
                        '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: trend >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _TestRow extends StatelessWidget {
  final ResultWithTestInfo entry;
  const _TestRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final result = entry.result;
    final date = entry.testInfo?.testDate ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(result.testName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          [
            if (date.isNotEmpty) date,
            '${result.totalCorrect}/${result.totalQuestions} correct',
          ].join('  •  '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${result.overallPercentage.toStringAsFixed(0)}%  ${result.overallGrade}',
            style: TextStyle(
                color: Colors.indigo.shade700, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FullTestReportScreen(result: result)),
        ),
      ),
    );
  }
}
