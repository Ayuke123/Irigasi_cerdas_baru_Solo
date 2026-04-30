import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '/services/notifikasi_service.dart';

class NotifikasiPage extends StatelessWidget {
  const NotifikasiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifRef = FirebaseDatabase.instance.ref('notifications/items');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        child: StreamBuilder<DatabaseEvent>(
          stream: notifRef.onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final raw = snapshot.data?.snapshot.value;

            if (raw == null || raw is! Map) {
              return _buildEmptyState();
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
              };
            }).toList();

            items.sort((a, b) {
              final timeA = a['time'] as String;
              final timeB = b['time'] as String;
              return timeB.compareTo(timeA);
            });

            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];

                  // 🔥 Popup Notifikasi
                  NotificationService.showNotification(
                    item['title'].toString(),
                    item['body'].toString(),
                  );

                  return _buildNotifCard(
                    context,
                    notifRef,
                    item,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotifCard(
    BuildContext context,
    DatabaseReference notifRef,
    Map<String, dynamic> item,
  ) {
    final key = item['key'] as String;
    final isRead = item['isRead'] as bool;

    return Card(
      color: const Color(0xFFF2F2F2),
      surfaceTintColor: const Color(0xFFF2F2F2),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: isRead ? Colors.grey.shade300 : Colors.red.shade50,
          child: Icon(
            Icons.notifications,
            color: isRead ? Colors.grey : Colors.red,
          ),
        ),
        title: Text(
          item['title'] as String,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['body'] as String),
              const SizedBox(height: 8),
              Text(
                item['time'] as String,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        onTap: () async {
          await notifRef.child(key).update({
            'isRead': true,
          });

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
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            "Belum ada notifikasi",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
