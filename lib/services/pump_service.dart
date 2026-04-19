import 'dart:async';

import 'package:firebase_database/firebase_database.dart';

/// Simple pump automation service that watches realtime DB nodes and issues
/// commands to `control/pump` when mode is `Otomatis`.
///
/// Note: For reliability, prefer running this logic on the device (MCU)
/// or in a backend (Cloud Function). This service is a quick app-side
/// implementation for prototyping.
class PumpService {
  final DatabaseReference dbRef;
  final int threshold;

  StreamSubscription<DatabaseEvent>? _liveSub;
  StreamSubscription<DatabaseEvent>? _modeSub;

  String _mode = 'Manual';
  int _soilValue = 0;
  String _pumpState = 'OFF';

  PumpService(this.dbRef, {this.threshold = 40});

  void start() {
    // Listen live data (soil value & pump state)
    _liveSub = dbRef.child('live').onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return;
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);

      _pumpState = data['pump_state']?.toString() ?? 'OFF';

      // handle int / string
      _soilValue = data['value'] is int
          ? data['value']
          : int.tryParse(data['value'].toString()) ?? 0;

      _evaluate();
    });

    // Listen mode changes
    _modeSub = dbRef.child('control/mode').onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        _mode = event.snapshot.value.toString();
        _evaluate();
      }
    });
  }

  void _evaluate() {
    // Only act when in otomatis mode
    if (_mode != 'Otomatis') return;

    // If soil below threshold, ensure pump is ON
    if (_soilValue < threshold && _pumpState != 'ON') {
      dbRef.child('control/pump').set('ON');
    }

    // If soil at/above threshold, ensure pump is OFF
    if (_soilValue >= threshold && _pumpState != 'OFF') {
      dbRef.child('control/pump').set('OFF');
    }
  }

  void stop() {
    _liveSub?.cancel();
    _modeSub?.cancel();
  }
}
