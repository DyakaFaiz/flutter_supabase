import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:latihan_supabase/screens/task_list_screen.dart';
import 'package:latihan_supabase/screens/add_task_screen.dart';
import 'package:latihan_supabase/providers/task_provider.dart';
import 'package:latihan_supabase/models/task.dart';

@GenerateNiceMocks([MockSpec<TaskProvider>()])
import 'task_screens_test.mocks.dart' as generated;

void main() {
  late generated.MockTaskProvider mockTaskProvider;

  // Data Dummy
  final tTask = Task(
    localId: 1,
    title: 'Test Task',
    description: 'Desc',
    userId: 'user1',
    completed: false,
    isSynced: true,
  );

  setUp(() {
    mockTaskProvider = generated.MockTaskProvider();
    
    // Default Stubs untuk mencegah Null Error
    when(mockTaskProvider.tasks).thenReturn([]);
    when(mockTaskProvider.isTaskLoading).thenReturn(false);
    when(mockTaskProvider.isSyncing).thenReturn(false);
    when(mockTaskProvider.unsyncedCount).thenReturn(0);
    when(mockTaskProvider.errorMessage).thenReturn(null);
  });

  Widget createWidgetUnderTest(Widget child) {
    return ChangeNotifierProvider<TaskProvider>.value(
      value: mockTaskProvider,
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('TaskListScreen Tests', () {
    testWidgets('task tidak tampil dengan benar', (tester) async {
      when(mockTaskProvider.tasks).thenReturn([]);

      await tester.pumpWidget(createWidgetUnderTest(TaskListScreen()));

      expect(find.text('Belum ada tasks'), findsOneWidget);
      expect(find.text('Tap + untuk menambah task pertama'), findsOneWidget);
      expect(find.byIcon(Icons.task_alt), findsOneWidget);
    });

    testWidgets('task tampil dengan benar', (tester) async {
      when(mockTaskProvider.isTaskLoading).thenReturn(true);
      when(mockTaskProvider.tasks).thenReturn([]);

      await tester.pumpWidget(createWidgetUnderTest(TaskListScreen()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Belum ada tasks'), findsNothing);
    });

    testWidgets('menampilkan teks karena tidak ada koneksi', (tester) async {
      when(mockTaskProvider.errorMessage).thenReturn('Gagal koneksi');
      when(mockTaskProvider.tasks).thenReturn([]);

      await tester.pumpWidget(createWidgetUnderTest(TaskListScreen()));

      expect(find.text('Gagal koneksi'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('menampilkan list dari task', (tester) async {
      when(mockTaskProvider.tasks).thenReturn([
        tTask,
        tTask.copyWith(localId: 2, title: 'Task 2'),
      ]);

      await tester.pumpWidget(createWidgetUnderTest(TaskListScreen()));

      expect(find.byType(TaskCard), findsNWidgets(2));
      expect(find.text('Test Task'), findsOneWidget);
      expect(find.text('Task 2'), findsOneWidget);
    });

    testWidgets('mengisi checkbox task sebagai completed', (tester) async {
      when(mockTaskProvider.tasks).thenReturn([tTask]);
      when(mockTaskProvider.toggleTask(any)).thenAnswer((_) async => true);

      await tester.pumpWidget(createWidgetUnderTest(TaskListScreen()));

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      verify(mockTaskProvider.toggleTask(tTask)).called(1);
    });

    testWidgets('menampilkan konfirmasi menghapus task dilanjutkan dengan menghapus', (tester) async {
      when(mockTaskProvider.tasks).thenReturn([tTask]);
      when(mockTaskProvider.deleteTask(any)).thenAnswer((_) async => true);

      await tester.pumpWidget(createWidgetUnderTest(TaskListScreen()));

      final taskCardFinder = find.byType(TaskCard);
      final menuButton = find.descendant(
        of: taskCardFinder,
        matching: find.byIcon(Icons.more_vert),
      );
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hapus').last);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Yakin ingin menghapus task ini?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Hapus'));
      await tester.pumpAndSettle();

      verify(mockTaskProvider.deleteTask(tTask)).called(1);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Task dihapus'), findsOneWidget);
    });
    
    testWidgets('mengarahkan ke halaman menambahkan task', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(TaskListScreen()));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Add Task'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });

  group('AddTaskScreen Tests', () {
    testWidgets('validasi ketika judul kosong', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(AddTaskScreen()));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
      await tester.pump();

      expect(find.text('Title harus diisi'), findsOneWidget);
      
      verifyNever(mockTaskProvider.addTask(any, any));
    });

    testWidgets('membuat task dengan benar dan berhasil', (tester) async {
      when(mockTaskProvider.addTask(any, any)).thenAnswer((_) async => true);
      when(mockTaskProvider.isLoading).thenReturn(false);

      await tester.pumpWidget(createWidgetUnderTest(AddTaskScreen()));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Title'), 'Belanja');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Description'), 'Susu dan Telur');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Add Task'));
      await tester.pump();

      verify(mockTaskProvider.addTask('Belanja', 'Susu dan Telur')).called(1);
    });

    testWidgets('menampilkan loading setelah menambahkan task', (tester) async {
       when(mockTaskProvider.isLoading).thenReturn(true);

       await tester.pumpWidget(createWidgetUnderTest(AddTaskScreen()));

       expect(find.byType(ElevatedButton), findsNothing);
       expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}