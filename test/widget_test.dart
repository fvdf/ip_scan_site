import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ip_scan/main.dart';

void main() {
  testWidgets('shows home page and navigates to search pages', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const IpScanApp());

    expect(find.text('Analyse reseau rapide'), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Recherche IP'), findsWidgets);
    expect(find.text('Recherche domaine'), findsWidgets);

    await tester.tap(find.widgetWithText(TextButton, 'Recherche IP'));
    await tester.pumpAndSettle();

    expect(find.text('Adresse IP'), findsWidgets);
    expect(find.text('Exemple: 8.8.8.8'), findsOneWidget);
    expect(find.textContaining('Backend non configure'), findsOneWidget);

    await tester.tap(find.text('Fichier CSV'));
    await tester.pumpAndSettle();

    expect(find.text('Choisir un CSV'), findsOneWidget);
    expect(find.text('Analyser le CSV'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Recherche domaine'));
    await tester.pumpAndSettle();

    expect(find.text('Nom de domaine'), findsOneWidget);
    expect(find.text('Exemple: example.com'), findsOneWidget);
  });
}
