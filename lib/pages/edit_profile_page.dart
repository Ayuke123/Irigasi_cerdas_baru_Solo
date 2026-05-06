import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'pages/notif_widget.dart'; // pastikan path ini benar

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final phoneController = TextEditingController();
  final alamatController = TextEditingController();

  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;

  bool showCurrent = false;
  bool showNew = false;
  bool showConfirm = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    phoneController.dispose();
    alamatController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();

    if (!mounted) return;

    setState(() {
      phoneController.text = data?['phone'] ?? '';
      alamatController.text = data?['alamat'] ?? '';
    });
  }

  Future<void> updateProfile() async {
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 🔐 reauth WAJIB aman
      if (currentPasswordController.text.isNotEmpty) {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPasswordController.text.trim(),
        );

        await user.reauthenticateWithCredential(credential);
      }

      // 🔑 update password kalau diisi
      if (newPasswordController.text.isNotEmpty) {
        if (newPasswordController.text != confirmPasswordController.text) {
          showMsg("Password tidak cocok");
          return;
        }

        await user.updatePassword(newPasswordController.text.trim());
      }

      // 🔥 update firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'phone': phoneController.text.trim(),
        'alamat': alamatController.text.trim(),
      });

      // 🔔 notif (PASTIKAN ADA DI notif_widget.dart)
      await kirimNotifikasi(
        "Profil Diperbarui",
        "Data akun kamu berhasil diperbarui",
      );

      showMsg("Berhasil diperbarui");
      Navigator.pop(context, true);
    } catch (e) {
      showMsg("Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        title: const Text(
          "Edit Profil",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,

        // 🔥 INI YANG SEBELUMNYA ERROR KALAU IMPORT SALAH
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Informasi Akun",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildInput(
                label: "Email",
                icon: Icons.email,
                controller: TextEditingController(text: email),
                enabled: false,
              ),
              _buildInput(
                label: "Nomor Telepon",
                icon: Icons.phone,
                controller: phoneController,
              ),
              _buildInput(
                label: "Alamat",
                icon: Icons.location_on,
                controller: alamatController,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              _buildPassword(
                "Password Saat Ini",
                currentPasswordController,
                showCurrent,
                () => setState(() => showCurrent = !showCurrent),
              ),
              _buildPassword(
                "Password Baru",
                newPasswordController,
                showNew,
                () => setState(() => showNew = !showNew),
              ),
              _buildPassword(
                "Konfirmasi Password",
                confirmPasswordController,
                showConfirm,
                () => setState(() => showConfirm = !showConfirm),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 90, 158, 227),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Simpan Perubahan",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    bool enabled = true,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: const Color(0xffF1F4F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPassword(
    String label,
    TextEditingController controller,
    bool visible,
    VoidCallback toggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: !visible,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                visible ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: toggle,
            ),
            filled: true,
            fillColor: const Color(0xffF1F4F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
