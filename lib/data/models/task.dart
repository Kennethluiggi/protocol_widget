import 'package:isar/isar.dart';

part 'task.g.dart';

@collection
class Task {
  Id id = Isar.autoIncrement;

  late int planId;
  late int orderIndex;

  late String type;
  late String title;

  List<String> bullets = [];

  int? plannedStartMin;
  int? plannedEndMin;
  int? targetMin;

  late String status;

  int? actualStartTs;
  int? actualEndTs;

  int actualAccumulatedMs = 0;

  bool goalChimed = false;
}