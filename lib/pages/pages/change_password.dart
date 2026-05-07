import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:irigasi_cerdas_baru/pages/pages/notif_widget.dart';
import 'package:irigasi_cerdas_baru/pages/pages/notif_widget.dart'; // ⭐ notif

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;

  bool showCurrent = false;
  bool showNew = false;
  bool showConfirm = false;

  Future<void> changePassword() async {
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPasswordController.text.trim(),
      );

      await user.reauthenticateWithCredential(credential);

      if (newPasswordController.text != confirmPasswordController.text) {
        showMsg("Password tidak cocok");
        return;
      }

      await user.updatePassword(newPasswordController.text.trim());

      // 🔔 NOTIF MASUK KE HALAMAN NOTIF
      await kirimNotifikasi(
        "Password Diubah",
        "Password akun kamu berhasil diperbarui",
      );

      showMsg("Password berhasil diubah");
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
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildInput(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB), // ✅ sama kayak edit profil
      appBar: AppBar(
        title: const Text(
          "Ganti Password",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
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
                "Keamanan Akun",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildInput(
                "Password Saat Ini",
                currentPasswordController,
                showCurrent,
                () => setState(() => showCurrent = !showCurrent),
              ),
              _buildInput(
                "Password Baru",
                newPasswordController,
                showNew,
                () => setState(() => showNew = !showNew),
              ),
              _buildInput(
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
                  onPressed: isLoading ? null : changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 90, 158, 227),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Simpan Password",
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
}
