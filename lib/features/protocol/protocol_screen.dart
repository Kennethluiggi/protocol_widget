import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:isar/isar.dart';
import '../../data/isar_db.dart';
import '../../data/models/daily_task_completion.dart';
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
  static const int _lockedCoreTaskCount = 4;
  static const List<String> _legacyCoreTitlesInOrder = [
    _walkTitle,
    _transitionTitle,
    _deskMantraTitle,
    _brainDumpTitle,
  ];
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
  static const double _widgetMinWidth = 520;
  static const double _widgetMinHeight = 220;
  static const double _widgetMaxWidth = 1600;
  static const double _widgetMaxHeight = 1000;
  static const double _normalMinWidth = 940;
  static const double _normalMinHeight = 640;
  static const double _normalMaxWidth = 2200;
  static const double _windowScreenMargin = 40;
  static const double _normalBaseHeight = 530;
  static const double _normalTaskRowHeight = 48;
  static const double _widgetDefaultHeight = 300;
  static const double _widgetDefaultWidth = 860;
  static const double _widgetModeMinWidth = 680;
  static const double _widgetModeMinHeight = 280;

  final Map<int, DateTime> _runningSince = {};
  final ValueNotifier<DateTime> _ticker = ValueNotifier(DateTime.now());
  final ScrollController _normalTaskListScrollController = ScrollController();

  late Future<void> _initFuture;
  late final Timer _timer;
  late final Timer _currentWindowRefreshTimer;

  bool _alwaysOnTop = false;
  bool _widgetMode = false; // requested mode / switch state
  bool _renderWidgetMode = false; // actual rendered layout
  bool _isTransitioningWidgetMode = false;
  


  // Guard flags to avoid repeated window ops.
  bool _appliedInitialNormalBounds = false;
  bool _centeredWidgetOnce = false;
  bool _didInitialTaskAwareSizing = false;
  bool _startupSizingQueued = false;
  Size? _fullModeWindowSize;
  Size? _widgetModeSize;
  Size? _lastKnownFullModeLogicalSize;
  Size? _lastAppliedWidgetResizeTarget;
  bool _isResizingWidget = false;
  int? _lastNormalSizedTaskCount;
  bool _deleteMode = false;
  int _planId = _todayPlanId();
  String _selectedThemeId = _defaultThemeId;
  String _mantraLine1 = _defaultLine1;
  String _mantraLine2 = _defaultLine2;
  String _mantraLine3 = _defaultLine3;
  String _mantraLine4 = _defaultLine4;

  static const int _dailyMinutesFloor = 0;

  static double _clampPercent(double value) => value.clamp(0.0, 1.0);

  bool _isValidTargetSnapshot(int? targetMinutesSnapshot) {
    return targetMinutesSnapshot != null && targetMinutesSnapshot > 0;
  }

  String _formatDateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

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
  _normalTaskListScrollController.dispose();
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
    if (existing.isNotEmpty) {
      await _normalizeLockedCoreTasks(existing);
      return;
    }

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
          ..type = 'prep'
          ..title = item.title
          ..isLockedCoreTask = true
          ..lockedCoreSlot = i
          ..targetMin = item.targetMin
          ..status = 'not_started',
      );
    }

    await isar.writeTxn(() async {
      await isar.tasks.putAll(tasks);
    });
  }

  Future<void> _normalizeLockedCoreTasks(List<Task> tasks) async {
    if (tasks.isEmpty) return;

    final ordered = [...tasks]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    final assignedTaskIds = <int>{};
    final assignedSlots = <int, Task>{};
    final updates = <Task>[];

    bool _isValidLockedSlot(int? slot) =>
        slot != null && slot >= 0 && slot < _lockedCoreTaskCount;

    for (final task in ordered) {
      if (!task.isLockedCoreTask) continue;
      final slot = task.lockedCoreSlot;
      if (!_isValidLockedSlot(slot) || assignedSlots.containsKey(slot)) {
        task
          ..isLockedCoreTask = false
          ..lockedCoreSlot = null;
        updates.add(task);
        continue;
      }
      assignedSlots[slot!] = task;
      assignedTaskIds.add(task.id);
    }

    Task? _firstUnassignedWhere(bool Function(Task task) matcher) {
      for (final task in ordered) {
        if (assignedTaskIds.contains(task.id)) continue;
        if (matcher(task)) return task;
      }
      return null;
    }

    for (var slot = 0; slot < _lockedCoreTaskCount; slot++) {
      if (assignedSlots.containsKey(slot)) continue;

      final legacyTitle = _legacyCoreTitlesInOrder[slot];
      final byLegacyTitle = _firstUnassignedWhere((task) => task.title == legacyTitle);
      final fallbackFirstBlock = _firstUnassignedWhere((task) => task.orderIndex < _lockedCoreTaskCount);
      final fallbackAny = _firstUnassignedWhere((_) => true);
      final candidate = byLegacyTitle ?? fallbackFirstBlock ?? fallbackAny;
      if (candidate == null) continue;

      candidate
        ..isLockedCoreTask = true
        ..lockedCoreSlot = slot;
      updates.add(candidate);
      assignedSlots[slot] = candidate;
      assignedTaskIds.add(candidate.id);
    }

    for (final task in ordered) {
      if (!task.isLockedCoreTask) continue;
      if (assignedTaskIds.contains(task.id)) continue;
      task
        ..isLockedCoreTask = false
        ..lockedCoreSlot = null;
      updates.add(task);
    }

    if (updates.isEmpty) return;
    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.tasks.putAll(updates);
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
    _renderWidgetMode = _widgetMode;
  }

  Future<void> _setWidgetMode(bool value) async {
    if (value == _widgetMode || _isTransitioningWidgetMode) return;

    // Persist setting first.
    final existing = await _getSetting(_widgetModeTitle);
    final row =
        _newOrExistingSetting(existing, _widgetModeTitle)..goalChimed = value;

    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.tasks.put(row);
    });

    if (!mounted) return;
    setState(() {
      _widgetMode = value;
    });

    await _applyWidgetModeWindowState(value);
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
    const fallback = Size(1280, 800);
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      DebugLog.window('[WindowDebug][_displayLogicalSize] fallback: no views');
      return fallback;
    }

    final view = views.first;
    final dpr = view.devicePixelRatio;
    final physicalSize = view.physicalSize;
    if (dpr > 0 &&
        dpr.isFinite &&
        physicalSize.width > 0 &&
        physicalSize.height > 0) {
      final logical = Size(physicalSize.width / dpr, physicalSize.height / dpr);
      if (logical.width >= _normalMinWidth && logical.height >= _normalMinHeight) {
        _lastKnownFullModeLogicalSize = logical;
      }
      return logical;
    }

    DebugLog.window(
      '[WindowDebug][_displayLogicalSize] invalid physicalSize/dpr '
      '(${physicalSize.width}x${physicalSize.height}, dpr=$dpr), trying display',
    );
    try {
      final display = view.display;
      final displayDpr = display.devicePixelRatio;
      final displaySize = display.size;
      if (displayDpr > 0 &&
          displayDpr.isFinite &&
          displaySize.width > 0 &&
          displaySize.height > 0) {
        final logical = Size(
          displaySize.width / displayDpr,
          displaySize.height / displayDpr,
        );
        if (logical.width >= _normalMinWidth && logical.height >= _normalMinHeight) {
          _lastKnownFullModeLogicalSize = logical;
        }
        return logical;
      }
      DebugLog.window(
        '[WindowDebug][_displayLogicalSize] fallback: invalid display '
        '(${displaySize.width}x${displaySize.height}, dpr=$displayDpr)',
      );
    } catch (e) {
      DebugLog.window(
        '[WindowDebug][_displayLogicalSize] fallback: display unavailable ($e)',
      );
    }

    return fallback;
  }

  BoxConstraints _normalWindowBounds() {
    const fallback = Size(1920, 1080);
    final screen = _displayLogicalSize();
    final isSmallForNormal =
        screen.width < _normalMinWidth || screen.height < _normalMinHeight;
    final effectiveScreen =
        isSmallForNormal ? (_lastKnownFullModeLogicalSize ?? fallback) : screen;
    if (isSmallForNormal) {
      DebugLog.window(
        '[WindowDebug][_normalWindowBounds] using cached full-mode logical size '
        '(${effectiveScreen.width}x${effectiveScreen.height}) for small current '
        '(${screen.width}x${screen.height})',
      );
    }

    final widthReference = screen.width > fallback.width ? screen.width : fallback.width;
    final availableWidth = (widthReference - _windowScreenMargin)
        .clamp(_normalMinWidth, double.infinity)
        .toDouble();
    final availableHeight = (effectiveScreen.height - _windowScreenMargin)
        .clamp(_normalMinHeight, double.infinity)
        .toDouble();
    final maxWidth = _normalMaxWidth.clamp(_normalMinWidth, availableWidth).toDouble();
    final permissiveMaxHeight =
        availableHeight < (_normalMinHeight + 240) ? (_normalMinHeight + 600) : availableHeight;
    return BoxConstraints(
      minWidth: _normalMinWidth,
      minHeight: _normalMinHeight,
      maxWidth: maxWidth,
      maxHeight: permissiveMaxHeight,
    );
  }

BoxConstraints _widgetWindowBounds() {
  const fallback = Size(1920, 1080);

  final effectiveScreen = _lastKnownFullModeLogicalSize ?? fallback;

  final availableWidth = (effectiveScreen.width - _windowScreenMargin)
      .clamp(_widgetModeMinWidth, double.infinity)
      .toDouble();

  final availableHeight = (effectiveScreen.height - _windowScreenMargin)
      .clamp(_widgetModeMinHeight, double.infinity)
      .toDouble();

  final maxWidth =
      _widgetMaxWidth.clamp(_widgetModeMinWidth, availableWidth).toDouble();
  final maxHeight =
      _widgetMaxHeight.clamp(_widgetModeMinHeight, availableHeight).toDouble();

  DebugLog.window(
    '[WindowDebug][_widgetWindowBounds] stable full-mode reference '
    '(${effectiveScreen.width}x${effectiveScreen.height}) '
    'min=($_widgetModeMinWidth,$_widgetModeMinHeight) '
    'max=($maxWidth,$maxHeight)',
  );

  return BoxConstraints(
    minWidth: _widgetModeMinWidth,
    minHeight: _widgetModeMinHeight,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
  );
}

  double _recommendedNormalHeight(int taskCount) {
    final bounds = _normalWindowBounds();
    final visibleTaskCount = taskCount < 1 ? 1 : taskCount;
    const additionalLayoutOverhead = 36.0;
    const safetyBuffer = 16.0;
    final desired =
        _normalBaseHeight +
        additionalLayoutOverhead +
        (visibleTaskCount * _normalTaskRowHeight) +
        safetyBuffer;
    return desired.clamp(bounds.minHeight, bounds.maxHeight).toDouble();
  }

  Future<void> _applyNormalWindowSizingForTasks(int taskCount) async {
    if (!_isDesktopPlatform() || _widgetMode) return;

    DebugLog.window(
      '[StartupSizing] enter taskCount=$taskCount '
      'widgetMode=$_widgetMode '
      'didInitial=$_didInitialTaskAwareSizing '
      'lastNormalSizedTaskCount=$_lastNormalSizedTaskCount',
    );

    if (_lastNormalSizedTaskCount == taskCount && _didInitialTaskAwareSizing) {
      DebugLog.window(
        '[StartupSizing] EARLY RETURN because taskCount unchanged and startup sizing already completed',
      );
      return;
    }

    _lastNormalSizedTaskCount = taskCount;

    final bounds = _normalWindowBounds();
    DebugLog.window(
      '[StartupSizing] bounds '
      'min=(${bounds.minWidth},${bounds.minHeight}) '
      'max=(${bounds.maxWidth},${bounds.maxHeight})',
    );

    await windowManager.setMinimumSize(Size(bounds.minWidth, bounds.minHeight));
    await windowManager.setMaximumSize(Size(bounds.maxWidth, bounds.maxHeight));

    final current = await windowManager.getSize();
    final targetHeight = _recommendedNormalHeight(taskCount);
    const comfortableTableWidth = 1400.0;
    final targetWidth = (current.width > comfortableTableWidth
            ? current.width
            : comfortableTableWidth)
        .clamp(bounds.minWidth, bounds.maxWidth)
        .toDouble();

    DebugLog.window(
      '[StartupSizing] initial target width=$targetWidth height=$targetHeight',
    );

    await windowManager.setSize(Size(targetWidth, targetHeight));

    final afterInitialSize = await windowManager.getSize();
    DebugLog.window(
      '[StartupSizing] after initial setSize actual=${afterInitialSize.width}x${afterInitialSize.height}',
    );

    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 16));

    DebugLog.window(
      '[StartupSizing] post-layout check '
      'hasClients=${_normalTaskListScrollController.hasClients}',
    );

    if (_normalTaskListScrollController.hasClients) {
      final position = _normalTaskListScrollController.position;
      final overflow = position.maxScrollExtent;

      DebugLog.window(
        '[StartupSizing] scroll metrics '
        'maxScrollExtent=${position.maxScrollExtent} '
        'viewport=${position.viewportDimension} '
        'pixels=${position.pixels}',
      );

      if (overflow > 0) {
        final sized = await windowManager.getSize();
        const overflowBuffer = 12.0;
        final expandedHeight = (sized.height + overflow + overflowBuffer)
            .clamp(bounds.minHeight, bounds.maxHeight)
            .toDouble();

        DebugLog.window(
          '[StartupSizing] overflow detected '
          'currentHeight=${sized.height} '
          'overflow=$overflow '
          'expandedHeight=$expandedHeight',
        );

        if (expandedHeight > sized.height) {
          await windowManager.setSize(Size(sized.width, expandedHeight));

          final afterOverflowSize = await windowManager.getSize();
          DebugLog.window(
            '[StartupSizing] after overflow setSize '
            '${afterOverflowSize.width}x${afterOverflowSize.height}',
          );
        }
      } else {
        DebugLog.window('[StartupSizing] no overflow detected');
      }
    } else {
      DebugLog.window('[StartupSizing] no scroll clients attached yet');
    }

    _didInitialTaskAwareSizing = true;
    DebugLog.window('[StartupSizing] marking _didInitialTaskAwareSizing=true');
  }

    
    

  Future<void> _applyWidgetModeWindowState(bool enabled) async {
    DebugLog.widgetMode('HIT _applyWidgetModeWindowState enabled=$enabled');
    DebugLog.window('ENTER enabled=$enabled (start)');
    if (!_isDesktopPlatform()) return;
    if (_isTransitioningWidgetMode) return;

    _isTransitioningWidgetMode = true;

    try {
      if (enabled) {
        final widgetBounds = _widgetWindowBounds();

        _fullModeWindowSize ??= await windowManager.getSize();

        _widgetModeSize ??= Size(
          _widgetDefaultWidth
              .clamp(widgetBounds.minWidth, widgetBounds.maxWidth)
              .toDouble(),
          _widgetDefaultHeight
              .clamp(widgetBounds.minHeight, widgetBounds.maxHeight)
              .toDouble(),
        );
        DebugLog.window('WIDGET enabled=true after computing widgetModeSize');

        final target = Size(
          _widgetModeSize!.width
              .clamp(widgetBounds.minWidth, widgetBounds.maxWidth)
              .toDouble(),
          _widgetModeSize!.height
              .clamp(widgetBounds.minHeight, widgetBounds.maxHeight)
              .toDouble(),
        );
        _widgetModeSize = target;

        await windowManager.setResizable(false);
        await windowManager.setHasShadow(false);
        await windowManager.setAsFrameless();
        await windowManager.setBackgroundColor(Colors.transparent);

        await windowManager.setMinimumSize(
          Size(widgetBounds.minWidth, widgetBounds.minHeight),
        );
        await windowManager.setMaximumSize(
          Size(widgetBounds.maxWidth, widgetBounds.maxHeight),
        );
        DebugLog.window('WIDGET enabled=true after setMinimumSize/setMaximumSize');

        await windowManager.setSize(target);
        DebugLog.window('WIDGET enabled=true after setSize(target)');

        if (!_centeredWidgetOnce) {
          _centeredWidgetOnce = true;
          await windowManager.center();
        }

        if (mounted) {
          setState(() {
            _renderWidgetMode = true;
          });
        }

        return;
      }

      final normalBounds = _normalWindowBounds();
      DebugLog.window(
        '[WindowDebug][NORMAL bounds] '
        'min=(${normalBounds.minWidth},${normalBounds.minHeight}) '
        'max=(${normalBounds.maxWidth},${normalBounds.maxHeight})',
      );
      DebugLog.window('NORMAL enabled=false after computing normalBounds');

      Size? restoreSize = _fullModeWindowSize;
      DebugLog.window('[WindowDebug][restoreSize before clamp] $restoreSize');

      if (restoreSize != null) {
        final clamped = Size(
          restoreSize.width
              .clamp(normalBounds.minWidth, normalBounds.maxWidth)
              .toDouble(),
          restoreSize.height
              .clamp(normalBounds.minHeight, normalBounds.maxHeight)
              .toDouble(),
        );
        DebugLog.window('[WindowDebug][restoreSize AFTER clamp] $clamped');
        restoreSize = clamped;
      } else {
        DebugLog.window('[WindowDebug][restoreSize is null]');
      }

      DebugLog.window('NORMAL enabled=false after restoreSize clamp');
      DebugLog.window(
        'NORMAL enabled=false after computing restoreSize=$restoreSize',
      );

      await windowManager.setResizable(false);

      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.setHasShadow(true);

      final bg = Theme.of(context).scaffoldBackgroundColor;
      await windowManager.setBackgroundColor(bg);
      DebugLog.window('NORMAL enabled=false after setBackgroundColor');

      if (restoreSize != null) {
        await windowManager.setSize(restoreSize);
        DebugLog.window('NORMAL enabled=false after setSize(restoreSize)');
      }

      await windowManager.setMinimumSize(
        Size(normalBounds.minWidth, normalBounds.minHeight),
      );
      await windowManager.setMaximumSize(
        Size(normalBounds.maxWidth, normalBounds.maxHeight),
      );
      await windowManager.setResizable(true);
      DebugLog.window('NORMAL enabled=false AFTER min/max/resizable');
      DebugLog.window(
        'NORMAL enabled=false after setMinimumSize/setMaximumSize/setResizable(true)',
      );

      if (mounted) {
        setState(() {
          _renderWidgetMode = false;
        });
      }

      if (!_appliedInitialNormalBounds) {
        DebugLog.window(
          '[StartupSizing] _applyWidgetModeWindowState(false) '
          'marking _appliedInitialNormalBounds=true',
        );
        _appliedInitialNormalBounds = true;
      }
    } finally {
      _isTransitioningWidgetMode = false;
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
      if (!_renderWidgetMode || _isResizingWidget || _isTransitioningWidgetMode) {
        return;
      }

      final dx = details.delta.dx;
      final dy = details.delta.dy;

      // Ignore pure no-op drag updates.
      if (dx == 0 && dy == 0) {
        return;
      }

      _isResizingWidget = true;

      try {
        final current = await windowManager.getSize();
        final bounds = _widgetWindowBounds();

        final rawNextWidth = current.width + dx;
        final rawNextHeight = current.height + dy;

        final nextWidth = rawNextWidth
            .clamp(bounds.minWidth, bounds.maxWidth)
            .toDouble();
        final nextHeight = rawNextHeight
            .clamp(bounds.minHeight, bounds.maxHeight)
            .toDouble();

        // Ignore effectively unchanged sizes after clamping.
        if ((nextWidth - current.width).abs() < 1 &&
            (nextHeight - current.height).abs() < 1) {
          return;
        }

        final next = Size(nextWidth, nextHeight);

        // Ignore duplicate targets to reduce resize spam.
        final last = _lastAppliedWidgetResizeTarget;
        if (last != null &&
            (last.width - next.width).abs() < 1 &&
            (last.height - next.height).abs() < 1) {
          return;
        }

        DebugLog.window(
          '[WidgetResize] resize current=${current.width}x${current.height} '
          'next=${next.width}x${next.height} delta=($dx, $dy)',
        );

        _lastAppliedWidgetResizeTarget = next;
        await windowManager.setSize(next);
        _widgetModeSize = next;
      } finally {
        _isResizingWidget = false;
      }
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
    _debugPrintTaskIds(tasks);
    return tasks;
  }

  String _todayDateKey() {
    final now = DateTime.now().toLocal();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<List<DailyTaskCompletion>> _getAllDailyCompletions() async {
    final isar = await IsarDb.instance();
    final records = await isar.dailyTaskCompletions.where().findAll();
    debugPrint('[DailyAnalytics] read all rows count=${records.length}');
    return records;
  }

  Future<List<DailyTaskCompletion>> _getDailyCompletionsByTaskId(
    String taskId, {
    List<DailyTaskCompletion>? preloadedRows,
  }) async {
    final records = preloadedRows ?? await _getAllDailyCompletions();
    final rows = records.where((record) => record.taskId == taskId).toList();
    debugPrint('[DailyAnalytics] read by taskId=$taskId count=${rows.length}');
    return rows;
  }

  Future<List<DailyTaskCompletion>> _getDailyCompletionsByDateKey(
    String dateKey, {
    List<DailyTaskCompletion>? preloadedRows,
  }) async {
    final records = preloadedRows ?? await _getAllDailyCompletions();
    final rows = records.where((record) => record.dateKey == dateKey).toList();
    debugPrint('[DailyAnalytics] read by dateKey=$dateKey count=${rows.length}');
    return rows;
  }

  Future<DailyTaskCompletion?> _getDailyCompletionForTask(
    String taskId,
    String dateKey, {
    List<DailyTaskCompletion>? preloadedRows,
  }) async {
    final rows = await _getDailyCompletionsByDateKey(
      dateKey,
      preloadedRows: preloadedRows,
    );
    DailyTaskCompletion? match;
    for (final record in rows) {
      if (record.taskId == taskId) {
        match = record;
        break;
      }
    }
    debugPrint(
      '[DailyAnalytics] read by taskId+dateKey taskId=$taskId dateKey=$dateKey found=${match != null}',
    );
    return match;
  }

  double _calculateTaskDailyCompletionPercent(DailyTaskCompletion? record) {
    if (record == null || !_isValidTargetSnapshot(record.targetMinutesSnapshot)) {
      return 0.0;
    }
    final completedMinutes = record.completedMinutes < _dailyMinutesFloor
        ? _dailyMinutesFloor
        : record.completedMinutes;
    final ratio = completedMinutes / record.targetMinutesSnapshot;
    return _clampPercent(ratio);
  }

  Future<double> _calculateDailyCompletionPercentForTask(
    String taskId,
    String dateKey,
  ) async {
    final record = await _getDailyCompletionForTask(taskId, dateKey);
    final percent = _calculateTaskDailyCompletionPercent(record);
    debugPrint(
      '[DailyAnalytics] task daily percent taskId=$taskId dateKey=$dateKey percent=$percent',
    );
    return percent;
  }

  Map<String, DailyTaskCompletion> _buildTaskCompletionMapForDate(
    List<DailyTaskCompletion> rows,
    String dateKey,
  ) {
    final byTaskId = <String, DailyTaskCompletion>{};
    for (final row in rows) {
      if (row.dateKey != dateKey) continue;
      final existing = byTaskId[row.taskId];
      if (existing == null || row.id > existing.id) {
        byTaskId[row.taskId] = row;
      }
    }
    return byTaskId;
  }

  Map<String, Map<String, DailyTaskCompletion>> _buildCompletionMapByDateAndTask(
    List<DailyTaskCompletion> rows,
  ) {
    final byDateAndTask = <String, Map<String, DailyTaskCompletion>>{};
    for (final row in rows) {
      final byTask = byDateAndTask.putIfAbsent(
        row.dateKey,
        () => <String, DailyTaskCompletion>{},
      );
      final existing = byTask[row.taskId];
      if (existing == null || row.id > existing.id) {
        byTask[row.taskId] = row;
      }
    }
    return byDateAndTask;
  }

  Future<List<String>> _getExpectedAnalyticsTaskIds() async {
    final isar = await IsarDb.instance();
    final tasks = await isar.tasks
        .filter()
        .planIdEqualTo(_planId)
        .sortByOrderIndex()
        .findAll();

    final expectedTaskIds = <String>[];
    for (final task in tasks) {
      final targetMin = task.targetMin;
      if (targetMin != null && targetMin > 0) {
        expectedTaskIds.add(task.id.toString());
      }
    }

    debugPrint(
      '[DailyAnalytics] expected task set planId=$_planId expectedTaskCount=${expectedTaskIds.length}',
    );
    return expectedTaskIds;
  }

  Future<double> _calculateDailyOverallAveragePercent(String dateKey) async {
    final expectedTaskIds = await _getExpectedAnalyticsTaskIds();
    final expectedTaskCount = expectedTaskIds.length;
    if (expectedTaskCount == 0) {
      debugPrint(
        '[DailyAnalytics] overall daily avg dateKey=$dateKey expectedTaskCount=0 matchedRowCount=0 missingRowCount=0 average=0.0',
      );
      return 0.0;
    }

    final allRows = await _getAllDailyCompletions();
    final rows = await _getDailyCompletionsByDateKey(
      dateKey,
      preloadedRows: allRows,
    );
    final byTaskId = _buildTaskCompletionMapForDate(rows, dateKey);

    var total = 0.0;
    var matchedRowCount = 0;
    var missingRowCount = 0;

    for (final taskId in expectedTaskIds) {
      final row = byTaskId[taskId];
      if (row == null) {
        missingRowCount += 1;
        continue;
      }
      matchedRowCount += 1;
      total += _calculateTaskDailyCompletionPercent(row);
    }

    final average = _clampPercent(total / expectedTaskCount);
    debugPrint(
      '[DailyAnalytics] overall daily avg dateKey=$dateKey expectedTaskCount=$expectedTaskCount matchedRowCount=$matchedRowCount missingRowCount=$missingRowCount average=$average',
    );
    return average;
  }


  Future<void> _debugPrintDailyCompletionSummaryForDate(String dateKey) async {
    final expectedTaskIds = await _getExpectedAnalyticsTaskIds();
    final expectedTaskCount = expectedTaskIds.length;
    final allRows = await _getAllDailyCompletions();
    final rowsForDate = await _getDailyCompletionsByDateKey(
      dateKey,
      preloadedRows: allRows,
    );
    final byTaskId = _buildTaskCompletionMapForDate(rowsForDate, dateKey);

    final matchedTaskIds = <String>[];
    final missingTaskIds = <String>[];
    var total = 0.0;

    for (final taskId in expectedTaskIds) {
      final row = byTaskId[taskId];
      if (row == null) {
        missingTaskIds.add(taskId);
        continue;
      }
      matchedTaskIds.add(taskId);
      total += _calculateTaskDailyCompletionPercent(row);
    }

    final average = expectedTaskCount == 0
        ? 0.0
        : _clampPercent(total / expectedTaskCount);

    debugPrint(
      '[DailyAnalytics] daily summary dateKey=$dateKey expectedTaskCount=$expectedTaskCount totalRowsForDate=${rowsForDate.length} matchedTaskIds=$matchedTaskIds missingTaskIds=$missingTaskIds average=$average',
    );
  }

  List<String> _buildWeekDateKeys(DateTime anchorDate) {
    final localDate = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    final weekdayOffset = localDate.weekday - DateTime.monday;
    final weekStart = localDate.subtract(Duration(days: weekdayOffset));
    final keys = List<String>.generate(
      7,
      (index) => _formatDateKey(weekStart.add(Duration(days: index))),
    );
    debugPrint(
      '[DailyAnalytics] week date keys anchor=${_formatDateKey(localDate)} start=${keys.first} end=${keys.last} count=${keys.length}',
    );
    return keys;
  }

  List<String> _buildMonthDateKeys(DateTime anchorDate) {
    final firstDay = DateTime(anchorDate.year, anchorDate.month, 1);
    final firstDayNextMonth = anchorDate.month == 12
        ? DateTime(anchorDate.year + 1, 1, 1)
        : DateTime(anchorDate.year, anchorDate.month + 1, 1);
    final daysInMonth = firstDayNextMonth.difference(firstDay).inDays;
    final keys = List<String>.generate(
      daysInMonth,
      (index) => _formatDateKey(firstDay.add(Duration(days: index))),
    );
    debugPrint(
      '[DailyAnalytics] month date keys anchor=${_formatDateKey(DateTime(anchorDate.year, anchorDate.month, anchorDate.day))} start=${keys.first} end=${keys.last} count=${keys.length}',
    );
    return keys;
  }

  List<String> _buildYearDateKeys(DateTime anchorDate) {
    final firstDay = DateTime(anchorDate.year, 1, 1);
    final firstDayNextYear = DateTime(anchorDate.year + 1, 1, 1);
    final daysInYear = firstDayNextYear.difference(firstDay).inDays;
    final keys = List<String>.generate(
      daysInYear,
      (index) => _formatDateKey(firstDay.add(Duration(days: index))),
    );
    debugPrint(
      '[DailyAnalytics] year date keys year=${anchorDate.year} start=${keys.first} end=${keys.last} count=${keys.length}',
    );
    return keys;
  }

  Future<Map<String, double>> _calculateDailyAverageSeries(
    List<String> dateKeys, {
    List<String>? expectedTaskIds,
    List<DailyTaskCompletion>? preloadedRows,
  }) async {
    final resolvedExpectedTaskIds = expectedTaskIds ?? await _getExpectedAnalyticsTaskIds();
    final expectedTaskCount = resolvedExpectedTaskIds.length;

    final records = preloadedRows ?? await _getAllDailyCompletions();
    final byDateAndTask = _buildCompletionMapByDateAndTask(records);

    final series = <String, double>{};
    for (final dateKey in dateKeys) {
      if (expectedTaskCount == 0) {
        series[dateKey] = 0.0;
        debugPrint(
          '[DailyAnalytics] series daily avg dateKey=$dateKey expectedTaskCount=0 matchedRowCount=0 missingRowCount=0 average=0.0',
        );
        continue;
      }

      final byTaskId = byDateAndTask[dateKey] ?? const <String, DailyTaskCompletion>{};
      var totalPercent = 0.0;
      var matchedRowCount = 0;
      var missingRowCount = 0;

      for (final taskId in resolvedExpectedTaskIds) {
        final row = byTaskId[taskId];
        if (row == null) {
          missingRowCount += 1;
          continue;
        }
        matchedRowCount += 1;
        totalPercent += _calculateTaskDailyCompletionPercent(row);
      }

      final average = _clampPercent(totalPercent / expectedTaskCount);
      series[dateKey] = average;
      debugPrint(
        '[DailyAnalytics] series daily avg dateKey=$dateKey expectedTaskCount=$expectedTaskCount matchedRowCount=$matchedRowCount missingRowCount=$missingRowCount average=$average',
      );
    }

    debugPrint(
      '[DailyAnalytics] series computed points=${series.length} first=${dateKeys.isEmpty ? 'n/a' : dateKeys.first} last=${dateKeys.isEmpty ? 'n/a' : dateKeys.last}',
    );
    return series;
  }

  Future<Map<String, double>> _calculateWeeklyAverageSeries(DateTime anchorDate) async {
    final dateKeys = _buildWeekDateKeys(anchorDate);
    final expectedTaskIds = await _getExpectedAnalyticsTaskIds();
    final records = await _getAllDailyCompletions();
    final series = await _calculateDailyAverageSeries(
      dateKeys,
      expectedTaskIds: expectedTaskIds,
      preloadedRows: records,
    );
    debugPrint(
      '[DailyAnalytics] weekly series anchor=${_formatDateKey(DateTime(anchorDate.year, anchorDate.month, anchorDate.day))} points=${series.length}',
    );
    return series;
  }

  Future<Map<String, double>> _calculateMonthlyAverageSeries(DateTime anchorDate) async {
    final dateKeys = _buildMonthDateKeys(anchorDate);
    final expectedTaskIds = await _getExpectedAnalyticsTaskIds();
    final records = await _getAllDailyCompletions();
    final series = await _calculateDailyAverageSeries(
      dateKeys,
      expectedTaskIds: expectedTaskIds,
      preloadedRows: records,
    );
    debugPrint(
      '[DailyAnalytics] monthly series anchor=${_formatDateKey(DateTime(anchorDate.year, anchorDate.month, anchorDate.day))} points=${series.length}',
    );
    return series;
  }

  Future<Map<String, double>> _calculateYearlyAverageSeries(DateTime anchorDate) async {
    final dateKeys = _buildYearDateKeys(anchorDate);
    final expectedTaskIds = await _getExpectedAnalyticsTaskIds();
    final records = await _getAllDailyCompletions();
    final series = await _calculateDailyAverageSeries(
      dateKeys,
      expectedTaskIds: expectedTaskIds,
      preloadedRows: records,
    );
    debugPrint(
      '[DailyAnalytics] yearly series year=${anchorDate.year} points=${series.length}',
    );
    return series;
  }


  Future<void> _openSummaryDialog() async {
    debugPrint('[SummaryUI] opening dialog');
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        var selectedRange = 'week';
        var seriesFuture = _loadSummarySeries(selectedRange);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Summary'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 860,
                  minWidth: 520,
                  maxHeight: 620,
                ),
                child: SizedBox(
                  width: 820,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'week',
                              label: Text('Week'),
                            ),
                            ButtonSegment<String>(
                              value: 'month',
                              label: Text('Month'),
                            ),
                            ButtonSegment<String>(
                              value: 'year',
                              label: Text('Year'),
                            ),
                          ],
                          selected: {selectedRange},
                          showSelectedIcon: false,
                          onSelectionChanged: (selection) {
                            final nextRange = selection.first;
                            if (nextRange == selectedRange) return;
                            setDialogState(() {
                              selectedRange = nextRange;
                              seriesFuture = _loadSummarySeries(selectedRange);
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<Map<String, double>>(
                          future: seriesFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(
                                height: 280,
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return const SizedBox(
                                height: 280,
                                child: Center(
                                  child: Text(
                                    'No summary data yet. Use Start/Done or Log Time to begin tracking progress.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }

                            final points = snapshot.data ?? const <String, double>{};
                            if (points.isEmpty) {
                              return const SizedBox(
                                height: 280,
                                child: Center(
                                  child: Text(
                                    'No summary data yet. Use Start/Done or Log Time to begin tracking progress.',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            }

                            return _buildSummaryChart(points: points, range: selectedRange);
                          },
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<Map<String, dynamic>>(
                          future: _buildTodaySummaryData(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: LinearProgressIndicator(minHeight: 2),
                              );
                            }

                            if (snapshot.hasError || !snapshot.hasData) {
                              return const Text(
                                "Today's summary is unavailable right now.",
                              );
                            }

                            final data = snapshot.data!;
                            final percent = ((data['percent'] as double) * 100).round();
                            final expectedCount = data['expectedCount'] as int;
                            final loggedCount = data['loggedCount'] as int;
                            final missingCount = data['missingCount'] as int;

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Today's Summary",
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Text("Today's Completion: $percent%"),
                                  const SizedBox(height: 4),
                                  Text('Logged Tasks: $loggedCount / $expectedCount'),
                                  const SizedBox(height: 4),
                                  Text('Missing Tasks: $missingCount'),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, double>> _loadSummarySeries(String range) async {
    debugPrint('[SummaryUI] loading range=$range');
    final now = DateTime.now();
    late final Map<String, double> series;
    switch (range) {
      case 'month':
        series = await _calculateMonthlyAverageSeries(now);
        break;
      case 'year':
        series = await _calculateYearlyAverageSeries(now);
        break;
      case 'week':
      default:
        series = await _calculateWeeklyAverageSeries(now);
        break;
    }
    debugPrint('[SummaryUI] loaded points=${series.length} range=$range');
    return series;
  }

  Future<Map<String, dynamic>> _buildTodaySummaryData() async {
    final todayKey = _todayDateKey();
    await _debugPrintDailyCompletionSummaryForDate(todayKey);
    final percent = await _calculateDailyOverallAveragePercent(todayKey);
    final expectedTaskIds = await _getExpectedAnalyticsTaskIds();
    final rows = await _getDailyCompletionsByDateKey(todayKey);
    final byTask = _buildTaskCompletionMapForDate(rows, todayKey);
    final loggedCount = expectedTaskIds.where((id) => byTask.containsKey(id)).length;
    final expectedCount = expectedTaskIds.length;
    final missingCount = math.max(0, expectedCount - loggedCount);
    debugPrint(
      '[SummaryUI] today summary percent=$percent logged=$loggedCount expected=$expectedCount missing=$missingCount',
    );
    return {
      'percent': percent,
      'expectedCount': expectedCount,
      'loggedCount': loggedCount,
      'missingCount': missingCount,
    };
  }

  Widget _buildSummaryChart({
    required Map<String, double> points,
    required String range,
  }) {
    final entries = points.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final values = entries.map((entry) => _clampPercent(entry.value)).toList();
    final labels = entries
        .map((entry) => _buildSummaryXAxisLabel(entry.key, range))
        .toList();

    return SizedBox(
      height: 320,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 44,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Text('100%'),
                      Text('75%'),
                      Text('50%'),
                      Text('25%'),
                      Text('0%'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CustomPaint(
                    painter: _SummaryLineChartPainter(values: values),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 20,
            child: _buildSummaryXAxis(labels, range),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryXAxis(List<String> labels, String range) {
    if (labels.isEmpty) return const SizedBox.shrink();

    final visibleIndexes = <int>{};
    if (range == 'year') {
      for (var i = 0; i < labels.length; i++) {
        final label = labels[i];
        if (label.isNotEmpty) {
          visibleIndexes.add(i);
        }
      }
    } else if (range == 'month') {
      final step = math.max(1, (labels.length / 8).ceil());
      for (var i = 0; i < labels.length; i += step) {
        visibleIndexes.add(i);
      }
      visibleIndexes.add(labels.length - 1);
    } else {
      for (var i = 0; i < labels.length; i++) {
        visibleIndexes.add(i);
      }
    }

    return Row(
      children: List<Widget>.generate(labels.length, (index) {
        final show = visibleIndexes.contains(index);
        return Expanded(
          child: Align(
            alignment: Alignment.center,
            child: show
                ? Text(
                    labels[index],
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  )
                : const SizedBox.shrink(),
          ),
        );
      }),
    );
  }

  String _buildSummaryXAxisLabel(String dateKey, String range) {
    final parts = dateKey.split('-');
    if (parts.length != 3) return dateKey;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return dateKey;

    if (range == 'week') {
      final date = DateTime(year, month, day);
      final idx = date.weekday - 1;
      const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      if (idx < 0 || idx >= weekdayLabels.length) return dateKey;
      return weekdayLabels[idx];
    }

    if (range == 'month') {
      return day.toString();
    }

    if (range == 'year') {
      const monthLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      if (day == 1 && month >= 1 && month <= 12) {
        return monthLabels[month - 1];
      }
      return '';
    }

    return dateKey;
  }

  Future<void> _upsertDailyCompletionForTask(Task task, int completedMinutes) async {
    final targetMinutesSnapshot = task.targetMin;
    if (targetMinutesSnapshot == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Set a goal minutes value before logging time for this task.'),
          ),
        );
      }
      return;
    }

    final dateKey = _todayDateKey();
    final taskId = task.id.toString();
    final isDone = completedMinutes >= targetMinutesSnapshot;

    debugPrint(
      '[DailyCompletion] save request taskId=$taskId dateKey=$dateKey completedMinutes=$completedMinutes targetMinutesSnapshot=$targetMinutesSnapshot isDone=$isDone',
    );

    final isar = await IsarDb.instance();
    final existing = await _getDailyCompletionForTask(taskId, dateKey);
    await isar.writeTxn(() async {
      final record = existing ?? DailyTaskCompletion();
      record.taskId = taskId;
      record.dateKey = dateKey;
      record.completedMinutes = completedMinutes;
      record.targetMinutesSnapshot = targetMinutesSnapshot;
      record.isDone = isDone;
      await isar.dailyTaskCompletions.put(record);
    });

    final saved = await _getDailyCompletionForTask(taskId, dateKey);
    if (saved != null) {
      debugPrint(
        '[DailyCompletion] saved record id=${saved.id} taskId=${saved.taskId} dateKey=${saved.dateKey} completedMinutes=${saved.completedMinutes} targetMinutesSnapshot=${saved.targetMinutesSnapshot} isDone=${saved.isDone}',
      );
    }
  }

  void _debugPrintTaskIds(List<Task> tasks) {
    for (final task in tasks) {
      debugPrint('[TaskDebug] task title="${task.title}" id=${task.id}');
    }
  }

  Future<void> _openLogTimeDialog(Task task) async {
    if (task.targetMin == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Set a goal minutes value before logging time for this task.'),
          ),
        );
      }
      return;
    }

    final controller = TextEditingController();
    String? errorText;

    final didSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Log Time'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the total amount of time you completed for this task today.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Minutes',
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final raw = controller.text.trim();
                    final parsed = int.tryParse(raw);
                    if (raw.isEmpty || parsed == null || parsed < 0) {
                      setDialogState(() {
                        errorText = 'Enter a non-negative whole number';
                      });
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );

    if (didSave == true) {
      final completedMinutes = int.parse(controller.text.trim());
      await _upsertDailyCompletionForTask(task, completedMinutes);
    }

    controller.dispose();
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

    final completedMinutes = (task.actualAccumulatedMs / 60000).floor();
    await _upsertDailyCompletionForTask(task, completedMinutes);

    setState(() {});
  }

  Future<void> _saveTask(Task task) async {
    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.tasks.put(task);
    });
  }

  int? _lockedCoreOrder(Task task) {
    if (!task.isLockedCoreTask) return null;
    final slot = task.lockedCoreSlot;
    if (slot == null || slot < 0 || slot >= _lockedCoreTaskCount) return null;
    return slot;
  }

  int? _nonRitualStartThreshold(List<Task> tasks) {
    for (final task in tasks) {
      if (task.lockedCoreSlot != _lockedCoreTaskCount - 1) continue;
      if (task.plannedEndMin != null) return task.plannedEndMin;
      if (task.plannedStartMin != null && task.targetMin != null) {
        return task.plannedStartMin! + task.targetMin!;
      }
    }
    return null;
  }
    List<Task> _lockedTasksInOrder(List<Task> tasks) {
    final locked = tasks.where(_isMandatoryTask).toList();
    locked.sort((a, b) => _lockedCoreOrder(a)!.compareTo(_lockedCoreOrder(b)!));
    return locked;
  }

  String? _lockedSequenceValidationMessage({
    required Task selected,
    required List<Task> tasks,
    required int proposedStart,
  }) {
    final selectedOrder = _lockedCoreOrder(selected);
    if (selectedOrder == null) return null;

    final locked = _lockedTasksInOrder(tasks);

    for (final other in locked) {
      if (other.id == selected.id) continue;

      final otherOrder = _lockedCoreOrder(other);
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
      if (_isMandatoryTask(task)) {
        ritualTasks.add(task);
      } else {
        nonRitualTasks.add(task);
      }
    }

    ritualTasks.sort((a, b) {
      return _lockedCoreOrder(a)!.compareTo(_lockedCoreOrder(b)!);
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
    return task.isLockedCoreTask;
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
      case 'log_time':
        await _openLogTimeDialog(task);
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
                      _lastAppliedWidgetResizeTarget = null;
                      DebugLog.window('[WidgetResize] handle pan start');
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
          backgroundColor: _renderWidgetMode ? Colors.transparent : null,
          appBar: _renderWidgetMode ? null : _buildCustomTitleBar(),
          body: FutureBuilder<List<Task>>(
            future: _loadPlanTasks(),
            builder: (context, tasksSnapshot) {
              if (!tasksSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
                            final tasks = tasksSnapshot.data!;
              DebugLog.window('[StartupSizing] build received tasks count=${tasks.length}');

              if (!_renderWidgetMode &&
                  !_startupSizingQueued &&
                  (!_didInitialTaskAwareSizing || _lastNormalSizedTaskCount != tasks.length)) {
                _startupSizingQueued = true;

                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  _startupSizingQueued = false;
                  if (!mounted || _renderWidgetMode) return;
                  await _applyNormalWindowSizingForTasks(tasks.length);
                });
              }
              return ValueListenableBuilder<DateTime>(
                valueListenable: _ticker,
                builder: (context, tick, _) {
                  final activeSession = _activeSessionTask(tasks);
                  if (_renderWidgetMode) {
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
                              child: Padding(
                                padding: const EdgeInsets.only(right: 96, bottom: 56),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onPanStart: (_) {
                                    if (_isDesktopPlatform()) {
                                      DebugLog.window('[WidgetResize] background drag start');
                                      windowManager.startDragging();
                                    }
                                  },
                                  child: const SizedBox.expand(),
                                ),
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
                                      onPanStart: (_) {
                                        DebugLog.window('[WidgetResize] handle pan start');
                                      },
                                      onPanUpdate: (details) async {
                                        DebugLog.window(
                                          '[WidgetResize] handle pan update dx=${details.delta.dx} dy=${details.delta.dy}',
                                        );
                                        await _resizeWidgetMode(details);
                                      },
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.22),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.drag_handle,
                                          size: 16,
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

 return LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxHeight < 420) {
      return const SizedBox.expand();
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: ClipRect(
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
                onPressed: tasks.isEmpty ? null : () => _resetToday(tasks),
                child: const Text('Reset Today'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _openSummaryDialog,
                child: const Text('Summary'),
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
                        await _showSettingsComingSoonDialog('Import PNG');
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
                      child: Scrollbar(
                        controller: _normalTaskListScrollController,
                        thumbVisibility: true,
                        interactive: true,
                        child: ListView.separated(
                          controller: _normalTaskListScrollController,
                          primary: false,
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                          itemCount: tasks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 2),
                          itemBuilder: (context, index) {
                            final activeWindowIndex =
                                _activeWindowTaskIndex(tasks, _nowLocal());
                            final task = tasks[index];
                            final elapsed = _elapsedMs(task, tick);
                            final isCurrentWindowTask =
                                activeWindowIndex == index;
                            final rowHighlightColor = Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.12);

                            return Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isCurrentWindowTask
                                      ? rowHighlightColor
                                      : null,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      child: _isMandatoryTask(task)
                                          ? const Icon(Icons.lock, size: 15)
                                          : null,
                                    ),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: _timeColumnWidth,
                                      child: _buildTimePill(task, tasks),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _editTaskName(task),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: Text(
                                            '${_taskEmoji(task)} ${task.title}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              decoration:
                                                  task.status == 'done'
                                                      ? TextDecoration.lineThrough
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
                                      width: _deleteMode &&
                                              !_isMandatoryTask(task)
                                          ? 76
                                          : 40,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          if (_deleteMode &&
                                              !_isMandatoryTask(task))
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              tooltip: 'Delete task',
                                              onPressed: () =>
                                                  _deleteTask(task, tasks),
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
                                                child: Text('Edit task name'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'edit_time',
                                                child: Text('Edit time'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'edit_goal',
                                                child: Text('Edit goal'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'log_time',
                                                child: Text('Log Time'),
                                              ),
                                              if (!_isMandatoryTask(task))
                                                const PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Delete'),
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
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  },
);                },
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

class _SummaryLineChartPainter extends CustomPainter {
  _SummaryLineChartPainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    final axisPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), axisPaint);

    if (values.isEmpty) return;

    final path = Path();
    final pointPaint = Paint()
      ..color = Colors.blue.shade600
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.blue.shade600
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < values.length; i++) {
      final dx = values.length == 1
          ? size.width / 2
          : (size.width * i) / (values.length - 1);
      final dy = size.height * (1 - values[i].clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    canvas.drawPath(path, linePaint);

    for (var i = 0; i < values.length; i++) {
      final dx = values.length == 1
          ? size.width / 2
          : (size.width * i) / (values.length - 1);
      final dy = size.height * (1 - values[i].clamp(0.0, 1.0));
      canvas.drawCircle(Offset(dx, dy), 2.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SummaryLineChartPainter oldDelegate) {
    if (identical(oldDelegate.values, values)) return false;
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) {
        return true;
      }
    }
    return false;
  }
}
