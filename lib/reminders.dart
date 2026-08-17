class DueItem {
  const DueItem({
    required this.petId,
    required this.petName,
    required this.label,
    required this.dueDate,
  });

  final String petId;
  final String petName;
  final String label;
  final DateTime dueDate;
}

List<DueItem> sortUpcoming(List<DueItem> items, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);
  final upcoming = items.where((item) => !item.dueDate.isBefore(startOfToday)).toList();
  upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return upcoming;
}
