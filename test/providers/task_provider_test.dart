import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:latihan_supabase/providers/task_provider.dart';
import 'package:latihan_supabase/api/task_api.dart';
import 'package:latihan_supabase/local/task_local_db.dart';
import 'package:latihan_supabase/models/task.dart';

@GenerateNiceMocks([MockSpec<TaskApiService>(), MockSpec<TaskLocalDb>()])
import 'task_provider_test.mocks.dart';

void main() {
  late TaskProvider provider;
  late MockTaskApiService mockApiService;
  late MockTaskLocalDb mockLocalDb;

  final tUser = {'email': 'test@gmail.com', 'id': 'user_123'};
  final tTask = Task(
    localId: 1,
    title: 'Test Task',
    userId: 'user_123',
    completed: false,
    isSynced: false,
  );

  setUp(() {
    mockApiService = MockTaskApiService();
    mockLocalDb = MockTaskLocalDb();
    provider = TaskProvider(mockApiService, mockLocalDb);
  });

  group('TaskProvider - Authentication', () {
    test('Initial state is correct', () {
      expect(provider.isAuthenticated, false);
      expect(provider.tasks, isEmpty);
      expect(provider.isAuthLoading, true);
    });

    test('load data ketika session ada', () async {
      when(mockApiService.loadSession()).thenAnswer((_) async => {
            'email': 'test@test.com',
            'userId': 'user_123',
            'token': 'abc',
          });
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);

      await provider.checkSession();

      expect(provider.isAuthenticated, true);
      expect(provider.email, 'test@test.com');
      expect(provider.userId, 'user_123');
      expect(provider.isAuthLoading, false);
      verify(mockLocalDb.getAllTasks()).called(greaterThan(0));
    });

    test('update state dan load data', () async {
      when(mockApiService.login(any, any)).thenAnswer((_) async => {
            'access_token': 'token',
            'user': tUser,
          });
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);

      final result = await provider.login('email', 'pass');

      expect(result, true);
      expect(provider.isAuthenticated, true);
      expect(provider.errorMessage, isNull);
    });

    test('login salah', () async {
      when(mockApiService.login(any, any)).thenAnswer((_) async => null);

      final result = await provider.login('email', 'wrong_pass');

      expect(result, false);
      expect(provider.isAuthenticated, false);
      expect(provider.errorMessage, contains('Login gagal'));
    });

    test('logout mengosongkan state dan database lokal', () async {
      await provider.logout();

      expect(provider.isAuthenticated, false);
      expect(provider.userId, isNull);
      expect(provider.tasks, isEmpty);
      verify(mockApiService.logout()).called(1);
      verify(mockLocalDb.clearAll()).called(1);
    });
  });

  group('TaskProvider - Task Management (CRUD)', () {
    setUp(() async {
      when(mockApiService.login(any, any)).thenAnswer((_) async => {
            'access_token': 'token',
            'user': tUser,
          });
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      
      await provider.login('test@test.com', 'pass');
    });

    test('baca lokal dan sinkron API ke lokal', () async {
      final remoteTask = Task(title: 'Remote', userId: 'user_123', serverId: 99);
      
      // Setup Mock API
      when(mockApiService.getTasks())
          .thenAnswer((_) async => [remoteTask]);
      
      // Setup Mock Local DB untuk replace
      when(mockLocalDb.replaceAllTasks(any))
          .thenAnswer((_) async => {});
      
      // Setup Mock Local DB getAllTasks dengan logika urutan
      // Hapus definisi 'when' yang berulang, cukup satu blok logika ini:
      var callCount = 0;
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async {
        callCount++;
        // Panggilan pertama (sebelum sync) kosong, panggilan kedua (setelah sync) ada isinya
        if (callCount > 1) return [remoteTask.copyWith(isSynced: true)];
        return [];
      });

      // --- SOLUSI UTAMA ---
      // Hapus riwayat panggilan yang terjadi akibat 'login' di 'setUp'
      clearInteractions(mockLocalDb); 
      clearInteractions(mockApiService); // Opsional, biar bersih juga

      // Act (Jalankan fungsi yang dites)
      await provider.loadTasksOfflineFirst();

      // Assert
      expect(provider.tasks.length, 1);
      expect(provider.tasks.first.isSynced, true);
      
      // Sekarang verifikasi akan sukses karena hitungan di-reset jadi 0 sebelum Act
      verify(mockLocalDb.replaceAllTasks(any)).called(1);
    });

    test('tambah tugas dan pembaruan antara lokal dan API', () async {
      final newTask = tTask.copyWith(title: 'New Task');
      final serverTask = tTask.copyWith(title: 'New Task', serverId: 100, isSynced: true);

      when(mockLocalDb.insertTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.createTask(any)).thenAnswer((_) async => serverTask);
      
      await provider.addTask('New Task', 'Desc');

      // Assert
      // 1. Cek apakah insert lokal dipanggil
      verify(mockLocalDb.insertTask(any)).called(1);
      
      // 2. Cek apakah create API dipanggil
      verify(mockApiService.createTask(any)).called(1);
      
      // 3. Cek apakah update lokal dipanggil (karena sync sukses)
      verify(mockLocalDb.updateTask(any)).called(1);

      expect(provider.tasks.length, 1);
      expect(provider.tasks.first.title, 'New Task');
      expect(provider.tasks.first.isSynced, true);
    });

    test('tambah data offline', () async {
      when(mockLocalDb.insertTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.createTask(any)).thenAnswer((_) async => null);

      await provider.addTask('Offline Task', 'Desc');

      verify(mockLocalDb.insertTask(any)).called(1);
      verify(mockApiService.createTask(any)).called(1);
      
      verifyNever(mockLocalDb.updateTask(any));

      expect(provider.tasks.length, 1);
      expect(provider.tasks.first.isSynced, false);
    });

    test('sinkron lokal dan API', () async {
      final existingTask = tTask.copyWith(localId: 1, serverId: 55, completed: false);
      
      when(mockLocalDb.insertTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.createTask(any)).thenAnswer((_) async => existingTask);
      await provider.addTask('Title', 'Desc'); 
      
      when(mockApiService.updateTask(any)).thenAnswer((_) async => true);
      
      final taskToToggle = provider.tasks.first;
      await provider.toggleTask(taskToToggle);

      // Assert
      expect(provider.tasks.first.completed, true);
      verify(mockApiService.updateTask(any)).called(1);
      verify(mockLocalDb.updateTask(any)).called(3);
    });

    test('deleteTask removes from local and server', () async {
      // Arrange: Populate list
      when(mockLocalDb.insertTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.createTask(any)).thenAnswer((_) async => tTask.copyWith(serverId: 10));
      await provider.addTask('Delete Me', 'Desc');

      final taskToDelete = provider.tasks.first;

      when(mockApiService.deleteTask(any)).thenAnswer((_) async => true);

      // Act
      await provider.deleteTask(taskToDelete);

      // Assert
      expect(provider.tasks, isEmpty);
      verify(mockLocalDb.deleteTask(taskToDelete.localId!)).called(1);
      verify(mockApiService.deleteTask(taskToDelete.serverId!)).called(1);
    });
  });
}