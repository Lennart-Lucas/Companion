import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/events/widgets/event_display.dart';

void main() {
  test('eventDateTimeRangeLabel includes times on the same day', () {
    final start = DateTime(2026, 7, 1, 9, 30);
    final end = DateTime(2026, 7, 1, 11, 0);

    expect(
      eventDateTimeRangeLabel(start, end),
      '2026-07-01 09:30 – 11:00',
    );
  });

  test('eventDateTimeRangeLabel includes full datetimes across days', () {
    final start = DateTime(2026, 7, 1, 22, 0);
    final end = DateTime(2026, 7, 2, 1, 15);

    expect(
      eventDateTimeRangeLabel(start, end),
      '2026-07-01 22:00 – 2026-07-02 01:15',
    );
  });

  test('eventSubtitle formats start-only events with time', () {
    final event = Event(
      id: '1',
      name: 'Standup',
      startAt: DateTime(2026, 7, 1, 8, 0),
    );

    expect(eventSubtitle(event), '2026-07-01 08:00');
  });
}
