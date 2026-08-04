import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/models.dart';
import '../utils/ticket_outcome.dart';

/// Tarjeta con efecto glassmorphism del design system AURA VITAE.
///
/// Relleno blanco translúcido con gradiente sutil, borde luminoso y
/// sombra suave sobre [AuraBackground]. Por rendimiento, el desenfoque
/// real del fondo ([frosted]) está apagado por defecto: `BackdropFilter`
/// es muy costoso en Flutter web y sobre un fondo estático el resultado
/// visual es casi idéntico sin él. Actívalo solo cuando la tarjeta
/// flote sobre contenido que se mueve por debajo.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding,
    this.blur = 16,
    this.opacity = 0.55,
    this.frosted = false,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;

  /// Opacidad del relleno blanco (0-1). Más bajo = más transparente.
  final double opacity;

  /// `true` aplica desenfoque real del fondo (costoso; usar con medida).
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    final content = Container(
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
    );

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
        child: frosted
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: content,
              )
            : content,
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
              colors: [Color(0xFFF4ECE8), AppTheme.almond, Color(0xFFEDDEDA)],
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -80,
          child: _blob(300, AppTheme.peony, 0.55),
        ),
        Positioned(
          top: 260,
          left: -140,
          child: _blob(280, AppTheme.mauve, 0.22),
        ),
        Positioned(
          bottom: -110,
          right: 60,
          child: _blob(320, AppTheme.merlot, 0.12),
        ),
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

/// Ruta del asset del catálogo que le corresponde a un producto por su nombre.
///
/// Las fotos de `res/images/products/` están nombradas con el nombre del
/// producto en minúsculas y unido por guiones: "Cleansing Foam" resuelve a
/// `res/images/products/cleansing-foam.webp`.
///
/// OJO — esto ata la foto al nombre del producto: si alguien lo renombra, su
/// imagen deja de encontrarse y aparece el ícono de imagen rota. Es una
/// decisión consciente para no tener que guardar la ruta en cada documento de
/// Firestore. Si el catálogo va a cambiar de nombres, lo correcto es guardar
/// la ruta en el campo `imageUrl`, que tiene prioridad sobre esta derivación.
String productAssetPath(String productName) {
  final slug = productName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return 'res/images/products/$slug.webp';
}

/// Imagen de producto, desde un asset empaquetado o desde una URL externa.
///
/// Orden de resolución:
/// 1. Si [imageUrl] no empieza con `http`, se usa tal cual como asset.
/// 2. Si se pasó [productName], se busca el asset que le corresponde por
///    nombre (ver [productAssetPath]).
/// 3. Si ese asset no existe y [imageUrl] es una URL, se intenta la red.
/// 4. Si nada resuelve, se muestra el ícono de imagen rota.
///
/// Los assets locales son la vía preferida para el catálogo. Las imágenes
/// alojadas en Google Drive no funcionan bien aquí: Drive no envía las
/// cabeceras CORS que el navegador exige para decodificar los bytes, así
/// que cada miniatura falla primero por la vía normal (~300 ms perdidos) y
/// solo se dibuja por el respaldo de elemento `<img>`, que no admite
/// redimensionado ni queda cacheado por el service worker.
///
/// Los tres estados sin foto son visualmente distintos, para poder
/// diagnosticar de un vistazo por qué una celda está vacía:
/// - Sin ruta: ícono de inventario (el producto no tiene foto).
/// - Cargando: indicador de progreso.
/// - Error: ícono de imagen rota (la ruta existe pero no sirve).
///
/// `webHtmlElementStrategy.fallback` es lo que habilita ese respaldo de
/// `<img>` para las URLs sin CORS. Ojo: por esa vía el widget delega la
/// carga al navegador y los estados de progreso y error no siempre llegan
/// hasta aquí, así que una URL rota servida sin CORS puede quedarse en el
/// estado de carga. Con assets locales los tres estados sí son fiables.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    this.productName,
    this.size = 44,
    this.borderRadius = 10,
    this.width,
    this.height,
  });

  final String imageUrl;

  /// Nombre del producto, para localizar su foto empaquetada cuando
  /// [imageUrl] no apunta ya a un asset. Omitirlo desactiva esa búsqueda.
  final String? productName;

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

    Widget placeholder(Widget child) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppTheme.almond,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Center(child: child),
        );

    final empty = placeholder(
      Icon(
        Icons.inventory_2_outlined,
        color: AppTheme.brandNavy,
        size: iconSize,
      ),
    );

    final loading = placeholder(
      SizedBox.square(
        dimension: iconSize * 0.6,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.brandNavy.withValues(alpha: 0.35),
        ),
      ),
    );

    final broken = placeholder(
      Icon(
        Icons.broken_image_outlined,
        color: AppTheme.brandNavy.withValues(alpha: 0.55),
        size: iconSize,
      ),
    );

    final source = imageUrl.trim();
    final name = productName?.trim() ?? '';
    final isRemote = source.startsWith('http');

    // Nada que resolver: ni ruta guardada ni nombre del que deducirla.
    if (source.isEmpty && name.isEmpty) return empty;

    // El asset derivado del nombre gana sobre una URL remota. Las fotos del
    // catálogo están empaquetadas; ir a la red por ellas sería más lento y,
    // en el caso de las URLs de Drive que quedaron en Firestore, fallaría.
    final derivedAsset = (isRemote || source.isEmpty) && name.isNotEmpty
        ? productAssetPath(name)
        : null;

    // Decodificar la imagen al tamaño mostrado (no a resolución completa):
    // las fotos del catálogo pueden ser de 1000+ px y aquí se pintan como
    // miniaturas; sin esto cada lista decodifica megapíxeles de más.
    //
    // Se omite solo para URLs remotas en web: ahí el redimensionado fuerza
    // la vía de decodificación con CORS, que Drive no soporta, y rompe las
    // imágenes que hoy dependen del respaldo de <img>. Los assets locales
    // no tienen ese problema, así que sí se redimensionan en toda
    // plataforma — que es media razón para migrar el catálogo a `res/`.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logicalWidth = w.isFinite ? w : (h.isFinite ? h * 2 : 300);
    final resizeWidth = (logicalWidth * dpr).round();

    Widget clip(Widget child) => ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: child,
        );

    Widget remote() => clip(
          Image.network(
            source,
            width: w,
            height: h,
            fit: BoxFit.cover,
            cacheWidth: kIsWeb ? null : resizeWidth,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : loading,
            errorBuilder: (context, error, stackTrace) => broken,
          ),
        );

    Widget asset(String path, {required Widget Function() onMissing}) => clip(
          Image.asset(
            path,
            width: w,
            height: h,
            fit: BoxFit.cover,
            cacheWidth: resizeWidth,
            errorBuilder: (context, error, stackTrace) => onMissing(),
          ),
        );

    // Ruta ya guardada como asset: es explícita, se respeta sin más.
    if (source.isNotEmpty && !isRemote) {
      return asset(source, onMissing: () => broken);
    }

    // Foto deducida del nombre. Si no existe un archivo para ese nombre se
    // cae a la URL guardada, y si tampoco hay, al ícono de imagen rota —
    // que es la señal de que el nombre del producto no coincide con ningún
    // archivo de `res/images/products/`.
    if (derivedAsset != null) {
      return asset(
        derivedAsset,
        onMissing: () => isRemote ? remote() : broken,
      );
    }

    return remote();
  }
}

/// Selector de producto con búsqueda por nombre o SKU.
class SearchableProductSelect extends FormField<String> {
  SearchableProductSelect({
    super.key,
    required List<Product> products,
    super.initialValue,
    super.validator,
    super.onSaved,
    ValueChanged<String?>? onChanged,
    InputDecoration decoration = const InputDecoration(
      labelText: 'Producto',
      prefixIcon: Icon(Icons.inventory_2_outlined),
    ),
  }) : super(
          builder: (state) {
            final entries = [
              for (final product in products)
                DropdownMenuEntry<String>(
                  value: product.id,
                  label: _productOptionLabel(product),
                ),
            ];

            return LayoutBuilder(
              builder: (context, constraints) {
                return DropdownMenu<String>(
                  width: constraints.maxWidth,
                  enableFilter: true,
                  requestFocusOnTap: true,
                  initialSelection: state.value,
                  label: decoration.labelText == null
                      ? null
                      : Text(decoration.labelText!),
                  leadingIcon: decoration.prefixIcon,
                  hintText: 'Buscar por nombre o código…',
                  helperText: decoration.helperText,
                  errorText: state.errorText,
                  menuHeight: 320,
                  dropdownMenuEntries: entries,
                  onSelected: (value) {
                    state.didChange(value);
                    onChanged?.call(value);
                  },
                  filterCallback: (items, filter) {
                    final query = filter.trim().toLowerCase();
                    if (query.isEmpty) return items;
                    return items.where((item) {
                      final product = products.firstWhere(
                        (p) => p.id == item.value,
                      );
                      return product.name.toLowerCase().contains(query) ||
                          product.sku.toLowerCase().contains(query);
                    }).toList();
                  },
                );
              },
            );
          },
        );

  static String _productOptionLabel(Product product) =>
      '${product.name} · ${product.sku} · stock: ${product.stock}';
}

/// Chip de estado de stock (En stock / Stock bajo / Agotado).
class StockStatusChip extends StatelessWidget {
  const StockStatusChip({super.key, required this.status});

  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      StockStatus.ok => ('En stock', AppTheme.success),
      StockStatus.low => ('Stock bajo', AppTheme.mauve),
      StockStatus.out => ('Agotado', AppTheme.danger),
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
      // FittedBox: si el espacio disponible es menor al contenido
      // (p. ej. paneles compactos), se escala en lugar de desbordar.
      child: FittedBox(
        fit: BoxFit.scaleDown,
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

/// Avisa al usuario qué pasó con el ticket. Cuando la impresión sale bien
/// no se dice nada: el diálogo del navegador ya es la confirmación.
void showTicketOutcome(
  BuildContext context,
  TicketOutcome outcome,
  String folio,
) {
  switch (outcome) {
    case TicketOutcome.printed:
      break;
    case TicketOutcome.downloaded:
      showSuccessSnackBar(
        context,
        'El navegador bloqueó la impresión, así que el ticket se descargó '
        'como Ticket-$folio.html. Ábrelo para imprimirlo.',
      );
    case TicketOutcome.unavailable:
      showErrorSnackBar(
        context,
        'No se pudo generar el ticket $folio en este navegador. '
        'Inténtalo desde otro navegador o vuelve a intentarlo.',
      );
  }
}
