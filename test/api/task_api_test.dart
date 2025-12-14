import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latihan_supabase/api/task_api.dart';
import 'package:latihan_supabase/models/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TaskApiService Tests', () {
    late TaskApiService apiService;
    
    final tTask = Task(
      serverId: 1,
      title: 'Test Task',
      userId: 'user_123',
      completed: false,
    );

    final tAuthResponse = {
      'access_token': 'dummy_token',
      'user': {
        'id': 'user_123',
        'email': 'test@example.com'
      }
    };

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    group('Authentication', () {
      test('login berhasil', () async {
        final mockClient = MockClient((request) async {
          return http.Response(jsonEncode(tAuthResponse), 200);
        });

        apiService = TaskApiService(client: mockClient);

        final result = await apiService.login('test@example.com', 'password');

        expect(result, isNotNull);
        expect(result!['access_token'], 'dummy_token');

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('access_token'), 'dummy_token');
        expect(prefs.getString('user_id'), 'user_123');
      });

      test('salah akun', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Invalid credentials', 400);
        });

        apiService = TaskApiService(client: mockClient);
        final result = await apiService.login('wrong', 'pass');

        expect(result, isNull);
      });

      test('mengosongkan shared preference', () async {
        SharedPreferences.setMockInitialValues({
          'access_token': 'old_token',
          'user_id': 'old_user'
        });

        apiService = TaskApiService();
        
        await apiService.logout();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('access_token'), isNull);
        expect(prefs.getString('user_id'), isNull);
      });
    });

    group('CRUD Operations', () {
      test('berhasil dapat data dari API', () async {
        final mockResponse = [
          {
            'id': 1,
            'title': 'Task 1',
            'user_id': 'u1',
            'created_at': DateTime.now().toIso8601String()
          },
          {
            'id': 2,
            'title': 'Task 2',
            'user_id': 'u1',
            'created_at': DateTime.now().toIso8601String()
          }
        ];

        final mockClient = MockClient((request) async {
          expect(request.headers['apikey'], isNotNull);
          return http.Response(jsonEncode(mockResponse), 200);
        });

        apiService = TaskApiService(client: mockClient);
        final tasks = await apiService.getTasks();

        expect(tasks.length, 2);
        expect(tasks.first.title, 'Task 1');
      });

      test('buat tugas baru', () async {
        final newTask = Task(title: 'New Task', userId: 'u1');
        final responseBody = {
          'id': 10,
          'title': 'New Task',
          'user_id': 'u1',
          'created_at': DateTime.now().toIso8601String()
        };

        final mockClient = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.headers['Prefer'], 'return=representation');
          return http.Response(jsonEncode(responseBody), 201);
        });

        apiService = TaskApiService(client: mockClient);
        final result = await apiService.createTask(newTask);

        expect(result, isNotNull);
        expect(result!.serverId, 10);
      });

      test('update data kosong', () async {
         final mockClient = MockClient((request) async {
          expect(request.method, 'PATCH');
          return http.Response('', 204);
        });

        apiService = TaskApiService(client: mockClient);
        final result = await apiService.updateTask(tTask);

        expect(result, true);
      });

      test('menghapus data', () async {
        final mockClient = MockClient((request) async {
          expect(request.method, 'DELETE');
          return http.Response('', 200);
        });

        apiService = TaskApiService(client: mockClient);
        final result = await apiService.deleteTask(123);

        expect(result, true);
      });
    });

    group('Network Errors & Edge Cases', () {
      test('kembalikan data kosong ketika ada offline/session habis)', () async {
        final mockClient = MockClient((request) async {
          throw const SocketException('No Internet');
        });

        apiService = TaskApiService(client: mockClient);
        
        final tasks = await apiService.getTasks();

        expect(tasks, isEmpty);
      });

      test('mengembalikan data kosong karena belum login', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });

        apiService = TaskApiService(client: mockClient);
        final tasks = await apiService.getTasks();

        expect(tasks, isEmpty);
      });

      test('handle respon bukan json', () async {
        final newTask = Task(title: 'Buggy Task', userId: 'u1');
        
        final mockClient = MockClient((request) async {
          return http.Response('<html>Error 500</html>', 500);
        });

        apiService = TaskApiService(client: mockClient);
        final result = await apiService.createTask(newTask);

        expect(result, isNull);
      });
      
      test('mengembalikkan false ketika serverId null', () async {
        final localTask = Task(title: 'Local Only', userId: 'u1');
        
        apiService = TaskApiService();
        final result = await apiService.updateTask(localTask);
        
        expect(result, false);
      });
    });
  });
}