import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// ==============================
/// 🔴 BADGE NOTIF (REALTIME)
/// ==============================
class NotifBadge extends StatelessWidget {
  const NotifBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    final ref =
        FirebaseDatabase.instance.ref('notifications/${user.uid}/items');

    return StreamBuilder<DatabaseEvent>(
      stream: ref.onValue,
      builder: (context, snapshot) {
        int unread = 0;

        final data = snapshot.data?.snapshot.value;

        if (data is Map) {
          data.forEach((key, item) {
            if (item is Map) {
              if (item['isRead'] != true) {
                unread++;
              }
            }
          });
        }

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotifikasiPage(),
                  ),
                );
              },
            ),

            /// 🔴 BADGE
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unread > 9 ? '9+' : unread.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// ==============================
/// 🔔 HALAMAN NOTIF
/// ==============================
class NotifikasiPage extends StatefulWidget {
  const NotifikasiPage({super.key});

  @override
  State<NotifikasiPage> createState() => _NotifikasiPageState();
}

class _NotifikasiPageState extends State<NotifikasiPage> {
  @override
  void initState() {
    super.initState();
    tandaiSemuaSudahDibaca(); // 🔥 otomatis hilang badge saat dibuka
  }

  void tandaiSemuaSudahDibaca() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref =
        FirebaseDatabase.instance.ref('notifications/${user.uid}/items');

    final snapshot = await ref.get();

    if (snapshot.value is Map) {
      final data = snapshot.value as Map;

      for (var key in data.keys) {
        await ref.child(key).update({'isRead': true});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User belum login")),
      );
    }

    final ref =
        FirebaseDatabase.instance.ref('notifications/${user.uid}/items');

    return Scaffold(
      appBar: AppBar(title: const Text("Notifikasi")),
      body: StreamBuilder<DatabaseEvent>(
        stream: ref.onValue,
        builder: (context, snapshot) {
          final data = snapshot.data?.snapshot.value;

          if (data == null || data is! Map) {
            return const Center(child: Text("Belum ada notifikasi"));
          }

          final List<Map<String, dynamic>> items = [];

          data.forEach((key, value) {
            if (value is Map) {
              items.add({
                'key': key.toString(),
                'title': value['title'] ?? '',
                'body': value['body'] ?? '',
                'time': value['time'] ?? '',
                'isRead': value['isRead'] == true,
              });
            }
          });

          /// 🔥 SORT TERBARU DI ATAS
          items.sort(
            (a, b) => (b['time'] as String).compareTo(a['time'] as String),
          );

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];

              return ListTile(
                title: Text(item['title']),
                subtitle: Text(item['body']),
                trailing: item['isRead']
                    ? null
                    : const Icon(Icons.circle, color: Colors.red, size: 10),
                onTap: () async {
                  await ref.child(item['key']).update({'isRead': true});
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// ==============================
/// 🔔 FUNGSI KIRIM NOTIF
/// ==============================
Future<void> kirimNotifikasi(String title, String body) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await FirebaseDatabase.instance
      .ref('notifications/${user.uid}/items')
      .push()
      .set({
    'title': title,
    'body': body,
    'time': DateTime.now().toIso8601String(),
    'isRead': false,
  });
}
