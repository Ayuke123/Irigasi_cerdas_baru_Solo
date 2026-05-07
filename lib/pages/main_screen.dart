import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ⭐ TAMBAHAN

import 'package:irigasi_cerdas_baru/pages/riwayat_page.dart';
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

  /// 🔥 FIX: pakai UID user
  DatabaseReference getNotifRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return FirebaseDatabase.instance.ref('notifications/dummy/items');
    }
    return FirebaseDatabase.instance.ref('notifications/${user.uid}/items');
  }

  /// 🔥 FIX: tandai semua notif sebagai read
  Future<void> markAllNotifRead() async {
    final notifRef = getNotifRef();

    final snapshot = await notifRef.get();

    if (snapshot.exists && snapshot.value is Map) {
      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

      for (var item in data.entries) {
        await notifRef.child(item.key).update({
          'isRead': true,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifRef = getNotifRef(); // ⭐ FIX

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
            final raw = Map<dynamic, dynamic>.from(
                snapshot.data!.snapshot.value as Map);

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

              /// 🔥 kalau klik notif → hapus badge
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

              /// 🔴 BADGE NOTIF
              BottomNavigationBarItem(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications),
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
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
