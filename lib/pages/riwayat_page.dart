import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  final DatabaseReference _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://irigasi-cerdas-baru-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref('history');
  List<Map<String, dynamic>> riwayatList = [];

  @override
  void initState() {
    super.initState();
    _listenRiwayat();
  }

  // 🔥 REALTIME LISTENER
  void _listenRiwayat() {
    _database.onValue.listen((event) {
      print("🔥 LISTENER RIWAYAT AKTIF");
      print("DATA MASUK: ${event.snapshot.value}");

      final data = event.snapshot.value;

      if (data != null) {
        final rawData = data as Map<dynamic, dynamic>;

        List<Map<String, dynamic>> loadedData = [];

        rawData.forEach((key, value) {
          if (value != null) {
            final item = value as Map<dynamic, dynamic>;

            loadedData.add({
              'tanggal': item['waktu']?.toString() ?? '-',
              'kelembaban': int.tryParse("${item['nilai_persen']}") ?? 0,
              'status': item['status']?.toString() ?? '-',
            });
          }
        });

        setState(() {
          riwayatList = loadedData.reversed.toList();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Text(
            'Riwayat Penyiraman',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF1E88E5),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: riwayatList.isEmpty
            ? const Center(child: Text("Belum ada data"))
            : ListView.builder(
                itemCount: riwayatList.length,
                itemBuilder: (context, index) {
                  final item = riwayatList[index];

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(item['tanggal']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kelembaban: ${item['kelembaban']}%'),
                          Text(
                            'Status: ${item['status']}',
                            style: TextStyle(
                              color: item['status'] == "Kering"
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
