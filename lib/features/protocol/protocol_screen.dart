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
  static const String _themeTitle = 'header_theme';
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
  static const String _walkTitle = 'Walk';
  static const String _transitionTitle = 'Transition (Light meal / half-caff + cold water)';
  static const String _deskMantraTitle = 'Desk + Mantra';
  static const String _brainDumpTitle = 'Brain Dump';
  static const String _defaultThemeId = 'clouds';

  static const List<String> _themeOptions = ['clouds', 'books', 'aggressive', 'minimal'];

  static const double _timeColumnWidth = 190;
  static const double _goalColumnWidth = 130;
  static const double _controlColumnWidth = 220;
  static const int _taskTitleMaxChars = 40;
  static const Set<String> _mandatoryRitualTitles = {
    _walkTitle,
    _transitionTitle,
    _deskMantraTitle,
    _brainDumpTitle,
  };

  final Map<int, DateTime> _runningSince = {};
  final ValueNotifier<DateTime> _ticker = ValueNotifier(DateTime.now());

  late Future<void> _initFuture;
  late final Timer _timer;

  bool _alwaysOnTop = false;
  bool _deleteMode = false;
  int _planId = _todayPlanId();
  String _selectedThemeId = _defaultThemeId;
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
    await _loadTheme();
  }

  static DateTime _localNow() => DateTime.now().toLocal();

  static int _todayPlanId() {
    final now = _localNow();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  Future<void> _ensureTodayRitualTasks() async {
    final isar = await IsarDb.instance();
    final existing = await isar.tasks.filter().planIdEqualTo(_planId).findAll();
    if (existing.isNotEmpty) return;

    final templates = <({String title, int? targetMin})>[
      (title: _walkTitle, targetMin: 30),
      (title: _transitionTitle, targetMin: null),
      (title: _deskMantraTitle, targetMin: null),
      (title: _brainDumpTitle, targetMin: 15),
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
    if (setting == null || setting.bullets.isEmpty) return null;
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

  Future<void> _loadTheme() async {
    final value = await _getSettingText(_themeTitle);
    setState(() {
      _selectedThemeId = _themeOptions.contains(value) ? value! : _defaultThemeId;
    });
  }

  Future<void> _saveTheme(String themeId) async {
    await _saveSettingText(_themeTitle, themeId);
    if (!mounted) return;
    setState(() {
      _selectedThemeId = themeId;
    });
  }

  Future<void> _openThemePickerDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Header Theme'),
          content: SizedBox(
            width: 420,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _themeOptions.map((themeId) {
                final isSelected = themeId == _selectedThemeId;
                return InkWell(
                  onTap: () => Navigator.of(context).pop(themeId),
                  child: Container(
                    width: 180,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/themes/$themeId.png',
                            height: 84,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.black12,
                              height: 84,
                              alignment: Alignment.center,
                              child: const Text('Missing image'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(themeId.toUpperCase()),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (selected == null || selected == _selectedThemeId) return;
    await _saveTheme(selected);
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
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
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
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Future<void> _applyAlwaysOnTop(bool value) async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    await windowManager.setAlwaysOnTop(value);
  }

  Future<List<Task>> _loadPlanTasks() async {
    final localTodayPlanId = _todayPlanId();
    if (_planId != localTodayPlanId) {
      _planId = localTodayPlanId;
      await _ensureTodayRitualTasks();
    }

    final isar = await IsarDb.instance();
    return isar.tasks.filter().planIdEqualTo(_planId).sortByOrderIndex().findAll();
  }

  Future<void> _openAddTaskDialog(List<Task> tasks) async {
    final titleController = TextEditingController();
    final goalController = TextEditingController();
    TimeOfDay? plannedStart;
    String? titleError;
    String? goalError;
    String? startError;

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
                      maxLength: _taskTitleMaxChars,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      inputFormatters: [LengthLimitingTextInputFormatter(_taskTitleMaxChars)],
                      decoration: InputDecoration(
                        labelText: 'Task name *',
                        border: const OutlineInputBorder(),
                        errorText: titleError,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: goalController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Goal minutes *',
                        border: const OutlineInputBorder(),
                        errorText: goalError,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plannedStart == null ? 'Planned start: —' : 'Planned start: ${plannedStart!.format(context)}',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final picked = await _pickValidStartTime(
                              tasks: tasks,
                              isRitualTask: false,
                              initialMinutes: plannedStart == null ? null : plannedStart!.hour * 60 + plannedStart!.minute,
                            );
                            if (picked != null) {
                              setDialogState(() {
                                plannedStart = TimeOfDay(hour: picked ~/ 60, minute: picked % 60);
                                startError = null;
                              });
                            }
                          },
                          child: const Text('Pick time'),
                        ),
                      ],
                    ),
                    if (startError != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          startError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    final parsed = int.tryParse(goalController.text.trim());
                    final missingTitle = titleController.text.trim().isEmpty;
                    final missingGoal = parsed == null || parsed <= 0;
                    final missingStart = plannedStart == null;
                    if (missingTitle || missingGoal || missingStart) {
                      setDialogState(() {
                        titleError = missingTitle ? 'Title is required' : null;
                        goalError = missingGoal ? 'Goal minutes required' : null;
                        startError = missingStart ? 'Planned start required' : null;
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
      final goalMin = int.parse(goalController.text.trim());
      final startMin = plannedStart!.hour * 60 + plannedStart!.minute;
      final endMin = startMin + goalMin;

      var nextOrderIndex = 0;
      for (final task in tasks) {
        if (task.orderIndex >= nextOrderIndex) nextOrderIndex = task.orderIndex + 1;
      }

      final newTask = Task()
        ..planId = _planId
        ..orderIndex = nextOrderIndex
        ..type = 'focus'
        ..title = title
        ..targetMin = goalMin
        ..plannedStartMin = startMin
        ..plannedEndMin = endMin
        ..status = 'not_started';

      final isar = await IsarDb.instance();
      await isar.writeTxn(() async {
        await isar.tasks.put(newTask);
      });

      final updatedTasks = await _loadPlanTasks();
      await _sortTasksByStartTime(updatedTasks);
      if (mounted) setState(() {});
    }

    titleController.dispose();
    goalController.dispose();
  }

  Future<void> _resetToday(List<Task> tasks) async {
    for (final task in tasks) {
      task.status = 'not_started';
      task.actualStartTs = null;
      task.actualEndTs = null;
      task.actualAccumulatedMs = 0;
      task.goalChimed = false;
      _runningSince.remove(task.id);
    }

    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.tasks.putAll(tasks);
    });
    if (mounted) setState(() {});
  }

  Future<void> _startTask(Task task) async {
    final tasks = await _loadPlanTasks();
    final hasOtherActiveSession = tasks.any((item) => item.id != task.id && (item.status == 'running' || item.status == 'paused'));
    if (hasOtherActiveSession) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finish or reset the current active session before starting another task.')),
        );
      }
      return;
    }

    task.actualStartTs ??= DateTime.now().millisecondsSinceEpoch;
    task.status = 'running';
    _runningSince[task.id] = DateTime.now();
    await _saveTask(task);
    setState(() {});
  }

  Future<void> _pauseTask(Task task) async {
    final since = _runningSince[task.id];
    if (since != null) {
      task.actualAccumulatedMs += DateTime.now().difference(since).inMilliseconds;
    }
    _runningSince.remove(task.id);
    task.status = 'paused';
    await _saveTask(task);
    setState(() {});
  }

  Future<void> _doneTask(Task task) async {
    final since = _runningSince[task.id];
    if (since != null && task.status == 'running') {
      task.actualAccumulatedMs += DateTime.now().difference(since).inMilliseconds;
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

  int? _ritualOrder(String title) {
    if (title == _walkTitle) return 0;
    if (title == _transitionTitle) return 1;
    if (title == _deskMantraTitle) return 2;
    if (title == _brainDumpTitle) return 3;
    return null;
  }

  int? _nonRitualStartThreshold(List<Task> tasks) {
    for (final task in tasks) {
      if (task.title != _brainDumpTitle) continue;
      if (task.plannedEndMin != null) return task.plannedEndMin;
      if (task.plannedStartMin != null && task.targetMin != null) {
        return task.plannedStartMin! + task.targetMin!;
      }
    }
    return null;
  }

  Future<int?> _pickValidStartTime({
    required List<Task> tasks,
    required bool isRitualTask,
    int? initialMinutes,
  }) async {
    var nextInitial = initialMinutes ?? 540;
    while (true) {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: nextInitial ~/ 60, minute: nextInitial % 60),
      );
      if (picked == null) return null;

      final pickedStart = picked.hour * 60 + picked.minute;
      final threshold = isRitualTask ? null : _nonRitualStartThreshold(tasks);
      if (threshold != null && pickedStart < threshold) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You can’t schedule tasks before your 4 mandatory locked tasks. Choose a time after your ritual.',
              ),
            ),
          );
        }
        nextInitial = threshold;
        continue;
      }
      return pickedStart;
    }
  }

  Future<void> _sortTasksByStartTime(List<Task> tasks) async {
    final ritualTasks = <Task>[];
    final nonRitualTasks = <Task>[];

    for (final task in tasks) {
      if (_ritualOrder(task.title) != null) {
        ritualTasks.add(task);
      } else {
        nonRitualTasks.add(task);
      }
    }

    ritualTasks.sort((a, b) {
      return _ritualOrder(a.title)!.compareTo(_ritualOrder(b.title)!);
    });

    nonRitualTasks.sort((a, b) {
      final aStart = a.plannedStartMin;
      final bStart = b.plannedStartMin;
      if (aStart == null && bStart == null) {
        return a.orderIndex.compareTo(b.orderIndex);
      }
      if (aStart == null) return 1;
      if (bStart == null) return -1;
      final byStart = aStart.compareTo(bStart);
      if (byStart != 0) return byStart;
      return a.orderIndex.compareTo(b.orderIndex);
    });

    final combined = <Task>[...ritualTasks, ...nonRitualTasks];
    for (var i = 0; i < combined.length; i++) {
      combined[i].orderIndex = i;
    }

    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.tasks.putAll(combined);
    });
  }

  Task? _activeSessionTask(List<Task> tasks) {
    for (final task in tasks) {
      if (task.status == 'running') return task;
    }
    for (final task in tasks) {
      if (task.status == 'paused') return task;
    }
    return null;
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

  String _formatClock(BuildContext context, int minutes) {
    final hour = (minutes ~/ 60) % 24;
    final minute = minutes % 60;
    return MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));
  }

  String _plannedWindow(BuildContext context, Task task) {
    final start = task.plannedStartMin;
    final end = task.plannedEndMin;
    if (start == null || end == null) return '—';
    return '${_formatClock(context, start)}–${_formatClock(context, end)}';
  }

  Future<void> _editStartTime(Task selected, List<Task> tasks) async {
    final oldStart = selected.plannedStartMin;
    final newStart = await _pickValidStartTime(
      tasks: tasks,
      isRitualTask: _isMandatoryTask(selected),
      initialMinutes: oldStart,
    );
    if (newStart == null || oldStart == newStart) return;

    selected.plannedStartMin = newStart;
    selected.plannedEndMin = selected.targetMin == null ? null : newStart + selected.targetMin!;
    await _sortTasksByStartTime(tasks);
    setState(() {});
  }

  Future<void> _editGoal(Task task) async {
    final controller = TextEditingController(text: task.targetMin?.toString() ?? '');
    int? selectedValue = task.targetMin;

    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Set goal (minutes)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Minutes', border: OutlineInputBorder()),
                    onChanged: (v) {
                      setDialogState(() {
                        selectedValue = int.tryParse(v);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [10, 15, 30, 40, 60].map((m) {
                      return ChoiceChip(
                        label: Text('$m'),
                        selected: selectedValue == m,
                        onSelected: (_) {
                          setDialogState(() {
                            selectedValue = m;
                            controller.text = '$m';
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
              ],
            );
          },
        );
      },
    );

    if (didSave != true) {
      controller.dispose();
      return;
    }

    final goal = int.tryParse(controller.text.trim());
    controller.dispose();
    if (goal == null || goal <= 0) return;

    task.targetMin = goal;
    if (task.plannedStartMin != null) {
      task.plannedEndMin = task.plannedStartMin! + goal;
    }
    await _saveTask(task);
    if (mounted) setState(() {});
  }

  Future<void> _editTaskName(Task task) async {
    final controller = TextEditingController(text: task.title);
    String? error;

    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit task name'),
              content: TextField(
                controller: controller,
                maxLength: _taskTitleMaxChars,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                inputFormatters: [LengthLimitingTextInputFormatter(_taskTitleMaxChars)],
                decoration: InputDecoration(
                  labelText: 'Task name *',
                  border: const OutlineInputBorder(),
                  errorText: error,
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) {
                      setDialogState(() {
                        error = 'Task name is required';
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
      task.title = controller.text.trim();
      await _saveTask(task);
      if (mounted) setState(() {});
    }
    controller.dispose();
  }

  Future<void> _deleteTask(Task task, List<Task> tasks) async {
    if (_isMandatoryTask(task)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${task.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    final remaining = tasks.where((t) => t.id != task.id).toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    for (var i = 0; i < remaining.length; i++) {
      remaining[i].orderIndex = i;
    }

    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.tasks.delete(task.id);
      await isar.tasks.putAll(remaining);
    });

    _runningSince.remove(task.id);
    if (mounted) {
      setState(() {
        _deleteMode = remaining.any((item) => !_isMandatoryTask(item)) && _deleteMode;
      });
    }
  }


  bool _isMandatoryTask(Task task) {
    return _mandatoryRitualTitles.contains(task.title);
  }

  List<Task> _deletableTasks(List<Task> tasks) {
    return tasks.where((task) => !_isMandatoryTask(task)).toList();
  }

  String _taskEmoji(Task task) {
    final lower = task.title.toLowerCase();
    if (lower.startsWith('walk')) return '🚶';
    if (lower.startsWith('transition')) return '⚡';
    if (lower.startsWith('desk + mantra')) return '🪑';
    if (lower.startsWith('brain dump')) return '🧠';
    if (lower.contains('reading')) return '📖';
    if (lower.contains('writing')) return '✍️';
    if (lower.contains('coding')) return '💻';
    if (lower.contains('job') || lower.contains('outreach')) return '📬';
    return '✅';
  }

  Future<void> _onTaskMenuSelected(String action, Task task, List<Task> tasks) async {
    switch (action) {
      case 'edit_name':
        await _editTaskName(task);
        break;
      case 'edit_time':
        await _editStartTime(task, tasks);
        break;
      case 'edit_goal':
        await _editGoal(task);
        break;
      case 'delete':
        await _deleteTask(task, tasks);
        break;
    }
  }

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: const [
          SizedBox(width: 24),
          SizedBox(width: 8),
          SizedBox(width: _timeColumnWidth, child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: 16),
          Expanded(child: Text('Task', style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: _goalColumnWidth, child: Text('Goal', style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: _controlColumnWidth, child: Text('Control', style: TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildTimePill(Task task, List<Task> tasks) {
    final set = task.plannedStartMin != null && task.plannedEndMin != null;
    return OutlinedButton.icon(
      onPressed: () => _editStartTime(task, tasks),
      icon: Icon(set ? Icons.edit : Icons.schedule),
      label: Text(set ? _plannedWindow(context, task) : 'Set time'),
    );
  }

  Widget _buildGoalPill(Task task) {
    final set = task.targetMin != null;
    return OutlinedButton.icon(
      onPressed: () => _editGoal(task),
      icon: Icon(set ? Icons.edit : Icons.flag_outlined),
      label: Text(set ? '${task.targetMin} min' : 'Set goal'),
    );
  }

  Widget _buildRunningBanner(Task task, int elapsedMs) {
    final isRunning = task.status == 'running';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _formatDuration(elapsedMs),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_taskEmoji(task)} ${task.title}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: isRunning ? () => _pauseTask(task) : () => _startTask(task),
                  child: Text(isRunning ? 'Pause' : 'Resume'),
                ),
                FilledButton.tonal(onPressed: () => _doneTask(task), child: const Text('Done')),
              ],
            ),
          ),
        ),
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
                  Switch(value: _alwaysOnTop, onChanged: _setAlwaysOnTop),
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
                  final activeSession = _activeSessionTask(tasks);
                  return Column(
                    children: [
                      if (activeSession != null) _buildRunningBanner(activeSession, _elapsedMs(activeSession, tick)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    'assets/themes/$_selectedThemeId.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                                  ),
                                ),
                                Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.25))),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: _openThemePickerDialog,
                                            style: TextButton.styleFrom(foregroundColor: Colors.white),
                                            child: const Text('Theme'),
                                          ),
                                          TextButton(
                                            onPressed: _openEditMantraDialog,
                                            style: TextButton.styleFrom(foregroundColor: Colors.white),
                                            child: const Text('Edit'),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        _mantraLine1,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _mantraLine2,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _mantraLine3,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.16),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _mantraLine4,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            FilledButton.tonal(onPressed: () => _openAddTaskDialog(tasks), child: const Text('Add Task')),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: _deletableTasks(tasks).isEmpty
                                  ? null
                                  : () {
                                      setState(() {
                                        _deleteMode = !_deleteMode;
                                      });
                                    },
                              child: Text(_deleteMode ? 'Done Deleting' : 'Delete Task'),
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
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            final task = tasks[index];
                            final elapsed = _elapsedMs(task, tick);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.45)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    child: _isMandatoryTask(task) ? const Icon(Icons.lock, size: 16) : null,
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(width: _timeColumnWidth, child: _buildTimePill(task, tasks)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _editTaskName(task),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Text(
                                          '${_taskEmoji(task)} ${task.title}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            decoration: task.status == 'done' ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: _goalColumnWidth, child: _buildGoalPill(task)),
                                  SizedBox(
                                    width: _controlColumnWidth,
                                    child: _buildControls(task, elapsed, tasks),
                                  ),
                                  SizedBox(
                                    width: _deleteMode && !_isMandatoryTask(task) ? 80 : 44,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (_deleteMode && !_isMandatoryTask(task))
                                          IconButton(
                                            tooltip: 'Delete task',
                                            onPressed: () => _deleteTask(task, tasks),
                                            icon: const Icon(Icons.delete_outline),
                                          ),
                                        PopupMenuButton<String>(
                                          tooltip: 'Task actions',
                                          onSelected: (value) => _onTaskMenuSelected(value, task, tasks),
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'edit_name', child: Text('Edit task name')),
                                            const PopupMenuItem(value: 'edit_time', child: Text('Edit time')),
                                            const PopupMenuItem(value: 'edit_goal', child: Text('Edit goal')),
                                            if (!_isMandatoryTask(task))
                                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildControls(Task task, int elapsedMs, List<Task> tasks) {
    final activeSession = _activeSessionTask(tasks);
    final startBlockedByOtherSession = activeSession != null && activeSession.id != task.id;
    final canStart = task.plannedStartMin != null && task.targetMin != null && !startBlockedByOtherSession;
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
            TextButton(onPressed: canStart ? () => _startTask(task) : null, child: const Text('Start')),
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
        return TextButton(onPressed: canStart ? () => _startTask(task) : null, child: const Text('Start'));
    }
  }
}
