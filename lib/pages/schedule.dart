import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final DatabaseReference ref = FirebaseDatabase.instance.ref("schedule/items");

  final TextEditingController hourController = TextEditingController();
  final TextEditingController minuteController = TextEditingController();
  final TextEditingController durationController = TextEditingController();

  // ➕ SIMPAN JADWAL (FIXED)
  void addSchedule() {
    String hour = hourController.text.trim();
    String minute = minuteController.text.trim();

    if (hour.isEmpty || minute.isEmpty || durationController.text.isEmpty)
      return;

    // pastikan format 2 digit
    String time = "${hour.padLeft(2, '0')}:${minute.padLeft(2, '0')}";

    ref.push().set({
      "time": time, // ✔ STRING AMAN
      "duration": int.tryParse(durationController.text) ?? 0, // ✔ INT AMAN
      "active": true,
    });

    hourController.clear();
    minuteController.clear();
    durationController.clear();
  }

  void toggle(String key, bool value) {
    ref.child(key).update({"active": value});
  }

  void delete(String key) {
    ref.child(key).remove();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text("Penjadwalan"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ================= INPUT =================
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 8),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Tambah Jadwal",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 12),

                // JAM & MENIT
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hourController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Jam (00-23)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: minuteController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Menit (00-59)",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Durasi (menit)",
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: addSchedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 61, 149, 208),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: const Text("Simpan"),
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Daftar Jadwal",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),

          // ================= LIST =================
          Expanded(
            child: StreamBuilder(
              stream: ref.onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
                  return const Center(
                    child: Text("Belum ada jadwal"),
                  );
                }

                final data = Map<String, dynamic>.from(
                  snapshot.data!.snapshot.value as Map,
                );

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: data.entries.map((e) {
                    final key = e.key;
                    final item = Map<String, dynamic>.from(e.value);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            color: (item["active"] == true)
                                ? const Color.fromARGB(255, 126, 187, 228)
                                : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ✔ FIX ERROR TYPE INT/STRING
                                Text(
                                  item["time"].toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),

                                Text(
                                  "Durasi: ${item["duration"].toString()} menit",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: item["active"] == true,
                            onChanged: (val) => toggle(key, val),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => delete(key),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
