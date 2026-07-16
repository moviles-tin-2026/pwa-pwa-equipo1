import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/models.dart';

/// Tarjeta con efecto glassmorphism del design system AURA VITAE.
///
/// Vidrio esmerilado: desenfoque del fondo (BackdropFilter), relleno
/// blanco translúcido con gradiente sutil, borde luminoso y sombra suave.
/// Úsala sobre [AuraBackground] (o cualquier fondo con color/gradiente)
/// para que el desenfoque tenga algo que difuminar.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding,
    this.blur = 16,
    this.opacity = 0.55,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;

  /// Opacidad del relleno blanco (0-1). Más bajo = más transparente.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppTheme.merlot.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: opacity + 0.15),
                  Colors.white.withValues(alpha: opacity - 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.70),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Fondo decorativo del shell: gradiente cálido con manchas de color
/// difusas (peony/mauve/merlot) que hacen visible el efecto de vidrio
/// de las [GlassCard] superpuestas.
class AuraBackground extends StatelessWidget {
  const AuraBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF4ECE8),
                AppTheme.almond,
                Color(0xFFEDDEDA),
              ],
            ),
          ),
        ),
        Positioned(top: -120, right: -80, child: _blob(300, AppTheme.peony, 0.55)),
        Positioned(top: 260, left: -140, child: _blob(280, AppTheme.mauve, 0.22)),
        Positioned(bottom: -110, right: 60, child: _blob(320, AppTheme.merlot, 0.12)),
        child,
      ],
    );
  }

  static Widget _blob(double size, Color color, double alpha) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de indicador (KPI) para dashboards.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color = AppTheme.merlot,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.14,
                      color: AppTheme.mauve,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.01,
                  color: AppTheme.cocoa,
                ),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppTheme.mauve,
                ),
              ),
            ],
          ],
      ),
    );
  }
}

/// Imagen de producto con carga desde URL externa.
///
/// - URL vacía o con error: muestra el ícono de inventario como fallback.
/// - `webHtmlElementStrategy.fallback`: en Flutter web (CanvasKit) permite
///   renderizar con un `<img>` cuando el host de la imagen no envía
///   cabeceras CORS, evitando que fallen en GitHub Pages.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    this.size = 44,
    this.borderRadius = 10,
    this.width,
    this.height,
  });

  final String imageUrl;
  final double size;
  final double borderRadius;

  /// Anulan [size] cuando la imagen no es cuadrada
  /// (p. ej. ancho completo de una tarjeta). `double.infinity` es válido.
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final h = height ?? size;
    final iconSize = (h.isFinite ? h : size) * 0.5;

    final fallback = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: AppTheme.almond,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        color: AppTheme.brandNavy,
        size: iconSize,
      ),
    );

    if (imageUrl.trim().isEmpty) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        imageUrl.trim(),
        width: w,
        height: h,
        fit: BoxFit.cover,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

/// Chip de estado de stock (En stock / Stock bajo / Agotado).
class StockStatusChip extends StatelessWidget {
  const StockStatusChip({super.key, required this.status});

  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      StockStatus.ok  => ('En stock',   AppTheme.success),
      StockStatus.low => ('Stock bajo', AppTheme.mauve),
      StockStatus.out => ('Agotado',    AppTheme.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Montserrat',
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.06,
        ),
      ),
    );
  }
}

/// Insignia de rol (Admin / Operador).
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final (bgColor, textColor) = role == UserRole.admin
        ? (AppTheme.peony, AppTheme.merlot)
        : (AppTheme.almond, AppTheme.mauve);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontFamily: 'Montserrat',
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.06,
        ),
      ),
    );
  }
}

/// Encabezado de sección con acción opcional.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.16,
            color: AppTheme.mauve,
          ),
        ),
        ?action,
      ],
    );
  }
}

/// Estado vacío para listas sin resultados.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppTheme.peony),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.06,
                color: AppTheme.mauve,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppTheme.mauve,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// SnackBars consistentes para éxito / error.
void showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.success,
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppTheme.danger,
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
