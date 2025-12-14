import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:latihan_supabase/providers/task_provider.dart';
import 'package:latihan_supabase/screens/login_screen.dart';
import 'package:latihan_supabase/screens/task_list_screen.dart';
import 'package:latihan_supabase/models/task.dart';
import '../providers/task_provider_test.mocks.dart';

void main() {
  late MockTaskApiService mockApiService;
  late MockTaskLocalDb mockLocalDb;
  late TaskProvider taskProvider;

  Widget createMainApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskProvider>.value(value: taskProvider),
      ],
      child: MaterialApp(
        home: Consumer<TaskProvider>(
          builder: (context, provider, _) {
            // Logika routing sederhana berdasarkan status auth
            return provider.isAuthenticated ? TaskListScreen() : LoginScreen();
          },
        ),
      ),
    );
  }

  setUp(() {
    mockApiService = MockTaskApiService();
    mockLocalDb = MockTaskLocalDb();
    
    taskProvider = TaskProvider(mockApiService, mockLocalDb);
  });

  group('Integration Tests: Complete User Flows', () {
    
    testWidgets('user bisa login, menambahkan task dan logout', (tester) async {
      when(mockApiService.loadSession()).thenAnswer((_) async => null);

      when(mockApiService.login(any, any)).thenAnswer((_) async => {
        'access_token': 'token',
        'user': {'id': 'user_1', 'email': 'test@test.com'}
      });
      
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []); 
      when(mockApiService.getTasks()).thenAnswer((_) async => []); 

      await taskProvider.checkSession();
      await tester.pumpWidget(createMainApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'test@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle(); 

      expect(find.text('My Tasks (0)'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Add Task'), findsOneWidget);

      final newTask = Task(title: 'New Integration Task', userId: 'user_1');
      final savedTask = newTask.copyWith(localId: 1, serverId: 100, isSynced: true);

      when(mockLocalDb.insertTask(any)).thenAnswer((_) async => 1);
      when(mockApiService.createTask(any)).thenAnswer((_) async => savedTask);
      when(mockLocalDb.updateTask(any)).thenAnswer((_) async => 1);

      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => [savedTask]);
      when(mockApiService.getTasks()).thenAnswer((_) async => [savedTask]);

      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'New Integration Task');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
      await tester.pumpAndSettle(); 

      // Assert: Kembali ke TaskList dan data muncul
      expect(find.text('New Integration Task'), findsOneWidget);
      expect(find.text('My Tasks (1)'), findsOneWidget);

      // --- LOGOUT FLOW ---
      // 5. Logout
      final appBarMenu = find.descendant(
        of: find.byType(AppBar), 
        matching: find.byIcon(Icons.more_vert)
      );
      await tester.tap(appBarMenu);
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();

      // --- PERBAIKAN DI SINI ---
      // Gunakan widgetWithText(AppBar, ...) agar spesifik mencari Judul Halaman
      // Kalau pakai find.text('Login') saja, dia bingung antara Judul vs Tombol
      expect(find.widgetWithText(AppBar, 'Login'), findsOneWidget);
      
      verify(mockApiService.logout()).called(1);
    });

    testWidgets('buat task ketika offline dan mengambil task dari API', (tester) async {
      when(mockApiService.login(any, any)).thenAnswer((_) async => {
        'access_token': 'token', 'user': {'id': 'u1', 'email': 't@t.com'}
      });
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);
      
      await tester.pumpWidget(createMainApp());
      when(mockApiService.loadSession()).thenAnswer((_) async => null);
      await taskProvider.login('t@t.com', 'pass');
      await tester.pumpAndSettle();

      final offlineTask = Task(
        localId: 1, 
        title: 'Offline Task', 
        userId: 'u1', 
      );

      when(mockLocalDb.insertTask(any)).thenAnswer((_) async => 1);
      
      when(mockApiService.createTask(any)).thenAnswer((_) async => null);

      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => [offlineTask]);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Offline Task');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
      await tester.pumpAndSettle();

      expect(find.text('Offline Task'), findsOneWidget);
      
      expect(find.byIcon(Icons.offline_bolt), findsOneWidget);
      expect(find.text('1 task belum tersinkron'), findsOneWidget);

      final syncedTask = offlineTask.copyWith(
        serverId: 50, 
        isSynced: true
      );
      
      when(mockApiService.getTasks()).thenAnswer((_) async => [syncedTask]);
      when(mockLocalDb.replaceAllTasks(any)).thenAnswer((_) async => {});
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => [syncedTask]);

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.offline_bolt), findsNothing);
      expect(find.text('Semua data tersinkron'), findsOneWidget);
    });

    testWidgets('kesalahan login dan melakukan login kembali', (tester) async {
      when(mockApiService.loadSession()).thenAnswer((_) async => null);
      
      when(mockApiService.login(any, any)).thenAnswer((_) async => null);

      await taskProvider.checkSession();

      await tester.pumpWidget(createMainApp());
      await tester.pumpAndSettle(); 
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'wrong@test.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrongpass');
      
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Login gagal. Periksa email dan password.'), findsOneWidget);
      expect(find.text('My Tasks'), findsNothing);

      when(mockApiService.login(any, any)).thenAnswer((_) async => {
        'access_token': 'token', 'user': {'id': 'u1', 'email': 'correct@test.com'}
      });
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => []);
      when(mockApiService.getTasks()).thenAnswer((_) async => []);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle(); // Tunggu transisi halaman

      expect(find.text('My Tasks (0)'), findsOneWidget);
    });

    testWidgets('menampilkan data banyak secara halus', (tester) async {
      final manyTasks = List.generate(50, (index) => Task(
        localId: index,
        serverId: index,
        title: 'Performance Task #$index',
        userId: 'u1',
        isSynced: true
      ));

      when(mockApiService.login(any, any)).thenAnswer((_) async => {
        'access_token': 'token', 'user': {'id': 'u1', 'email': 't@t.com'}
      });
      when(mockLocalDb.getAllTasks()).thenAnswer((_) async => manyTasks);
      when(mockApiService.getTasks()).thenAnswer((_) async => manyTasks);

      await tester.pumpWidget(createMainApp());
      await taskProvider.login('t@t.com', 'pass');
      await tester.pumpAndSettle();

      expect(find.text('My Tasks (50)'), findsOneWidget);
      
      expect(find.text('Performance Task #0'), findsOneWidget);

      await tester.fling(find.byType(ListView), const Offset(0, -500), 1000);
      await tester.pumpAndSettle();

      expect(find.byType(TaskCard), findsWidgets);
    });
  });
}