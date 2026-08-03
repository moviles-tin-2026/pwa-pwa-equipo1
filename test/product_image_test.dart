// Pruebas de ProductImage: cómo decide entre asset local y red.
//
// El catálogo está migrando de URLs de Google Drive a assets empaquetados
// bajo `res/`, así que durante la transición el mismo campo `imageUrl`
// puede traer una ruta local o una URL. Estas pruebas fijan ese contrato.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:login_app/widgets/common.dart';

void main() {
  // `cacheWidth` envuelve al proveedor real en un ResizeImage; hay que
  // desenvolverlo para saber de dónde sale la imagen.
  ImageProvider unwrap(ImageProvider provider) =>
      provider is ResizeImage ? provider.imageProvider : provider;

  Future<void> pump(WidgetTester tester, String source) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProductImage(imageUrl: source)),
        ),
      );

  testWidgets('una ruta sin esquema se carga como asset local',
      (WidgetTester tester) async {
    await pump(tester, 'res/images/products/av-lf-002.webp');

    final image = tester.widget<Image>(find.byType(Image));
    expect(unwrap(image.image), isA<AssetImage>());
  });

  testWidgets('una URL http se carga desde la red',
      (WidgetTester tester) async {
    await pump(tester, 'https://ejemplo.com/producto.webp');

    final image = tester.widget<Image>(find.byType(Image));
    expect(unwrap(image.image), isA<NetworkImage>());
  });

  testWidgets('sin ruta muestra el ícono de inventario, no una imagen',
      (WidgetTester tester) async {
    await pump(tester, '');

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });

  testWidgets('los espacios alrededor de la ruta no cambian la decisión',
      (WidgetTester tester) async {
    await pump(tester, '  res/images/products/av-lf-002.webp  ');

    final image = tester.widget<Image>(find.byType(Image));
    expect(unwrap(image.image), isA<AssetImage>());
  });

  group('foto deducida del nombre del producto', () {
    test('el nombre se convierte en la ruta del asset', () {
      expect(productAssetPath('Cleansing Foam'),
          'res/images/products/cleansing-foam.webp');
      expect(productAssetPath('Matte Sunscreen SPF 50+'),
          'res/images/products/matte-sunscreen-spf-50.webp');
      expect(productAssetPath('Retinol 0.2% Night Serum'),
          'res/images/products/retinol-0-2-night-serum.webp');
      expect(productAssetPath('  Toner  '), 'res/images/products/toner.webp');
    });

    testWidgets('el nombre gana sobre una URL remota',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageUrl: 'https://drive.google.com/uc?id=abc123',
              productName: 'Cleansing Foam',
            ),
          ),
        ),
      );

      // Va al asset empaquetado, no a la red: las URLs de Drive que quedaron
      // en Firestore fallan por CORS y son más lentas aunque funcionaran.
      final image = tester.widget<Image>(find.byType(Image));
      final provider = unwrap(image.image);
      expect(provider, isA<AssetImage>());
      expect((provider as AssetImage).assetName,
          'res/images/products/cleansing-foam.webp');
    });

    testWidgets('una ruta guardada explícitamente gana sobre el nombre',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageUrl: 'res/images/products/otra-foto.webp',
              productName: 'Cleansing Foam',
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect((unwrap(image.image) as AssetImage).assetName,
          'res/images/products/otra-foto.webp');
    });
  });
}
