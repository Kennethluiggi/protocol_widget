import 'package:isar/isar.dart';

@collection
class DailyTaskCompletion {
  Id id = Isar.autoIncrement;

  late String taskId;
  late String dateKey;
  late int completedMinutes;
  late bool isDone;
  late int targetMinutesSnapshot;
}

extension GetDailyTaskCompletionCollection on Isar {
  IsarCollection<DailyTaskCompletion> get dailyTaskCompletions => collection();
}

const DailyTaskCompletionSchema = CollectionSchema(
  name: r'DailyTaskCompletion',
  id: 7123948501217765421,
  properties: {
    r'completedMinutes': PropertySchema(
      id: 0,
      name: r'completedMinutes',
      type: IsarType.long,
    ),
    r'dateKey': PropertySchema(
      id: 1,
      name: r'dateKey',
      type: IsarType.string,
    ),
    r'isDone': PropertySchema(
      id: 2,
      name: r'isDone',
      type: IsarType.bool,
    ),
    r'targetMinutesSnapshot': PropertySchema(
      id: 3,
      name: r'targetMinutesSnapshot',
      type: IsarType.long,
    ),
    r'taskId': PropertySchema(
      id: 4,
      name: r'taskId',
      type: IsarType.string,
    ),
  },
  estimateSize: _dailyTaskCompletionEstimateSize,
  serialize: _dailyTaskCompletionSerialize,
  deserialize: _dailyTaskCompletionDeserialize,
  deserializeProp: _dailyTaskCompletionDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _dailyTaskCompletionGetId,
  getLinks: _dailyTaskCompletionGetLinks,
  attach: _dailyTaskCompletionAttach,
  version: '3.1.0+1',
);

int _dailyTaskCompletionEstimateSize(
  DailyTaskCompletion object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.dateKey.length * 3;
  bytesCount += 3 + object.taskId.length * 3;
  return bytesCount;
}

void _dailyTaskCompletionSerialize(
  DailyTaskCompletion object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.completedMinutes);
  writer.writeString(offsets[1], object.dateKey);
  writer.writeBool(offsets[2], object.isDone);
  writer.writeLong(offsets[3], object.targetMinutesSnapshot);
  writer.writeString(offsets[4], object.taskId);
}

DailyTaskCompletion _dailyTaskCompletionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DailyTaskCompletion();
  object.completedMinutes = reader.readLong(offsets[0]);
  object.dateKey = reader.readString(offsets[1]);
  object.id = id;
  object.isDone = reader.readBool(offsets[2]);
  object.targetMinutesSnapshot = reader.readLong(offsets[3]);
  object.taskId = reader.readString(offsets[4]);
  return object;
}

P _dailyTaskCompletionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _dailyTaskCompletionGetId(DailyTaskCompletion object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _dailyTaskCompletionGetLinks(
  DailyTaskCompletion object,
) {
  return [];
}

void _dailyTaskCompletionAttach(
  IsarCollection<dynamic> col,
  Id id,
  DailyTaskCompletion object,
) {
  object.id = id;
}
