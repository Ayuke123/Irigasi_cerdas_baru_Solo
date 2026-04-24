import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  // 1. Inisialisasi StreamSubscription untuk menghindari memory leak
  StreamSubscription? _subscription;
  List<Map<String, dynamic>> riwayatList = [];
  bool _isLoading = true;

  // 2. Referensi Database dengan Query (Urutkan berdasarkan Key dan ambil 50 data terakhir)
  final Query _historyQuery = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        "https://irigasi-cerdas-baru-default-rtdb.asia-southeast1.firebasedatabase.app",
  ).ref('history').orderByKey().limitToLast(50);

  @override
  void initState() {
    super.initState();
    _listenRiwayat();
  }

  @override
  void dispose() {
    // 3. Batalkan listener saat halaman ditutup
    _subscription?.cancel();
    super.dispose();
  }

  void _listenRiwayat() {
    _subscription = _historyQuery.onValue.listen((event) {
      if (!event.snapshot.exists) {
        setState(() {
          riwayatList = [];
          _isLoading = false;
        });
        return;
      }

      List<Map<String, dynamic>> loadedData = [];

      // Menggunakan children untuk menjaga urutan yang diberikan oleh query limitToLast
      for (var child in event.snapshot.children) {
        final data = child.value as Map<dynamic, dynamic>;
        loadedData.add({
          'id': child.key,
          'tanggal': data['waktu']?.toString() ?? '-',
          'kelembaban': int.tryParse("${data['nilai_persen']}") ?? 0,
          'status': data['status']?.toString() ?? '-',
        });
      }

      setState(() {
        // Karena limitToLast(50), data terbaru ada di akhir list children.
        // Kita balik (reverse) agar yang paling baru muncul di atas.
        riwayatList = loadedData.reversed.toList();
        _isLoading = false;
      });
    }, onError: (error) {
      print("Error Database: $error");
      setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Riwayat Penyiraman',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        centerTitle: false, // 🔥 ini bikin ke kiri
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator()) // Loading indicator
          : Padding(
              padding: const EdgeInsets.all(16),
              child: riwayatList.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: riwayatList.length,
                      itemBuilder: (context, index) {
                        final item = riwayatList[index];
                        return _buildHistoryCard(item);
                      },
                    ),
            ),
    );
  }

  // Widget untuk tampilan kartu riwayat
  Widget _buildHistoryCard(Map<String, dynamic> item) {
    bool isKering = item['status'] == "Kering";

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isKering ? Colors.red.shade50 : Colors.green.shade50,
          child: Icon(
            isKering ? Icons.water_drop_outlined : Icons.check_circle_outline,
            color: isKering ? Colors.red : Colors.green,
          ),
        ),
        title: Text(
          item['tanggal'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Kelembaban: ${item['kelembaban']}%'),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isKering ? Colors.red : Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item['status'],
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget jika data kosong
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "Belum ada riwayat aktivitas",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
