import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/operating_hours.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/open_status.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/schedule_editor.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)));

void main() {
  group('status line', () {
    testWidgets('no hours → "Hours unavailable"', (tester) async {
      await tester.pumpWidget(_host(const OpenStatusLine(hours: OperatingHours())));
      expect(find.textContaining('Hours unavailable'), findsOneWidget);
      expect(find.textContaining('Open Now'), findsNothing);
      expect(find.textContaining('Closed Now'), findsNothing);
    });

    testWidgets('temporarily closed shows its note', (tester) async {
      final hours = OperatingHours(
        days: {for (var d = 1; d <= 7; d++) d: const DayHours(0, 0)},
        temporarilyClosed: true,
        closureNote: 'Back on Oct 20',
      );
      await tester.pumpWidget(_host(OpenStatusLine(hours: hours)));
      expect(find.textContaining('Temporarily Closed · Back on Oct 20'), findsOneWidget);
    });

    testWidgets('open 24 hours shows Open Now', (tester) async {
      final hours = OperatingHours(days: {for (var d = 1; d <= 7; d++) d: const DayHours(0, 0)});
      await tester.pumpWidget(_host(OpenStatusBadge(hours: hours)));
      expect(find.text('Open Now'), findsOneWidget);
    });
  });

  group('schedule editor', () {
    Future<OperatingHours> pumpEditor(WidgetTester tester, OperatingHours start) async {
      var value = start;
      await tester.pumpWidget(_host(StatefulBuilder(
        builder: (context, setState) => SingleChildScrollView(
          child: ScheduleEditor(value: value, onChanged: (h) => setState(() => value = h)),
        ),
      )));
      return value;
    }

    testWidgets('all seven days are listed; unset days read Closed', (tester) async {
      await pumpEditor(tester, const OperatingHours());
      for (final day in OperatingHours.shortDayNames.values) {
        expect(find.text(day), findsOneWidget);
      }
      expect(find.text('Closed'), findsNWidgets(7));
    });

    testWidgets('set days show their hours and the "every day" shortcut', (tester) async {
      await pumpEditor(tester, OperatingHours(days: {DateTime.monday: const DayHours(8 * 60, 21 * 60)}));
      expect(find.text('8:00 AM'), findsOneWidget);
      expect(find.text('9:00 PM'), findsOneWidget);
      expect(find.text('Use Mon hours for every day'), findsOneWidget);

      await tester.tap(find.text('Use Mon hours for every day'));
      await tester.pump();
      expect(find.text('8:00 AM'), findsNWidgets(7));
      expect(find.text('Use Mon hours for every day'), findsNothing); // already the same every day
    });

    testWidgets('switching a day off closes it', (tester) async {
      await pumpEditor(tester, OperatingHours(days: {DateTime.monday: const DayHours(8 * 60, 21 * 60)}));
      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      expect(find.text('Closed'), findsNWidgets(7));
    });

    testWidgets('switching a day on copies the last day set (no made-up hours)', (tester) async {
      await pumpEditor(tester, OperatingHours(days: {DateTime.monday: const DayHours(7 * 60, 19 * 60)}));
      await tester.tap(find.byType(Switch).at(1)); // Tuesday
      await tester.pump();
      expect(find.text('7:00 AM'), findsNWidgets(2));
    });
  });
}
