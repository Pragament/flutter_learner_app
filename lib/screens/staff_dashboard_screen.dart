import 'package:flutter/material.dart';
import '../models/result.dart';
import '../models/student_report.dart';
import '../models/staff_role.dart';
import '../models/student.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'student_profile_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  final List<StaffRole> staffRoles;
  const StaffDashboardScreen({super.key, required this.staffRoles});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final _auth = AuthService();
  final _firestore = FirestoreService();
  final _searchCtrl = TextEditingController();
  
  String _query = '';
  String? _selectedSchoolId;
  String? _selectedClass;
  String? _selectedSectionId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allSectionIds = widget.staffRoles.expand((r) => r.sectionIds).toList();
    final isAdmin = widget.staffRoles.any((r) => r.isAdmin);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                widget.staffRoles.length == 1
                    ? widget.staffRoles.first.schoolName
                    : 'Admin Dashboard',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(isAdmin ? 'ADMIN MODE' : 'STAFF MODE',
                style: const TextStyle(fontSize: 10, letterSpacing: 1.2)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _auth.signOut,
          ),
        ],
      ),
      body: StreamBuilder<List<Student>>(
        stream: _firestore.streamStudentsBySections(allSectionIds),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final allStudents = snap.data ?? [];
          
          // 1. Deduplicate students by studentId (fallback to admissionNo)
          final Map<String, Student> uniqueMap = {};
          for (var s in allStudents) {
            final key = s.studentId.isNotEmpty ? s.studentId : s.admissionNo;
            if (!uniqueMap.containsKey(key)) {
              uniqueMap[key] = s;
            }
          }
          final deduplicatedStudents = uniqueMap.values.toList();

          // 2. Build School list
          final List<StaffRole> availableSchools = widget.staffRoles;

          // 3. Build Class and Section lists based on School filter
          Set<String> classSet = {};
          List<SchoolSection> availableSections = [];

          if (_selectedSchoolId != null) {
            final selectedRole = widget.staffRoles.firstWhere((r) => r.schoolDocId == _selectedSchoolId);
            availableSections = selectedRole.sections;
            
            for (var s in deduplicatedStudents) {
              if (selectedRole.sectionIds.contains(s.sectionId)) {
                if (s.studentClass.isNotEmpty) classSet.add(s.studentClass);
              }
            }
          } else {
            // "All Schools" case
            for (var role in widget.staffRoles) {
              availableSections.addAll(role.sections);
            }
            // deduplicate sections by ID
            final seenSids = <String>{};
            availableSections = availableSections.where((s) => seenSids.add(s.id)).toList();

            for (var s in deduplicatedStudents) {
              if (s.studentClass.isNotEmpty) classSet.add(s.studentClass);
            }
          }

          final classes = classSet.toList()..sort();
          availableSections.sort((a, b) => a.name.compareTo(b.name));

          // 4. Apply all active filters locally
          final filtered = deduplicatedStudents.where((s) {
            final matchesSchool = _selectedSchoolId == null || 
                widget.staffRoles.firstWhere((r) => r.schoolDocId == _selectedSchoolId).sectionIds.contains(s.sectionId);
            final matchesClass = _selectedClass == null || s.studentClass == _selectedClass;
            final matchesSection = _selectedSectionId == null || s.sectionId == _selectedSectionId;
            final matchesQuery = _query.isEmpty ||
                s.name.toLowerCase().contains(_query) ||
                s.admissionNo.toLowerCase().contains(_query);

            return matchesSchool && matchesClass && matchesSection && matchesQuery;
          }).toList();

          // DEBUG LOGS
          debugPrint('DEBUG: ==========================================');
          debugPrint('DEBUG: Schools Loaded: ${availableSchools.length}');
          debugPrint('DEBUG: Classes Found: $classes');
          debugPrint('DEBUG: Sections Found: ${availableSections.map((s) => s.name).toList()}');
          debugPrint('DEBUG: Students Loaded: ${deduplicatedStudents.length}');
          if (_selectedSchoolId != null) {
             debugPrint('DEBUG: Selected School ID: $_selectedSchoolId');
             debugPrint('DEBUG: Classes Available: $classes');
             debugPrint('DEBUG: Sections Available: ${availableSections.map((s) => s.name).toList()}');
          }
          debugPrint('DEBUG: ==========================================');

          return Column(
            children: [
              // ── Search and Filter Header ────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search Name or Admission No.',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // School Filter
                        Expanded(
                          child: _FilterDropdown(
                            hint: 'All Schools',
                            value: _selectedSchoolId,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Schools', style: TextStyle(fontSize: 11))),
                              ...availableSchools.map((r) => DropdownMenuItem(
                                value: r.schoolDocId,
                                child: Text(r.schoolName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                              )),
                            ],
                            onChanged: (v) => setState(() {
                              _selectedSchoolId = v;
                              _selectedClass = null;
                              _selectedSectionId = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Class Filter
                        Expanded(
                          child: _FilterDropdown(
                            hint: 'All Classes',
                            value: _selectedClass,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Classes', style: TextStyle(fontSize: 11))),
                              ...classes.map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c, style: const TextStyle(fontSize: 11)),
                              )),
                            ],
                            onChanged: (v) => setState(() {
                              _selectedClass = v;
                            }),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Section Filter
                        Expanded(
                          child: _FilterDropdown(
                            hint: 'All Sections',
                            value: _selectedSectionId,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Sections', style: TextStyle(fontSize: 11))),
                              ...availableSections.map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                              )),
                            ],
                            onChanged: (v) => setState(() {
                              _selectedSectionId = v;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Student List ───────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _NoDataState(
                        icon: Icons.search_off,
                        message: deduplicatedStudents.isEmpty
                            ? 'No students found for your schools.'
                            : 'No students match your filters.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: availableSchools.length,
                        itemBuilder: (context, idx) {
                          final schoolRole = availableSchools[idx];
                          final schoolStudents = filtered.where((s) => schoolRole.sectionIds.contains(s.sectionId)).toList();

                          if (schoolStudents.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                child: Text(
                                  schoolRole.schoolName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigo.shade800,
                                  ),
                                ),
                              ),
                              ...schoolStudents.map((s) => _StaffStudentCard(
                                student: s,
                                firestore: _firestore,
                              )),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<DropdownMenuItem<String?>> items;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({required this.hint, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StaffStudentCard extends StatelessWidget {
  final Student student;
  final FirestoreService firestore;
  const _StaffStudentCard({required this.student, required this.firestore});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.indigo.shade50,
          child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : '?', style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('Adm: ${student.admissionNo} • Roll: ${student.rollNo} • Class: ${student.studentClass}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        trailing: StreamBuilder<List<TestResult>>(
          stream: firestore.streamResultsForStudent(student),
          builder: (context, snap) {
            final results = snap.data ?? [];
            if (results.isEmpty) return const SizedBox.shrink();
            final latest = results.first;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text('${latest.overallPercentage.toStringAsFixed(0)}%', style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
            );
          },
        ),
        children: [
          const Divider(height: 1),
          StreamBuilder<List<TestResult>>(
            stream: firestore.streamResultsForStudent(student),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(8.0), child: LinearProgressIndicator());
              final results = snap.data ?? [];
              if (results.isEmpty) return const Padding(padding: EdgeInsets.all(16.0), child: Text('No reports found.', style: TextStyle(fontSize: 12, color: Colors.grey)));

              return Column(
                children: [
                  ...results.map((TestResult r) {
                    final isPass = r.overallPercentage >= 35;
                    return ListTile(
                      dense: true,
                      title: Text(r.testName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Score: ${r.totalCorrect}/${r.totalQuestions} • Grade: ${r.overallGrade} • ${isPass ? "PASS" : "FAIL"}', 
                            style: TextStyle(fontSize: 11, color: isPass ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.w500)),
                          if (r.subjectScores.isNotEmpty)
                            Text('Subjects: ' + r.subjectScores.entries.map((e) => '${e.key}: ${e.value.correct}/${e.value.total}').join(' • '),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      trailing: Text('${r.overallPercentage.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentProfileScreen(student: student))),
                    );
                  }),
                  TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentProfileScreen(student: student))), child: const Text('View Full Academic Profile')),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NoDataState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _NoDataState({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text(message, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))])));
  }
}
