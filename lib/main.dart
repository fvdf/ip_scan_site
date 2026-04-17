import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const IpScanApp());
}

class IpScanApp extends StatelessWidget {
  const IpScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IP Scan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        scaffoldBackgroundColor: const Color(0xFFF7FAFC),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          ),
        ),
      ),
      home: const SiteShell(),
    );
  }
}

class SiteShell extends StatefulWidget {
  const SiteShell({super.key});

  @override
  State<SiteShell> createState() => _SiteShellState();
}

class _SiteShellState extends State<SiteShell> {
  int _selectedIndex = 0;

  final List<_SitePage> _pages = const [
    _SitePage(label: 'Accueil', icon: Icons.home_outlined, body: HomePage()),
    _SitePage(
      label: 'Recherche IP',
      icon: Icons.travel_explore,
      body: IpSearchPage(),
    ),
    _SitePage(
      label: 'Recherche domaine',
      icon: Icons.language,
      body: DomainSearchPage(),
    ),
  ];

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDrawer = constraints.maxWidth < 900;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 1,
            shadowColor: Colors.black26,
            leading: useDrawer
                ? Builder(
                    builder: (context) {
                      return IconButton(
                        tooltip: 'Ouvrir le menu',
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      );
                    },
                  )
                : null,
            titleSpacing: useDrawer ? 0 : 28,
            title: const _BrandTitle(),
            actions: useDrawer
                ? null
                : [
                    for (var i = 0; i < _pages.length; i++)
                      _MenuButton(
                        label: _pages[i].label,
                        selected: i == _selectedIndex,
                        onPressed: () => _selectPage(i),
                      ),
                    const SizedBox(width: 20),
                  ],
          ),
          drawer: useDrawer
              ? _SiteDrawer(
                  pages: _pages,
                  selectedIndex: _selectedIndex,
                  onSelect: _selectPage,
                )
              : null,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(_selectedIndex),
              child: _pages[_selectedIndex].body,
            ),
          ),
        );
      },
    );
  }
}

class _SitePage {
  const _SitePage({
    required this.label,
    required this.icon,
    required this.body,
  });

  final String label;
  final IconData icon;
  final Widget body;
}

class _SiteDrawer extends StatelessWidget {
  const _SiteDrawer({
    required this.pages,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<_SitePage> pages;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: _BrandTitle(),
            ),
            const Divider(height: 1),
            for (var i = 0; i < pages.length; i++)
              ListTile(
                leading: Icon(pages[i].icon),
                title: Text(pages[i].label),
                selected: i == selectedIndex,
                onTap: () {
                  Navigator.of(context).pop();
                  onSelect(i);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF0F766E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.radar, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            'IP Scan',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: const Color(0xFF111827),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF0F766E) : const Color(0xFF374151);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_HomeIntro(), SizedBox(height: 42), _FeatureGrid()],
      ),
    );
  }
}

class _HomeIntro extends StatelessWidget {
  const _HomeIntro();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 36,
      runSpacing: 28,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analyse reseau rapide',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Consultez vos informations IP et preparez vos recherches de noms de domaine depuis une interface simple.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF4B5563),
                  height: 1.5,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: () {},
                child: const Text('Commencer une recherche'),
              ),
            ],
          ),
        ),
        const _StatusPanel(),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 850;
        final cards = const [
          _InfoCard(
            icon: Icons.public,
            title: 'Recherche IP',
            text:
                'Identifiez une adresse IP et centralisez les premiers details utiles.',
          ),
          _InfoCard(
            icon: Icons.language,
            title: 'Nom de domaine',
            text: 'Lancez une verification de domaine depuis une page dediee.',
          ),
          _InfoCard(
            icon: Icons.devices,
            title: 'Interface responsive',
            text:
                'La navigation reste accessible sur ordinateur, tablette et mobile.',
          ),
        ];

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final card in cards) ...[card, const SizedBox(height: 18)],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final card in cards) ...[
              Expanded(child: card),
              if (card != cards.last) const SizedBox(width: 18),
            ],
          ],
        );
      },
    );
  }
}

class IpSearchPage extends StatefulWidget {
  const IpSearchPage({super.key});

  @override
  State<IpSearchPage> createState() => _IpSearchPageState();
}

class _IpSearchPageState extends State<IpSearchPage> {
  static const _maxCsvBytes = 1000000;

  final _api = const IpAnalysisApi();
  final _ipController = TextEditingController();

  _IpSearchMode _mode = _IpSearchMode.single;
  _IpSearchStatus _status = _IpSearchStatus.idle;
  Map<String, dynamic>? _response;
  String? _errorMessage;
  String? _csvFileName;
  String? _csvText;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  void _setMode(_IpSearchMode mode) {
    setState(() {
      _mode = mode;
      _status = _IpSearchStatus.idle;
      _response = null;
      _errorMessage = null;
    });
  }

  Future<void> _pickCsv() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }

    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        _status = _IpSearchStatus.error;
        _errorMessage = 'Impossible de lire le fichier selectionne.';
      });
      return;
    }

    if (bytes.length > _maxCsvBytes) {
      setState(() {
        _status = _IpSearchStatus.error;
        _errorMessage = 'Le fichier CSV depasse la limite de 1 MB.';
      });
      return;
    }

    setState(() {
      _csvFileName = file.name;
      _csvText = utf8.decode(bytes, allowMalformed: true);
      _status = _IpSearchStatus.idle;
      _response = null;
      _errorMessage = null;
    });
  }

  Future<void> _runSingleIpSearch() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      setState(() {
        _status = _IpSearchStatus.error;
        _errorMessage = 'Saisissez une adresse IP.';
      });
      return;
    }
    await _runSearch(() => _api.analyzeIp(ip));
  }

  Future<void> _runCsvSearch() async {
    final csvText = _csvText;
    if (csvText == null || csvText.trim().isEmpty) {
      setState(() {
        _status = _IpSearchStatus.error;
        _errorMessage = 'Selectionnez un fichier CSV contenant des IP.';
      });
      return;
    }
    await _runSearch(() => _api.analyzeCsv(csvText));
  }

  Future<void> _runSearch(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    if (!_api.isConfigured) {
      setState(() {
        _status = _IpSearchStatus.error;
        _errorMessage =
            'Configurez IP_SCAN_API_BASE_URL avec le domaine Appwrite Function.';
      });
      return;
    }

    setState(() {
      _status = _IpSearchStatus.loading;
      _response = null;
      _errorMessage = null;
    });

    try {
      final response = await request();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = _IpSearchStatus.success;
        _response = response;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = _IpSearchStatus.error;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IpSearchHeader(),
          const SizedBox(height: 22),
          if (!_api.isConfigured) ...[
            const _ConfigurationNotice(),
            const SizedBox(height: 18),
          ],
          _ModeSelector(selected: _mode, onChanged: _setMode),
          const SizedBox(height: 18),
          if (_mode == _IpSearchMode.single)
            _SingleIpForm(
              controller: _ipController,
              loading: _status == _IpSearchStatus.loading,
              onSubmit: _runSingleIpSearch,
            )
          else
            _CsvForm(
              fileName: _csvFileName,
              loading: _status == _IpSearchStatus.loading,
              onPick: _pickCsv,
              onSubmit: _runCsvSearch,
            ),
          const SizedBox(height: 22),
          _ResultPanel(
            mode: _mode,
            status: _status,
            response: _response,
            errorMessage: _errorMessage,
          ),
        ],
      ),
    );
  }
}

enum _IpSearchMode { single, csv }

enum _IpSearchStatus { idle, loading, success, error }

class IpAnalysisApi {
  const IpAnalysisApi();

  static const String baseUrl = String.fromEnvironment('IP_SCAN_API_BASE_URL');

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  Future<Map<String, dynamic>> analyzeIp(String ip) {
    return _post('/analyze-ip', {'ip': ip});
  }

  Future<Map<String, dynamic>> analyzeCsv(String csvText) {
    return _post('/analyze-ips', {'csv': csvText});
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$normalizedBaseUrl$path');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Reponse backend inattendue.');
    }

    if (response.statusCode >= 400) {
      throw Exception(decoded['error']?.toString() ?? 'Erreur backend.');
    }

    return decoded;
  }
}

class _IpSearchHeader extends StatelessWidget {
  const _IpSearchHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFFE0F2F1),
          child: Icon(Icons.travel_explore, color: Color(0xFF0F766E)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recherche IP',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Analysez une adresse IP ou un fichier CSV contenant plusieurs IP.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF4B5563),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfigurationNotice extends StatelessWidget {
  const _ConfigurationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: const Text(
        'Backend non configure. Lancez le site avec --dart-define=IP_SCAN_API_BASE_URL=https://votre-function.appwrite.run.',
        style: TextStyle(color: Color(0xFF92400E), height: 1.4),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onChanged});

  final _IpSearchMode selected;
  final ValueChanged<_IpSearchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ChoiceChip(
          label: const Text('Adresse IP'),
          selected: selected == _IpSearchMode.single,
          onSelected: (_) => onChanged(_IpSearchMode.single),
        ),
        ChoiceChip(
          label: const Text('Fichier CSV'),
          selected: selected == _IpSearchMode.csv,
          onSelected: (_) => onChanged(_IpSearchMode.csv),
        ),
      ],
    );
  }
}

class _SingleIpForm extends StatelessWidget {
  const _SingleIpForm({
    required this.controller,
    required this.loading,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _FormSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final field = TextField(
            controller: controller,
            enabled: !loading,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => loading ? null : onSubmit(),
            decoration: const InputDecoration(
              labelText: 'Adresse IP',
              hintText: 'Exemple: 8.8.8.8',
            ),
          );
          final button = FilledButton(
            onPressed: loading ? null : onSubmit,
            child: const Text('Rechercher l IP'),
          );

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: field),
                const SizedBox(width: 14),
                button,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [field, const SizedBox(height: 14), button],
          );
        },
      ),
    );
  }
}

class _CsvForm extends StatelessWidget {
  const _CsvForm({
    required this.fileName,
    required this.loading,
    required this.onPick,
    required this.onSubmit,
  });

  final String? fileName;
  final bool loading;
  final VoidCallback onPick;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return _FormSurface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final fileLabel = Text(
            fileName ?? 'Aucun fichier selectionne',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF374151)),
          );
          final pickButton = OutlinedButton.icon(
            onPressed: loading ? null : onPick,
            icon: const Icon(Icons.upload_file),
            label: const Text('Choisir un CSV'),
          );
          final submitButton = FilledButton(
            onPressed: loading ? null : onSubmit,
            child: const Text('Analyser le CSV'),
          );

          if (wide) {
            return Row(
              children: [
                Expanded(child: fileLabel),
                const SizedBox(width: 14),
                pickButton,
                const SizedBox(width: 10),
                submitButton,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              fileLabel,
              const SizedBox(height: 14),
              pickButton,
              const SizedBox(height: 10),
              submitButton,
            ],
          );
        },
      ),
    );
  }
}

class _FormSurface extends StatelessWidget {
  const _FormSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.mode,
    required this.status,
    required this.response,
    required this.errorMessage,
  });

  final _IpSearchMode mode;
  final _IpSearchStatus status;
  final Map<String, dynamic>? response;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (status == _IpSearchStatus.loading) {
      return const _DarkResultSurface(
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: 14),
            Expanded(child: Text('Analyse en cours...')),
          ],
        ),
      );
    }

    if (status == _IpSearchStatus.error) {
      return _ErrorResultSurface(message: errorMessage ?? 'Erreur inconnue.');
    }

    if (status == _IpSearchStatus.success && response != null) {
      if (mode == _IpSearchMode.csv) {
        return _CsvResult(response: response!);
      }
      final result = response!['result'];
      if (result is Map<String, dynamic>) {
        return _SingleIpResult(result: result);
      }
      return const _ErrorResultSurface(message: 'Reponse IP illisible.');
    }

    return const _DarkResultSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resultat',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'Lancez une recherche pour afficher la localisation, le reseau, la categorie et les priorites d investigation.',
            style: TextStyle(color: Color(0xFFD1D5DB), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _DarkResultSurface extends StatelessWidget {
  const _DarkResultSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle(
        style: Theme.of(
          context,
        ).textTheme.bodyMedium!.copyWith(color: Colors.white, height: 1.45),
        child: child,
      ),
    );
  }
}

class _ErrorResultSurface extends StatelessWidget {
  const _ErrorResultSurface({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: const Color(0xFF991B1B),
          height: 1.4,
        ),
      ),
    );
  }
}

class _SingleIpResult extends StatelessWidget {
  const _SingleIpResult({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    if (result['ok'] != true) {
      return _ErrorResultSurface(
        message: result['error']?.toString() ?? 'Analyse IP impossible.',
      );
    }

    final location = _mapValue(result['location']);
    final network = _mapValue(result['network']);
    final analysis = _mapValue(result['analysis']);
    final reasons = _stringList(analysis['reasons']);
    final requirements = _stringList(result['identity_requirements']);

    return _ResultSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ResultTitle(title: result['ip']?.toString() ?? 'IP analysee'),
          const SizedBox(height: 16),
          _KeyValueWrap(
            values: {
              'Pays': location['country'],
              'Ville': location['city'],
              'Operateur': network['isp'] ?? network['org'],
              'ASN': network['asn_full'] ?? network['asn'],
              'Categorie': analysis['category'],
              'Score': analysis['score'],
              'Valeur': analysis['investigative_value'],
              'Confiance': analysis['confidence'],
            },
          ),
          const SizedBox(height: 18),
          _TextList(title: 'Raisons', items: reasons),
          const SizedBox(height: 18),
          _TextList(title: 'Pour aller plus loin', items: requirements),
        ],
      ),
    );
  }
}

class _CsvResult extends StatelessWidget {
  const _CsvResult({required this.response});

  final Map<String, dynamic> response;

  @override
  Widget build(BuildContext context) {
    if (response['ok'] != true) {
      return _ErrorResultSurface(
        message: response['error']?.toString() ?? 'Analyse CSV impossible.',
      );
    }

    final summary = _mapValue(response['summary']);
    final categories = _mapValue(summary['categories']);
    final priorities = _mapList(summary['priority_ips']);
    final results = _mapList(response['results']);

    return _ResultSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ResultTitle(title: 'Resume du CSV'),
          const SizedBox(height: 16),
          _KeyValueWrap(
            values: {
              'Lignes IP': response['input_count'],
              'IP uniques': response['unique_count'],
              'Analyses OK': summary['ok'],
              'Erreurs': summary['errors'],
            },
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 18),
            _CategoryChips(categories: categories),
          ],
          if (priorities.isNotEmpty) ...[
            const SizedBox(height: 18),
            _PriorityList(priorities: priorities),
          ],
          const SizedBox(height: 18),
          _ResultList(results: results),
        ],
      ),
    );
  }
}

class _ResultSurface extends StatelessWidget {
  const _ResultSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _ResultTitle extends StatelessWidget {
  const _ResultTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: const Color(0xFF111827),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _KeyValueWrap extends StatelessWidget {
  const _KeyValueWrap({required this.values});

  final Map<String, dynamic> values;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries
        .where(
          (entry) =>
              entry.value != null && entry.value.toString().trim().isNotEmpty,
        )
        .toList();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final entry in entries)
          Container(
            width: 220,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.value.toString(),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TextList extends StatelessWidget {
  const _TextList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in items) ...[
          Text(
            '- $item',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF374151),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories});

  final Map<String, dynamic> categories;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in categories.entries)
          Chip(label: Text('${entry.key}: ${entry.value}')),
      ],
    );
  }
}

class _PriorityList extends StatelessWidget {
  const _PriorityList({required this.priorities});

  final List<Map<String, dynamic>> priorities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IP a prioriser',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in priorities.take(8)) ...[
          Text(
            '${item['ip']} - ${item['requisition_target']} - score ${item['score']}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF374151),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.results});

  final List<Map<String, dynamic>> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Text('Aucun resultat.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resultats',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final result in results.take(30)) ...[
          _CompactIpRow(result: result),
          const SizedBox(height: 8),
        ],
        if (results.length > 30)
          Text(
            '${results.length - 30} resultats supplementaires non affiches.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
          ),
      ],
    );
  }
}

class _CompactIpRow extends StatelessWidget {
  const _CompactIpRow({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final location = _mapValue(result['location']);
    final network = _mapValue(result['network']);
    final analysis = _mapValue(result['analysis']);
    final ok = result['ok'] == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFF9FAFB) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ok ? const Color(0xFFE5E7EB) : const Color(0xFFFCA5A5),
        ),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            (result['ip'] ?? result['input'] ?? 'IP inconnue').toString(),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text((location['country'] ?? 'Pays inconnu').toString()),
          Text(
            (network['isp'] ?? network['org'] ?? 'Operateur inconnu')
                .toString(),
          ),
          Text(
            (analysis['category'] ?? result['error'] ?? 'Categorie inconnue')
                .toString(),
          ),
          if (result['occurrences'] != null)
            Text('${result['occurrences']} occurrence(s)'),
        ],
      ),
    );
  }
}

Map<String, dynamic> _mapValue(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return {};
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) {
    return [];
  }
  return value
      .whereType<Map>()
      .map(
        (item) =>
            item.map((key, mapValue) => MapEntry(key.toString(), mapValue)),
      )
      .toList();
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return [];
  }
  return value.map((item) => item.toString()).toList();
}

class DomainSearchPage extends StatelessWidget {
  const DomainSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PageFrame(
      child: _SearchPanel(
        icon: Icons.language,
        title: 'Recherche nom de domaine',
        description: 'Saisissez un domaine pour preparer une verification DNS.',
        label: 'Nom de domaine',
        hintText: 'Exemple: example.com',
        buttonText: 'Rechercher le domaine',
        resultTitle: 'Resultat',
        resultText:
            'La zone de resultat est prete pour afficher les informations DNS, registrar ou disponibilite.',
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      constraints: const BoxConstraints(minHeight: 230),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MetricLine(label: 'Pages', value: '3'),
          SizedBox(height: 16),
          _MetricLine(label: 'Navigation', value: 'Menu + drawer'),
          SizedBox(height: 16),
          _MetricLine(label: 'Etat', value: 'Pret a connecter'),
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF6B7280)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF111827),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0F766E), size: 30),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF111827),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF4B5563),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.icon,
    required this.title,
    required this.description,
    required this.label,
    required this.hintText,
    required this.buttonText,
    required this.resultTitle,
    required this.resultText,
  });

  final IconData icon;
  final String title;
  final String description;
  final String label;
  final String hintText;
  final String buttonText;
  final String resultTitle;
  final String resultText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFE0F2F1),
              child: Icon(icon, color: const Color(0xFF0F766E)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF4B5563),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 720;
              final field = TextField(
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hintText,
                ),
              );
              final button = FilledButton(
                onPressed: () {},
                child: Text(buttonText),
              );

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: 14),
                    button,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [field, const SizedBox(height: 14), button],
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                resultTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                resultText,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFD1D5DB),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
