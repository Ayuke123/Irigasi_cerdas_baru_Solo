import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final DatabaseReference ref = FirebaseDatabase.instance.ref("schedule/item");

  final TextEditingController dateController = TextEditingController();

  final TextEditingController hourController = TextEditingController();

  final TextEditingController minuteController = TextEditingController();

  final TextEditingController durationController = TextEditingController();

  // =========================
  // ADD / UPDATE SCHEDULE
  // =========================
  void addSchedule() {
    String hour = hourController.text.trim();
    String minute = minuteController.text.trim();
    String date = dateController.text.trim();

    if (hour.isEmpty ||
        minute.isEmpty ||
        durationController.text.isEmpty ||
        date.isEmpty) {
      return;
    }

    String time = "${hour.padLeft(2, '0')}:${minute.padLeft(2, '0')}";

    // HANYA 1 JADWAL
    ref.set({
      "date": date,
      "time": time,
      "duration": int.tryParse(durationController.text) ?? 0,
      "active": true,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Jadwal berhasil disimpan"),
      ),
    );

    dateController.clear();
    hourController.clear();
    minuteController.clear();
    durationController.clear();
  }

  // =========================
  // TOGGLE ACTIVE
  // =========================
  void toggle(bool value) {
    ref.update({
      "active": value,
    });
  }

  // =========================
  // DELETE
  // =========================
  void deleteSchedule() {
    ref.remove();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FB),
      appBar: AppBar(
        title: const Text(
          "Penjadwalan",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
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
              // =========================
              // INPUT CARD
              // =========================
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

                    // =========================
                    // TANGGAL
                    // =========================
                    TextField(
                      controller: dateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Tanggal",
                        hintText: "Pilih tanggal",
                        filled: true,
                        fillColor: const Color(0xffF1F4F9),
                        suffixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035),
                        );

                        if (picked != null) {
                          setState(() {
                            dateController.text =
                                "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 12),

                    // =========================
                    // JAM MENIT
                    // =========================
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

                    // =========================
                    // DURASI
                    // =========================
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

                    // =========================
                    // BUTTON
                    // =========================
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

              // =========================
              // TITLE
              // =========================
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Jadwal Aktif",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // =========================
              // LIST
              // =========================
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

                  final item = Map<String, dynamic>.from(
                    snapshot.data!.snapshot.value as Map,
                  );

                  return Container(
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
                                item["date"].toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                item["time"].toString(),
                              ),
                              Text(
                                "Durasi: ${item["duration"]} menit",
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: item["active"] == true,
                          onChanged: (val) {
                            toggle(val);
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                          onPressed: deleteSchedule,
                        ),
                      ],
                    ),
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
