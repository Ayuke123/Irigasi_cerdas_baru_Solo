import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final DatabaseReference dbRef =
      FirebaseDatabase.instance.ref().child('history');

  List<Map<String, dynamic>> historyList = [];

  @override
  void initState() {
    super.initState();
    getData();
  }

  void getData() {
    dbRef.onValue.listen((event) {
      final data = event.snapshot.value;

      if (data != null && data is Map) {
        final Map<dynamic, dynamic> map = data;

        List<Map<String, dynamic>> tempList = [];

        map.forEach((key, value) {
          if (value is Map) {
            final item = Map<dynamic, dynamic>.from(value);

            tempList.add({
              "status": item["status"] ?? "-",
              "nilai": item["nilai_persen"] ?? 0,
              "waktu": item["waktu"] ?? "-",
            });
          }
        });

        setState(() {
          historyList = tempList.reversed.toList();
        });
      }
    });
  }

  // 🔥 CEK HARI INI
  bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // 🔥 FORMAT TANGGAL
  String formatDate(DateTime date) {
    return DateFormat('dd MMMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<Map<String, dynamic>>> groupedData = {};

    for (var item in historyList) {
      try {
        DateTime date = DateTime.parse(item['waktu']);

        String key = isToday(date) ? "Hari ini" : formatDate(date);

        if (!groupedData.containsKey(key)) {
          groupedData[key] = [];
        }

        groupedData[key]!.add(item);
      } catch (e) {
        print("Error parsing date: $e");
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xffF7F7F7),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔥 HEADER
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: const [
                  Icon(Icons.edit_note, size: 28),
                  SizedBox(width: 10),
                  Text(
                    "Riwayat Penyiraman",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // 🔥 LIST
            Expanded(
              child: historyList.isEmpty
                  ? const Center(child: Text("Belum ada data"))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: groupedData.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🔥 JUDUL TANGGAL
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),

                            // 🔥 LIST CARD
                            ...entry.value.map((item) {
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['waktu'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Status: ${item['status']} • ${item['nilai']}%",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: item['status'] == "Kering"
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
