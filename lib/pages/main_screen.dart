import 'package:flutter/material.dart';
import 'package:irigasi_cerdas_baru/pages/akun_page.dart';
import 'package:irigasi_cerdas_baru/pages/profile_screen.dart';
import 'home_page.dart';
import 'riwayat_page.dart';
import 'notifikasi_page.dart';
import 'cuaca_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  final pages = [
    DashboardPage(),
    HistoryPage(),
    NotifikasiPage(),
    CuacaPage(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
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
