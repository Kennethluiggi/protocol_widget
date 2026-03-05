import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/task.dart';

class IsarDb {
  static Isar? _isar;

  static Future<Isar> instance() async {
    if (_isar != null) return _isar!;
    final dir = await getApplicationSupportDirectory();
    debugPrint('[IsarDb] support dir: ${dir.path}');

    _isar = await Isar.open(
      [TaskSchema],
      directory: dir.path,
      inspector: true,
    );

    return _isar!;
  }

  static Future<void> reset() async {
    if (_isar == null) return;
    try {
      await _isar!.close();
    } catch (_) {
      // ignore close failures on resume edge cases
    } finally {
      _isar = null;
    }
    debugPrint('[IsarDb] reset() complete');
  }
}