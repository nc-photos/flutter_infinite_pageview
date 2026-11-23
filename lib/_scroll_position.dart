part of 'infinite_pageview.dart';

class _InfiniteScrollPosition extends ScrollPositionWithSingleContext {
  _InfiniteScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
    this.negativeScroll = false,
    this.didChangeViewportDimension,
  });

  final bool negativeScroll;
  final void Function(double viewportDimension)? didChangeViewportDimension;

  /// Scroll offset in viewport units, kept while the viewport is 0 wide.
  double? _cachedPage;

  void _forceNegativePixels(double value) {
    super.forcePixels(-value);
  }

  @override
  void saveScrollOffset() {
    if (!negativeScroll) {
      super.saveScrollOffset();
    }
  }

  @override
  void restoreScrollOffset() {
    if (!negativeScroll) {
      super.restoreScrollOffset();
    }
  }

  @override
  void goBallistic(double velocity) {
    if (negativeScroll) {
      // The negative position only mirrors the positive one. A ballistic
      // activity of its own would move it to another page.
      goIdle();
      return;
    }
    super.goBallistic(velocity);
  }

  @override
  double get minScrollExtent => double.negativeInfinity;

  @override
  double get maxScrollExtent => double.infinity;

  @override
  bool applyViewportDimension(double viewportDimension) {
    final oldViewportDimension =
        hasViewportDimension ? this.viewportDimension : null;
    var result = super.applyViewportDimension(viewportDimension);
    if (oldViewportDimension != null &&
        oldViewportDimension != viewportDimension &&
        hasPixels) {
      // Keep the same page, like PageView does. Without this the old pixel
      // offset lands on another page in the new viewport.
      final page = oldViewportDimension == 0.0
          ? _cachedPage
          : pixels / oldViewportDimension;
      if (page != null) {
        _cachedPage = viewportDimension == 0.0 ? page : null;
        final newPixels = page * viewportDimension;
        if (newPixels != pixels) {
          correctPixels(newPixels);
          result = false;
        }
      }
    }
    didChangeViewportDimension?.call(viewportDimension);
    return result;
  }
}
