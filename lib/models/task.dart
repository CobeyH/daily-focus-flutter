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
}
