import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String docId;
  final String studentId;   // used to fetch results
  final String admissionNo;
  final String name;
  final String rollNo;
  final String sectionId;
  final String studentClass;
  final String phoneNumber;
  final List<String> parentIds;

  Student({
    required this.docId,
    required this.studentId,
    required this.admissionNo,
    required this.name,
    required this.rollNo,
    required this.sectionId,
    required this.studentClass,
    required this.phoneNumber,
    required this.parentIds,
  });

  factory Student.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Student(
      docId: doc.id,
      studentId: (d['studentId'] ?? '').toString(),
      admissionNo: (d['admissionNo'] ?? '').toString(),
      name: (d['name'] ?? '').toString(),
      rollNo: (d['rollNo'] ?? '').toString(),
      sectionId: (d['sectionId'] ?? '').toString(),
      studentClass: (d['class'] ?? '').toString(),
      phoneNumber: (d['phoneNumber'] ?? '').toString(),
      parentIds: List<String>.from(d['parentIds'] ?? d['parentUids'] ?? []),
    );
  }
}
