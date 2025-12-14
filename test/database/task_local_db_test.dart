import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:latihan_supabase/local/task_local_db.dart';
import 'package:latihan_supabase/models/task.dart';

void main() {
  late TaskLocalDb localDb;

  setUpAll(() {
    // Mengaktifkan database factory berbasis FFI (untuk Windows/Mac/Linux)
    sqfliteFfiInit();
    
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    localDb = TaskLocalDb();
    
    final db = await localDb.database;
    await db.delete('tasks_local');
  });

  tearDown(() async {
    await localDb.close();
  });

  group('TaskLocalDb Tests (SQLite FFI)', () {
    
    test('tambah mengambil task', () async {
      final task = Task(
        title: 'Test FFI',
        userId: 'user_1',
        completed: false,
        isSynced: false,
      );

      final id = await localDb.insertTask(task);
      
      expect(id, greaterThan(0));

      final tasks = await localDb.getAllTasks();

      expect(tasks.length, 1);
      expect(tasks.first.title, 'Test FFI');
      expect(tasks.first.localId, id);
    });

    test('update status task', () async {
      final task = Task(title: 'To Update', userId: 'u1');
      final id = await localDb.insertTask(task);
      final insertedTask = task.copyWith(localId: id);

      final updatedTask = insertedTask.copyWith(completed: true);
      await localDb.updateTask(updatedTask);

      final tasks = await localDb.getAllTasks();
      final myTask = tasks.firstWhere((t) => t.localId == id);
      expect(myTask.completed, true);
    });

    test('hapus task', () async {
      final task = Task(title: 'To Delete', userId: 'u1');
      final id = await localDb.insertTask(task);

      await localDb.deleteTask(id);

      final tasks = await localDb.getAllTasks();
      expect(tasks, isEmpty);
    });
  });
}