import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'add_student_screen.dart';
import 'student_profile_screen.dart';

class DashboardScreen extends StatelessWidget {
  DashboardScreen({super.key});

  final _auth = AuthService();
  final _firestore = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _auth.signOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddStudentScreen()),
        ),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Student'),
      ),
      body: StreamBuilder<List<Student>>(
        stream: _firestore.streamClaimedStudents(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final students = snap.data ?? [];
          if (students.isEmpty) {
            return const _EmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _StudentCard(student: students[i]),
          );
        },
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Student student;
  const _StudentCard({required this.student});

  Future<void> _showDeleteDialog(BuildContext context, Student student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Student?'),
        content: Text(
            'Are you sure you want to remove ${student.name} from your account? '
            'You can add them back later with their school code, admission number, and phone number.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final auth = AuthService();
      final firestore = FirestoreService();
      final uid = auth.currentUser?.uid;
      if (uid != null) {
        await firestore.unclaimStudent(uid, student.docId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${student.name} removed.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.shade50,
          child: Text(
            student.name.isNotEmpty ? student.name[0] : '?',
            style: TextStyle(
                color: Colors.indigo.shade700,
                fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(student.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            'Adm No: ${student.admissionNo} • Class: ${student.studentClass}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Remove Student',
              onPressed: () => _showDeleteDialog(context, student),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StudentProfileScreen(student: student),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.family_restroom, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No students linked yet.',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'Tap "Add Student" and enter your child\'s school code, '
              'admission number and phone number.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
