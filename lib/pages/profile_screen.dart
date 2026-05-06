import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page.dart';
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
  bool isLoading = true;
  bool emailPendingVerification = false;

  StreamSubscription<User?>? _userSub;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    getData();

    _userSub = FirebaseAuth.instance.userChanges().listen((u) {
      if (u == null) return;
      if (!mounted) return;
      getData();
    });
  }

  Future<void> getData() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final data = doc.data();

        if (!mounted) return;

        setState(() {
          email = user.email ?? data?['email'] ?? '';
          nomorTelepon = data?['phone'] ?? '';
          alamat = data?['alamat'] ?? '';
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("ERROR getData: $e");
    }

    _isFetching = false;
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  // ================= SETTINGS =================
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
              onTap: () async {
                Navigator.pop(context);

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditProfilePage(),
                  ),
                );

                if (!mounted) return;

                if (result == true) {
                  getData();
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Hapus Akun',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= DIALOG INPUT PASSWORD =================
  void confirmDelete() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Masukkan password untuk konfirmasi'),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "Password",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              deleteAccount(passwordController.text);
            },
            child: const Text(
              'Hapus',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  // ================= DELETE ACCOUNT =================
  Future<void> deleteAccount(String password) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        showMessage("User tidak ditemukan");
        return;
      }

      if (password.isEmpty) {
        showMessage("Password wajib diisi");
        return;
      }

      // 🔥 refresh session
      await user.reload();

      // 🔐 re-auth
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password.trim(),
      );

      await user.reauthenticateWithCredential(credential);

      // 🗑 hapus firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // 🗑 hapus auth
      await user.delete();

      if (!mounted) return;

      showMessage("Akun berhasil dihapus");

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        showMessage("Password salah ❌");
      } else if (e.code == 'requires-recent-login') {
        showMessage("Session expired, coba lagi");
      } else if (e.code == 'invalid-credential') {
        showMessage("Credential tidak valid");
      } else {
        showMessage("Error: ${e.message}");
      }
    } catch (e) {
      showMessage("Error: $e");
    }
  }

  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F4F4),
      appBar: AppBar(
        title: const Text(
          'Profil Pengguna',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xffF3F5F6),
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: showSettingsBottomSheet,
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xffE7ECF4),
                    child: Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 20),
                  buildCard('Email', email),
                  const SizedBox(height: 16),
                  buildCard('Nomor Telepon', nomorTelepon),
                  const SizedBox(height: 16),
                  buildCard('Alamat', alamat),
                  const SizedBox(height: 30),

                  // 🔴 LOGOUT
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();

                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  Widget buildCard(String title, String value) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(value.isEmpty ? '-' : value),
      ),
    );
  }
}
