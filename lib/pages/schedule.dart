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

  void addSchedule() {
    String hour = hourController.text.trim();
    String minute = minuteController.text.trim();

    if (hour.isEmpty || minute.isEmpty || durationController.text.isEmpty) {
      return;
    }

    String time = "${hour.padLeft(2, '0')}:${minute.padLeft(2, '0')}";

    ref.push().set({
      "time": time,
      "duration": int.tryParse(durationController.text) ?? 0,
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
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        title: const Text(
          "Penjadwalan",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ================= INPUT CARD =================
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Tambah Jadwal",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // JAM & MENIT
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hourController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Jam",
                              hintText: "07",
                              filled: true,
                              fillColor: const Color(0xffF1F4F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: minuteController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Menit",
                              hintText: "15",
                              filled: true,
                              fillColor: const Color(0xffF1F4F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Durasi (menit)",
                        filled: true,
                        fillColor: const Color(0xffF1F4F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: addSchedule,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 90, 158, 227),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Simpan Jadwal",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Daftar Jadwal",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ================= LIST =================
              StreamBuilder(
                stream: ref.onValue,
                builder: (context, snapshot) {
                  if (!snapshot.hasData ||
                      snapshot.data!.snapshot.value == null) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Text("Belum ada jadwal"),
                    );
                  }

                  final data = Map<String, dynamic>.from(
                    snapshot.data!.snapshot.value as Map,
                  );

                  return Column(
                    children: data.entries.map((e) {
                      final key = e.key;
                      final item = Map<String, dynamic>.from(e.value);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: item["active"] == true
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item["time"].toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    "Durasi: ${item["duration"]} menit",
                                    style: const TextStyle(color: Colors.grey),
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
            ],
          ),
        ),
      ),
    );
  }
}
