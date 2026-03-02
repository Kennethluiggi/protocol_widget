import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

import 'data/isar_db.dart';
import 'data/models/task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarDb.instance();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: IsarSmokeTest(),
    );
  }
}

class IsarSmokeTest extends StatefulWidget {
  const IsarSmokeTest({super.key});

  @override
  State<IsarSmokeTest> createState() => _IsarSmokeTestState();
}

class _IsarSmokeTestState extends State<IsarSmokeTest> {
  String status = 'Ready';

  Future<void> writeAndRead() async {
    final isar = await IsarDb.instance();

    final t = Task()
      ..planId = 20260301
      ..orderIndex = 0
      ..type = 'ritual'
      ..title = 'Brain Dump (offline)'
      ..bullets = ['Write ideas on paper/whiteboard', 'No in-app notes']
      ..targetMin = 15
      ..status = 'not_started';

    await isar.writeTxn(() async {
      await isar.tasks.put(t);
    });

   final fetched = await isar.tasks.get(t.id);

    setState(() {
      status = fetched == null
          ? 'No record found'
          : 'Saved Task: id=${fetched.id}, title="${fetched.title}", targetMin=${fetched.targetMin}';
    });
  }

  Future<void> clearAll() async {
    final isar = await IsarDb.instance();
    await isar.writeTxn(() async {
      await isar.tasks.clear();
    });
    setState(() => status = 'Cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forge - Isar Smoke Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(status),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: writeAndRead,
              child: const Text('Write + Read Task'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: clearAll,
              child: const Text('Clear Tasks'),
            ),
          ],
        ),
      ),
    );
  }
}