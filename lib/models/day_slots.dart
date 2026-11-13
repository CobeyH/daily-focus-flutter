enum DaySlot {
  morning('Morning'),
  afternoon('Afternoon'),
  evening('Evening');

  final String label;
  const DaySlot(this.label);
}

class DaySlots {
  final int morning, afternoon, evening;
  const DaySlots(
      {this.morning = 360, this.afternoon = 720, this.evening = 1080});
  bool get isValid =>
      morning >= 0 &&
      morning < afternoon &&
      afternoon < evening &&
      evening < 1440;
  int start(DaySlot slot) => switch (slot) {
        DaySlot.morning => morning,
        DaySlot.afternoon => afternoon,
        DaySlot.evening => evening
      };
  Map<String, dynamic> toJson() =>
      {'morning': morning, 'afternoon': afternoon, 'evening': evening};
  factory DaySlots.fromJson(Map<String, dynamic> json) {
    final value = DaySlots(
        morning: (json['morning'] as num?)?.toInt() ?? 360,
        afternoon: (json['afternoon'] as num?)?.toInt() ?? 720,
        evening: (json['evening'] as num?)?.toInt() ?? 1080);
    return value.isValid ? value : const DaySlots();
  }
}
