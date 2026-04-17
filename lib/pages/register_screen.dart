// TODO Implement this library.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/pages/login_screen.dart';
import 'main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final namaController = TextEditingController(); // ✅ pindah ke sini
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final alamatController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  Future<void> registerUser() async {
    final nama = namaController.text.trim(); // ✅ ambil di sini
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final alamat = alamatController.text.trim();

    if (nama.isEmpty || email.isEmpty || password.isEmpty || alamat.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Nama, email, password, dan alamat wajib diisi')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user!.uid;

      // ✅ SIMPAN SEMUA DATA
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'nama': nama,
        'email': email,
        'alamat': alamat,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Registrasi gagal';

      if (e.code == 'email-already-in-use') {
        message = 'Email sudah digunakan';
      } else if (e.code == 'invalid-email') {
        message = 'Format email tidak valid';
      } else if (e.code == 'weak-password') {
        message = 'Password terlalu lemah';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    namaController.dispose(); // ✅ jangan lupa
    emailController.dispose();
    passwordController.dispose();
    alamatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F95D0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EEEE),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Daftar Akun',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 🔥 NAMA
                  const Text('Nama',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: namaController,
                    decoration: InputDecoration(
                      hintText: 'Masukkan nama',
                      filled: true,
                      fillColor: const Color(0xFFD9D9D9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔥 EMAIL
                  const Text('Email',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      hintText: 'Masukkan email',
                      filled: true,
                      fillColor: const Color(0xFFD9D9D9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔥 PASSWORD
                  const Text('Password',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Masukkan password',
                      filled: true,
                      fillColor: const Color(0xFFD9D9D9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 🔥 ALAMAT
                  const Text('Alamat',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: alamatController,
                    decoration: InputDecoration(
                      hintText: 'Masukkan alamat',
                      filled: true,
                      fillColor: const Color(0xFFD9D9D9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : registerUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD8A441),
                        foregroundColor: Colors.black,
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              'DAFTAR',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
