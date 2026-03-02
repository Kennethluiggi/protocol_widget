import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../data/isar_db.dart';
import '../../data/models/task.dart';

class ProtocolScreen extends StatefulWidget {
  const ProtocolScreen({super.key});

  @override
  State<ProtocolScreen> createState() => _ProtocolScreenState();
}

class _ProtocolScreenState extends State<ProtocolScreen> {
  static const int _settingsPlanId = -1;
  static const String _settingsType = 'user_settings';
  static const String _aotTitle = 'always_on_top';

  final Map<int, DateTime> _runningSince = {};
  final ValueNotifier<DateTime> _ticker = ValueNotifier(DateTime.now());

  late Future<void> _initFuture;
  late final Timer _timer;

  bool _alwaysOnTop = false;
  int _planId = _todayPlanId();

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _ticker.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _ensureTodayRitualTasks();
    await _loadAlwaysOnTop();
  }

  static int _todayPlanId() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  Future<void> _ensureTodayRitualTasks() async {
    final isar = await IsarDb.instance();
    final existing = await isar.tasks.filter().planIdEqualTo(_planId).findAll();
    if (existing.isNotEmpty) {
      return;
    }

    final templates = <({String title, int? targetMin})>[
      (title: 'Walk', targetMin: 30),
      (title: 'Transition (Light meal / half-caff + cold water)', targetMin: null),
      (title: 'Desk + Mantra', targetMin: null),
      (title: 'Brain Dump', targetMin: 15),
    ];

    final tasks = <Task>[];
    for (var i = 0; i < templates.length; i++) {
      final item = templates[i];
      tasks.add(
        Task()
          ..planId = _planId
          ..orderIndex = i
          ..type = 'ritual'
          ..title = item.title
          ..targetMin = item.targetMin
          ..status = 'not_started',
      );
    }

    await isar.writeTxn(() async {
      await isar.tasks.putAll(tasks);
    });
  }

  Future<void> _loadAlwaysOnTop() async {
    final isar = await IsarDb.instance();
    final setting = await isar.tasks
        .filter()
        .planIdEqualTo(_settingsPlanId)
        .typeEqualTo(_settingsType)
        .titleEqualTo(_aotTitle)
        .findFirst();

    _alwaysOnTop = setting?.goalChimed ?? false;
    await _applyAlwaysOnTop(_alwaysOnTop);
  }

  Future<void> _setAlwaysOnTop(bool value) async {
    final isar = await IsarDb.instance();
    final existing = await isar.tasks
        .filter()
        .planIdEqualTo(_settingsPlanId)
        .typeEqualTo(_settingsType)
        .titleEqualTo(_aotTitle)
        .findFirst();

    final row = existing ??
        (Task()
          ..planId = _settingsPlanId
          ..orderIndex = 0
          ..type = _settingsType
          ..title = _aotTitle
          ..status = 'done');

    row.goalChimed = value;

    await isar.writeTxn(() async {
      await isar.tasks.put(row);
    });

    setState(() {
      _alwaysOnTop = value;
    });

    await _applyAlwaysOnTop(value);
  }

  Future<void> _applyAlwaysOnTop(bool value) async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }
    await windowManager.setAlwaysOnTop(value);
  }

  Future<List<Task>> _loadPlanTasks() async {
    final isar = await IsarDb.instance();
    return isar.tasks
        .filter()
        .planIdEqualTo(_planId)
        .typeEqualTo('ritual')
        .sortByOrderIndex()
        .findAll();
  }

  Future<void> _startTask(Task task) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    task.actualStartTs ??= now;
    task.status = 'running';
    _runningSince[task.id] = DateTime.now();
    await _saveTask(task);
    setState(() {});
  }

  Future<void> _pauseTask(Task task) async {
    final since = _runningSince[task.id];
    if (since != null) {
      final delta = DateTime.now().difference(since).inMilliseconds;
      task.actualAccumulatedMs += delta;
    }
    _runningSince.remove(task.id);
    task.status = 'paused';
    await _saveTask(task);
    setState(() {});
  }

  Future<void> _doneTask(Task task) async {
    if (task.status == 'running') {
      final since = _runningSince[task.id];
      if (since != null) {
        final delta = DateTime.now().difference(since).inMilliseconds;
        task.actualAccumulatedMs += delta;
      }
    }

    _runningSince.remove(task.id);
    task.actualEndTs = DateTime.now().millisecondsSinceEpoch;
    task.status = 'done';
    await _saveTask(task);
    setState(() {});
  }

  Future<void> _saveTask(Task task) async {
    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.tasks.put(task);
    });
  }

  int _elapsedMs(Task task, DateTime tick) {
    final base = task.actualAccumulatedMs;
    if (task.status != 'running') return base;
    final since = _runningSince[task.id];
    if (since == null) return base;
    return base + tick.difference(since).inMilliseconds;
  }

  String _formatDuration(int ms) {
    final totalSec = (ms / 1000).floor();
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    final s = totalSec % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _plannedWindow(Task task) {
    final start = task.plannedStartMin;
    final end = task.plannedEndMin;
    if (start == null || end == null) return '—';
    return '${_formatClock(start)}–${_formatClock(end)}';
  }

  String _formatClock(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _editStartTime(Task selected, List<Task> tasks) async {
    final oldStart = selected.plannedStartMin;
    final initialMin = oldStart ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialMin ~/ 60, minute: initialMin % 60),
    );

    if (picked == null) return;

    final newStart = picked.hour * 60 + picked.minute;
    if (oldStart == null) {
      final duration = selected.targetMin ?? 0;
      selected.plannedStartMin = newStart;
      selected.plannedEndMin = duration > 0 ? newStart + duration : newStart;
      await _saveTask(selected);
      setState(() {});
      return;
    }

    final delta = newStart - oldStart;
    if (delta == 0) return;

    final changed = <Task>[];
    for (final task in tasks) {
      if (task.orderIndex < selected.orderIndex) continue;
      if (task.plannedStartMin == null || task.plannedEndMin == null) continue;
      task.plannedStartMin = task.plannedStartMin! + delta;
      task.plannedEndMin = task.plannedEndMin! + delta;
      changed.add(task);
    }

    if (changed.isEmpty) {
      return;
    }

    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.tasks.putAll(changed);
    });

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Protocol Table'),
            actions: [
              Row(
                children: [
                  const Text('Always on top'),
                  Switch(
                    value: _alwaysOnTop,
                    onChanged: _setAlwaysOnTop,
                  ),
                ],
              ),
            ],
          ),
          body: FutureBuilder<List<Task>>(
            future: _loadPlanTasks(),
            builder: (context, tasksSnapshot) {
              if (!tasksSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final tasks = tasksSnapshot.data!;

              return ValueListenableBuilder<DateTime>(
                valueListenable: _ticker,
                builder: (context, tick, _) {
                  return ListView.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final elapsed = _elapsedMs(task, tick);
                      return ListTile(
                        title: Row(
                          children: [
                            SizedBox(
                              width: 92,
                              child: InkWell(
                                onTap: () => _editStartTime(task, tasks),
                                child: Text(
                                  _plannedWindow(task),
                                  style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  decoration: task.status == 'done' ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildControls(task, elapsed),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildControls(Task task, int elapsedMs) {
    switch (task.status) {
      case 'running':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_formatDuration(elapsedMs)),
            const SizedBox(width: 8),
            TextButton(onPressed: () => _pauseTask(task), child: const Text('Pause')),
            const SizedBox(width: 4),
            FilledButton.tonal(onPressed: () => _doneTask(task), child: const Text('Done')),
          ],
        );
      case 'paused':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_formatDuration(elapsedMs)),
            const SizedBox(width: 8),
            TextButton(onPressed: () => _startTask(task), child: const Text('Start')),
            const SizedBox(width: 4),
            FilledButton.tonal(onPressed: () => _doneTask(task), child: const Text('Done')),
          ],
        );
      case 'done':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 6),
            Text(_formatDuration(elapsedMs)),
          ],
        );
      case 'not_started':
      default:
        return TextButton(onPressed: () => _startTask(task), child: const Text('Start'));
    }
  }
}
