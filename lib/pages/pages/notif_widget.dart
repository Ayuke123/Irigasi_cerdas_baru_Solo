import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '/services/notifikasi_service.dart';

/// ==============================
/// 🔴 BADGE NOTIF (ANTI SPAM)
/// ==============================
class NotifBadge extends StatefulWidget {
  const NotifBadge({super.key});

  @override
  State<NotifBadge> createState() => _NotifBadgeState();
}

class _NotifBadgeState extends State<NotifBadge> {
  final Set<String> shownNotif = {};

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
              final isRead = item['isRead'] == true;

              if (!isRead && !shownNotif.contains(key)) {
                shownNotif.add(key);

                NotificationService.showNotification(
                  item['title'] ?? '',
                  item['body'] ?? '',
                );
              }

              if (!isRead) unread++;
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
class NotifikasiPage extends StatelessWidget {
  const NotifikasiPage({super.key});

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

          items.sort(
              (a, b) => (b['time'] as String).compareTo(a['time'] as String));

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
/// 🔔 KIRIM NOTIF
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
