import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_pageview/infinite_pageview.dart';

void main() {
  // Page 0 lives in the positive viewport. Scrolled to page < 0 that viewport
  // still lays out its first child, so page 0 (e.g. a playing video) stayed
  // alive off screen.
  for (final page in [-1, -2, 1, 2]) {
    testWidgets('only the current page is alive on page $page', (tester) async {
      final alive = <int>{};
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: InfinitePageView(
          itemBuilder: (context, i) => _Probe(index: i, alive: alive),
        ),
      ));
      expect(alive, {0});

      final dx = page > 0 ? -300.0 : 300.0;
      for (var i = 0; i < page.abs(); ++i) {
        await tester.fling(find.byType(InfinitePageView), Offset(dx, 0), 1000);
        await tester.pumpAndSettle();
      }
      expect(alive, {page});

      // and page 0 comes back when scrolling back
      for (var i = 0; i < page.abs(); ++i) {
        await tester.fling(find.byType(InfinitePageView), Offset(-dx, 0), 1000);
        await tester.pumpAndSettle();
      }
      expect(alive, {0});
    });
  }

  testWidgets('page 0 is visible while dragging from page -1', (tester) async {
    final alive = <int>{};
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: InfinitePageView(
        itemBuilder: (context, i) => _Probe(index: i, alive: alive),
      ),
    ));
    await tester.fling(
        find.byType(InfinitePageView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(alive, {-1});

    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(InfinitePageView)));
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    expect(alive, {-1, 0});
    await gesture.up();
    await tester.pumpAndSettle();
    expect(alive, {-1});
  });
}

class _Probe extends StatefulWidget {
  const _Probe({required this.index, required this.alive});

  final int index;
  final Set<int> alive;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.alive.add(widget.index);
  }

  @override
  void dispose() {
    widget.alive.remove(widget.index);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
