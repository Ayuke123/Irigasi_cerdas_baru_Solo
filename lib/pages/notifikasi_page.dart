import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class NotifikasiPage extends StatelessWidget {
  const NotifikasiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifRef = FirebaseDatabase.instance.ref('notifications/items');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        centerTitle: true,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: notifRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final raw = snapshot.data?.snapshot.value;

          if (raw == null || raw is! Map) {
            return const Center(
              child: Text('Belum ada notifikasi'),
            );
          }

          final data = Map<Object?, Object?>.from(raw);

          final items = data.entries.map((entry) {
            final key = entry.key.toString();
            final value = Map<Object?, Object?>.from(entry.value as Map);

            return {
              'key': key,
              'title': (value['title'] ?? '').toString(),
              'body': (value['body'] ?? '').toString(),
              'time': (value['time'] ?? '').toString(),
              'isRead': value['isRead'] == true,
              'type': (value['type'] ?? '').toString(),
            };
          }).toList();

          items.sort((a, b) {
            final timeA = a['time'] as String;
            final timeB = b['time'] as String;
            return timeB.compareTo(timeA);
          });

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final key = item['key'] as String;
              final isRead = item['isRead'] as bool;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isRead ? Colors.grey.shade300 : Colors.red.shade100,
                  child: Icon(
                    Icons.notifications,
                    color: isRead ? Colors.grey.shade700 : Colors.red,
                  ),
                ),
                title: Text(
                  item['title'] as String,
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(item['body'] as String),
                    const SizedBox(height: 4),
                    Text(
                      item['time'] as String,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                onTap: () async {
                  await notifRef.child(key).update({'isRead': true});

                  if (!context.mounted) return;

                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(item['title'] as String),
                      content: Text(item['body'] as String),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Tutup'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
