import 'package:flutter/material.dart';

import '../api/task_api.dart';
import '../models/task.dart';

class TaskProvider extends ChangeNotifier {
  final TaskApiService _apiService;

  TaskProvider(this._apiService);

  // Auth state
  bool _isAuthenticated = false;
  bool _isAuthLoading = true;
  bool _isTaskLoading = false;
  String? _email;
  String? _userId;
  String? _errorMessage;

  // Task state
  List<Task> _tasks = [];

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isAuthLoading; // For backward compatibility
  bool get isAuthLoading => _isAuthLoading;
  bool get isTaskLoading => _isTaskLoading;
  String? get email => _email;
  String? get userId => _userId;
  String? get errorMessage => _errorMessage;
  List<Task> get tasks => _tasks;

  // Check saved session on app start
  Future<void> checkSession() async {
    _isAuthLoading = true;
    notifyListeners();

    final session = await _apiService.loadSession();
    if (session != null) {
      _isAuthenticated = true;
      _email = session['email'];
      _userId = session['userId'];
    }

    _isAuthLoading = false;
    notifyListeners();
  }

  // Login
  Future<bool> login(String email, String password) async {
    _errorMessage = null;
    _isAuthLoading = true;
    notifyListeners();

    final result = await _apiService.login(email, password);

    _isAuthLoading = false;

    if (result != null) {
      _isAuthenticated = true;
      _email = result['user']['email'];
      _userId = result['user']['id'];
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Login gagal. Periksa email dan password.';
      notifyListeners();
      return false;
    }
  }

  // Register
  Future<bool> register(String email, String password) async {
    _errorMessage = null;
    _isAuthLoading = true;
    notifyListeners();

    final result = await _apiService.register(email, password);

    _isAuthLoading = false;

    if (result != null) {
      _isAuthenticated = true;
      _email = result['user']['email'];
      _userId = result['user']['id'].toString();
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Registrasi gagal. Coba email lain.';
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _apiService.logout();
    _isAuthenticated = false;
    _email = null;
    _userId = null;
    _tasks = [];
    notifyListeners();
  }

  // === TASK OPERATIONS ===

  // Load all tasks
  Future<void> loadTasks() async {
    // Avoid multiple simultaneous loads
    if (_isTaskLoading && _tasks.isEmpty) return;

    _isTaskLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _tasks = await _apiService.getTasks();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Gagal memuat tasks';
    }

    _isTaskLoading = false;
    notifyListeners();
  }

  // Add new task
  Future<bool> addTask(String title, String description) async {
    if (_userId == null) return false;

    final task = Task(
      title: title,
      description: description,
      userId: _userId!,
    );

    final createdTask = await _apiService.createTask(task);

    if (createdTask != null) {
      _tasks.insert(0, createdTask);
      notifyListeners();
      return true;
    }

    _errorMessage = 'Gagal menambahkan task';
    notifyListeners();
    return false;
  }

  // Toggle task completion
  Future<bool> toggleTask(Task task) async {
    final updatedTask = Task(
      id: task.id,
      title: task.title,
      description: task.description,
      completed: !task.completed,
      userId: task.userId,
      createdAt: task.createdAt,
    );

    final success = await _apiService.updateTask(updatedTask);

    if (success) {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = updatedTask;
        notifyListeners();
      }
      return true;
    }

    _errorMessage = 'Gagal mengupdate task';
    notifyListeners();
    return false;
  }

  // Delete task
  Future<bool> deleteTask(int taskId) async {
    final success = await _apiService.deleteTask(taskId);

    if (success) {
      _tasks.removeWhere((task) => task.id == taskId);
      notifyListeners();
      return true;
    }

    _errorMessage = 'Gagal menghapus task';
    notifyListeners();
    return false;
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
