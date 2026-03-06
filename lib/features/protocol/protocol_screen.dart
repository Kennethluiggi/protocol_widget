import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:isar/isar.dart';
import '../../data/isar_db.dart';
import '../../data/models/task.dart';
import '../../debug/debug_log.dart';
class ProtocolScreen extends StatefulWidget {
  const ProtocolScreen({super.key});

  @override
  State<ProtocolScreen> createState() => _ProtocolScreenState();
}

class _ProtocolScreenState extends State<ProtocolScreen>
  with WidgetsBindingObserver {

  static const int _settingsPlanId = -1;
  static const String _settingsType = 'user_settings';
  static const String _aotTitle = 'always_on_top';
  static const String _themeTitle = 'header_theme';
  static const String _widgetModeTitle = 'widget_mode';
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
  static const String _transitionTitle =
      'Transition (Light meal / half-caff + cold water)';
  static const String _deskMantraTitle = 'Desk + Mantra';
  static const String _brainDumpTitle = 'Brain Dump';
  static const String _defaultThemeId = 'clouds';

  static const List<String> _themeOptions = [
    'clouds',
    'books',
    'aggressive',
    'minimal',
  ];

  static const double _timeColumnWidth = 190;
  static const double _goalColumnWidth = 130;
  static const double _controlColumnWidth = 140;
  static const int _taskTitleMaxChars = 40;
  static const Set<String> _mandatoryRitualTitles = {
    _walkTitle,
    _transitionTitle,
    _deskMantraTitle,
    _brainDumpTitle,
  };
  static const double _widgetMinWidth = 520;
  static const double _widgetMinHeight = 220;
  static const double _widgetMaxWidth = 1600;
  static const double _widgetMaxHeight = 1000;
  static const double _normalMinWidth = 940;
  static const double _normalMinHeight = 640;
  static const double _normalMaxWidth = 2200;
  static const double _windowScreenMargin = 40;
  static const double _normalBaseHeight = 470;
  static const double _normalTaskRowHeight = 48;
  static const double _widgetDefaultHeight = 300;
  static const double _widgetDefaultWidth = 860;
  static const double _widgetModeMinWidth = 680;
  static const double _widgetModeMinHeight = 280;

  final Map<int, DateTime> _runningSince = {};
  final ValueNotifier<DateTime> _ticker = ValueNotifier(DateTime.now());

  late Future<void> _initFuture;
  late final Timer _timer;
  late final Timer _currentWindowRefreshTimer;

  bool _alwaysOnTop = false;
  bool _widgetMode = false;
  bool _isExitingWidgetMode = false;

  // Guard flags to avoid repeated window ops.
  bool _appliedInitialNormalBounds = false;
  bool _centeredWidgetOnce = false;
  Size? _fullModeWindowSize;
  Size? _widgetModeSize;
  int? _lastNormalSizedTaskCount;
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
  WidgetsBinding.instance.addObserver(this);

  _initFuture = _initialize();
  _timer = Timer.periodic(const Duration(seconds: 1), (_) {
    _ticker.value = DateTime.now();
  });
  _currentWindowRefreshTimer = Timer.periodic(const Duration(seconds: 30), (
    _,
  ) {
    if (!mounted) return;
    setState(() {});
  });
}

@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _timer.cancel();
  _currentWindowRefreshTimer.cancel();
  _ticker.dispose();
  super.dispose();
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _handleResume();
  }
}

Future<void> _handleResume() async {
  if (!_isDesktopPlatform()) return;

  DebugLog.lifecycle('[Lifecycle] resumed -> resetting Isar + reloading UI');

  // Force a clean DB reopen after sleep/resume.
  await IsarDb.reset();
  await IsarDb.instance();

  // Trigger UI refresh so the FutureBuilder reruns _loadPlanTasks().
  if (!mounted) return;
  setState(() {});
}


Future<void> _initialize() async {
  DebugLog.init('HIT _initialize');

  if (!_isDesktopPlatform()) return;

  // Always use custom chrome: hide native title bar buttons permanently.
  await windowManager.setTitleBarStyle(
    TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );
  await windowManager.setResizable(true);
  await windowManager.setBackgroundColor(Colors.white);

  // Small delay helps Windows/DWM fully apply the chrome before we mutate other window state.
  await Future.delayed(const Duration(milliseconds: 30));

  await _loadWidgetMode();
  await _loadAlwaysOnTop();

  await _applyWidgetModeWindowState(_widgetMode);
}

  static DateTime _localNow() => DateTime.now().toLocal();

  //static int _todayPlanId() {
  //  final now = _localNow();
  //  return now.year * 10000 + now.month * 100 + now.day;
  //}
  // Single, persistent plan id for all user tasks.
  // (Settings already use _settingsPlanId = -1)
  static int _todayPlanId() => 1;

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

  Future<void> _loadWidgetMode() async {
    final setting = await _getSetting(_widgetModeTitle);
    _widgetMode = setting?.goalChimed ?? false;
  }

  Future<void> _setWidgetMode(bool value) async {
    if (value == _widgetMode) return;

    // Persist setting first.
    final existing = await _getSetting(_widgetModeTitle);
    final row =
        _newOrExistingSetting(existing, _widgetModeTitle)..goalChimed = value;

    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.tasks.put(row);
    });

    // Exiting widget mode: keep rendering widget UI until window restore is done.
    if (!value) {
      if (!mounted) return;
      setState(() {
        _isExitingWidgetMode = true;
      });

      await _applyWidgetModeWindowState(false);
      if (!mounted) return;

      setState(() {
        _widgetMode = false;
        _isExitingWidgetMode = false;
      });
      return;
    }

    // Entering widget mode: flip UI state, then apply widget window state.
    if (!mounted) return;
    setState(() {
      _widgetMode = true;
    });

    await _applyWidgetModeWindowState(true);
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
      _selectedThemeId = _themeOptions.contains(value)
          ? value!
          : _defaultThemeId;
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
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).dividerColor,
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
      _mantraLine1 = (line1 == null || line1.trim().isEmpty)
          ? _defaultLine1
          : line1;
      _mantraLine2 = (line2 == null || line2.trim().isEmpty)
          ? _defaultLine2
          : line2;
      _mantraLine3 = (line3 == null || line3.trim().isEmpty)
          ? _defaultLine3
          : line3;
      _mantraLine4 = (line4 == null || line4.trim().isEmpty)
          ? _defaultLine4
          : line4;
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
      final nextLine1 = line1Controller.text.trim().isEmpty
          ? _defaultLine1
          : line1Controller.text.trim();
      final nextLine2 = line2Controller.text.trim().isEmpty
          ? _defaultLine2
          : line2Controller.text.trim();
      final nextLine3 = line3Controller.text.trim().isEmpty
          ? _defaultLine3
          : line3Controller.text.trim();
      final nextLine4 = line4Controller.text.trim().isEmpty
          ? _defaultLine4
          : line4Controller.text.trim();

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

  Widget _buildMantraField(
    String label,
    TextEditingController controller,
    int maxChars,
  ) {
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
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;
    await windowManager.setAlwaysOnTop(value);
  }

  bool _isDesktopPlatform() {
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  Size _displayLogicalSize() {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final display = view.display;
    return Size(
      display.size.width / display.devicePixelRatio,
      display.size.height / display.devicePixelRatio,
    );
  }

  BoxConstraints _normalWindowBounds() {
    final screen = _displayLogicalSize();
    final maxWidth = (_normalMaxWidth)
        .clamp(
          _normalMinWidth,
          (screen.width - _windowScreenMargin).clamp(
            _normalMinWidth,
            _normalMaxWidth,
          ),
        )
        .toDouble();
    final maxHeight = (screen.height - _windowScreenMargin)
        .clamp(_normalMinHeight, screen.height)
        .toDouble();
    return BoxConstraints(
      minWidth: _normalMinWidth,
      minHeight: _normalMinHeight,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  BoxConstraints _widgetWindowBounds() {
    final screen = _displayLogicalSize();
    final maxWidth = (_widgetMaxWidth)
        .clamp(
          _widgetModeMinWidth,
          (screen.width - _windowScreenMargin).clamp(
            _widgetModeMinWidth,
            _widgetMaxWidth,
          ),
        )
        .toDouble();
    final maxHeight = (_widgetMaxHeight)
        .clamp(
          _widgetModeMinHeight,
          (screen.height - _windowScreenMargin).clamp(
            _widgetModeMinHeight,
            _widgetMaxHeight,
          ),
        )
        .toDouble();
    return BoxConstraints(
      minWidth: _widgetModeMinWidth,
      minHeight: _widgetModeMinHeight,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  double _recommendedNormalHeight(int taskCount) {
    final bounds = _normalWindowBounds();
    final desired = _normalBaseHeight + (taskCount * _normalTaskRowHeight);
    return desired.clamp(bounds.minHeight, bounds.maxHeight).toDouble();
  }

  Future<void> _applyNormalWindowSizingForTasks(int taskCount) async {
    if (!_isDesktopPlatform() || _widgetMode) return;
    if (_lastNormalSizedTaskCount == taskCount) return;

    _lastNormalSizedTaskCount = taskCount;
    final bounds = _normalWindowBounds();
    await windowManager.setMinimumSize(Size(bounds.minWidth, bounds.minHeight));
    await windowManager.setMaximumSize(Size(bounds.maxWidth, bounds.maxHeight));

    final current = await windowManager.getSize();
    final targetHeight = _recommendedNormalHeight(taskCount);
    final targetWidth = current.width
        .clamp(bounds.minWidth, bounds.maxWidth)
        .toDouble();
    final next = Size(targetWidth, targetHeight);
    await windowManager.setSize(next);
  }

  Future<void> _applyWidgetModeWindowState(bool enabled) async {
    DebugLog.widgetMode('HIT _applyWidgetModeWindowState enabled=$enabled');
    DebugLog.window('ENTER enabled=$enabled (start)');
    if (!_isDesktopPlatform()) return;

    if (enabled) {
      final widgetBounds = _widgetWindowBounds();

      _fullModeWindowSize ??= await windowManager.getSize();

      _widgetModeSize ??= Size(
        _widgetDefaultWidth.clamp(widgetBounds.minWidth, widgetBounds.maxWidth).toDouble(),
        _widgetDefaultHeight.clamp(widgetBounds.minHeight, widgetBounds.maxHeight).toDouble(),
      );
      DebugLog.window('WIDGET enabled=true after computing widgetModeSize');

      // Apply widget bounds constraints.
      await windowManager.setMinimumSize(
        Size(widgetBounds.minWidth, widgetBounds.minHeight),
      );
      await windowManager.setMaximumSize(
        Size(widgetBounds.maxWidth, widgetBounds.maxHeight),
      );
      DebugLog.window('WIDGET enabled=true after setMinimumSize/setMaximumSize');
      // Force Windows to re-apply sizing constraints after mode switches.
      await windowManager.setResizable(false);
      await Future.delayed(const Duration(milliseconds: 20));
      await windowManager.setResizable(true);
      // Widget mode: truly frameless + no OS resize frame (we resize via our handle).
      await windowManager.setHasShadow(false);
      await windowManager.setAsFrameless();

      // IMPORTANT: do NOT call setAsFrameless() here.
      // It can remove native resize frame styles and may not restore them reliably.
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setResizable(false);

      // Compute final target size ONCE, clamp ONCE, set ONCE.
      final target = Size(
        _widgetModeSize!.width.clamp(widgetBounds.minWidth, widgetBounds.maxWidth).toDouble(),
        _widgetModeSize!.height.clamp(widgetBounds.minHeight, widgetBounds.maxHeight).toDouble(),
      );
      _widgetModeSize = target;

      await windowManager.setSize(target);
      DebugLog.window('WIDGET enabled=true after setSize(target)');

      // Center only the first time we ever enter widget mode to avoid jumpiness.
      if (!_centeredWidgetOnce) {
        _centeredWidgetOnce = true;
        await windowManager.center();
      }

      return;
    }

    // Exiting widget mode -> restore normal bounds (native titlebar stays hidden;
    // we use a custom title bar in Flutter permanently).
    final normalBounds = _normalWindowBounds();
    DebugLog.window(
      '[WindowDebug][NORMAL bounds] '
      'min=(${normalBounds.minWidth},${normalBounds.minHeight}) '
      'max=(${normalBounds.maxWidth},${normalBounds.maxHeight})'
    );
    DebugLog.window('NORMAL enabled=false after computing normalBounds');

    // Compute restore size first (clamped to normal bounds).
    Size? restoreSize = _fullModeWindowSize;

    DebugLog.window('[WindowDebug][restoreSize before clamp] $restoreSize');

    if (restoreSize != null) {
      final clamped = Size(
        restoreSize.width.clamp(normalBounds.minWidth, normalBounds.maxWidth).toDouble(),
        restoreSize.height.clamp(normalBounds.minHeight, normalBounds.maxHeight).toDouble(),
      );
      DebugLog.window('[WindowDebug][restoreSize AFTER clamp] $clamped');
      restoreSize = clamped;
    } else {
      DebugLog.window('[WindowDebug][restoreSize is null]');
    }

    DebugLog.window('NORMAL enabled=false after restoreSize clamp');
    DebugLog.window('NORMAL enabled=false after computing restoreSize=$restoreSize');

  // Restore a resizable Windows window style after widget-mode frameless.
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );

    await windowManager.setHasShadow(true);

    final bg = Theme.of(context).scaffoldBackgroundColor;
    await windowManager.setBackgroundColor(bg);
    DebugLog.window('NORMAL enabled=false after setBackgroundColor');

    // Set the target normal size BEFORE raising min constraints.
    if (restoreSize != null) {
      await windowManager.setSize(restoreSize);
      DebugLog.window('NORMAL enabled=false after setSize(restoreSize)');
    }

    // Now apply normal min/max constraints.
    await windowManager.setMinimumSize(
      Size(normalBounds.minWidth, normalBounds.minHeight),
    );
    await windowManager.setMaximumSize(
      Size(normalBounds.maxWidth, normalBounds.maxHeight),
    );
    await windowManager.setResizable(true);
    DebugLog.window('NORMAL enabled=false AFTER min/max/resizable');
    DebugLog.window('NORMAL enabled=false after setMinimumSize/setMaximumSize/setResizable(true)');

    if (!_appliedInitialNormalBounds) {
      _appliedInitialNormalBounds = true;
    }
  }

  Future<void> _applyNormalBoundsOnlyOnce() async {
    DebugLog.window('HIT _applyNormalBoundsOnlyOnce');
    if (!_isDesktopPlatform()) return;
    if (_widgetMode) return;
    if (_appliedInitialNormalBounds) return;

    _appliedInitialNormalBounds = true;

    final normalBounds = _normalWindowBounds();

    await windowManager.setHasShadow(true);
    await windowManager.setResizable(true);

    // Ensure we are opaque in normal mode (native titlebar remains hidden; custom
    // title bar is rendered in Flutter).
    final bg = Theme.of(context).scaffoldBackgroundColor;
    await windowManager.setBackgroundColor(bg);

    await windowManager.setMinimumSize(
      Size(normalBounds.minWidth, normalBounds.minHeight),
    );
    await windowManager.setMaximumSize(
      Size(normalBounds.maxWidth, normalBounds.maxHeight),
    );

    // Clamp current window size into normal bounds if needed.
    final current = await windowManager.getSize();
    final clamped = Size(
      current.width.clamp(normalBounds.minWidth, normalBounds.maxWidth).toDouble(),
      current.height.clamp(normalBounds.minHeight, normalBounds.maxHeight).toDouble(),
    );

    if (clamped != current) {
      await windowManager.setSize(clamped);
    }
  }

  Future<void> _resizeWidgetMode(DragUpdateDetails details) async {
    if (!_widgetMode || !_isDesktopPlatform()) return;
    final bounds = _widgetWindowBounds();
    final current = _widgetModeSize ?? await windowManager.getSize();
    final next = Size(
      (current.width + details.delta.dx)
          .clamp(bounds.minWidth, bounds.maxWidth)
          .toDouble(),
      (current.height + details.delta.dy)
          .clamp(bounds.minHeight, bounds.maxHeight)
          .toDouble(),
    );
    _widgetModeSize = next;
    await windowManager.setSize(next);
  }

    Future<List<Task>> _loadPlanTasks() async {
    //final localTodayPlanId = _todayPlanId();
    // Always keep planId aligned to today.
    //if (_planId != localTodayPlanId) {
    //  _planId = localTodayPlanId;
    //}
    // Always ensure the 4 ritual tasks exist for today (cold start safe).
    //await _ensureTodayRitualTasks();
    

    // No day rollover. Tasks live under one persistent plan id.
    await _ensureTodayRitualTasks();
    final isar = await IsarDb.instance();

    // (Optional debug)
    final total = await isar.tasks.count();
    DebugLog.db('ISAR total tasks count = $total, planId=$_planId');

    final tasks = await isar.tasks
        .filter()
        .planIdEqualTo(_planId)
        .sortByOrderIndex()
        .findAll();

    await _applyNormalWindowSizingForTasks(tasks.length);
    return tasks;
  }

  Future<void> _openAddTaskDialog(List<Task> tasks) async {
    final titleController = TextEditingController();
    final goalController = TextEditingController();
    TimeOfDay? plannedStart;
    int? plannedStartTimelineMin;
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
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(_taskTitleMaxChars),
                      ],
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
                            plannedStart == null
                                ? 'Planned start: —'
                                : 'Planned start: ${plannedStart!.format(context)}',
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final goalMin = int.tryParse(
                              goalController.text.trim(),
                            );
                            if (goalMin == null || goalMin <= 0) {
                              await _showScheduleMessageDialog(
                                title: 'Schedule setup required',
                                message:
                                    'Enter goal minutes first, then choose a time.',
                              );
                              setDialogState(() {
                                goalError = 'Goal minutes required';
                              });
                              return;
                            }

                            final picked = await _pickValidStartTime(
                              tasks: tasks,
                              isRitualTask: false,
                              goalMinutes: goalMin,
                              initialMinutes: plannedStart == null
                                  ? null
                                  : plannedStart!.hour * 60 +
                                        plannedStart!.minute,
                            );
                            if (picked != null) {
                              setDialogState(() {
                                plannedStartTimelineMin = picked;
                                plannedStart = TimeOfDay(
                                  hour: (picked % 1440) ~/ 60,
                                  minute: (picked % 1440) % 60,
                                );
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
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
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
                  onPressed: () async {
                    final parsed = int.tryParse(goalController.text.trim());
                    final missingTitle = titleController.text.trim().isEmpty;
                    final missingGoal = parsed == null || parsed <= 0;
                    final missingStart = plannedStartTimelineMin == null;
                    if (missingTitle || missingGoal || missingStart) {
                      setDialogState(() {
                        titleError = missingTitle ? 'Title is required' : null;
                        goalError = missingGoal
                            ? 'Goal minutes required'
                            : null;
                        startError = missingStart
                            ? 'Planned start required'
                            : null;
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
      final startMin = plannedStartTimelineMin ??
          (plannedStart!.hour * 60 + plannedStart!.minute);
      final endMin = startMin + goalMin;

      var nextOrderIndex = 0;
      for (final task in tasks) {
        if (task.orderIndex >= nextOrderIndex)
          nextOrderIndex = task.orderIndex + 1;
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
      final addedIndex = updatedTasks.indexWhere((t) => t.id == newTask.id);
      if (addedIndex >= 0) {
        await _cascadeOverlapsFromIndex(updatedTasks, addedIndex);
      }
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
    final hasOtherActiveSession = tasks.any(
      (item) =>
          item.id != task.id &&
          (item.status == 'running' || item.status == 'paused'),
    );
    if (hasOtherActiveSession) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Finish or reset the current active session before starting another task.',
            ),
          ),
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
      task.actualAccumulatedMs += DateTime.now()
          .difference(since)
          .inMilliseconds;
    }
    _runningSince.remove(task.id);
    task.status = 'paused';
    await _saveTask(task);
    setState(() {});
  }

  Future<void> _doneTask(Task task) async {
    final since = _runningSince[task.id];
    if (since != null && task.status == 'running') {
      task.actualAccumulatedMs += DateTime.now()
          .difference(since)
          .inMilliseconds;
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
    List<Task> _lockedTasksInOrder(List<Task> tasks) {
    final locked = tasks.where(_isMandatoryTask).toList();
    locked.sort((a, b) {
      return _ritualOrder(a.title)!.compareTo(_ritualOrder(b.title)!);
    });
    return locked;
  }

  String? _lockedSequenceValidationMessage({
    required Task selected,
    required List<Task> tasks,
    required int proposedStart,
  }) {
    final selectedOrder = _ritualOrder(selected.title);
    if (selectedOrder == null) return null;

    final locked = _lockedTasksInOrder(tasks);

    for (final other in locked) {
      if (other.id == selected.id) continue;

      final otherOrder = _ritualOrder(other.title);
      final otherStart = other.plannedStartMin;

      if (otherOrder == null || otherStart == null) continue;

      // A later locked row cannot start before an earlier locked row.
      if (selectedOrder > otherOrder && proposedStart < otherStart) {
        return 'This locked task must stay after the earlier locked tasks. '
            'Choose a time that keeps rows 1–4 in order.';
      }

      // An earlier locked row cannot start after a later locked row.
      if (selectedOrder < otherOrder && proposedStart > otherStart) {
        return 'This locked task must stay before the later locked tasks. '
            'Choose a time that keeps rows 1–4 in order.';
      }
    }

    return null;
  }

  Future<void> _showScheduleMessageDialog({
    required String title,
    required String message,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSettingsComingSoonDialog(String featureName) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Coming soon'),
          content: Text('$featureName is planned but not implemented yet.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }


  Future<bool> _showScheduleConfirmDialog({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  int _resolveStartMinutesForAnchor({
    required int pickedMinuteOfDay,
    required int anchorMinute,
  }) {
    final anchorDayOffset = (anchorMinute ~/ 1440) * 1440;
    var candidate = anchorDayOffset + pickedMinuteOfDay;
    if (candidate < anchorMinute) {
      candidate += 1440;
    }
    return candidate;
  }

  Task? _findScheduleConflict({
    required List<Task> tasks,
    required int newStart,
    required int newEnd,
    int? excludedTaskId,
  }) {
    for (final other in tasks) {
      if (excludedTaskId != null && other.id == excludedTaskId) continue;
      final otherStart = other.plannedStartMin;
      final otherEnd = other.plannedEndMin;
      if (otherStart == null || otherEnd == null) continue;
      final overlaps = newStart < otherEnd && newEnd > otherStart;
      if (overlaps) return other;
    }
    return null;
  }

  Future<int?> _pickValidStartTime({
    required List<Task> tasks,
    required bool isRitualTask,
    required int? goalMinutes,
    int? initialMinutes,
    int? excludedTaskId,
  }) async {
    var nextInitial = initialMinutes ?? 540;
    final editedIndex = excludedTaskId == null
        ? null
        : tasks.indexWhere((t) => t.id == excludedTaskId);

    while (true) {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: (nextInitial % 1440) ~/ 60,
          minute: (nextInitial % 1440) % 60,
        ),
      );
      if (picked == null) return null;

      final pickedStart = picked.hour * 60 + picked.minute;
      final threshold = isRitualTask ? null : _nonRitualStartThreshold(tasks);
      if (!isRitualTask && threshold == null) {
        await _showScheduleMessageDialog(
          title: 'Locked ritual first',
          message:
              'You can’t schedule tasks before your 4 mandatory locked tasks. Choose a time after your ritual.',
        );
        continue;
      }

      final resolvedStart = threshold == null
          ? pickedStart
          : _resolveStartMinutesForAnchor(
              pickedMinuteOfDay: pickedStart,
              anchorMinute: threshold,
            );

      if (goalMinutes == null || goalMinutes <= 0) {
        return resolvedStart;
      }

      final resolvedEnd = resolvedStart + goalMinutes;
      final conflict = _findScheduleConflict(
        tasks: tasks,
        newStart: resolvedStart,
        newEnd: resolvedEnd,
        excludedTaskId: excludedTaskId,
      );

      if (conflict != null) {
        final conflictStart = conflict.plannedStartMin!;
        final conflictEnd = conflict.plannedEndMin!;

        final shouldContinue = await _showScheduleConfirmDialog(
          title: 'Schedule conflict',
          message:
              "This overlaps with '${conflict.title}' (${_formatClock(context, conflictStart)}–${_formatClock(context, conflictEnd)}). If you continue, tasks below will be shifted automatically to remove overlaps. Would you like to continue?",
        );

        if (shouldContinue) {
          return resolvedStart;
        } else {
          return null;
        }
      }

      return resolvedStart;
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

    int? timelineStartForSort(Task task) {
      final start = task.plannedStartMin;
      final end = task.plannedEndMin;
      if (start == null || end == null) return null;

      final isLockedTask = _isMandatoryTask(task);

      final startOffset = _effectiveDayOffset(
        isLockedTask: isLockedTask,
        minutes: start,
      );

      final startTimeline = start + (startOffset * 1440);
      return startTimeline;
    }

    nonRitualTasks.sort((a, b) {
      final aStartTimeline = timelineStartForSort(a);
      final bStartTimeline = timelineStartForSort(b);

      if (aStartTimeline == null && bStartTimeline == null) {
        return a.orderIndex.compareTo(b.orderIndex);
      }
      if (aStartTimeline == null) return 1;
      if (bStartTimeline == null) return -1;

      final byStart = aStartTimeline.compareTo(bStartTimeline);
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

    // IMPORTANT:
    // Keep the in-memory list in the same order we just persisted,
    // so any follow-up logic (like cascade) uses the correct order.
    tasks
      ..clear()
      ..addAll(combined);
  }

  Future<void> _cascadeOverlapsFromIndex(List<Task> tasks, int editedIndex) async {
    if (editedIndex < 0 || editedIndex >= tasks.length) return;

    final int? initialCursorEnd = tasks[editedIndex].plannedEndMin;
    if (initialCursorEnd == null) return;

    int runningEnd = initialCursorEnd;
    final changed = <Task>[];

    for (var i = editedIndex + 1; i < tasks.length; i++) {
      final task = tasks[i];
      final int? oldStart = task.plannedStartMin;
      final int? oldEnd = task.plannedEndMin;

      // Stop cascade at the first untimed task.
      if (oldStart == null || oldEnd == null) break;

      // Stop cascade as soon as there is no overlap anymore.
      if (oldStart >= runningEnd) break;

      int duration = oldEnd - oldStart;

      // Cross-midnight legacy duration handling.
      if (duration <= 0) {
        duration = (oldEnd + 1440) - oldStart;
      }

      // Fallback to targetMin if needed.
      if (duration <= 0) {
        final int? target = task.targetMin;
        if (target != null && target > 0) {
          duration = target;
        } else {
          break;
        }
      }

      final int newStart = runningEnd;
      final int newEnd = newStart + duration;

      task.plannedStartMin = newStart;
      task.plannedEndMin = newEnd;
      changed.add(task);

      runningEnd = newEnd;
    }

    if (changed.isEmpty) return;

    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.tasks.putAll(changed);
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
    if (task.status != 'running') {
      return base < 0 ? 0 : base;
    }

    final since = _runningSince[task.id];
    if (since == null) {
      return base < 0 ? 0 : base;
    }

    final delta = tick.difference(since).inMilliseconds;
    final computed = base + delta;
    return computed < 0 ? 0 : computed;
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '00:00';

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
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: hour, minute: minute));
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
      goalMinutes: selected.targetMin,
      initialMinutes: oldStart,
      excludedTaskId: selected.id,
    );
    if (newStart == null || oldStart == newStart) return;

    if (_isMandatoryTask(selected)) {
      final lockedValidationMessage = _lockedSequenceValidationMessage(
        selected: selected,
        tasks: tasks,
        proposedStart: newStart,
      );

      if (lockedValidationMessage != null) {
        await _showScheduleMessageDialog(
          title: 'Locked task order',
          message: lockedValidationMessage,
        );
        return;
      }
    }

    selected.plannedStartMin = newStart;
    selected.plannedEndMin =
        selected.targetMin == null ? null : newStart + selected.targetMin!;

    await _saveTask(selected);

    final updatedTasks = await _loadPlanTasks();
    await _sortTasksByStartTime(updatedTasks);

    final editedIndex = updatedTasks.indexWhere((t) => t.id == selected.id);
    if (editedIndex >= 0) {
      await _cascadeOverlapsFromIndex(updatedTasks, editedIndex);
    }

    await _sortTasksByStartTime(updatedTasks);

    if (mounted) setState(() {});
  }

  Future<void> _editGoal(Task task) async {
    final controller = TextEditingController(
      text: task.targetMin?.toString() ?? '',
    );
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
                    decoration: const InputDecoration(
                      labelText: 'Minutes',
                      border: OutlineInputBorder(),
                    ),
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
                inputFormatters: [
                  LengthLimitingTextInputFormatter(_taskTitleMaxChars),
                ],
                decoration: InputDecoration(
                  labelText: 'Task name *',
                  border: const OutlineInputBorder(),
                  errorText: error,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final remaining = tasks.where((t) => t.id != task.id).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
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
        _deleteMode =
            remaining.any((item) => !_isMandatoryTask(item)) && _deleteMode;
      });
    }
  }

  bool _isMandatoryTask(Task task) {
    return _mandatoryRitualTitles.contains(task.title);
  }

  DateTime _nowLocal() => DateTime.now();

  int _minutesSinceMidnight(DateTime dt) => dt.hour * 60 + dt.minute;

  ({int startMinutes, int endMinutes})? _scheduledWindowMinutes(Task task) {
    final start = task.plannedStartMin;
    final end = task.plannedEndMin;
    if (start == null || end == null) return null;
    return (startMinutes: start, endMinutes: end);
  }

  bool _isEarlyMorningMinutes(int minutes) => minutes >= 0 && minutes < 360;

  int _effectiveDayOffset({required bool isLockedTask, required int minutes}) {
    if (isLockedTask) return 0;
    return _isEarlyMorningMinutes(minutes) ? 1 : 0;
  }

  int? _activeWindowTaskIndex(List<Task> tasks, DateTime now) {
    final nowMinutes = _minutesSinceMidnight(now);
    final candidates = <({int index, int startTimeline, int endTimeline})>[];

    for (var index = 0; index < tasks.length; index++) {
      final task = tasks[index];
      final window = _scheduledWindowMinutes(task);
      if (window == null) continue;

      final isLockedTask = _isMandatoryTask(task);
      final startOffset = _effectiveDayOffset(
        isLockedTask: isLockedTask,
        minutes: window.startMinutes,
      );
      var endOffset = _effectiveDayOffset(
        isLockedTask: isLockedTask,
        minutes: window.endMinutes,
      );

      final crossesMidnight = window.endMinutes < window.startMinutes;
      if (crossesMidnight && endOffset <= startOffset) {
        endOffset = startOffset + 1;
      }

      final startTimeline = window.startMinutes + (startOffset * 1440);
      final endTimeline = window.endMinutes + (endOffset * 1440);
      if (endTimeline <= startTimeline) continue;

      var nowTimeline = nowMinutes;
      if (nowTimeline < startTimeline && nowTimeline + 1440 < endTimeline) {
        nowTimeline += 1440;
      }

      final inWindow = startTimeline <= nowTimeline && nowTimeline < endTimeline;
      if (!inWindow) continue;

      candidates.add((
        index: index,
        startTimeline: startTimeline,
        endTimeline: endTimeline,
      ));
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.index.compareTo(b.index));
    return candidates.first.index;
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

  Future<void> _onTaskMenuSelected(
    String action,
    Task task,
    List<Task> tasks,
  ) async {
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
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Row(
        children: const [
          SizedBox(width: 24),
          SizedBox(width: 8),
          SizedBox(
            width: _timeColumnWidth,
            child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text('Task', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: _goalColumnWidth,
            child: Text('Goal', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: _controlColumnWidth,
            child: Text(
              'Control',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildTimePill(Task task, List<Task> tasks) {
    final set = task.plannedStartMin != null && task.plannedEndMin != null;
    return OutlinedButton.icon(
      onPressed: () => _editStartTime(task, tasks),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(set ? Icons.edit : Icons.schedule, size: 16),
      label: Text(set ? _plannedWindow(context, task) : 'Set time'),
    );
  }

  Widget _buildGoalPill(Task task) {
    final set = task.targetMin != null;
    return OutlinedButton.icon(
      onPressed: () => _editGoal(task),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(set ? Icons.edit : Icons.flag_outlined, size: 16),
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
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.7),
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
                  onPressed: isRunning
                      ? () => _pauseTask(task)
                      : () => _startTask(task),
                  child: Text(isRunning ? 'Pause' : 'Resume'),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _doneTask(task),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetModeTaskStrip(Task? activeSession, int elapsedMs) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(10),
      ),
      child: activeSession == null
          ? const Text(
              'No active task',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: Text(
                    '${_taskEmoji(activeSession)} ${activeSession.title} • ${_formatDuration(elapsedMs)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: activeSession.status == 'running'
                      ? () => _pauseTask(activeSession)
                      : () => _startTask(activeSession),
                  child: Text(
                    activeSession.status == 'running' ? 'Pause' : 'Resume',
                  ),
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.surface.withValues(
                      alpha: 0.85,
                    ),
                  ),
                  onPressed: () async {
                    await _doneTask(activeSession);
                    await _setWidgetMode(false);
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildCustomTitleBar() {
    // Only render in normal mode. Widget mode uses its own compact UI.
    const double barHeight = 44;

    return PreferredSize(
      preferredSize: const Size.fromHeight(barHeight),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 0,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: barHeight,
            child: Row(
              children: [
                // Drag region + title.
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) async {
                      if (_isDesktopPlatform()) {
                        // IMPORTANT: startDragging takes NO arguments.
                        await windowManager.startDragging();
                      }
                    },
                    onDoubleTap: () async {
                      if (!_isDesktopPlatform()) return;
                      final isMax = await windowManager.isMaximized();
                      if (isMax) {
                        await windowManager.unmaximize();
                      } else {
                        await windowManager.maximize();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Protocol Table',
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),

                // Existing controls.
                Row(
                  children: [
                    const Text('Always on top'),
                    Switch(value: _alwaysOnTop, onChanged: _setAlwaysOnTop),
                    const SizedBox(width: 8),
                    const Text('Widget mode'),
                    Switch(value: _widgetMode, onChanged: _setWidgetMode),
                    const SizedBox(width: 8),
                  ],
                ),

                // Custom window buttons.
                if (_isDesktopPlatform()) ...[
                  IconButton(
                    tooltip: 'Minimize',
                    icon: const Icon(Icons.remove),
                    onPressed: () async => windowManager.minimize(),
                  ),
                  IconButton(
                    tooltip: 'Maximize',
                    icon: const Icon(Icons.crop_square),
                    onPressed: () async {
                      final isMax = await windowManager.isMaximized();
                      if (isMax) {
                        await windowManager.unmaximize();
                      } else {
                        await windowManager.maximize();
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () async => windowManager.close(),
                  ),
                  const SizedBox(width: 4),
                ],
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: _widgetMode ? Colors.transparent : null,
          appBar: _widgetMode ? null : _buildCustomTitleBar(),
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
                  if (_widgetMode || _isExitingWidgetMode) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              'assets/themes/$_selectedThemeId.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.25),
                            ),
                          ),
                          if (_widgetMode)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onPanStart: (_) {
                                  if (_isDesktopPlatform()) {
                                    windowManager.startDragging();
                                  }
                                },
                                child: const SizedBox.expand(),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Column(
                              children: [
                                if (!_widgetMode)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: _openThemePickerDialog,
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Theme'),
                                      ),
                                      TextButton(
                                        onPressed: _openEditMantraDialog,
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.white,
                                        ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 12,
                                  ),
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
                          if (_widgetMode)
                            Positioned(
                              left: 12,
                              right: 92,
                              bottom: 10,
                              child: _buildWidgetModeTaskStrip(
                                activeSession,
                                activeSession == null ? 0 : _elapsedMs(activeSession, tick),
                              ),
                            ),
                          if (_widgetMode)
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.30),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: IconButton(
                                      tooltip: 'Expand',
                                      onPressed: () => _setWidgetMode(false),
                                      icon: const Icon(
                                        Icons.open_in_full,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 34,
                                        minHeight: 34,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.resizeUpLeftDownRight,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onPanUpdate: (details) async {
                                        await _resizeWidgetMode(details);
                                      },
                                      child: Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.22),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(
                                          Icons.drag_handle,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                  }

                  return Column(
                    children: [
                      if (activeSession != null)
                        _buildRunningBanner(
                          activeSession,
                          _elapsedMs(activeSession, tick),
                        ),
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
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.25),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    12,
                                  ),
                                  child: ClipRect(
                                    child: Column(
                                      children: [
                                        if (!_widgetMode)
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              TextButton(
                                                onPressed:
                                                    _openThemePickerDialog,
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: const Text('Theme'),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    _openEditMantraDialog,
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                ),
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
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                            horizontal: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.16,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                            FilledButton.tonal(
                              onPressed: () => _openAddTaskDialog(tasks),
                              child: const Text('Add Task'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: _deletableTasks(tasks).isEmpty
                                  ? null
                                  : () {
                                      setState(() {
                                        _deleteMode = !_deleteMode;
                                      });
                                    },
                              child: Text(
                                _deleteMode ? 'Done Deleting' : 'Delete Task',
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: tasks.isEmpty
                                  ? null
                                  : () => _resetToday(tasks),
                              child: const Text('Reset Today'),
                            ),
                          ],
                        ),
                      ),
                      if (!_widgetMode)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              PopupMenuButton<String>(
                                tooltip: 'Settings',
                                onSelected: (value) async {
                                  switch (value) {
                                    case 'import_png':
                                      await _showSettingsComingSoonDialog(
                                        'Import PNG',
                                      );
                                      break;
                                    case 'widget_task_time_only':
                                      await _showSettingsComingSoonDialog(
                                        'Widget mode: task + time only',
                                      );
                                      break;
                                    case 'widget_window_color':
                                      await _showSettingsComingSoonDialog(
                                        'Widget window color',
                                      );
                                      break;
                                    case 'highlighted_row_color':
                                      await _showSettingsComingSoonDialog(
                                        'Highlighted row color',
                                      );
                                      break;
                                  }
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem<String>(
                                    value: 'import_png',
                                    child: Text('Import PNG'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'widget_task_time_only',
                                    child: Text('Widget mode: task + time only'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'widget_window_color',
                                    child: Text('Widget window color'),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'highlighted_row_color',
                                    child: Text('Highlighted row color'),
                                  ),
                                ],
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.settings),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!_widgetMode)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).dividerColor.withValues(alpha: 0.45),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  _buildHeaderRow(),
                                  const Divider(height: 1),
                                  Expanded(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        6,
                                        8,
                                        8,
                                      ),
                                      itemCount: tasks.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 2),
                                      itemBuilder: (context, index) {
                                        final activeWindowIndex =
                                            _activeWindowTaskIndex(
                                              tasks,
                                              _nowLocal(),
                                            );
                                        final task = tasks[index];
                                        final elapsed = _elapsedMs(task, tick);
                                        final isCurrentWindowTask =
                                            activeWindowIndex == index;
                                        final rowHighlightColor =
                                            Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.12);
                                        return Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            4,
                                            4,
                                            4,
                                            4,
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: isCurrentWindowTask
                                                  ? rowHighlightColor
                                                  : null,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                              SizedBox(
                                                width: 24,
                                                child: _isMandatoryTask(task)
                                                    ? const Icon(
                                                        Icons.lock,
                                                        size: 15,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 6),
                                              SizedBox(
                                                width: _timeColumnWidth,
                                                child: _buildTimePill(
                                                  task,
                                                  tasks,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: InkWell(
                                                  onTap: () =>
                                                      _editTaskName(task),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 2,
                                                        ),
                                                    child: Text(
                                                      '${_taskEmoji(task)} ${task.title}',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 14,
                                                        decoration:
                                                            task.status ==
                                                                'done'
                                                            ? TextDecoration
                                                                  .lineThrough
                                                            : null,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: _goalColumnWidth,
                                                child: _buildGoalPill(task),
                                              ),
                                              SizedBox(
                                                width: _controlColumnWidth,
                                                child: _buildControls(
                                                  task,
                                                  elapsed,
                                                  tasks,
                                                ),
                                              ),
                                              SizedBox(
                                                width:
                                                    _deleteMode &&
                                                        !_isMandatoryTask(task)
                                                    ? 72
                                                    : 40,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    if (_deleteMode &&
                                                        !_isMandatoryTask(task))
                                                      IconButton(
                                                        visualDensity:
                                                            VisualDensity
                                                                .compact,
                                                        tooltip: 'Delete task',
                                                        onPressed: () =>
                                                            _deleteTask(
                                                              task,
                                                              tasks,
                                                            ),
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                          size: 18,
                                                        ),
                                                      ),
                                                    PopupMenuButton<String>(
                                                      tooltip: 'Task actions',
                                                      onSelected: (value) =>
                                                          _onTaskMenuSelected(
                                                            value,
                                                            task,
                                                            tasks,
                                                          ),
                                                      itemBuilder: (context) => [
                                                        const PopupMenuItem(
                                                          value: 'edit_name',
                                                          child: Text(
                                                            'Edit task name',
                                                          ),
                                                        ),
                                                        const PopupMenuItem(
                                                          value: 'edit_time',
                                                          child: Text(
                                                            'Edit time',
                                                          ),
                                                        ),
                                                        const PopupMenuItem(
                                                          value: 'edit_goal',
                                                          child: Text(
                                                            'Edit goal',
                                                          ),
                                                        ),
                                                        if (!_isMandatoryTask(
                                                          task,
                                                        ))
                                                          const PopupMenuItem(
                                                            value: 'delete',
                                                            child: Text(
                                                              'Delete',
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
    final startBlockedByOtherSession =
        activeSession != null && activeSession.id != task.id;
    final canStart =
        task.plannedStartMin != null &&
        task.targetMin != null &&
        !startBlockedByOtherSession;

    Widget constrainedControls(Widget child) {
      return SizedBox(
        width: _controlColumnWidth,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.max,
          children: [child],
        ),
      );
    }

    switch (task.status) {
      case 'running':
        return constrainedControls(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _pauseTask(task),
                child: const Text('Pause'),
              ),
              const SizedBox(width: 2),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 28),
                ),
                onPressed: () => _doneTask(task),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      case 'paused':
        return constrainedControls(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: canStart ? () => _startTask(task) : null,
                child: const Text('Start'),
              ),
              const SizedBox(width: 2),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 28),
                ),
                onPressed: () => _doneTask(task),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      case 'done':
        return constrainedControls(
          const Icon(Icons.check_circle, color: Colors.green),
        );
      case 'not_started':
      default:
        return constrainedControls(
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: canStart ? () => _startTask(task) : null,
            child: const Text('Start'),
          ),
        );
    }
  }
}
