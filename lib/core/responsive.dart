import 'package:flutter/widgets.dart';

/// Breakpoints del sistema (mobile-first).
///
/// - `< 700`  : móvil — navegación inferior, listas en tarjetas.
/// - `700-1099`: tablet — NavigationRail compacto, grids de 2 columnas.
/// - `>= 1100`: escritorio/web — rail extendido, tablas y grids amplios.
class Breakpoints {
  Breakpoints._();

  static const double tablet = 700;
  static const double desktop = 1100;
}

enum ScreenSize { mobile, tablet, desktop }

extension ResponsiveContext on BuildContext {
  ScreenSize get screenSize {
    final width = MediaQuery.sizeOf(this).width;
    if (width >= Breakpoints.desktop) return ScreenSize.desktop;
    if (width >= Breakpoints.tablet) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTablet => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;

  /// Padding horizontal estándar de página según el ancho.
  double get pagePadding => isMobile ? 16 : (isTablet ? 24 : 32);
}
