import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;

    try {
      final cred = EmailAuthProvider.credential(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await user!.reauthenticateWithCredential(cred);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      await user.delete();

      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hapus Akun')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Masukkan email & password"),
            TextField(controller: emailController),
            TextField(controller: passwordController, obscureText: true),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: deleteAccount,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Hapus Akun"),
            )
          ],
        ),
      ),
    );
  }
}
