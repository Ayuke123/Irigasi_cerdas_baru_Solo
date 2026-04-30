import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:irigasi_cerdas_baru/pages/riwayat_page.dart';
import 'package:irigasi_cerdas_baru/pages/akun_page.dart';
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

  final List<Widget> pages = [
    DashboardPage(),
    const RiwayatPage(),
    const NotifikasiPage(),
    const CuacaPage(),
    const ProfileScreen(),
  ];

  Future<void> markAllNotifRead() async {
    final notifRef = FirebaseDatabase.instance.ref('notifications/items');

    final snapshot = await notifRef.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;

      for (var item in data.entries) {
        await notifRef.child(item.key).update({
          'isRead': true,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifRef = FirebaseDatabase.instance.ref('notifications/items');

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: StreamBuilder<DatabaseEvent>(
        stream: notifRef.onValue,
        builder: (context, snapshot) {
          int unreadCount = 0;

          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final raw = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

            raw.forEach((key, value) {
              final item = Map<dynamic, dynamic>.from(value);

              if (item['isRead'] == false) {
                unreadCount++;
              }
            });
          }

          return BottomNavigationBar(
            currentIndex: selectedIndex,
            type: BottomNavigationBarType.fixed,
            onTap: (i) async {
              setState(() {
                selectedIndex = i;
              });

              // 🔥 Kalau klik notif, badge hilang
              if (i == 2) {
                await markAllNotifRead();
              }
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Beranda',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.history),
                label: 'Riwayat',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                label: 'Notif',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.cloud),
                label: 'Cuaca',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Akun',
              ),
            ],
          );
        },
      ),
    );
  }
}
