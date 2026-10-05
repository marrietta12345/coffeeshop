import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/menu_item.dart';
import 'package:local_based_coffee_shops_mobile_application/models/review.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/coffee_review_form_page.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/coffee_review_service.dart';
import 'package:local_based_coffee_shops_mobile_application/utils/review_insights.dart';
import 'package:local_based_coffee_shops_mobile_application/widgets/coffee_review_widgets.dart';

const latte = MenuItem(id: 'latte1', shopId: 'shop1', name: 'Spanish Latte', description: '', price: 150, category: 'Spanish Latte');

Review coffeeReview(double rating, {String coffeeId = 'latte1', String text = '', int daysAgo = 0, String user = 'u1', String? photo}) => Review(
      id: CoffeeReviewService.reviewId(coffeeId, user),
      shopId: 'shop1',
      userId: user,
      userName: 'Maria',
      rating: rating,
      timeAgo: '',
      text: text,
      photoUrl: photo,
      createdAt: DateTime(2026, 10, 5).subtract(Duration(days: daysAgo)),
      coffeeId: coffeeId,
      coffeeName: 'Spanish Latte',
    );

void main() {
  group('Coffee reviews', () {
    test('one review per customer per coffee — same id when posting again', () {
      expect(CoffeeReviewService.reviewId('latte1', 'u1'), 'latte1_u1');
      expect(CoffeeReviewService.reviewId('latte1', 'u1'), CoffeeReviewService.reviewId('latte1', 'u1'));
      // A different coffee or customer is a different review.
      expect(CoffeeReviewService.reviewId('americano', 'u1'), isNot('latte1_u1'));
      expect(CoffeeReviewService.reviewId('latte1', 'u2'), isNot('latte1_u1'));
    });

    test('rating is the average of the real reviews; none → no rating', () {
      expect(CoffeeRatingLine.average([coffeeReview(5, user: 'a'), coffeeReview(4, user: 'b'), coffeeReview(5, user: 'c')]), closeTo(4.67, 0.01));
      expect(CoffeeRatingLine.average(const []), 0);
    });

    test('newest first', () {
      final sorted = CoffeeReviewService.newestFirst([
        coffeeReview(3, daysAgo: 5, user: 'a'),
        coffeeReview(5, daysAgo: 1, user: 'b'),
        coffeeReview(4, daysAgo: 3, user: 'c'),
      ]);
      expect(sorted.map((r) => r.userId), ['b', 'c', 'a']);
    });

    test('sorting and summary work the same as café reviews', () {
      final reviews = [coffeeReview(2, user: 'a'), coffeeReview(5, user: 'b', photo: 'https://x/p.jpg')];
      expect(ReviewInsights.sorted(reviews, ReviewSort.highest).first.rating, 5);
      expect(ReviewInsights.sorted(reviews, ReviewSort.withPhotos).length, 1);
      expect(ReviewInsights.summarize(reviews).total, 2);
    });

    test('the comment is optional', () {
      expect(coffeeReview(5).hasText, isFalse);
      expect(coffeeReview(5, text: 'Creamy!').hasText, isTrue);
    });
  });

  group('Coffee review form', () {
    Future<void> pump(WidgetTester tester, {Review? existing}) async {
      tester.view.physicalSize = const Size(1080, 3600);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: CoffeeReviewFormPage(coffee: latte, existing: existing)));
    }

    testWidgets('new review: stars, optional comment and photo, Post Review', (tester) async {
      await pump(tester);
      expect(find.text('Write a Review'), findsOneWidget);
      expect(find.text('Spanish Latte'), findsOneWidget);
      expect(find.text('Coffee Review'), findsOneWidget);
      expect(find.text('Share your thoughts about this coffee...'), findsOneWidget);
      expect(find.text('Add a photo of your coffee (optional)'), findsOneWidget);
      expect(find.text('Post Review'), findsOneWidget);
      expect(find.text('Delete Review'), findsNothing);
      // No purchase claims anywhere.
      expect(find.textContaining('Verified'), findsNothing);

      await tester.tap(find.byIcon(Icons.star_rounded).at(2)); // 3 stars
      await tester.pump();
      expect(find.text('Good'), findsOneWidget);
    });

    testWidgets('editing loads the review and offers Update and Delete', (tester) async {
      await pump(tester, existing: coffeeReview(4, text: 'Creamy and not too sweet!'));
      expect(find.text('Edit Review'), findsOneWidget);
      expect(find.text('Creamy and not too sweet!'), findsOneWidget);
      expect(find.text('Great'), findsOneWidget); // 4 stars
      expect(find.text('Update Review'), findsOneWidget);
      expect(find.text('Delete Review'), findsOneWidget);
    });
  });

  group('Owner replies are signed by the café', () {
    test('label uses the café name, with a safe fallback', () {
      expect(ownerReplyLabel('Local Brew Café'), 'Local Brew Café · Owner');
      expect(ownerReplyLabel('  Bean House '), 'Bean House · Owner');
      expect(ownerReplyLabel(null), 'Coffee Shop · Owner');
      expect(ownerReplyLabel(''), 'Coffee Shop · Owner');
    });

    testWidgets('a reply shows under the review as "<Café> · Owner"', (tester) async {
      const review = Review(
        userName: 'Maria',
        rating: 5,
        timeAgo: '2 days ago',
        text: 'Creamy and not too sweet!',
        ownerReply: 'Thank you for trying our Spanish Latte!',
        ownerReplyBy: 'owner-uid-123',
      );
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: CoffeeReviewTile(review: review, shopName: 'Local Brew Café')),
      ));
      expect(find.text('Maria'), findsOneWidget); // the customer's name is unchanged
      expect(find.text('Local Brew Café · Owner'), findsOneWidget);
      expect(find.text('Thank you for trying our Spanish Latte!'), findsOneWidget);
      expect(find.textContaining('owner-uid'), findsNothing); // never shown
    });
  });
}
