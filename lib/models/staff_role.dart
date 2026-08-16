import 'package:cloud_firestore/cloud_firestore.dart';

/// A resolved school-staff identity for the signed-in user — found by
/// matching their email against `schools/{schoolId}/staff/{id}` documents.
/// Presence of this (role == 'admin' or 'staff') switches the app into
/// Teacher/Admin mode instead of the manual-claim Parent flow.
class SchoolSection {
  final String id;
  final String name;
  final String className;

  SchoolSection({required this.id, required this.name, required this.className});
}

class StaffRole {
  final String schoolDocId;
  final String schoolCode;
  final String schoolName;
  final String role; // 'admin' | 'staff' | 'teacher'
  final String staffDocId;
  final List<SchoolSection> sections;

  StaffRole({
    required this.schoolDocId,
    required this.schoolCode,
    required this.schoolName,
    required this.role,
    required this.staffDocId,
    required this.sections,
  });

  bool get isAdmin => role == 'admin';
  List<String> get sectionIds => sections.map((s) => s.id).toList();

  factory StaffRole.fromDocs({
    required DocumentSnapshot<Map<String, dynamic>> staffDoc,
    required DocumentSnapshot<Map<String, dynamic>> schoolDoc,
  }) {
    final staffData = staffDoc.data() ?? {};
    final schoolData = schoolDoc.data() ?? {};
    
    final sectionsData = List.from(schoolData['sections'] ?? []);
    final List<SchoolSection> parsedSections = [];
    
    for (var s in sectionsData) {
      if (s is Map) {
        parsedSections.add(SchoolSection(
          id: (s['sectionId'] ?? '').toString(),
          name: (s['sectionName'] ?? '').toString(),
          className: (s['className'] ?? '').toString(),
        ));
      }
    }

    return StaffRole(
      schoolDocId: schoolDoc.id,
      schoolCode: (schoolData['schoolCode'] ?? '').toString(),
      schoolName: (schoolData['schoolName'] ?? '').toString(),
      role: (staffData['role'] ?? '').toString(),
      staffDocId: staffDoc.id,
      sections: parsedSections,
    );
  }
}
