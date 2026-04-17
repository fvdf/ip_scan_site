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

  testWidgets('shows desktop csv results and opens ip detail', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IpSearchPage(
            api: _FakeIpAnalysisApi(_csvResponse([_sampleIpResult('8.8.8.8')])),
            initialCsvFileName: 'ips.csv',
            initialCsvText: 'IPAddress\n8.8.8.8',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Fichier CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyser le CSV'));
    await tester.pumpAndSettle();

    expect(find.text('Resultats'), findsOneWidget);
    expect(find.text('IP'), findsWidgets);
    expect(find.text('Pays'), findsWidgets);
    expect(find.text('Operateur'), findsWidgets);
    expect(find.byTooltip('Copier l IP 8.8.8.8'), findsOneWidget);
    expect(find.byTooltip('Voir le detail 8.8.8.8'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('ip-row-8.8.8.8')));
    await tester.tap(find.byKey(const ValueKey('ip-row-8.8.8.8')));
    await tester.pumpAndSettle();

    expect(find.text('Detail IP 8.8.8.8'), findsOneWidget);
    expect(find.text('Copier le resume'), findsOneWidget);
    expect(find.text('Pour aller plus loin'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Resume du CSV'), findsOneWidget);
  });

  testWidgets('shows mobile csv cards and opens detail from card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IpSearchPage(
            api: _FakeIpAnalysisApi(_csvResponse([_sampleIpResult('8.8.8.8')])),
            initialCsvFileName: 'ips.csv',
            initialCsvText: 'IPAddress\n8.8.8.8',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Fichier CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyser le CSV'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ip-card-8.8.8.8')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('ip-card-8.8.8.8')));
    await tester.tap(find.byKey(const ValueKey('ip-card-8.8.8.8')));
    await tester.pumpAndSettle();

    expect(find.text('Detail IP 8.8.8.8'), findsOneWidget);
    expect(find.text('Google LLC'), findsWidgets);
  });

  testWidgets('shows csv result errors clearly', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IpSearchPage(
            api: _FakeIpAnalysisApi(
              _csvResponse([
                {
                  'ok': false,
                  'input': 'not-an-ip',
                  'error': 'IP invalide',
                  'occurrences': 1,
                },
              ]),
            ),
            initialCsvFileName: 'ips.csv',
            initialCsvText: 'IPAddress\nnot-an-ip',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Fichier CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyser le CSV'));
    await tester.pumpAndSettle();

    expect(find.text('IP invalide'), findsOneWidget);
    expect(find.byTooltip('Voir le detail not-an-ip'), findsOneWidget);
  });
}

class _FakeIpAnalysisApi extends IpAnalysisApi {
  const _FakeIpAnalysisApi(this.csvResponse);

  final Map<String, dynamic> csvResponse;

  @override
  bool get isConfigured => true;

  @override
  Future<Map<String, dynamic>> analyzeCsv(String csvText) async => csvResponse;

  @override
  Future<Map<String, dynamic>> analyzeIp(String ip) async {
    return {'ok': true, 'result': _sampleIpResult(ip)};
  }
}

Map<String, dynamic> _csvResponse(List<Map<String, dynamic>> results) {
  final okCount = results.where((result) => result['ok'] == true).length;
  final errorCount = results.length - okCount;

  return {
    'ok': true,
    'input_count': results.length,
    'unique_count': results.length,
    'summary': {
      'ok': okCount,
      'errors': errorCount,
      'categories': {'infrastructure_ou_relais_probable': okCount},
      'priority_ips': [
        if (okCount > 0)
          {
            'ip': results.first['ip'],
            'category': 'infrastructure_ou_relais_probable',
            'score': 20,
            'investigative_value': 'faible',
            'requisition_target': 'service intermediaire',
            'occurrences': 1,
          },
      ],
    },
    'results': results,
  };
}

Map<String, dynamic> _sampleIpResult(String ip) {
  return {
    'ok': true,
    'input': ip,
    'ip': ip,
    'location': {'country': 'USA', 'city': 'Ashburn'},
    'network': {
      'isp': 'Google LLC',
      'org': 'Google Public DNS',
      'asn_full': 'AS15169 Google LLC',
    },
    'flags': {
      'is_mobile': false,
      'is_proxy_or_vpn_or_tor': false,
      'is_hosting_or_datacenter': true,
    },
    'analysis': {
      'category': 'infrastructure_ou_relais_probable',
      'score': 20,
      'investigative_value': 'faible',
      'confidence': 'moyenne',
      'reasons': ['L API signale une IP de datacenter.'],
    },
    'identity_requirements': [
      'Les journaux du fournisseur reseau sont necessaires.',
    ],
    'occurrences': 1,
  };
}
