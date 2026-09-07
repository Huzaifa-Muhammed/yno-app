import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// App-wide responsive shell.
///
/// * Fills the device on phones (full width).
/// * On wide screens (tablets / web) the content is centred and capped so the
///   mobile layout never stretches awkwardly.
/// * Optionally renders a native Material [AppBar] (with its built-in back
///   button) when [appBarTitle] / [appBarActions] / [appBarLeading] are given.
class YnoScaffold extends StatelessWidget {
  const YnoScaffold({
    super.key,
    required this.child,
    this.bottomNav,
    this.glow = const [],
    this.baseColor = AppColors.bg,
    this.maxContentWidth = 520,
    this.extendBehindBottom = true,
    this.endDrawer,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.appBarTitle,
    this.appBarActions,
    this.appBarLeading,
    this.showBackButton = true,
  });

  final Widget child;
  final Widget? bottomNav;
  final Widget? endDrawer;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Radial accent washes painted behind the content.
  final List<ScreenGlow> glow;
  final Color baseColor;
  final double maxContentWidth;
  final bool extendBehindBottom;

  /// Native AppBar config. When [appBarTitle] (or [appBarLeading]/[appBarActions])
  /// is set, a flat wireframe AppBar is shown with a native back button unless
  /// [showBackButton] is false (top-level tab pages).
  final String? appBarTitle;
  final List<Widget>? appBarActions;
  final Widget? appBarLeading;
  final bool showBackButton;

  bool get _hasAppBar =>
      appBarTitle != null ||
      appBarLeading != null ||
      (appBarActions != null && appBarActions!.isNotEmpty);

  PreferredSizeWidget? _appBar() {
    if (!_hasAppBar) return null;
    return AppBar(
      backgroundColor: baseColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: showBackButton,
      leading: appBarLeading,
      titleSpacing:
          (showBackButton || appBarLeading != null) ? 0 : 18,
      iconTheme: const IconThemeData(color: AppColors.txt),
      title: appBarTitle == null
          ? null
          : Text(appBarTitle!.toUpperCase(),
              style: AppText.condensed(size: 20, weight: FontWeight.w800)),
      actions: appBarActions,
      // Subtle hairline under the bar.
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.line),
      ),
    );
  }

  /// The accent glows to paint behind content — the caller's [glow] list plus a
  /// faint ambient volt-green wash at the top so screens have brand atmosphere.
  List<ScreenGlow> get _glows => [
        const ScreenGlow(
          color: Color(0x14D4FF00),
          center: Alignment(0, -1.05),
          radius: 1.1,
        ),
        ...glow,
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: baseColor,
      extendBody: extendBehindBottom,
      endDrawer: endDrawer,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      appBar: _appBar(),
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: baseColor,
          backgroundBlendMode: BlendMode.srcOver,
        ),
        child: Stack(
          children: [
            // Radial accent glows behind the content for brand atmosphere.
            for (final g in _glows)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: g.center,
                        radius: g.radius,
                        colors: [g.color, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
            // Top-aligned (not Center) so short scrollable screens don't float
            // in the vertical middle; width is still capped + centred.
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: child,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: bottomNav == null
          ? null
          // `heightFactor: 1.0` makes this shrink-wrap the nav's real height so
          // it stays docked at the bottom. A plain `Center` would expand to the
          // loose maxHeight the Scaffold passes here and float the bar in the
          // vertical middle of the screen. Width is still capped + centred so
          // the bar matches the mobile content column on wide screens.
          : Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1.0,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: bottomNav,
              ),
            ),
    );
  }
}

/// A single radial glow specification.
class ScreenGlow {
  const ScreenGlow({
    required this.color,
    this.center = const Alignment(0, -1),
    this.radius = 0.9,
  });

  final Color color;
  final Alignment center;
  final double radius;
}
