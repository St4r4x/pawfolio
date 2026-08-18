import 'package:flutter_test/flutter_test.dart';
import 'package:pawfolio/reminders.dart';
import 'package:pawfolio/theme.dart';

void main() {
  final now = DateTime(2024, 6, 15);

  test('filters out due dates strictly before today', () {
    final items = [
      DueItem(petId: 'p1', petName: 'Rex', label: 'Rage', dueDate: DateTime(2024, 6, 14)),
      DueItem(petId: 'p1', petName: 'Rex', label: 'Vermifuge', dueDate: DateTime(2024, 6, 15)),
    ];
    final result = sortUpcoming(items, now: now);
    expect(result.map((item) => item.label), ['Vermifuge']);
  });

  test('sorts remaining items by due date ascending', () {
    final items = [
      DueItem(petId: 'p1', petName: 'Rex', label: 'B', dueDate: DateTime(2024, 7, 1)),
      DueItem(petId: 'p1', petName: 'Rex', label: 'A', dueDate: DateTime(2024, 6, 20)),
    ];
    final result = sortUpcoming(items, now: now);
    expect(result.map((item) => item.label), ['A', 'B']);
  });

  test('reminderUrgency classifies a due-today item', () {
    expect(reminderUrgency(DateTime(2024, 6, 15), now: now), ReminderUrgency.today);
  });

  test('reminderUrgency classifies an item due within 7 days as soon', () {
    expect(reminderUrgency(DateTime(2024, 6, 20), now: now), ReminderUrgency.soon);
  });

  test('reminderUrgency classifies an item due after 7 days as later', () {
    expect(reminderUrgency(DateTime(2024, 6, 25), now: now), ReminderUrgency.later);
  });

  test('urgencyColor maps each urgency to its token', () {
    expect(urgencyColor(ReminderUrgency.today), AppColors.error);
    expect(urgencyColor(ReminderUrgency.soon), AppColors.warningDueSoon);
    expect(urgencyColor(ReminderUrgency.later), AppColors.muted);
  });
}
