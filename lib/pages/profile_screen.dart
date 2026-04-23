import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page.dart'; // Import EditProfilePage
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String email = '';
  String nomorTelepon = '';
  String alamat = '';

  @override
  void initState() {
    super.initState();
    getData();
  }

  // Fetch user data from Firestore
  Future<void> getData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      setState(() {
        email = data?['email'] ?? '';
        nomorTelepon = data?['phoneNumber'] ?? '';
        alamat = data?['alamat'] ?? '';
      });
    }
  }

  // Show bottom sheet with options to edit profile or delete account
  void showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Informasi Pengguna'),
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  const Text('Hapus Akun', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context); // Close the bottom sheet
                confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Confirm deletion of the account
  void confirmDelete() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: const Text('Yakin mau hapus akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              deleteAccount();
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // Delete the user's account
  Future<void> deleteAccount() async {
    try {
      String email = FirebaseAuth.instance.currentUser!.email!;

      // Hardcoded password for testing
      String password =
          "ISI_PASSWORD_USER"; // This should be an input from the user

      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      // Re-authenticate user
      await FirebaseAuth.instance.currentUser!
          .reauthenticateWithCredential(credential);

      // Delete user data from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .delete();

      // Delete user from FirebaseAuth
      await FirebaseAuth.instance.currentUser!.delete();

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      print("ERROR DELETE: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal hapus akun: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 246, 244, 244),
      appBar: AppBar(
        title: const Text(
          'Profil Pengguna',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color.fromARGB(255, 243, 245, 246),
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: showSettingsBottomSheet,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar Profile
            CircleAvatar(
              radius: 60,
              backgroundColor: const Color.fromARGB(255, 231, 236, 244),
              child: Icon(
                Icons.person,
                size: 80,
                color: const Color.fromARGB(255, 158, 155, 155),
              ),
            ),
            const SizedBox(height: 20),

            // Displaying Email and Phone
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: const Text(
                  'Email',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(email),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: const Text(
                  'Nomor Telepon',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(nomorTelepon),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: const Text(
                  'Alamat',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(alamat),
              ),
            ),
            const SizedBox(height: 30),

            // Edit Profile Button

            const SizedBox(height: 20),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "KELUAR",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
