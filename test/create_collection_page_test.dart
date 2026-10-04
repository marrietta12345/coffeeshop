import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_based_coffee_shops_mobile_application/models/shop_collection.dart';
import 'package:local_based_coffee_shops_mobile_application/pages/create_collection_page.dart';

/// No collections started yet: all 8 categories unstarted.
final _noCollections = [for (final c in CollectionCategory.all) ShopCollection.empty(c)];

/// A stand-in "My Collections" screen with a + button that opens Create
/// Collection, recording what comes back.
class _Harness extends StatefulWidget {
  final CollectionSaver saver;
  final List<ShopCollection> collections;

  const _Harness({required this.saver, required this.collections});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String result = 'none';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('My Collections — result: $result'),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => CreateCollectionPage(allCollections: widget.collections, saver: widget.saver),
                ),
              );
              setState(() => result = '$saved');
            },
          ),
        ],
      ),
    );
  }
}

Future<List<CollectionDraft>> _pumpAndOpen(
  WidgetTester tester, {
  List<ShopCollection>? collections,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final saved = <CollectionDraft>[];
  await tester.pumpWidget(MaterialApp(
    home: _Harness(collections: collections ?? _noCollections, saver: (d) async => saved.add(d)),
  ));
  await tester.tap(find.byIcon(Icons.add_rounded));
  await tester.pumpAndSettle();
  return saved;
}

void main() {
  testWidgets('+ opens the Create Collection screen', (tester) async {
    await _pumpAndOpen(tester);
    expect(find.text('Create Collection'), findsWidgets); // header title + button
    expect(find.text('Collection name'), findsOneWidget);
    expect(find.text('Choose an icon'), findsOneWidget);
  });

  testWidgets('Back button returns to My Collections without saving', (tester) async {
    final saved = await _pumpAndOpen(tester);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('My Collections — result: null'), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('enter a name, choose an icon, and save', (tester) async {
    final saved = await _pumpAndOpen(tester);
    await tester.enterText(find.byType(TextFormField), 'Best Matcha');
    await tester.ensureVisible(find.byKey(const ValueKey('icon-leaf')));
    await tester.tap(find.byKey(const ValueKey('icon-leaf')));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Collection'));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.name, 'Best Matcha');
    expect(saved.single.iconKey, 'leaf');
    expect(saved.single.categoryId, isNull); // a custom collection
    // Back on My Collections, told it was saved.
    expect(find.text('My Collections — result: true'), findsOneWidget);
  });

  testWidgets('an empty name is rejected and nothing is saved', (tester) async {
    final saved = await _pumpAndOpen(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Collection'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a collection name'), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('a duplicate of an existing collection name is rejected', (tester) async {
    final saved = await _pumpAndOpen(tester, collections: [
      ..._noCollections,
      const ShopCollection(id: 'abc', name: 'Best Matcha', iconKey: 'leaf'),
    ]);
    await tester.enterText(find.byType(TextFormField), 'best matcha');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Collection'));
    await tester.pumpAndSettle();
    expect(find.text('You already have a collection with this name'), findsOneWidget);
    expect(saved, isEmpty);
  });

  testWidgets('picking a built-in suggestion starts that category', (tester) async {
    final saved = await _pumpAndOpen(tester);
    await tester.tap(find.text('Want to Visit'));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Collection'));
    await tester.pumpAndSettle();
    expect(saved.single.categoryId, 'want_to_visit');
  });
}
