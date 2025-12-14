import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:latihan_supabase/screens/login_screen.dart';
import 'package:latihan_supabase/providers/task_provider.dart';

// Generate Mock untuk TaskProvider
@GenerateNiceMocks([MockSpec<TaskProvider>()])
import 'login_screen_test.mocks.dart';

void main() {
  late MockTaskProvider mockTaskProvider;

  setUp(() {
    mockTaskProvider = MockTaskProvider();

    when(mockTaskProvider.isLoading).thenReturn(false);
    when(mockTaskProvider.errorMessage).thenReturn(null);
  });

  Widget createLoginScreen() {
    return ChangeNotifierProvider<TaskProvider>.value(
      value: mockTaskProvider,
      child: MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  group('LoginScreen UI Tests', () {
    testWidgets('pindah screen login dan register', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      expect(find.text('Login'), findsWidgets);
      expect(find.text('Belum punya akun? Register'), findsOneWidget);

      await tester.tap(find.text('Belum punya akun? Register'));
      await tester.pump();

      expect(find.widgetWithText(AppBar, 'Register'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Register'), findsOneWidget);
      expect(find.text('Sudah punya akun? Login'), findsOneWidget);
    });

    testWidgets('validasi inputan kredensial', (tester) async {
      await tester.pumpWidget(createLoginScreen());
      final loginButton = find.widgetWithText(ElevatedButton, 'Login');

      await tester.tap(loginButton);
      await tester.pump();

      expect(find.text('Email harus diisi'), findsOneWidget);
      expect(find.text('Password harus diisi'), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'invalid-email');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), '123');
      await tester.tap(loginButton);
      await tester.pump();

      expect(find.text('Email tidak valid'), findsOneWidget);
      expect(find.text('Password minimal 6 karakter'), findsOneWidget);

      verifyNever(mockTaskProvider.login(any, any));
    });

    testWidgets('memunculkan indikator loading',(tester) async {
      when(mockTaskProvider.isLoading).thenReturn(true);

      await tester.pumpWidget(createLoginScreen());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('login benar', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      when(mockTaskProvider.login(any, any)).thenAnswer((_) async => true);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'test@test.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      verify(mockTaskProvider.login('test@test.com', 'password123')).called(1);
    });

    testWidgets('tes pengguna baru', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      await tester.tap(find.text('Belum punya akun? Register'));
      await tester.pump();

      when(mockTaskProvider.register(any, any)).thenAnswer((_) async => true);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'new@test.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));

      verify(mockTaskProvider.register('new@test.com', 'password123'))
          .called(1);
    });

    testWidgets('pesan error', (tester) async {
      await tester.pumpWidget(createLoginScreen());

      when(mockTaskProvider.login(any, any)).thenAnswer((_) async => false);
      when(mockTaskProvider.errorMessage)
          .thenReturn('Email salah atau tidak terdaftar');

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'wrong@test.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');

      await tester.tap(find.byType(ElevatedButton));

      await tester.pump();
      await tester.pump(
          const Duration(milliseconds: 100));

      expect(find.text('Email salah atau tidak terdaftar'), findsOneWidget);
    });
  });
}
