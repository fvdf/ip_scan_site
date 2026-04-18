import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  List<_SitePage> _buildPages() {
    return [
      _SitePage(
        label: 'Accueil',
        icon: Icons.home_outlined,
        body: HomePage(
          onIpSearch: () => _selectPage(1),
          onDomainSearch: () => _selectPage(2),
        ),
      ),
      const _SitePage(
        label: 'Recherche IP',
        icon: Icons.travel_explore,
        body: IpSearchPage(),
      ),
      const _SitePage(
        label: 'Recherche domaine',
        icon: Icons.language,
        body: DomainSearchPage(),
      ),
    ];
  }

  void _selectPage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

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
                    for (var i = 0; i < pages.length; i++)
                      _MenuButton(
                        label: pages[i].label,
                        selected: i == _selectedIndex,
                        onPressed: () => _selectPage(i),
                      ),
                    const SizedBox(width: 20),
                  ],
          ),
          drawer: useDrawer
              ? _SiteDrawer(
                  pages: pages,
                  selectedIndex: _selectedIndex,
                  onSelect: _selectPage,
                )
              : null,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(_selectedIndex),
              child: pages[_selectedIndex].body,
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
  const HomePage({super.key, this.onIpSearch, this.onDomainSearch});

  final VoidCallback? onIpSearch;
  final VoidCallback? onDomainSearch;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeIntro(onIpSearch: onIpSearch, onDomainSearch: onDomainSearch),
          const SizedBox(height: 42),
          const _FeatureGrid(),
        ],
      ),
    );
  }
}

class _HomeIntro extends StatelessWidget {
  const _HomeIntro({required this.onIpSearch, required this.onDomainSearch});

  final VoidCallback? onIpSearch;
  final VoidCallback? onDomainSearch;

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
                'Tableau de bord reseau',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Lancez une analyse IP, controlez un domaine et retrouvez les elements utiles pour orienter une requisition.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF4B5563),
                  height: 1.5,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onIpSearch,
                    icon: const Icon(Icons.travel_explore),
                    label: const Text('Recherche IP'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onDomainSearch,
                    icon: const Icon(Icons.language),
                    label: const Text('Recherche domaine'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const _DashboardPanel(),
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
                'Analysez une IP ou un CSV, puis classez les adresses de la plus exploitable a la moins exploitable.',
          ),
          _InfoCard(
            icon: Icons.language,
            title: 'Nom de domaine',
            text:
                'Controlez DNS, RDAP, IP associees, registrar et hebergeur probable.',
          ),
          _InfoCard(
            icon: Icons.assignment_outlined,
            title: 'Pistes de requisition',
            text:
                'Reperez rapidement le fournisseur a contacter et les donnees a demander.',
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
  const IpSearchPage({
    super.key,
    this.api = const IpAnalysisApi(),
    this.initialCsvFileName,
    this.initialCsvText,
  });

  final IpAnalysisApi api;
  final String? initialCsvFileName;
  final String? initialCsvText;

  @override
  State<IpSearchPage> createState() => _IpSearchPageState();
}

class _IpSearchPageState extends State<IpSearchPage> {
  static const _maxCsvBytes = 1000000;

  final _ipController = TextEditingController();

  _IpSearchMode _mode = _IpSearchMode.single;
  _IpSearchStatus _status = _IpSearchStatus.idle;
  Map<String, dynamic>? _response;
  String? _errorMessage;
  String? _csvFileName;
  String? _csvText;

  @override
  void initState() {
    super.initState();
    _csvFileName = widget.initialCsvFileName;
    _csvText = widget.initialCsvText;
  }

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
    await _runSearch(() => widget.api.analyzeIp(ip));
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
    await _runSearch(() => widget.api.analyzeCsv(csvText));
  }

  Future<void> _runSearch(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    if (!widget.api.isConfigured) {
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
          if (!widget.api.isConfigured) ...[
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

  Future<Map<String, dynamic>> analyzeDomain(String domain) {
    return _post('/analyze-domain', {'domain': domain});
  }

  Future<Map<String, dynamic>> analyzeDomainCsv(String csvText) {
    return _post('/analyze-domains', {'csv': csvText});
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
    return _ResultSurface(child: _IpResultDetailContent(result: result));
  }
}

class IpDetailPage extends StatelessWidget {
  const IpDetailPage({super.key, required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final viewModel = _IpResultViewModel(result);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black26,
        title: Text('Detail IP ${viewModel.ip}'),
      ),
      body: _PageFrame(
        child: _ResultSurface(child: _IpResultDetailContent(result: result)),
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

class _IpResultDetailContent extends StatelessWidget {
  const _IpResultDetailContent({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final viewModel = _IpResultViewModel(result);
    final reasons = _stringList(viewModel.analysis['reasons']);
    final requirements = _stringList(result['identity_requirements']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IpDetailHeader(viewModel: viewModel),
        const SizedBox(height: 16),
        if (!viewModel.ok) ...[
          _InlineErrorBlock(
            message: viewModel.errorText ?? 'Analyse IP impossible.',
          ),
        ] else ...[
          _KeyValueWrap(
            values: {
              'Type': viewModel.ipVersionLabel,
              'Pays': viewModel.country,
              'Ville': viewModel.city,
              'Operateur': viewModel.operatorName,
              'Organisation': viewModel.organization,
              'ASN': viewModel.asn,
              'Categorie': viewModel.category,
              'Score': viewModel.scoreText,
              'Valeur': viewModel.investigativeValue,
              'Confiance': viewModel.confidence,
              'Occurrences': viewModel.occurrences,
            },
          ),
          const SizedBox(height: 18),
          if (viewModel.isIpv4) ...[
            const _Ipv4PortRequirementNotice(),
            const SizedBox(height: 18),
          ],
          _FlagChips(flags: viewModel.flags),
          const SizedBox(height: 18),
          _TextList(title: 'Raisons', items: reasons),
          const SizedBox(height: 18),
          _TextList(title: 'Pour aller plus loin', items: requirements),
        ],
      ],
    );
  }
}

class _IpDetailHeader extends StatelessWidget {
  const _IpDetailHeader({required this.viewModel});

  final _IpResultViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultTitle(title: viewModel.ip),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _CategoryBadge(
                  label: viewModel.categoryOrError,
                  error: !viewModel.ok,
                ),
                if (viewModel.ipVersionLabel != null)
                  _IpVersionBadge(label: viewModel.ipVersionLabel!),
                _ScorePill(score: viewModel.score),
              ],
            ),
          ],
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => _copyIp(context, viewModel),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copier l IP'),
            ),
            FilledButton.icon(
              onPressed: () => _copySummary(context, viewModel),
              icon: const Icon(Icons.summarize, size: 18),
              label: const Text('Copier le resume'),
            ),
          ],
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              actions,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 14), actions],
        );
      },
    );
  }
}

class _InlineErrorBlock extends StatelessWidget {
  const _InlineErrorBlock({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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

class _Ipv4PortRequirementNotice extends StatelessWidget {
  const _Ipv4PortRequirementNotice();

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
      child: Text(
        'IPv4: indiquez idealement le port source avec l IP, la date, l heure et le fuseau horaire. Sans port source, une requisition peut ne pas suffire, notamment en cas de partage d adresse ou de CGNAT.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF92400E),
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
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
        for (final item in priorities) ...[
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

    final sortedResults = _sortIpResultsByInvestigativeValue(results);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Resultats',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${sortedResults.length}/${results.length} affiches',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 760) {
              return _DesktopIpResultsTable(results: sortedResults);
            }
            return _MobileIpResultCards(results: sortedResults);
          },
        ),
      ],
    );
  }
}

List<Map<String, dynamic>> _sortIpResultsByInvestigativeValue(
  List<Map<String, dynamic>> results,
) {
  return [...results]..sort(_compareIpResults);
}

int _compareIpResults(Map<String, dynamic> left, Map<String, dynamic> right) {
  final leftModel = _IpResultViewModel(left);
  final rightModel = _IpResultViewModel(right);

  if (leftModel.ok != rightModel.ok) {
    return leftModel.ok ? -1 : 1;
  }

  final valueCompare = _investigativeValueRank(
    leftModel.investigativeValue,
  ).compareTo(_investigativeValueRank(rightModel.investigativeValue));
  if (valueCompare != 0) {
    return valueCompare;
  }

  final originCompare = _originVisibilityRank(
    leftModel.originIpVisible,
  ).compareTo(_originVisibilityRank(rightModel.originIpVisible));
  if (originCompare != 0) {
    return originCompare;
  }

  final scoreCompare = (rightModel.score ?? -1).compareTo(
    leftModel.score ?? -1,
  );
  if (scoreCompare != 0) {
    return scoreCompare;
  }

  final occurrenceCompare = (rightModel.occurrences ?? 0).compareTo(
    leftModel.occurrences ?? 0,
  );
  if (occurrenceCompare != 0) {
    return occurrenceCompare;
  }

  return leftModel.ip.compareTo(rightModel.ip);
}

int _investigativeValueRank(String? value) {
  switch (value?.toLowerCase().trim()) {
    case 'elevee':
    case 'haute':
    case 'high':
      return 0;
    case 'moyenne':
    case 'medium':
      return 1;
    case 'faible':
    case 'low':
      return 2;
  }
  return 3;
}

int _originVisibilityRank(bool? value) {
  if (value == true) {
    return 0;
  }
  if (value == false) {
    return 1;
  }
  return 2;
}

class _DesktopIpResultsTable extends StatefulWidget {
  const _DesktopIpResultsTable({required this.results});

  final List<Map<String, dynamic>> results;

  @override
  State<_DesktopIpResultsTable> createState() => _DesktopIpResultsTableState();
}

class _DesktopIpResultsTableState extends State<_DesktopIpResultsTable> {
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Scrollbar(
        controller: _horizontalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            columnSpacing: 18,
            horizontalMargin: 12,
            dataRowMinHeight: 64,
            dataRowMaxHeight: 76,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
            columns: const [
              DataColumn(label: Text('Priorite')),
              DataColumn(label: Text('IP')),
              DataColumn(label: Text('Cible')),
              DataColumn(label: Text('Localisation')),
              DataColumn(label: Text('Occurrences')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final result in widget.results)
                _buildIpDataRow(context: context, result: result),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _buildIpDataRow({
    required BuildContext context,
    required Map<String, dynamic> result,
  }) {
    final viewModel = _IpResultViewModel(result);

    return DataRow(
      onSelectChanged: (_) => _openIpDetail(context, result),
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFFEFF6FF);
        }
        if (!viewModel.ok) {
          return const Color(0xFFFFFBFB);
        }
        return null;
      }),
      cells: [
        DataCell(_ReliabilityBadge(viewModel: viewModel)),
        DataCell(
          SizedBox(
            width: 170,
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  viewModel.ip,
                  key: ValueKey('ip-row-${viewModel.ip}'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (viewModel.ipVersionLabel != null)
                  _IpVersionBadge(label: viewModel.ipVersionLabel!),
              ],
            ),
          ),
        ),
        DataCell(_TableText(viewModel.requisitionTarget, width: 210)),
        DataCell(_TableText(viewModel.locationText, width: 170)),
        DataCell(Text(viewModel.occurrencesText)),
        DataCell(_IpRowActions(result: result, viewModel: viewModel)),
      ],
    );
  }
}

class _TableText extends StatelessWidget {
  const _TableText(this.text, {required this.width});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text, overflow: TextOverflow.ellipsis),
    );
  }
}

class _MobileIpResultCards extends StatelessWidget {
  const _MobileIpResultCards({required this.results});

  final List<Map<String, dynamic>> results;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final result in results) ...[
          _MobileIpResultCard(result: result),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MobileIpResultCard extends StatelessWidget {
  const _MobileIpResultCard({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final viewModel = _IpResultViewModel(result);

    return Container(
      decoration: BoxDecoration(
        color: viewModel.ok ? const Color(0xFFF9FAFB) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: viewModel.ok
              ? const Color(0xFFE5E7EB)
              : const Color(0xFFFCA5A5),
        ),
      ),
      child: InkWell(
        key: ValueKey('ip-card-${viewModel.ip}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openIpDetail(context, result),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      viewModel.ip,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  _IpRowActions(result: result, viewModel: viewModel),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _ReliabilityBadge(viewModel: viewModel),
                  _CategoryBadge(
                    label: viewModel.categoryOrError,
                    error: !viewModel.ok,
                  ),
                  if (viewModel.ipVersionLabel != null)
                    _IpVersionBadge(label: viewModel.ipVersionLabel!),
                  _ScorePill(score: viewModel.score),
                  Text(viewModel.occurrencesText),
                ],
              ),
              const SizedBox(height: 10),
              Text(viewModel.locationText),
              Text(viewModel.requisitionTarget),
            ],
          ),
        ),
      ),
    );
  }
}

class _IpRowActions extends StatelessWidget {
  const _IpRowActions({required this.result, required this.viewModel});

  final Map<String, dynamic> result;
  final _IpResultViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Copier l IP ${viewModel.ip}',
          onPressed: () => _copyIp(context, viewModel),
          icon: const Icon(Icons.copy, size: 18),
        ),
        IconButton(
          tooltip: 'Voir le detail ${viewModel.ip}',
          onPressed: () => _openIpDetail(context, result),
          icon: const Icon(Icons.open_in_new, size: 18),
        ),
      ],
    );
  }
}

class _ReliabilityBadge extends StatelessWidget {
  const _ReliabilityBadge({required this.viewModel});

  final _IpResultViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final rank = _investigativeValueRank(viewModel.investigativeValue);
    final label = !viewModel.ok
        ? 'Erreur'
        : switch (rank) {
            0 => 'Forte',
            1 => 'Moyenne',
            2 => 'Faible',
            _ => 'Inconnue',
          };
    final color = !viewModel.ok
        ? const Color(0xFF991B1B)
        : switch (rank) {
            0 => const Color(0xFF166534),
            1 => const Color(0xFF92400E),
            2 => const Color(0xFF6B7280),
            _ => const Color(0xFF374151),
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IpVersionBadge extends StatelessWidget {
  const _IpVersionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF1D4ED8),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label, this.error = false});

  final String label;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = error
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFE0F2F1);
    final borderColor = error
        ? const Color(0xFFFCA5A5)
        : const Color(0xFF99F6E4);
    final textColor = error ? const Color(0xFF991B1B) : const Color(0xFF115E59);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    final value = score;
    final color = value == null
        ? const Color(0xFF6B7280)
        : value >= 70
        ? const Color(0xFFB91C1C)
        : value >= 40
        ? const Color(0xFF92400E)
        : const Color(0xFF166534);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        value == null ? 'Score inconnu' : 'Score $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FlagChips extends StatelessWidget {
  const _FlagChips({required this.flags});

  final Map<String, dynamic> flags;

  @override
  Widget build(BuildContext context) {
    if (flags.isEmpty) {
      return const SizedBox.shrink();
    }

    final items = [
      MapEntry('Mobile', _boolValue(flags['is_mobile'])),
      MapEntry('Proxy VPN Tor', _boolValue(flags['is_proxy_or_vpn_or_tor'])),
      MapEntry(
        'Hosting datacenter',
        _boolValue(flags['is_hosting_or_datacenter']),
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          Chip(
            avatar: Icon(
              item.value == true ? Icons.check_circle : Icons.cancel,
              size: 18,
              color: item.value == true
                  ? const Color(0xFF166534)
                  : const Color(0xFF6B7280),
            ),
            label: Text('${item.key}: ${item.value == true ? 'oui' : 'non'}'),
          ),
      ],
    );
  }
}

class _IpResultViewModel {
  const _IpResultViewModel(this.raw);

  final Map<String, dynamic> raw;

  bool get ok => raw['ok'] == true;

  Map<String, dynamic> get location => _mapValue(raw['location']);

  Map<String, dynamic> get network => _mapValue(raw['network']);

  Map<String, dynamic> get analysis => _mapValue(raw['analysis']);

  Map<String, dynamic> get flags => _mapValue(raw['flags']);

  String get ip =>
      _textValue(raw['ip']) ?? _textValue(raw['input']) ?? 'IP inconnue';

  String? get errorText => _textValue(raw['error']);

  String? get country => _textValue(location['country']);

  String? get city => _textValue(location['city']);

  String? get operatorName => _textValue(network['isp']) ?? organization;

  String? get organization => _textValue(network['org']);

  String? get asn =>
      _textValue(network['asn_full']) ?? _textValue(network['asn']);

  String? get category => _textValue(analysis['category']);

  String get categoryOrError {
    if (!ok) {
      return errorText ?? 'Erreur analyse';
    }
    return category ?? 'Categorie inconnue';
  }

  int? get score => _intValue(analysis['score']);

  String get scoreText => score?.toString() ?? 'Non note';

  String? get investigativeValue => _textValue(analysis['investigative_value']);

  bool? get originIpVisible => _boolValue(analysis['origin_ip_visible']);

  String? get confidence => _textValue(analysis['confidence']);

  int? get occurrences => _intValue(raw['occurrences']);

  bool get isIpv6 => ip.contains(':');

  bool get isIpv4 => !isIpv6 && ip.contains('.');

  String? get ipVersionLabel {
    if (isIpv6) {
      return 'IPv6';
    }
    if (isIpv4) {
      return 'IPv4';
    }
    return null;
  }

  String get locationText {
    final countryText = country;
    final cityText = city;
    final parts = [?countryText, ?cityText];
    return parts.isEmpty ? 'Localisation inconnue' : parts.join(', ');
  }

  String get requisitionTarget {
    if (!ok) {
      return errorText ?? 'Analyse impossible';
    }
    final org = _lowerText(organization);
    if (org.contains('icloud private relay')) {
      return 'Apple / Akamai';
    }
    if (org.contains('warp')) {
      return 'Cloudflare';
    }
    if (_boolValue(flags['is_mobile']) == true) {
      return operatorName ?? 'Operateur mobile';
    }
    return operatorName ?? organization ?? 'Fournisseur reseau a determiner';
  }

  String get occurrencesText {
    final count = occurrences;
    if (count == null) {
      return 'Occurrence inconnue';
    }
    return count > 1 ? '$count occurrences' : '1 occurrence';
  }

  String get summaryText {
    final entries = <MapEntry<String, String?>>[
      MapEntry('IP', ip),
      MapEntry('Pays', country),
      MapEntry('Ville', city),
      MapEntry('Operateur', operatorName),
      MapEntry('ASN', asn),
      MapEntry('Categorie', ok ? category : errorText),
      MapEntry('Score', scoreText),
      MapEntry('Valeur investigative', investigativeValue),
      MapEntry('Confiance', confidence),
    ];

    return entries
        .where((entry) => entry.value != null && entry.value!.isNotEmpty)
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
  }
}

void _openIpDetail(BuildContext context, Map<String, dynamic> result) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) =>
          IpDetailPage(result: Map<String, dynamic>.from(result)),
    ),
  );
}

Future<void> _copyIp(BuildContext context, _IpResultViewModel viewModel) async {
  await _copyText(context, viewModel.ip, 'IP');
}

Future<void> _copySummary(
  BuildContext context,
  _IpResultViewModel viewModel,
) async {
  await _copyText(context, viewModel.summaryText, 'Resume');
}

Future<void> _copyText(BuildContext context, String text, String label) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$label copie dans le presse-papiers.')),
  );
}

String? _textValue(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

String _lowerText(Object? value) {
  return value?.toString().trim().toLowerCase() ?? '';
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '');
}

bool? _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final normalized = value.toLowerCase().trim();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  return null;
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

class DomainSearchPage extends StatefulWidget {
  const DomainSearchPage({
    super.key,
    this.api = const IpAnalysisApi(),
    this.initialCsvFileName,
    this.initialCsvText,
  });

  final IpAnalysisApi api;
  final String? initialCsvFileName;
  final String? initialCsvText;

  @override
  State<DomainSearchPage> createState() => _DomainSearchPageState();
}

class _DomainSearchPageState extends State<DomainSearchPage> {
  static const _maxCsvBytes = 1000000;

  final _domainController = TextEditingController();

  _DomainSearchMode _mode = _DomainSearchMode.single;
  _IpSearchStatus _status = _IpSearchStatus.idle;
  Map<String, dynamic>? _response;
  String? _errorMessage;
  String? _csvFileName;
  String? _csvText;

  @override
  void initState() {
    super.initState();
    _csvFileName = widget.initialCsvFileName;
    _csvText = widget.initialCsvText;
  }

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  void _setMode(_DomainSearchMode mode) {
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

  Future<void> _runSingleDomainSearch() async {
    final domain = _domainController.text.trim();
    if (domain.isEmpty) {
      setState(() {
        _status = _IpSearchStatus.error;
        _errorMessage = 'Saisissez un nom de domaine.';
      });
      return;
    }
    await _runSearch(() => widget.api.analyzeDomain(domain));
  }

  Future<void> _runCsvSearch() async {
    final csvText = _csvText;
    if (csvText == null || csvText.trim().isEmpty) {
      setState(() {
        _status = _IpSearchStatus.error;
        _errorMessage = 'Selectionnez un fichier CSV contenant des domaines.';
      });
      return;
    }
    await _runSearch(() => widget.api.analyzeDomainCsv(csvText));
  }

  Future<void> _runSearch(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    if (!widget.api.isConfigured) {
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
          const _DomainSearchHeader(),
          const SizedBox(height: 22),
          if (!widget.api.isConfigured) ...[
            const _ConfigurationNotice(),
            const SizedBox(height: 18),
          ],
          _DomainModeSelector(selected: _mode, onChanged: _setMode),
          const SizedBox(height: 18),
          if (_mode == _DomainSearchMode.single)
            _SingleDomainForm(
              controller: _domainController,
              loading: _status == _IpSearchStatus.loading,
              onSubmit: _runSingleDomainSearch,
            )
          else
            _CsvForm(
              fileName: _csvFileName,
              loading: _status == _IpSearchStatus.loading,
              onPick: _pickCsv,
              onSubmit: _runCsvSearch,
            ),
          const SizedBox(height: 22),
          _DomainResultPanel(
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

enum _DomainSearchMode { single, csv }

class _DomainSearchHeader extends StatelessWidget {
  const _DomainSearchHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 24,
          backgroundColor: Color(0xFFE0F2F1),
          child: Icon(Icons.language, color: Color(0xFF0F766E)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recherche nom de domaine',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Collectez DNS, RDAP, IP, hebergeur probable, certificats et contacts publics.',
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

class _DomainModeSelector extends StatelessWidget {
  const _DomainModeSelector({required this.selected, required this.onChanged});

  final _DomainSearchMode selected;
  final ValueChanged<_DomainSearchMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ChoiceChip(
          label: const Text('Nom de domaine'),
          selected: selected == _DomainSearchMode.single,
          onSelected: (_) => onChanged(_DomainSearchMode.single),
        ),
        ChoiceChip(
          label: const Text('Fichier CSV'),
          selected: selected == _DomainSearchMode.csv,
          onSelected: (_) => onChanged(_DomainSearchMode.csv),
        ),
      ],
    );
  }
}

class _SingleDomainForm extends StatelessWidget {
  const _SingleDomainForm({
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
              labelText: 'Nom de domaine',
              hintText: 'Exemple: example.com',
            ),
          );
          final button = FilledButton(
            onPressed: loading ? null : onSubmit,
            child: const Text('Rechercher le domaine'),
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

class _DomainResultPanel extends StatelessWidget {
  const _DomainResultPanel({
    required this.mode,
    required this.status,
    required this.response,
    required this.errorMessage,
  });

  final _DomainSearchMode mode;
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
            Expanded(child: Text('Analyse domaine en cours...')),
          ],
        ),
      );
    }

    if (status == _IpSearchStatus.error) {
      return _ErrorResultSurface(message: errorMessage ?? 'Erreur inconnue.');
    }

    if (status == _IpSearchStatus.success && response != null) {
      if (mode == _DomainSearchMode.csv) {
        return _DomainCsvResult(response: response!);
      }
      final result = response!['result'];
      if (result is Map<String, dynamic>) {
        return _SingleDomainResult(result: result);
      }
      return const _ErrorResultSurface(message: 'Reponse domaine illisible.');
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
            'Lancez une recherche pour afficher le DNS, le registrar, les IP, l hebergeur probable et les contacts publics.',
            style: TextStyle(color: Color(0xFFD1D5DB), height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SingleDomainResult extends StatelessWidget {
  const _SingleDomainResult({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    return _ResultSurface(child: _DomainResultDetailContent(result: result));
  }
}

class DomainDetailPage extends StatelessWidget {
  const DomainDetailPage({super.key, required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final viewModel = _DomainResultViewModel(result);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black26,
        title: Text('Detail domaine ${viewModel.domain}'),
      ),
      body: _PageFrame(
        child: _ResultSurface(
          child: _DomainResultDetailContent(result: result),
        ),
      ),
    );
  }
}

class _DomainCsvResult extends StatelessWidget {
  const _DomainCsvResult({required this.response});

  final Map<String, dynamic> response;

  @override
  Widget build(BuildContext context) {
    if (response['ok'] != true) {
      return _ErrorResultSurface(
        message: response['error']?.toString() ?? 'Analyse CSV impossible.',
      );
    }

    final summary = _mapValue(response['summary']);
    final registrars = _mapValue(summary['registrars']);
    final hostingProviders = _mapValue(summary['hosting_providers']);
    final ownerVisibility = _mapValue(summary['owner_visibility']);
    final priorities = _mapList(summary['priority_domains']);
    final results = _mapList(response['results']);

    return _ResultSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ResultTitle(title: 'Resume des domaines'),
          const SizedBox(height: 16),
          _KeyValueWrap(
            values: {
              'Domaines': response['input_count'],
              'Domaines uniques': response['unique_count'],
              'Analyses OK': summary['ok'],
              'Erreurs': summary['errors'],
            },
          ),
          if (registrars.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle('Registrars'),
            const SizedBox(height: 10),
            _CategoryChips(categories: registrars),
          ],
          if (hostingProviders.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle('Hebergeurs probables'),
            const SizedBox(height: 10),
            _CategoryChips(categories: hostingProviders),
          ],
          if (ownerVisibility.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionTitle('Visibilite proprietaire'),
            const SizedBox(height: 10),
            _CategoryChips(categories: ownerVisibility),
          ],
          if (priorities.isNotEmpty) ...[
            const SizedBox(height: 18),
            _DomainPriorityList(priorities: priorities),
          ],
          const SizedBox(height: 18),
          _DomainResultList(results: results),
        ],
      ),
    );
  }
}

class _DomainResultDetailContent extends StatelessWidget {
  const _DomainResultDetailContent({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final viewModel = _DomainResultViewModel(result);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DomainDetailHeader(viewModel: viewModel),
        const SizedBox(height: 16),
        if (!viewModel.ok) ...[
          _InlineErrorBlock(
            message: viewModel.errorText ?? 'Analyse domaine impossible.',
          ),
        ] else ...[
          _KeyValueWrap(
            values: {
              'Registrar': viewModel.registrar,
              'Proprietaire': viewModel.ownerVisibilityLabel,
              'Hebergeur': viewModel.hostingProvider,
              'CDN/proxy': viewModel.cdnText,
              'IP trouvees': viewModel.ipCountText,
              'Creation': viewModel.createdAt,
              'Expiration': viewModel.expiresAt,
              'HTTP': viewModel.httpStatusText,
              'TLS': viewModel.tlsText,
              'SPF': viewModel.spfText,
              'DMARC': viewModel.dmarcText,
              'DNSSEC': viewModel.dnssecText,
              'Sous-domaines CT': viewModel.ctSubdomainCountText,
              'Occurrences': viewModel.occurrences,
            },
          ),
          const SizedBox(height: 18),
          _TextList(
            title: 'Indices hebergement',
            items: viewModel.hostingEvidence,
          ),
          const SizedBox(height: 18),
          _DomainContactsList(contacts: viewModel.publicContacts),
          const SizedBox(height: 18),
          _DomainDnsSummary(dns: viewModel.dns),
          const SizedBox(height: 18),
          _DomainIpSummary(ips: viewModel.ips),
          const SizedBox(height: 18),
          _TextList(title: 'Limites et suite', items: viewModel.limitations),
          if (viewModel.hasNonPublicOwner) ...[
            const SizedBox(height: 18),
            _DomainRequisitionGuidance(viewModel: viewModel),
          ],
        ],
      ],
    );
  }
}

class _DomainDetailHeader extends StatelessWidget {
  const _DomainDetailHeader({required this.viewModel});

  final _DomainResultViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultTitle(title: viewModel.domain),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _CategoryBadge(
                  label: viewModel.ok
                      ? viewModel.ownerVisibilityLabel
                      : viewModel.categoryOrError,
                  error: !viewModel.ok,
                ),
                if (viewModel.isCdnOrProxy)
                  const _CategoryBadge(label: 'CDN/proxy probable'),
              ],
            ),
          ],
        );
        final actions = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => _copyDomain(context, viewModel),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copier le domaine'),
            ),
            FilledButton.icon(
              onPressed: () => _copyDomainSummary(context, viewModel),
              icon: const Icon(Icons.summarize, size: 18),
              label: const Text('Copier le resume'),
            ),
          ],
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              actions,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, const SizedBox(height: 14), actions],
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: const Color(0xFF111827),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _DomainPriorityList extends StatelessWidget {
  const _DomainPriorityList({required this.priorities});

  final List<Map<String, dynamic>> priorities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Domaines a traiter'),
        const SizedBox(height: 10),
        for (final item in priorities.take(8)) ...[
          Text(
            '${item['domain']} - ${item['registrar']} - ${item['owner_visibility']}',
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

class _DomainResultList extends StatelessWidget {
  const _DomainResultList({required this.results});

  final List<Map<String, dynamic>> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Text('Aucun resultat.');
    }

    final visibleResults = results.take(30).toList();
    final hiddenCount = results.length - visibleResults.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Resultats',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${visibleResults.length}/${results.length} affiches',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 760) {
              return _DesktopDomainResultsTable(results: visibleResults);
            }
            return _MobileDomainResultCards(results: visibleResults);
          },
        ),
        if (hiddenCount > 0) ...[
          const SizedBox(height: 10),
          Text(
            '$hiddenCount resultats supplementaires non affiches.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B7280)),
          ),
        ],
      ],
    );
  }
}

class _DesktopDomainResultsTable extends StatelessWidget {
  const _DesktopDomainResultsTable({required this.results});

  final List<Map<String, dynamic>> results;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
          columns: const [
            DataColumn(label: Text('Domaine')),
            DataColumn(label: Text('Registrar')),
            DataColumn(label: Text('Hebergeur')),
            DataColumn(label: Text('Proprietaire')),
            DataColumn(label: Text('IP')),
            DataColumn(label: Text('HTTP')),
            DataColumn(label: Text('Actions')),
          ],
          rows: [
            for (final result in results)
              _buildDomainDataRow(context: context, result: result),
          ],
        ),
      ),
    );
  }

  DataRow _buildDomainDataRow({
    required BuildContext context,
    required Map<String, dynamic> result,
  }) {
    final viewModel = _DomainResultViewModel(result);

    return DataRow(
      onSelectChanged: (_) => _openDomainDetail(context, result),
      color: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFFEFF6FF);
        }
        if (!viewModel.ok) {
          return const Color(0xFFFFFBFB);
        }
        return null;
      }),
      cells: [
        DataCell(
          SizedBox(
            width: 170,
            child: Text(
              viewModel.domain,
              key: ValueKey('domain-row-${viewModel.domain}'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        DataCell(_TableText(viewModel.registrar ?? 'Inconnu', width: 170)),
        DataCell(
          _TableText(viewModel.hostingProvider ?? 'Inconnu', width: 170),
        ),
        DataCell(
          SizedBox(
            width: 190,
            child: _CategoryBadge(
              label: viewModel.categoryOrError,
              error: !viewModel.ok,
            ),
          ),
        ),
        DataCell(Text(viewModel.ipCountText)),
        DataCell(Text(viewModel.httpStatusText)),
        DataCell(_DomainRowActions(result: result, viewModel: viewModel)),
      ],
    );
  }
}

class _MobileDomainResultCards extends StatelessWidget {
  const _MobileDomainResultCards({required this.results});

  final List<Map<String, dynamic>> results;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final result in results) ...[
          _MobileDomainResultCard(result: result),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MobileDomainResultCard extends StatelessWidget {
  const _MobileDomainResultCard({required this.result});

  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final viewModel = _DomainResultViewModel(result);

    return Container(
      decoration: BoxDecoration(
        color: viewModel.ok ? const Color(0xFFF9FAFB) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: viewModel.ok
              ? const Color(0xFFE5E7EB)
              : const Color(0xFFFCA5A5),
        ),
      ),
      child: InkWell(
        key: ValueKey('domain-card-${viewModel.domain}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openDomainDetail(context, result),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      viewModel.domain,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  _DomainRowActions(result: result, viewModel: viewModel),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _CategoryBadge(
                    label: viewModel.categoryOrError,
                    error: !viewModel.ok,
                  ),
                  Text(viewModel.ipCountText),
                  Text(viewModel.httpStatusText),
                ],
              ),
              const SizedBox(height: 10),
              Text(viewModel.registrar ?? 'Registrar inconnu'),
              Text(viewModel.hostingProvider ?? 'Hebergeur inconnu'),
            ],
          ),
        ),
      ),
    );
  }
}

class _DomainRowActions extends StatelessWidget {
  const _DomainRowActions({required this.result, required this.viewModel});

  final Map<String, dynamic> result;
  final _DomainResultViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Copier le domaine ${viewModel.domain}',
          onPressed: () => _copyDomain(context, viewModel),
          icon: const Icon(Icons.copy, size: 18),
        ),
        IconButton(
          tooltip: 'Voir le detail ${viewModel.domain}',
          onPressed: () => _openDomainDetail(context, result),
          icon: const Icon(Icons.open_in_new, size: 18),
        ),
      ],
    );
  }
}

class _DomainContactsList extends StatelessWidget {
  const _DomainContactsList({required this.contacts});

  final List<Map<String, dynamic>> contacts;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Contacts publics'),
        const SizedBox(height: 10),
        for (final contact in contacts.take(8)) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              _formatDomainContact(contact),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF374151),
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _DomainDnsSummary extends StatelessWidget {
  const _DomainDnsSummary({required this.dns});

  final Map<String, dynamic> dns;

  @override
  Widget build(BuildContext context) {
    final records = _mapValue(dns['records']);
    final items = <String>[];
    for (final type in [
      'A',
      'AAAA',
      'CNAME',
      'NS',
      'MX',
      'TXT',
      'SOA',
      'CAA',
    ]) {
      final entry = _mapValue(records[type]);
      final values = _stringList(entry['records']);
      if (values.isNotEmpty) {
        items.add('$type: ${values.take(3).join(', ')}');
      }
    }

    return _TextList(title: 'DNS', items: items);
  }
}

class _DomainIpSummary extends StatelessWidget {
  const _DomainIpSummary({required this.ips});

  final List<Map<String, dynamic>> ips;

  @override
  Widget build(BuildContext context) {
    final items = ips.take(8).map((item) {
      final viewModel = _IpResultViewModel(item);
      return '${viewModel.ip} - ${viewModel.operatorName ?? 'operateur inconnu'} - ${viewModel.country ?? 'pays inconnu'}';
    }).toList();

    return _TextList(title: 'IP associees', items: items);
  }
}

class _DomainRequisitionGuidance extends StatelessWidget {
  const _DomainRequisitionGuidance({required this.viewModel});

  final _DomainResultViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final registrar = viewModel.registrar ?? 'non determine';
    final hosting = viewModel.hostingProvider ?? 'non determine';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Pistes de requisition'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registrar detecte: $registrar',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hebergeur web probable: $hosting',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Le registrar peut etre requis pour obtenir l identite et les coordonnees declarees du titulaire. Ces donnees sont declaratives et ne sont pas forcement verifiees par le registrar.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF374151),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'La demande peut aussi viser les moyens de paiement utilises pour acheter ou renouveler le nom de domaine.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF374151),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'L hebergeur web probable est estime avec les donnees DNS, les IP associees, l ASN, l organisation reseau, les CNAME et les indices CDN/proxy.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF374151),
                  height: 1.45,
                ),
              ),
              if (viewModel.isCdnOrProxy) ...[
                const SizedBox(height: 8),
                Text(
                  'CDN/proxy probable: les IP visibles peuvent ne pas etre celles du serveur d origine.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF92400E),
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DomainResultViewModel {
  const _DomainResultViewModel(this.raw);

  final Map<String, dynamic> raw;

  bool get ok => raw['ok'] == true;

  String get domain =>
      _textValue(raw['domain']) ??
      _textValue(raw['input']) ??
      'Domaine inconnu';

  String? get errorText => _textValue(raw['error']);

  Map<String, dynamic> get summary => _mapValue(raw['summary']);

  Map<String, dynamic> get dns => _mapValue(raw['dns']);

  Map<String, dynamic> get rdap => _mapValue(raw['rdap']);

  Map<String, dynamic> get hosting => _mapValue(raw['hosting']);

  Map<String, dynamic> get http => _mapValue(raw['http']);

  Map<String, dynamic> get tls => _mapValue(raw['tls']);

  Map<String, dynamic> get certificateTransparency =>
      _mapValue(raw['certificate_transparency']);

  Map<String, dynamic> get contactWorkflow =>
      _mapValue(raw['contact_workflow']);

  List<Map<String, dynamic>> get ips => _mapList(raw['ips']);

  List<Map<String, dynamic>> get publicContacts =>
      _mapList(contactWorkflow['public_contacts']);

  List<String> get hostingEvidence => _stringList(hosting['evidence']);

  List<String> get limitations => _stringList(contactWorkflow['limitations']);

  String? get registrar =>
      _textValue(summary['registrar']) ?? _textValue(rdap['registrar']);

  String? get hostingProvider =>
      _textValue(summary['hosting_provider']) ??
      _textValue(hosting['probable_provider']);

  String? get createdAt =>
      _textValue(summary['created_at']) ?? _textValue(rdap['created_at']);

  String? get expiresAt =>
      _textValue(summary['expires_at']) ?? _textValue(rdap['expires_at']);

  String? get ownerVisibility =>
      _textValue(contactWorkflow['owner_visibility']) ??
      _textValue(summary['owner_visibility']);

  String get ownerVisibilityLabel {
    switch (ownerVisibility) {
      case 'public':
        return 'Proprietaire public';
      case 'partial':
        return 'Proprietaire partiel';
      case 'redacted':
        return 'Proprietaire masque';
      case 'unknown':
        return 'Proprietaire inconnu';
    }
    return ownerVisibility ?? 'Proprietaire inconnu';
  }

  String get categoryOrError {
    if (!ok) {
      return errorText ?? 'Erreur analyse';
    }
    return ownerVisibilityLabel;
  }

  int? get ipCount =>
      _intValue(summary['ip_count']) ?? (ips.isEmpty ? null : ips.length);

  String get ipCountText {
    final count = ipCount;
    if (count == null) {
      return 'IP inconnues';
    }
    return count > 1 ? '$count IP' : '$count IP';
  }

  bool get isCdnOrProxy =>
      _boolValue(summary['cdn_or_proxy']) ??
      _boolValue(hosting['is_cdn_or_proxy_probable']) ??
      false;

  String get cdnText => isCdnOrProxy ? 'probable' : 'non detecte';

  String get httpStatusText {
    final status =
        _textValue(summary['http_status']) ?? _textValue(http['status']);
    return status == null ? 'HTTP inconnu' : 'HTTP $status';
  }

  String get tlsText {
    if (_boolValue(tls['ok']) != true) {
      return 'TLS indisponible';
    }
    final days =
        _intValue(summary['tls_expires_in_days']) ??
        _intValue(tls['expires_in_days']);
    if (days == null) {
      return 'TLS valide';
    }
    return 'expire dans $days j';
  }

  String get spfText => _boolLabel(_boolValue(summary['has_spf']));

  String get dmarcText => _boolLabel(_boolValue(summary['has_dmarc']));

  String get dnssecText => _boolLabel(_boolValue(summary['dnssec']));

  String get ctSubdomainCountText {
    final count =
        _intValue(summary['ct_subdomain_count']) ??
        _intValue(certificateTransparency['subdomain_count']);
    return count?.toString() ?? 'Inconnu';
  }

  int? get occurrences => _intValue(raw['occurrences']);

  bool get hasNonPublicOwner {
    switch (ownerVisibility) {
      case 'public':
        return false;
      case 'partial':
      case 'redacted':
      case 'unknown':
      case null:
        return true;
    }
    return true;
  }

  String get summaryText {
    final entries = <MapEntry<String, String?>>[
      MapEntry('Domaine', domain),
      MapEntry('Registrar', registrar),
      MapEntry('Proprietaire', ownerVisibilityLabel),
      MapEntry('Hebergeur probable', hostingProvider),
      MapEntry('CDN/proxy', cdnText),
      MapEntry('IP trouvees', ipCountText),
      MapEntry('Creation', createdAt),
      MapEntry('Expiration', expiresAt),
      MapEntry('HTTP', httpStatusText),
      MapEntry('TLS', tlsText),
      MapEntry('SPF', spfText),
      MapEntry('DMARC', dmarcText),
      MapEntry('DNSSEC', dnssecText),
      MapEntry('Sous-domaines CT', ctSubdomainCountText),
    ];

    return entries
        .where((entry) => entry.value != null && entry.value!.isNotEmpty)
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
  }
}

String _boolLabel(bool? value) {
  if (value == true) {
    return 'oui';
  }
  if (value == false) {
    return 'non';
  }
  return 'inconnu';
}

String _formatDomainContact(Map<String, dynamic> contact) {
  final roles = _stringList(contact['roles']).join(', ');
  final entries = <String>[
    if (roles.isNotEmpty) 'Roles: $roles',
    if (_textValue(contact['name']) != null)
      'Nom: ${_textValue(contact['name'])}',
    if (_textValue(contact['organization']) != null)
      'Organisation: ${_textValue(contact['organization'])}',
    if (_textValue(contact['email']) != null)
      'Email: ${_textValue(contact['email'])}',
    if (_textValue(contact['phone']) != null)
      'Telephone: ${_textValue(contact['phone'])}',
  ];
  return entries.join('\n');
}

void _openDomainDetail(BuildContext context, Map<String, dynamic> result) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) =>
          DomainDetailPage(result: Map<String, dynamic>.from(result)),
    ),
  );
}

Future<void> _copyDomain(
  BuildContext context,
  _DomainResultViewModel viewModel,
) async {
  await _copyText(context, viewModel.domain, 'Domaine');
}

Future<void> _copyDomainSummary(
  BuildContext context,
  _DomainResultViewModel viewModel,
) async {
  await _copyText(context, viewModel.summaryText, 'Resume');
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

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel();

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
          _MetricLine(label: 'CSV IP', value: '100 IP uniques max'),
          SizedBox(height: 16),
          _MetricLine(label: 'CSV domaines', value: '50 domaines max'),
          SizedBox(height: 16),
          _MetricLine(label: 'Resultats', value: 'tries par fiabilite'),
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
