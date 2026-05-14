import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:irigasi_cerdas_baru/pages/pages/grafik_page.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  StreamSubscription? _subscription;

  List<Map<String, dynamic>> riwayatList = [];
  List<Map<String, dynamic>> filteredList = [];

  bool _isLoading = true;

  // ================= FILTER =================
  String selectedFilter = "Semua";
  DateTime? selectedDate;
  DateTimeRange? selectedRange;

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
    _subscription?.cancel();
    super.dispose();
  }

  // ================= FILTER FUNCTION =================
  void applyFilter() {
    filteredList = List.from(riwayatList);

    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    String yesterday = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().subtract(const Duration(days: 1)));

    // ================= HARI INI =================
    if (selectedFilter == "Hari Ini") {
      filteredList = riwayatList.where((item) {
        return item['tanggal'] == today;
      }).toList();
    }

    // ================= KEMARIN =================
    else if (selectedFilter == "Kemarin") {
      filteredList = riwayatList.where((item) {
        return item['tanggal'] == yesterday;
      }).toList();
    }

    // ================= PILIH TANGGAL =================
    else if (selectedFilter == "Pilih Tanggal" && selectedDate != null) {
      String selected = DateFormat(
        'yyyy-MM-dd',
      ).format(selectedDate!);

      filteredList = riwayatList.where((item) {
        return item['tanggal'] == selected;
      }).toList();
    }

    // ================= RANGE TANGGAL =================
    else if (selectedFilter == "Range Tanggal" && selectedRange != null) {
      filteredList = riwayatList.where((item) {
        try {
          DateTime itemDate = DateTime.parse(item['tanggal']);

          return itemDate.isAfter(
                selectedRange!.start.subtract(
                  const Duration(days: 1),
                ),
              ) &&
              itemDate.isBefore(
                selectedRange!.end.add(
                  const Duration(days: 1),
                ),
              );
        } catch (e) {
          return false;
        }
      }).toList();
    }
  }

  // ================= PICK DATE =================
  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedFilter = "Pilih Tanggal";
        applyFilter();
      });
    }
  }

  // ================= PICK RANGE =================
  Future<void> pickDateRange() async {
    DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedRange = picked;
        selectedFilter = "Range Tanggal";
        applyFilter();
      });
    }
  }

  // ================= FIREBASE =================
  void _listenRiwayat() {
    _subscription = _historyQuery.onValue.listen(
      (event) {
        if (!event.snapshot.exists) {
          setState(() {
            riwayatList = [];
            filteredList = [];
            _isLoading = false;
          });

          return;
        }

        List<Map<String, dynamic>> loadedData = [];

        for (var child in event.snapshot.children) {
          final data = child.value as Map<dynamic, dynamic>;

          // ================= WAKTU =================
          String fullWaktu = data['waktu']?.toString() ?? '-';

          String tanggal = '-';
          String jam = '-';

          if (fullWaktu.contains(' ')) {
            List<String> parts = fullWaktu.split(' ');

            tanggal = parts[0];
            jam = parts[1];
          } else {
            tanggal = fullWaktu;
          }

          int kelembaban = int.tryParse("${data['nilai_persen']}") ?? 0;

          loadedData.add({
            'id': child.key,

            // ================= TANGGAL =================
            'tanggal': tanggal,
            'jam': jam,

            // ================= DATA =================
            'kelembaban': kelembaban,

            'kelembaban_awal': int.tryParse(
                  "${data['kelembaban_awal']}",
                ) ??
                kelembaban,

            'kelembaban_akhir': int.tryParse(
                  "${data['kelembaban_akhir']}",
                ) ??
                kelembaban,

            'perubahan_kelembaban':
                "${data['kelembaban_awal'] ?? kelembaban}% → ${data['kelembaban_akhir'] ?? kelembaban}%",

            'durasi_pompa': int.tryParse(
                  "${data['durasi_pompa']}",
                ) ??
                0,

            'volume_air': int.tryParse(
                  "${data['volume_air']}",
                ) ??
                0,

            'status': data['status']?.toString() ?? '-',

            'mode': data['mode']?.toString() ?? 'Manual',
          });
        }

        setState(() {
          riwayatList = loadedData.reversed.toList();

          applyFilter();

          _isLoading = false;
        });
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Riwayat Penyiraman',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'grafik') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GrafikPage(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'grafik',
                child: Text('Lihat Grafik'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ================= FILTER =================
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Filter Riwayat",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (selectedFilter != "Semua")
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    selectedFilter = "Semua";

                                    selectedDate = null;

                                    selectedRange = null;

                                    applyFilter();
                                  });
                                },
                                child: const Text("Reset"),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildFilterChip(
                              title: "Semua",
                              icon: Icons.history,
                            ),
                            _buildFilterChip(
                              title: "Hari Ini",
                              icon: Icons.today,
                            ),
                            _buildFilterChip(
                              title: "Kemarin",
                              icon: Icons.calendar_view_day,
                            ),
                            ActionChip(
                              avatar: const Icon(
                                Icons.calendar_month,
                                size: 18,
                              ),
                              label: const Text(
                                "Pilih Tanggal",
                              ),
                              onPressed: pickDate,
                            ),
                            ActionChip(
                              avatar: const Icon(
                                Icons.date_range,
                                size: 18,
                              ),
                              label: const Text(
                                "Range Tanggal",
                              ),
                              onPressed: pickDateRange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              "Filter aktif: $selectedFilter",
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (selectedFilter == "Pilih Tanggal" &&
                                selectedDate != null)
                              Text(
                                "(${DateFormat('dd MMM yyyy').format(selectedDate!)})",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (selectedFilter == "Range Tanggal" &&
                                selectedRange != null)
                              Text(
                                "(${DateFormat('dd/MM').format(selectedRange!.start)} - ${DateFormat('dd/MM/yy').format(selectedRange!.end)})",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ================= LIST =================
                  Expanded(
                    child: filteredList.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              return _buildHistoryCard(
                                filteredList[index],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  // ================= CARD =================
  Widget _buildHistoryCard(
    Map<String, dynamic> item,
  ) {
    bool isKering = item['status'] == "Kering";

    return Card(
      color: const Color(0xFFF2F2F2),
      surfaceTintColor: const Color(0xFFF2F2F2),
      elevation: 0,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= ICON =================
            CircleAvatar(
              backgroundColor:
                  isKering ? Colors.red.shade50 : Colors.green.shade50,
              child: Icon(
                isKering
                    ? Icons.water_drop_outlined
                    : Icons.check_circle_outline,
                color: isKering ? Colors.red : Colors.green,
              ),
            ),

            const SizedBox(width: 16),

            // ================= CONTENT =================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ================= TANGGAL =================
                  Text(
                    item['tanggal'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  Text(
                    item['jam'],
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),

                  const Divider(height: 20),

                  // ================= KELEMBABAN =================
                  Text(
                    "Kelembaban: ${item['kelembaban']}%",
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Perubahan Kelembapan: ${item['perubahan_kelembaban']}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ================= DURASI =================
                  Text(
                    "Lama Pompa: ${item['durasi_pompa']} detik",
                  ),

                  const SizedBox(height: 6),

                  // ================= AIR =================
                  Text(
                    "Volume Air: ${item['volume_air']} mL",
                  ),

                  const SizedBox(height: 10),

                  // ================= STATUS =================
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isKering ? Colors.red : Colors.green,
                          borderRadius: BorderRadius.circular(
                            20,
                          ),
                        ),
                        child: Text(
                          item['status'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        "Mode: ${item['mode']}",
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= CHIP =================
  Widget _buildFilterChip({
    required String title,
    required IconData icon,
  }) {
    bool isSelected = selectedFilter == title;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : Colors.black54,
      ),
      label: Text(title),
      selected: isSelected,
      selectedColor: Colors.green,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) {
        setState(() {
          selectedFilter = title;
          applyFilter();
        });
      },
    );
  }

  // ================= EMPTY =================
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            "Belum ada riwayat aktivitas",
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
