class Task {
  final int? id;
  final String title;
  final String description;
  final bool completed;
  final String userId;
  final DateTime? createdAt;

  Task({
    this.id,
    required this.title,
    this.description = '',
    this.completed = false,
    required this.userId,
    this.createdAt,
  });

  // Convert to JSON untuk API requests
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'completed': completed,
      'user_id': userId,
    };
  }

  // Create from JSON untuk API responses
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      completed: json['completed'] ?? false,
      userId: json['user_id'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}