import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page.dart';
import 'login_screen.dart';

class PengaturanPage extends StatefulWidget {
  const PengaturanPage({super.key});

  @override
  State<PengaturanPage> createState() => _PengaturanPageState();
}

class _PengaturanPageState extends State<PengaturanPage> {
  final phoneController = TextEditingController();
  final alamatController = TextEditingController();

  User? user;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        phoneController.text = data?['phoneNumber'] ?? '';
        alamatController.text = data?['alamat'] ?? '';
      }
    } catch (e) {
      debugPrint("LOAD ERROR: $e");
    }
  }

  Future<void> updateProfile() async {
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'phoneNumber': phoneController.text.trim(),
      'alamat': alamatController.text.trim(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Berhasil update data')),
    );
  }

  // 🔥 DELETE TANPA HARDCODE PASSWORD (lebih aman untuk sekarang)
  Future<void> deleteAccount() async {
    try {
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .delete();

      await user!.delete();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal hapus akun: $e')),
      );
    }
  }

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

  @override
  void dispose() {
    phoneController.dispose();
    alamatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: const Color(0xFF1E88E5),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Edit Pengguna'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfilePage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Hapus Akun'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: confirmDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
