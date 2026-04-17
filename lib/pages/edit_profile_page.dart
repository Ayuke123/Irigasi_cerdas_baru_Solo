import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final alamatController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // Load data from Firestore
  Future<void> loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    final data = doc.data();

    // Set the fields to the current user's data
    emailController.text = user!.email ?? '';
    phoneController.text = data?['phoneNumber'] ?? '';
    alamatController.text = data?['alamat'] ?? '';
  }

  // Update the user's profile
  Future<void> update() async {
    // Check if email needs to be updated
    if (emailController.text != user!.email) {
      try {
        await user!.updateEmail(emailController.text); // Update email
      } catch (e) {
        // Handle error if email update fails
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating email: $e')),
        );
        return;
      }
    }

    // Update Firestore document with the new data
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'phoneNumber': phoneController.text.trim(),
      'alamat': alamatController.text.trim(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil berhasil diperbarui')),
    );

    // After updating, navigate back to ProfileScreen and refresh data
    Navigator.pop(
        context, true); // Return 'true' to indicate update was successful
  }

  @override
  void dispose() {
    emailController.dispose();
    phoneController.dispose();
    alamatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Edit email
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Edit phone number
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Nomor Telepon'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // Edit address
            TextField(
              controller: alamatController,
              decoration: const InputDecoration(labelText: 'Alamat'),
            ),
            const SizedBox(height: 20),

            // Save button
            ElevatedButton(
              onPressed: update,
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }
}
