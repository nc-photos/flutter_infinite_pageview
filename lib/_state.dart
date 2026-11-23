part of 'infinite_pageview.dart';

const _hiddenTolerance = 0.01;

class _InfinitePageViewState extends State<InfinitePageView> {
  double _lastReportedPage = 0;

  late InfiniteScrollController _controller;

  /// Whether page 0 is completely out of view on the negative side
  final _isFirstPageHidden = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void dispose() {
    _controller.removeListener(_updateFirstPageHidden);
    if (widget.controller == null) {
      _controller.dispose();
    }
    _isFirstPageHidden.dispose();
    super.dispose();
  }

  void _initController() {
    _controller = widget.controller ?? InfiniteScrollController();
    _controller.addListener(_updateFirstPageHidden);
  }

  @override
  void didUpdateWidget(InfinitePageView oldWidget) {
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_updateFirstPageHidden);
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _initController();
    }
    super.didUpdateWidget(oldWidget);
  }

  /// The positive viewport always lays out its first child, even when it is
  /// scrolled to a negative offset. Hide page 0 then, otherwise it stays alive
  /// off screen (e.g. a video keeps playing).
  void _updateFirstPageHidden() {
    if (!_controller.hasClients) {
      return;
    }
    final position = _controller.position;
    if (!position.hasPixels || !position.hasViewportDimension) {
      return;
    }
    final viewport = position.viewportDimension;
    final leadingPadding = widget.padEnds
        ? viewport * (1 - _controller.viewportFraction) / 2
        : 0.0;
    _isFirstPageHidden.value =
        position.pixels + viewport <= leadingPadding + _hiddenTolerance;
  }

  AxisDirection _getDirection(BuildContext context) {
    switch (widget.scrollDirection) {
      case Axis.horizontal:
        assert(debugCheckHasDirectionality(context));
        final TextDirection textDirection = Directionality.of(context);
        final AxisDirection axisDirection =
            textDirectionToAxisDirection(textDirection);
        return axisDirection;

      case Axis.vertical:
        return AxisDirection.down;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (widget.onPageChanged != null &&
            notification is ScrollUpdateNotification) {
          final m = notification.metrics;

          final page =
              clampDouble(m.pixels, m.minScrollExtent, m.maxScrollExtent) /
                  math.max(1.0, m.viewportDimension * widget.viewportFraction);

          if (page != _lastReportedPage) {
            widget.onPageChanged?.call(page);
            _lastReportedPage = page;
          }
        }

        return false;
      },
      child: _buildScrollable(),
    );
  }

  Scrollable _buildScrollable() {
    final List<Widget> slivers = _buildSlivers(context, negative: false);
    final List<Widget> negativeSlivers = _buildSlivers(context, negative: true);
    final AxisDirection axisDirection = _getDirection(context);
    final ScrollPhysics physics = _ForceImplicitScrollPhysics(
      allowImplicitScrolling: widget.allowImplicitScrolling,
    ).applyTo(
      widget.pageSnapping
          ? _kPagePhysics.applyTo(widget.physics ??
              widget.scrollBehavior?.getScrollPhysics(context))
          : widget.physics ?? widget.scrollBehavior?.getScrollPhysics(context),
    );

    return Scrollable(
      dragStartBehavior: widget.dragStartBehavior,
      axisDirection: axisDirection,
      controller: _controller,
      physics: physics,
      restorationId: widget.restorationId,
      scrollBehavior: widget.scrollBehavior ??
          ScrollConfiguration.of(context).copyWith(scrollbars: false),
      viewportBuilder: (BuildContext context, ViewportOffset offset) {
        return Builder(
          builder: (context) {
            /// Build negative [ScrollPosition] for the negative scrolling [Viewport].
            final state = Scrollable.of(context);
            final negativeOffset = _InfiniteScrollPosition(
              physics: physics,
              context: state,
              initialPixels: -offset.pixels,
              keepScrollOffset: _controller.keepScrollOffset,
              negativeScroll: true,
            );

            offset.addListener(() {
              negativeOffset._forceNegativePixels(offset.pixels);
            });

            return Stack(
              children: <Widget>[
                Viewport(
                  // TODO(dnfield): we should provide a way to set cacheExtent
                  // independent of implicit scrolling:
                  // https://github.com/flutter/flutter/issues/45632
                  cacheExtent: widget.allowImplicitScrolling ? 1.0 : 0.0,
                  cacheExtentStyle: CacheExtentStyle.viewport,
                  axisDirection: flipAxisDirection(axisDirection),
                  offset: negativeOffset,
                  clipBehavior: widget.clipBehavior,
                  slivers: negativeSlivers,
                ),
                Viewport(
                  // TODO(dnfield): we should provide a way to set cacheExtent
                  // independent of implicit scrolling:
                  // https://github.com/flutter/flutter/issues/45632
                  cacheExtent: widget.allowImplicitScrolling ? 1.0 : 0.0,
                  cacheExtentStyle: CacheExtentStyle.viewport,
                  axisDirection: axisDirection,
                  offset: offset,
                  clipBehavior: widget.clipBehavior,
                  slivers: slivers,
                )
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _buildSlivers(BuildContext context, {bool negative = false}) =>
      <Widget>[
        SliverFillViewport(
          viewportFraction: _controller.viewportFraction,
          delegate:
              negative ? negativeChildrenDelegate : positiveChildrenDelegate,
          padEnds: widget.padEnds,
        ),
      ];

  SliverChildDelegate get negativeChildrenDelegate {
    final itemCount = widget.itemCount;

    return SliverChildBuilderDelegate(
      (context, index) => index != 0
          ? widget.itemBuilder(context, -index)
          : const SizedBox.shrink(),
      childCount: itemCount != null ? math.max(0, itemCount * 2 - 1) : null,
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
    );
  }

  SliverChildDelegate get positiveChildrenDelegate {
    return SliverChildBuilderDelegate(
      (context, index) => index != 0
          ? widget.itemBuilder(context, index)
          : ValueListenableBuilder<bool>(
              valueListenable: _isFirstPageHidden,
              builder: (context, isHidden, _) => isHidden
                  ? const SizedBox.shrink()
                  : widget.itemBuilder(context, 0),
            ),
      childCount: widget.itemCount,
      addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
      addRepaintBoundaries: widget.addRepaintBoundaries,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description
        .add(EnumProperty<Axis>('scrollDirection', widget.scrollDirection));
    description.add(DiagnosticsProperty<InfiniteScrollController>(
        'controller', _controller,
        showName: false));
    description.add(DiagnosticsProperty<ScrollPhysics>(
        'physics', widget.physics,
        showName: false));
    description.add(FlagProperty('pageSnapping',
        value: widget.pageSnapping, ifFalse: 'snapping disabled'));
    description.add(FlagProperty('allowImplicitScrolling',
        value: widget.allowImplicitScrolling,
        ifTrue: 'allow implicit scrolling'));
  }
}
