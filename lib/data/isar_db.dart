import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/task.dart';

class IsarDb {
  static Isar? _isar;

  static Future<Isar> instance() async {
    if (_isar != null) return _isar!;
    final dir = await getApplicationSupportDirectory();

    _isar = await Isar.open(
      [TaskSchema],
      directory: dir.path,
      inspector: true,
    );

    return _isar!;
  }
}