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

    expect(find.text('Nom de domaine'), findsWidgets);
    expect(find.text('Exemple: example.com'), findsOneWidget);
    expect(find.textContaining('Backend non configure'), findsOneWidget);
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

  testWidgets('runs single domain search and shows request workflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DomainSearchPage(api: _FakeDomainAnalysisApi())),
      ),
    );

    await tester.enterText(find.byType(TextField), 'https://www.example.com');
    await tester.tap(find.text('Rechercher le domaine'));
    await tester.pumpAndSettle();

    expect(find.text('example.com'), findsWidgets);
    expect(find.text('Example Registrar'), findsWidgets);
    expect(find.text('Proprietaire masque'), findsWidgets);
    expect(find.text('Fiche de demande'), findsOneWidget);
    expect(
      find.textContaining('Domaine concerne: example.com'),
      findsOneWidget,
    );
    expect(find.text('Copier la demande'), findsOneWidget);
  });

  testWidgets('shows desktop domain csv results and opens detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DomainSearchPage(
            api: _FakeDomainAnalysisApi(),
            initialCsvFileName: 'domains.csv',
            initialCsvText: 'domain\nexample.com',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Fichier CSV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyser le CSV'));
    await tester.pumpAndSettle();

    expect(find.text('Resume des domaines'), findsOneWidget);
    expect(find.text('Resultats'), findsOneWidget);
    expect(find.text('Domaine'), findsWidgets);
    expect(find.byTooltip('Copier le domaine example.com'), findsOneWidget);
    expect(find.byTooltip('Voir le detail example.com'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('domain-row-example.com')),
    );
    await tester.tap(find.byKey(const ValueKey('domain-row-example.com')));
    await tester.pumpAndSettle();

    expect(find.text('Detail domaine example.com'), findsOneWidget);
    expect(find.text('Contacts publics'), findsOneWidget);
    expect(find.text('IP associees'), findsOneWidget);
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

class _FakeDomainAnalysisApi extends IpAnalysisApi {
  const _FakeDomainAnalysisApi();

  @override
  bool get isConfigured => true;

  @override
  Future<Map<String, dynamic>> analyzeDomain(String domain) async {
    return {'ok': true, 'result': _sampleDomainResult('example.com')};
  }

  @override
  Future<Map<String, dynamic>> analyzeDomainCsv(String csvText) async {
    final result = _sampleDomainResult('example.com');
    return {
      'ok': true,
      'input_count': 1,
      'unique_count': 1,
      'summary': {
        'ok': 1,
        'errors': 0,
        'registrars': {'Example Registrar': 1},
        'hosting_providers': {'Example Hosting': 1},
        'owner_visibility': {'redacted': 1},
        'priority_domains': [
          {
            'domain': 'example.com',
            'registrar': 'Example Registrar',
            'owner_visibility': 'redacted',
            'hosting_provider': 'Example Hosting',
          },
        ],
      },
      'results': [result],
    };
  }
}

Map<String, dynamic> _sampleDomainResult(String domain) {
  return {
    'ok': true,
    'input': domain,
    'domain': domain,
    'unicode_domain': domain,
    'tld': 'com',
    'dns': {
      'records': {
        'A': {
          'ok': true,
          'records': ['93.184.216.34'],
        },
        'AAAA': {'ok': true, 'records': []},
        'MX': {
          'ok': true,
          'records': ['10 mail.example.com.'],
        },
        'TXT': {
          'ok': true,
          'records': ['v=spf1 include:example.net -all'],
        },
      },
      'spf': 'v=spf1 include:example.net -all',
      'dmarc': 'v=DMARC1; p=reject',
      'dnssec': true,
    },
    'rdap': {
      'ok': true,
      'registrar': 'Example Registrar',
      'created_at': '2020-01-01T00:00:00Z',
      'expires_at': '2030-01-01T00:00:00Z',
      'owner_visibility': 'redacted',
      'nameservers': ['ns1.example.net'],
      'entities': [
        {
          'roles': ['abuse'],
          'name': 'Abuse Desk',
          'email': 'abuse@example.test',
        },
      ],
    },
    'ips': [_sampleIpResult('93.184.216.34')],
    'hosting': {
      'probable_provider': 'Example Hosting',
      'probable_hosting_provider': 'Example Hosting',
      'probable_cdn_proxy': 'Cloudflare',
      'is_cdn_or_proxy_probable': true,
      'evidence': ['DNS mentionne Cloudflare.'],
    },
    'http': {'ok': true, 'status': 200},
    'tls': {'ok': true, 'expires_in_days': 90},
    'certificate_transparency': {
      'ok': true,
      'subdomain_count': 2,
      'subdomains': ['www.example.com', 'api.example.com'],
    },
    'contact_workflow': {
      'owner_visibility': 'redacted',
      'request_needed': true,
      'rdrs_recommended': true,
      'request_template':
          'Domaine concerne: example.com\nRegistrar public: Example Registrar',
      'limitations': ['Les donnees RDAP publiques peuvent etre masquees.'],
      'public_contacts': [
        {
          'roles': ['abuse'],
          'name': 'Abuse Desk',
          'email': 'abuse@example.test',
        },
      ],
    },
    'summary': {
      'domain': domain,
      'registrar': 'Example Registrar',
      'created_at': '2020-01-01T00:00:00Z',
      'expires_at': '2030-01-01T00:00:00Z',
      'owner_visibility': 'redacted',
      'ip_count': 1,
      'hosting_provider': 'Example Hosting',
      'cdn_or_proxy': true,
      'nameserver_count': 1,
      'has_spf': true,
      'has_dmarc': true,
      'dnssec': true,
      'http_status': 200,
      'tls_ok': true,
      'tls_expires_in_days': 90,
      'ct_subdomain_count': 2,
    },
    'occurrences': 1,
  };
}
