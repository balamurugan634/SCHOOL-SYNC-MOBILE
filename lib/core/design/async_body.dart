import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/app_exception.dart';
import 'banners.dart';
import 'states.dart';
import 'tokens.dart';

/// Renders an [AsyncValue] with the app's loading / error / data states.
///
/// * first load: [loading] (a list skeleton by default)
/// * failure with nothing to show: a friendly [ErrorState] with Retry
/// * failure after data was shown: the last data stays on screen with a quiet "could not refresh" note
///   (so a dropped connection never blanks a screen)
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.data, this.onRetry, this.loading, this.isEmpty, this.empty});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) {
      final d = value.requireValue;
      if (isEmpty != null && isEmpty!(d) && empty != null) return empty!;
      final child = data(d);
      if (!value.hasError) return child;
      final offline = AppException.from(value.error!).isNetwork;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.sm),
            child: InfoBanner(
              tone: BannerTone.warning,
              icon: offline ? Icons.cloud_off_rounded : Icons.sync_problem_rounded,
              message: offline ? 'You are offline. Showing what was loaded last.' : 'Could not refresh. Showing what was loaded last.',
              action: onRetry == null ? null : 'Try again',
              onAction: onRetry,
            ),
          ),
          Expanded(child: child),
        ],
      );
    }
    if (value.hasError) return ErrorState(error: value.error!, onRetry: onRetry);
    return loading ?? const SingleChildScrollView(physics: NeverScrollableScrollPhysics(), child: Padding(padding: EdgeInsets.only(top: Gaps.sm), child: SkeletonList(count: 5)));
  }
}

/// A scroll view that supports pull-to-refresh and also works when the content is shorter than the screen.
class RefreshScroll extends StatelessWidget {
  const RefreshScroll({super.key, required this.onRefresh, required this.children, this.padding = const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.huge), this.controller});

  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(controller: controller, physics: const AlwaysScrollableScrollPhysics(), padding: padding, children: children),
  );
}
