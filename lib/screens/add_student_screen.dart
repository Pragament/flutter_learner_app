import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});
  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _schoolCodeCtrl = TextEditingController();
  final _admissionCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _firestore = FirestoreService();
  final _auth = AuthService();
  bool _busy = false;

  @override
  void dispose() {
    _schoolCodeCtrl.dispose();
    _admissionCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final schoolCode = _schoolCodeCtrl.text.trim().toUpperCase();
    final admissionNo = _admissionCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (schoolCode.isEmpty || admissionNo.isEmpty || phone.isEmpty) {
      _snack('Please fill in all three fields.');
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await _firestore.claimStudent(
        uid: uid,
        schoolCode: schoolCode,
        admissionNo: admissionNo,
        phoneNumber: phone,
      );
      if (!mounted) return;
      switch (result) {
        case ClaimResult.success:
          _snack('Student linked successfully!');
          Navigator.of(context).pop();
        case ClaimResult.alreadyClaimed:
          _snack('This student is already linked to your account.');
          Navigator.of(context).pop();
        case ClaimResult.notFound:
          _snack('No student found. Check the school code, admission number and phone.');
        case ClaimResult.noPhoneOnRecord:
          _snack('Phone number not registered. Contact the school office.');
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Student')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the details from your child\'s school. '
              'All three must match the school records.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _schoolCodeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'School Code',
                hintText: 'e.g. DSS2025',
                border: OutlineInputBorder(),
                helperText: 'Given by the school',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _admissionCtrl,
              decoration: const InputDecoration(
                labelText: 'Admission Number',
                hintText: 'e.g. 100',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Registered Phone Number',
                hintText: 'e.g. 9876543210',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Link Student'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
