import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Equipment checkout date validation', () {
    test('Future due date is valid', () {
      final checkout = DateTime(2026, 11, 17);
      final due = DateTime(2026, 11, 24);

      expect(due.isAfter(checkout), isTrue);
    });

    test('Past due date is invalid', () {
      final checkout = DateTime(2026, 11, 17);
      final due = DateTime(2026, 11, 16);

      expect(due.isBefore(checkout), isTrue);
    });
  });
}