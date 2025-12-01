import 'package:flutter/material.dart';
import 'package:latihan_supabase/providers/task_provider.dart';
import 'package:latihan_supabase/screens/login_screen.dart';
import 'package:latihan_supabase/screens/task_list_screen.dart';
import 'package:provider/provider.dart';

import 'api/task_api.dart';

void main() {
  // Initialize single API service
  final apiService = TaskApiService();

  runApp(
    ChangeNotifierProvider(
      create: (context) {
        final taskProvider = TaskProvider(apiService);
        taskProvider.checkSession(); // Check saved session
        return taskProvider;
      },
      child: MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REST API Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Selector<TaskProvider, bool>(
        selector: (context, provider) => provider.isAuthLoading,
        builder: (context, isAuthLoading, child) {
          return Consumer<TaskProvider>(
            builder: (context, taskProvider, child) {
              if (isAuthLoading) {
                return Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              return taskProvider.isAuthenticated
                  ? TaskListScreen()
                  : LoginScreen();
            },
          );
        },
      ),
    );
  }
}
