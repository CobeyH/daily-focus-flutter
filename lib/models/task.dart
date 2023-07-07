class Task {
  String name;
  int goal;
  double progress;
  bool incremental;

  Task({
    required this.name,
    required this.goal,
    required this.progress,
    required this.incremental,
  });

  Task.empty()
      : name = "",
        goal = 0,
        progress = 0.0,
        incremental = false;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'goal': goal,
      'progress': progress,
      'incremental': incremental,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      name: json['name'],
      goal: json['goal'],
      progress: json['progress'],
      incremental: json['incremental'],
    );
  }
}
