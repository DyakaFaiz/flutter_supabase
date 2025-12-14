import 'package:flutter_test/flutter_test.dart';
import 'package:latihan_supabase/models/task.dart';

void main() {
  group('Task Model Tests', () {
    
    group('JSON Serialization (API)', () {
      test('dari API', () {
        final json = {
          'id': 101,
          'title': 'Test API Task',
          'description': 'Description from API',
          'completed': true,
          'user_id': 'user_123',
          'created_at': '2025-01-01T12:00:00.000',
        };

        final task = Task.fromJson(json);

        expect(task.serverId, 101);
        expect(task.title, 'Test API Task');
        expect(task.completed, true);
        expect(task.isSynced, true);
        expect(task.createdAt, DateTime(2025, 1, 1, 12, 0, 0));
      });

      test('handle kosong', () {
        // Simulasi respon API yang tidak lengkap (missing description, completed, title null?)
        final json = {
          'id': 102,
          'user_id': 'user_456',
        };

        final task = Task.fromJson(json);

        expect(task.title, ''); // Default string kosong
        expect(task.description, ''); // Default string kosong
        expect(task.completed, false); // Default false
        expect(task.createdAt, null);
        expect(task.isSynced, true);
      });

      test('dari lokal ke API', () {
        final date = DateTime(2025, 1, 1, 10, 0, 0);
        final task = Task(
          serverId: 202,
          title: 'Outgoing Task',
          description: 'Sending to API',
          completed: true,
          userId: 'user_999',
          createdAt: date,
        );

        final json = task.toJson();

        expect(json['title'], 'Outgoing Task');
        expect(json['completed'], true);
        expect(json['id'], 202);
        expect(json['created_at'], date.toIso8601String());
      });

      test('buat data ke API', () {
        final task = Task(
          title: 'New Task',
          userId: 'user_1',
        );

        final json = task.toJson();

        expect(json.containsKey('id'), false);
        expect(json['title'], 'New Task');
      });
    });

    group('SQLite Conversion (Map)', () {
      test('boolean ke 1 atau 0', () {
        final taskTrue = Task(title: 'A', userId: '1', completed: true, isSynced: true);
        final taskFalse = Task(title: 'B', userId: '1', completed: false, isSynced: false);

        final mapTrue = taskTrue.toMap();
        final mapFalse = taskFalse.toMap();

        expect(mapTrue['completed'], 1);
        expect(mapTrue['is_synced'], 1);
        
        expect(mapFalse['completed'], 0);
        expect(mapFalse['is_synced'], 0);
      });

      test('0 1 ke boolean', () {
        final map = {
          'local_id': 1,
          'title': 'DB Task',
          'completed': 1,
          'is_synced': 0,
          'user_id': 'u1'
        };

        final task = Task.fromMap(map);

        expect(task.completed, true);
        expect(task.isSynced, false);
        expect(task.localId, 1);
      });
    });

    group('Edge Cases & Utilities', () {
      test('salah tanggal', () {
        final map = {
          'title': 'Edge Case',
          'user_id': 'u1',
          'created_at': 'INVALID-DATE-FORMAT',
        };

        final task = Task.fromMap(map);

        expect(task.createdAt, null);
      });

      test('handle null', () {
         final map = {
          'title': 'Null Bool',
          'user_id': 'u1',
          'completed': null,
        };

        final task = Task.fromMap(map);
        expect(task.completed, false);
      });

      test('tes copyWith', () {
        final task = Task(
          title: 'Old Title',
          completed: false,
          userId: 'u1',
        );

        final updatedTask = task.copyWith(
          title: 'New Title',
          completed: true,
        );

        expect(updatedTask.title, 'New Title');
        expect(updatedTask.completed, true);
        
        expect(updatedTask.userId, 'u1');
        
        expect(task.title, 'Old Title'); 
        expect(identical(task, updatedTask), false);
      });
    });
  });
}