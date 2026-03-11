// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_task_completion.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDailyTaskCompletionCollection on Isar {
  IsarCollection<DailyTaskCompletion> get dailyTaskCompletions =>
      this.collection();
}

const DailyTaskCompletionSchema = CollectionSchema(
  name: r'DailyTaskCompletion',
  id: -128571045614151118,
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
    )
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
    DailyTaskCompletion object) {
  return [];
}

void _dailyTaskCompletionAttach(
    IsarCollection<dynamic> col, Id id, DailyTaskCompletion object) {
  object.id = id;
}

extension DailyTaskCompletionQueryWhereSort
    on QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QWhere> {
  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension DailyTaskCompletionQueryWhere
    on QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QWhereClause> {
  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterWhereClause>
      idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterWhereClause>
      idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterWhereClause>
      idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension DailyTaskCompletionQueryFilter on QueryBuilder<DailyTaskCompletion,
    DailyTaskCompletion, QFilterCondition> {
  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      completedMinutesEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'completedMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      completedMinutesGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'completedMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      completedMinutesLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'completedMinutes',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      completedMinutesBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'completedMinutes',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      dateKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      dateKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      dateKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      dateKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dateKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      dateKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      dateKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      dateKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'dateKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      dateKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'dateKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      dateKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dateKey',
        value: '',
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      dateKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'dateKey',
        value: '',
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      isDoneEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDone',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      targetMinutesSnapshotEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'targetMinutesSnapshot',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      targetMinutesSnapshotGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'targetMinutesSnapshot',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      targetMinutesSnapshotLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'targetMinutesSnapshot',
        value: value,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      targetMinutesSnapshotBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'targetMinutesSnapshot',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      taskIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'taskId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      taskIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'taskId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      taskIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'taskId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      taskIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'taskId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      taskIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'taskId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      taskIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'taskId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      taskIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'taskId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      taskIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'taskId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      taskIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'taskId',
        value: '',
      ));
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterFilterCondition>
      taskIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'taskId',
        value: '',
      ));
    });
  }
}

extension DailyTaskCompletionQueryObject on QueryBuilder<DailyTaskCompletion,
    DailyTaskCompletion, QFilterCondition> {}

extension DailyTaskCompletionQueryLinks on QueryBuilder<DailyTaskCompletion,
    DailyTaskCompletion, QFilterCondition> {}

extension DailyTaskCompletionQuerySortBy
    on QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QSortBy> {
  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      sortByCompletedMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedMinutes', Sort.asc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      sortByCompletedMinutesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedMinutes', Sort.desc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      sortByDateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.asc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      sortByDateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.desc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      sortByIsDone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDone', Sort.asc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      sortByIsDoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDone', Sort.desc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      sortByTargetMinutesSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetMinutesSnapshot', Sort.asc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      sortByTargetMinutesSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetMinutesSnapshot', Sort.desc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      sortByTaskId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskId', Sort.asc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      sortByTaskIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskId', Sort.desc);
    });
  }
}

extension DailyTaskCompletionQuerySortThenBy
    on QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QSortThenBy> {
  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      thenByCompletedMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedMinutes', Sort.asc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      thenByCompletedMinutesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'completedMinutes', Sort.desc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      thenByDateKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.asc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      thenByDateKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateKey', Sort.desc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      thenByIsDone() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDone', Sort.asc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      thenByIsDoneDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDone', Sort.desc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      thenByTargetMinutesSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetMinutesSnapshot', Sort.asc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      thenByTargetMinutesSnapshotDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'targetMinutesSnapshot', Sort.desc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      thenByTaskId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskId', Sort.asc);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QAfterSortBy>
      thenByTaskIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskId', Sort.desc);
    });
  }
}

extension DailyTaskCompletionQueryWhereDistinct
    on QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QDistinct> {
  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QDistinct>
      distinctByCompletedMinutes() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'completedMinutes');
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QDistinct>
      distinctByDateKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dateKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QDistinct>
      distinctByIsDone() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDone');
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QDistinct>
      distinctByTargetMinutesSnapshot() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'targetMinutesSnapshot');
    });
  }

  QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QDistinct>
      distinctByTaskId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'taskId', caseSensitive: caseSensitive);
    });
  }
}

extension DailyTaskCompletionQueryProperty
    on QueryBuilder<DailyTaskCompletion, DailyTaskCompletion, QQueryProperty> {
  QueryBuilder<DailyTaskCompletion, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DailyTaskCompletion, int, QQueryOperations>
      completedMinutesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'completedMinutes');
    });
  }

  QueryBuilder<DailyTaskCompletion, String, QQueryOperations>
      dateKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dateKey');
    });
  }

  QueryBuilder<DailyTaskCompletion, bool, QQueryOperations> isDoneProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDone');
    });
  }

  QueryBuilder<DailyTaskCompletion, int, QQueryOperations>
      targetMinutesSnapshotProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'targetMinutesSnapshot');
    });
  }

  QueryBuilder<DailyTaskCompletion, String, QQueryOperations> taskIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'taskId');
    });
  }
}
