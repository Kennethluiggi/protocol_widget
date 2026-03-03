import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:isar/isar.dart';

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
  static const String _mantraLine1Key = 'mantra_line_1';
  static const String _mantraLine2Key = 'mantra_line_2';
  static const String _mantraLine3Key = 'mantra_line_3';
  static const String _mantraLine4Key = 'mantra_line_4';

  static const int _line1Max = 28;
  static const int _line2Max = 28;
  static const int _line3Max = 30;
  static const int _line4Max = 34;

  static const String _defaultLine1 = 'WHEN I SIT DOWN, I START.';
  static const String _defaultLine2 = 'I DON\'T NEGOTIATE WITH TODAY.';
  static const String _defaultLine3 = 'FINISH FIRST. IMPROVE SECOND.';
  static const String _defaultLine4 = 'CONSISTENCY BUILDS THE PROVIDER.';

  static const double _timeColumnWidth = 100;
  static const double _goalColumnWidth = 92;
  static const double _controlColumnWidth = 220;

  final Map<int, DateTime> _runningSince = {};
  final ValueNotifier<DateTime> _ticker = ValueNotifier(DateTime.now());

  late Future<void> _initFuture;
  late final Timer _timer;

  bool _alwaysOnTop = false;
  int _planId = _todayPlanId();
  String _mantraLine1 = _defaultLine1;
  String _mantraLine2 = _defaultLine2;
  String _mantraLine3 = _defaultLine3;
  String _mantraLine4 = _defaultLine4;

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
    await _loadMantra();
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
    final setting = await _getSetting(_aotTitle);
    _alwaysOnTop = setting?.goalChimed ?? false;
    await _applyAlwaysOnTop(_alwaysOnTop);
  }

  Future<void> _setAlwaysOnTop(bool value) async {
    final existing = await _getSetting(_aotTitle);
    final row = _newOrExistingSetting(existing, _aotTitle)..goalChimed = value;

    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.tasks.put(row);
    });

    setState(() {
      _alwaysOnTop = value;
    });

    await _applyAlwaysOnTop(value);
  }

  Future<void> _loadMantra() async {
    final line1 = await _getSettingText(_mantraLine1Key);
    final line2 = await _getSettingText(_mantraLine2Key);
    final line3 = await _getSettingText(_mantraLine3Key);
    final line4 = await _getSettingText(_mantraLine4Key);

    setState(() {
      _mantraLine1 = (line1 == null || line1.trim().isEmpty) ? _defaultLine1 : line1;
      _mantraLine2 = (line2 == null || line2.trim().isEmpty) ? _defaultLine2 : line2;
      _mantraLine3 = (line3 == null || line3.trim().isEmpty) ? _defaultLine3 : line3;
      _mantraLine4 = (line4 == null || line4.trim().isEmpty) ? _defaultLine4 : line4;
    });
  }

  Future<Task?> _getSetting(String key) async {
    final isar = await IsarDb.instance();
    return isar.tasks
        .filter()
        .planIdEqualTo(_settingsPlanId)
        .typeEqualTo(_settingsType)
        .titleEqualTo(key)
        .findFirst();
  }

  Task _newOrExistingSetting(Task? existing, String key) {
    return existing ??
        (Task()
          ..planId = _settingsPlanId
          ..orderIndex = 0
          ..type = _settingsType
          ..title = key
          ..status = 'done');
  }

  Future<String?> _getSettingText(String key) async {
    final setting = await _getSetting(key);
    if (setting == null || setting.bullets.isEmpty) {
      return null;
    }
    return setting.bullets.first;
  }

  Future<void> _saveSettingText(String key, String value) async {
    final existing = await _getSetting(key);
    final row = _newOrExistingSetting(existing, key)..bullets = [value];

    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.tasks.put(row);
    });
  }

  Future<void> _openEditMantraDialog() async {
    final line1Controller = TextEditingController(text: _mantraLine1);
    final line2Controller = TextEditingController(text: _mantraLine2);
    final line3Controller = TextEditingController(text: _mantraLine3);
    final line4Controller = TextEditingController(text: _mantraLine4);

    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit mantra'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMantraField('Line 1', line1Controller, _line1Max),
                const SizedBox(height: 8),
                _buildMantraField('Line 2', line2Controller, _line2Max),
                const SizedBox(height: 8),
                _buildMantraField('Line 3', line3Controller, _line3Max),
                const SizedBox(height: 8),
                _buildMantraField('Line 4', line4Controller, _line4Max),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (didSave == true) {
      final nextLine1 = line1Controller.text.trim().isEmpty ? _defaultLine1 : line1Controller.text.trim();
      final nextLine2 = line2Controller.text.trim().isEmpty ? _defaultLine2 : line2Controller.text.trim();
      final nextLine3 = line3Controller.text.trim().isEmpty ? _defaultLine3 : line3Controller.text.trim();
      final nextLine4 = line4Controller.text.trim().isEmpty ? _defaultLine4 : line4Controller.text.trim();

      await _saveSettingText(_mantraLine1Key, nextLine1);
      await _saveSettingText(_mantraLine2Key, nextLine2);
      await _saveSettingText(_mantraLine3Key, nextLine3);
      await _saveSettingText(_mantraLine4Key, nextLine4);

      if (mounted) {
        setState(() {
          _mantraLine1 = nextLine1;
          _mantraLine2 = nextLine2;
          _mantraLine3 = nextLine3;
          _mantraLine4 = nextLine4;
        });
      }
    }

    line1Controller.dispose();
    line2Controller.dispose();
    line3Controller.dispose();
    line4Controller.dispose();
  }

  Widget _buildMantraField(String label, TextEditingController controller, int maxChars) {
    return TextField(
      controller: controller,
      maxLength: maxChars,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      inputFormatters: [LengthLimitingTextInputFormatter(maxChars)],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _applyAlwaysOnTop(bool value) async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }
    await windowManager.setAlwaysOnTop(value);
  }

  Future<List<Task>> _loadPlanTasks() async {
    final isar = await IsarDb.instance();
    return isar.tasks.filter().planIdEqualTo(_planId).sortByOrderIndex().findAll();
  }

  Future<void> _openAddTaskDialog(List<Task> tasks) async {
    final titleController = TextEditingController();
    final goalController = TextEditingController();
    TimeOfDay? plannedStart;
    String? errorText;

    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Title *',
                        border: const OutlineInputBorder(),
                        errorText: errorText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: goalController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Goal minutes (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plannedStart == null
                                ? 'Planned start: —'
                                : 'Planned start: ${plannedStart!.format(context)}',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: plannedStart ?? const TimeOfDay(hour: 9, minute: 0),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                plannedStart = picked;
                              });
                            }
                          },
                          child: const Text('Pick time'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) {
                      setDialogState(() {
                        errorText = 'Title is required';
                      });
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (didSave == true) {
      final title = titleController.text.trim();
      final goalMin = int.tryParse(goalController.text.trim());
      final plannedStartMin = plannedStart == null ? null : plannedStart!.hour * 60 + plannedStart!.minute;
      final plannedEndMin = (plannedStartMin != null && goalMin != null) ? plannedStartMin + goalMin : null;

      var nextOrderIndex = 0;
      for (final task in tasks) {
        if (task.orderIndex >= nextOrderIndex) {
          nextOrderIndex = task.orderIndex + 1;
        }
      }

      final newTask = Task()
        ..planId = _planId
        ..orderIndex = nextOrderIndex
        ..type = 'focus'
        ..title = title
        ..targetMin = goalMin
        ..plannedStartMin = plannedStartMin
        ..plannedEndMin = plannedEndMin
        ..status = 'not_started';

      final isar = await IsarDb.instance();
      await isar.writeTxn(() async {
        await isar.tasks.put(newTask);
      });

      if (mounted) {
        setState(() {});
      }
    }

    titleController.dispose();
    goalController.dispose();
  }

  Future<void> _resetToday(List<Task> tasks) async {
    final resettable = <Task>[];
    for (final task in tasks) {
      task.status = 'not_started';
      task.actualStartTs = null;
      task.actualEndTs = null;
      task.actualAccumulatedMs = 0;
      task.goalChimed = false;
      resettable.add(task);
      _runningSince.remove(task.id);
    }

    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.tasks.putAll(resettable);
    });

    if (mounted) {
      setState(() {});
    }
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

  String _goalText(Task task) {
    if (task.targetMin == null) {
      return '—';
    }
    return '${task.targetMin} min';
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

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: const [
          SizedBox(
            width: _timeColumnWidth,
            child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: _goalColumnWidth,
            child: Text('Goal', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: _controlColumnWidth,
            child: Text('Control', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _openEditMantraDialog,
                        child: const Text('Edit'),
                      ),
                    ),
                    Text(
                      _mantraLine1,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _mantraLine2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.6),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _mantraLine3,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.4),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _mantraLine4,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              FutureBuilder<List<Task>>(
                future: _loadPlanTasks(),
                builder: (context, tasksSnapshot) {
                  if (!tasksSnapshot.hasData) {
                    return const Expanded(child: Center(child: CircularProgressIndicator()));
                  }
                  final tasks = tasksSnapshot.data!;

                  return Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            children: [
                              FilledButton.tonal(
                                onPressed: () => _openAddTaskDialog(tasks),
                                child: const Text('Add Task'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: tasks.isEmpty ? null : () => _resetToday(tasks),
                                child: const Text('Reset Today'),
                              ),
                            ],
                          ),
                        ),
                        _buildHeaderRow(),
                        const Divider(height: 1),
                        Expanded(
                          child: ValueListenableBuilder<DateTime>(
                            valueListenable: _ticker,
                            builder: (context, tick, _) {
                              return ListView.separated(
                                itemCount: tasks.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final task = tasks[index];
                                  final elapsed = _elapsedMs(task, tick);
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: _timeColumnWidth,
                                          child: InkWell(
                                            onTap: () => _editStartTime(task, tasks),
                                            child: Text(
                                              _plannedWindow(task),
                                              style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            task.title,
                                            style: TextStyle(
                                              decoration: task.status == 'done' ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: _goalColumnWidth, child: Text(_goalText(task))),
                                        SizedBox(width: _controlColumnWidth, child: _buildControls(task, elapsed)),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
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
            const SizedBox(width: 6),
            TextButton(onPressed: () => _pauseTask(task), child: const Text('Pause')),
            const SizedBox(width: 2),
            FilledButton.tonal(onPressed: () => _doneTask(task), child: const Text('Done')),
          ],
        );
      case 'paused':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_formatDuration(elapsedMs)),
            const SizedBox(width: 6),
            TextButton(onPressed: () => _startTask(task), child: const Text('Start')),
            const SizedBox(width: 2),
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
