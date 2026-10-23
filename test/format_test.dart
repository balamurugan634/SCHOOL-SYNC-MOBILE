import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/util/format.dart';
import 'package:schoolsync/features/notifications/notifications_providers.dart';

void main() {
  group('money', () {
    test('Indian digit grouping and paise', () {
      expect(formatMinor(1560000), '₹15,600');
      expect(formatMinor(12345678900), '₹12,34,56,789');
      expect(formatMinor(50), '₹0.50');
      expect(formatMinor(100050), '₹1,000.50');
      expect(formatMinor(0), '₹0');
      expect(formatMinor(-2500), '-₹25');
    });
    test('other currencies', () {
      expect(formatMinor(123456, currency: 'USD'), '\$1,234.56');
      expect(formatMinor(1000, currency: 'CHF'), 'CHF 10');
    });
  });

  group('dates and times', () {
    test('clock', () {
      expect(formatClock('08:30'), '8:30 am');
      expect(formatClock('12:05'), '12:05 pm');
      expect(formatClock('00:15'), '12:15 am');
      expect(formatClock('17:00'), '5:00 pm');
      expect(formatClock(null), '');
      expect(formatTimeRange('08:30', '09:15'), '8:30 am - 9:15 am');
    });

    test('relative day and due labels', () {
      final now = DateTime(2026, 10, 21, 10);
      expect(relativeDay(DateTime(2026, 10, 21), now), 'Today');
      expect(relativeDay(DateTime(2026, 10, 22), now), 'Tomorrow');
      expect(relativeDay(DateTime(2026, 10, 20), now), 'Yesterday');
      expect(dueLabel(DateTime(2026, 10, 24, 9), now), 'Due in 3 days');
      expect(dueLabel(DateTime(2026, 10, 22, 9), now), 'Due tomorrow');
      expect(dueLabel(DateTime(2026, 10, 19, 9), now), 'Overdue by 2 days');
      expect(dueLabel(DateTime(2026, 10, 20, 9), now), 'Overdue by 1 day');
      expect(dueLabel(DateTime(2026, 10, 21, 17), now), startsWith('Due today'));
    });

    test('plural and file size', () {
      expect(plural(1, 'day'), '1 day');
      expect(plural(3, 'day'), '3 days');
      expect(plural(2, 'child', 'children'), '2 children');
      expect(fileSize(512), '512 B');
      expect(fileSize(2048), '2 KB');
      expect(fileSize(3 * 1024 * 1024), '3.0 MB');
    });
  });

  group('server routes', () {
    test('known web routes map to app paths, anything else is ignored', () {
      expect(mapServerRoute('/homework/abc'), '/homework/abc');
      expect(mapServerRoute('/announcements/x?y=1'), '/announcements/x');
      expect(mapServerRoute('/tasks'), '/tab/1');
      expect(mapServerRoute('/fees/invoice/1'), '/fees/invoice/1');
      expect(mapServerRoute('/admin/secret'), isNull);
      expect(mapServerRoute('https://evil.example/homework'), isNull);
      expect(mapServerRoute(''), isNull);
      expect(mapServerRoute(null), isNull);
    });
  });
}
