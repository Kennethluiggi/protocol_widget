import 'package:isar/isar.dart';

part 'daily_task_completion.g.dart';

@collection
class DailyTaskCompletion {
  Id id = Isar.autoIncrement;

  late String taskId;
  late String dateKey;
  late int completedMinutes;
  late bool isDone;
  late int targetMinutesSnapshot;
}