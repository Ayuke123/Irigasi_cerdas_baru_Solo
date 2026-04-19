import 'package:flutter/material.dart';
import 'package:irigasi_cerdas_baru/pages/riwayat_page.dart'; // Pastikan sudah mengimpor RiwayatPage
import 'package:irigasi_cerdas_baru/pages/akun_page.dart'; // Pastikan sudah mengimpor halaman yang dibutuhkan
import 'package:irigasi_cerdas_baru/pages/profile_screen.dart';
import 'home_page.dart';
import 'notifikasi_page.dart';
import 'cuaca_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  // Daftar halaman yang ditampilkan sesuai index
  final List<Widget> pages = [
    DashboardPage(), // Ganti dengan halaman yang sesuai
    const RiwayatPage(), // Menampilkan RiwayatPage
    const NotifikasiPage(), // Halaman notifikasi
    const CuacaPage(), // Halaman cuaca
    const ProfileScreen(), // Halaman akun/profile
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex, // Menampilkan halaman sesuai index
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex, // Menyimpan halaman yang dipilih
        onTap: (i) => setState(() => selectedIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat'),
          BottomNavigationBarItem(
              icon: Icon(Icons.notifications), label: 'Notif'),
          BottomNavigationBarItem(icon: Icon(Icons.cloud), label: 'Cuaca'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Akun'),
        ],
      ),
    );
  }
}
