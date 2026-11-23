import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_pageview/infinite_pageview.dart';

// Pixel 9 Pro: 1280x2856 @ dpr 3.0
const _portrait = Size(1280, 2856);
const _landscape = Size(2856, 1280);

void main() {
  group('resize keeps current page', () {
    for (final page in [-3, -2, -1, 0, 1, 2, 3]) {
      testWidgets('page $page', (tester) async {
        final controller = await _setUp(tester, page);
        for (final size in [_landscape, _portrait, _landscape, _portrait]) {
          await _resize(tester, size);
          expect(_visiblePages(tester), [page],
              reason: 'after resize to $size');
          expect(controller.offset / controller.position.viewportDimension,
              page.toDouble());
        }
      });
    }
  });

  // nc-photos 94.2 jumps back to the page in a post-frame callback after a
  // resize. The negative viewport must follow it.
  group('resize with post-frame jumpToPage', () {
    for (final page in [-3, -2, -1, 1, 2, 3]) {
      testWidgets('page $page', (tester) async {
        final controller = await _setUp(tester, page);
        for (final size in [_landscape, _portrait, _landscape, _portrait]) {
          tester.view.physicalSize = size;
          await tester.pump();
          controller.jumpToPage(page);
          await tester.pumpAndSettle();
          expect(_visiblePages(tester), [page],
              reason: 'after resize to $size');
        }
      });
    }
  });

  testWidgets('resize while settling after a fling ends on a page',
      (tester) async {
    final controller = await _setUp(tester, 0);
    await tester.fling(
        find.byType(InfinitePageView), const Offset(300, 0), 1000);
    await tester.pump(const Duration(milliseconds: 50));
    await _resize(tester, _landscape);
    final pages = _visiblePages(tester);
    expect(pages.length, 1);
    expect(controller.offset / controller.position.viewportDimension,
        pages.single.toDouble());
  });
}

Future<InfiniteScrollController> _setUp(WidgetTester tester, int page) async {
  tester.view.physicalSize = _portrait;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final controller = InfiniteScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: InfinitePageView(
      controller: controller,
      itemBuilder: (context, i) => ColoredBox(
        color: const Color(0xFF000000),
        child: Center(child: Text('$i')),
      ),
    ),
  ));
  // swipe to the target page like a user would
  final dx = page > 0 ? -300.0 : 300.0;
  for (var i = 0; i < page.abs(); ++i) {
    await tester.fling(find.byType(InfinitePageView), Offset(dx, 0), 1000);
    await tester.pumpAndSettle();
  }
  expect(_visiblePages(tester), [page]);
  return controller;
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

/// Pages covering more than half of the screen
List<int> _visiblePages(WidgetTester tester) {
  final screen =
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  return find
      .byType(Text)
      .evaluate()
      .where((e) {
        final box = e.findAncestorRenderObjectOfType<RenderBox>()!;
        // the page box is the ColoredBox around the text
        final page = e.findAncestorWidgetOfExactType<ColoredBox>();
        if (page == null) return false;
        final r = box.localToGlobal(Offset.zero) & box.size;
        final visible = r.intersect(screen);
        return visible.width > 0 &&
            visible.height > 0 &&
            visible.width * visible.height >
                box.size.width * box.size.height / 2;
      })
      .map((e) => int.parse((e.widget as Text).data!))
      .toList();
}
