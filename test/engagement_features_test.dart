import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/tambay_check_service.dart';

void main() {
  final now = DateTime(2026, 11, 15, 15, 0);

  group('Tambay Check', () {
    TambayCheck check(String shop, TambayBusy busy, int minutesAgo, {bool? outlets, String? wifi}) => TambayCheck(
          shopId: shop,
          uid: 'u$minutesAgo',
          busy: busy,
          outlets: outlets,
          wifi: wifi,
          createdAt: now.subtract(Duration(minutes: minutesAgo)),
        );

    test('the newest report sets how busy it is; older answers fill the gaps', () {
      final summary = TambayCheckService.summarize([
        check('a', TambayBusy.packed, 40, outlets: true, wifi: 'fast'),
        check('a', TambayBusy.chill, 5),
      ], now)['a']!;
      expect(summary.busy, TambayBusy.chill);
      expect(summary.outlets, isTrue);
      expect(summary.wifi, 'fast');
      expect(summary.count, 2);
      expect(summary.headline, '🟢 Chill · Outlets free · Fast Wi-Fi');
      expect(summary.agoAt(now), '5 min ago');
    });

    test('reports older than 2 hours are not shown', () {
      final summaries = TambayCheckService.summarize([check('a', TambayBusy.chill, 121)], now);
      expect(summaries, isEmpty);
    });

    test('each café gets its own summary', () {
      final summaries = TambayCheckService.summarize([
        check('a', TambayBusy.chill, 1),
        check('b', TambayBusy.packed, 2, outlets: false),
      ], now);
      expect(summaries.keys, unorderedEquals(['a', 'b']));
      expect(summaries['b']!.headline, '🔴 Packed · No free outlets');
    });
  });
}
