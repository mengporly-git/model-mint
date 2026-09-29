import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/model_generator.dart';

void main() => runApp(const ModelMintApp());

class ModelMintApp extends StatelessWidget {
  const ModelMintApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17201B);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ModelMint — JSON to Dart',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF43D19E),
          surface: const Color(0xFFF7F9F6),
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F4F0),
        fontFamily: 'Arial',
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: ink,
          displayColor: ink,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          isDense: true,
        ),
      ),
      home: const ConverterPage(),
    );
  }
}

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  static const ink = Color(0xFF17201B);
  static const muted = Color(0xFF66726B);
  static const mint = Color(0xFF43D19E);
  static const border = Color(0xFFDCE3DC);
  static const sampleJson = '''{
  "greeting": "Welcome to quicktype!",
  "instructions": [
    "Type or paste JSON here",
    "Or choose a sample above",
    "quicktype will generate code in your",
    "chosen language to parse the sample data"
  ]
}''';

  final generator = DartModelGenerator();
  final jsonController = TextEditingController(text: sampleJson);
  final outputController = TextEditingController();
  final classController = TextEditingController(text: 'Response');
  String? error;
  int classCount = 0;
  bool liveConvert = true;
  bool copied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => convert());
  }

  @override
  void dispose() {
    jsonController.dispose();
    outputController.dispose();
    classController.dispose();
    super.dispose();
  }

  void convert() {
    try {
      final source = jsonController.text.trim();
      if (source.isEmpty) {
        setState(() {
          outputController.clear();
          error = null;
          classCount = 0;
        });
        return;
      }
      final result = generator.generate(
        json: jsonDecode(source),
        rootClassName: classController.text,
      );
      setState(() {
        outputController.text = result.code;
        classCount = result.classCount;
        error = null;
        copied = false;
      });
    } on FormatException catch (exception) {
      setState(() {
        error = friendlyError(exception);
        classCount = 0;
      });
    } catch (exception) {
      setState(() {
        error = 'Invalid JSON. Check the structure and try again. ($exception)';
        classCount = 0;
      });
    }
  }

  String friendlyError(FormatException exception) {
    final offset = exception.offset;
    if (offset == null) return exception.message;
    final before = jsonController.text.substring(
      0,
      offset.clamp(0, jsonController.text.length),
    );
    final line = '\n'.allMatches(before).length + 1;
    final column = before.length - before.lastIndexOf('\n');
    return 'Invalid JSON at line $line, column $column. ${exception.message}';
  }

  void formatJson() {
    try {
      jsonController.text = const JsonEncoder.withIndent('  ')
          .convert(jsonDecode(jsonController.text));
      convert();
    } on FormatException catch (exception) {
      setState(() => error = friendlyError(exception));
    }
  }

  Future<void> copyOutput() async {
    if (outputController.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: outputController.text));
    setState(() => copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => copied = false);
  }

  void clear() {
    jsonController.clear();
    outputController.clear();
    setState(() {
      error = null;
      classCount = 0;
    });
  }

  void loadSample() {
    jsonController.text = sampleJson;
    classController.text = 'Response';
    convert();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const _AppHeader(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 820;
                  final panels = [
                    Expanded(child: inputPanel()),
                    Expanded(child: outputPanel()),
                  ];
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 12 : 24,
                      12,
                      compact ? 12 : 24,
                      16,
                    ),
                    child: compact
                        ? Column(
                            children: [
                              panels.first,
                              const SizedBox(height: 12),
                              panels.last,
                            ],
                          )
                        : Row(
                            children: [
                              panels.first,
                              const SizedBox(width: 14),
                              panels.last,
                            ],
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget inputPanel() {
    return _Panel(
      header: _PanelHeader(
        eyebrow: 'SOURCE',
        title: 'JSON input',
        actions: [
          _ActionButton(
            icon: Icons.auto_fix_high_outlined,
            label: 'Format',
            onPressed: formatJson,
          ),
          _ActionButton(
            icon: Icons.delete_outline,
            label: 'Clear',
            onPressed: clear,
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: jsonController,
              onChanged: (_) {
                if (liveConvert) convert();
              },
              expands: true,
              maxLines: null,
              minLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.55,
                color: ink,
              ),
              decoration: const InputDecoration(
                hintText: 'Paste a JSON object or array here…',
                contentPadding: EdgeInsets.all(18),
              ),
            ),
          ),
          if (error != null) errorBanner(),
          inputFooter(),
        ],
      ),
    );
  }

  Widget errorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFFFFECEA),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 17, color: Color(0xFFC34439)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF9D3028), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget inputFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFA),
        border: Border(top: BorderSide(color: border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 440;
          final classField = TextField(
            controller: classController,
            onChanged: (_) {
              if (liveConvert) convert();
            },
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              border: fieldBorder(border),
              enabledBorder: fieldBorder(border),
              focusedBorder: fieldBorder(mint, width: 1.5),
            ),
          );
          final generateButton = FilledButton.icon(
            onPressed: convert,
            style: FilledButton.styleFrom(
              backgroundColor: ink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: const Text('Generate'),
          );
          if (narrow) {
            return Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Root class',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: classField),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: loadSample,
                      child: const Text('Load example'),
                    ),
                    const Spacer(),
                    generateButton,
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              const Text(
                'Root class',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(width: 9),
              SizedBox(width: 148, child: classField),
              const Spacer(),
              TextButton(onPressed: loadSample, child: const Text('Example')),
              const SizedBox(width: 4),
              generateButton,
            ],
          );
        },
      ),
    );
  }

  OutlineInputBorder fieldBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );

  Widget outputPanel() {
    final lines = outputController.text.isEmpty
        ? 0
        : '\n'.allMatches(outputController.text).length + 1;
    return _Panel(
      header: _PanelHeader(
        eyebrow: 'DART',
        title: 'Generated models',
        badge: classCount == 0 ? null : '$classCount classes',
        actions: [
          _ActionButton(
            icon: copied ? Icons.check_rounded : Icons.copy_outlined,
            label: copied ? 'Copied' : 'Copy',
            highlighted: copied,
            onPressed: copyOutput,
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFF18211D),
              child: TextField(
                controller: outputController,
                readOnly: true,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xFFE9F1ED),
                ),
                decoration: const InputDecoration(
                  hintText: 'Your Dart classes will appear here.',
                  hintStyle: TextStyle(color: Color(0xFF819087)),
                  contentPadding: EdgeInsets.all(18),
                ),
              ),
            ),
          ),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF111915),
              border: Border(top: BorderSide(color: Color(0xFF29342F))),
            ),
            child: Row(
              children: [
                _StatusDot(
                  ok: error == null && outputController.text.isNotEmpty,
                ),
                const SizedBox(width: 8),
                Text(
                  error != null
                      ? 'Fix the JSON to continue'
                      : outputController.text.isEmpty
                      ? 'Waiting for JSON'
                      : 'Generated safely',
                  style: const TextStyle(
                    color: Color(0xFFB8C4BD),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '$lines lines',
                  style: const TextStyle(
                    color: Color(0xFF718078),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Live',
                  style: TextStyle(color: Color(0xFF9EABA4), fontSize: 11),
                ),
                SizedBox(
                  height: 28,
                  child: Switch(
                    value: liveConvert,
                    activeTrackColor: mint,
                    onChanged: (value) {
                      setState(() => liveConvert = value);
                      if (value) convert();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _ConverterPageState.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _ConverterPageState.ink,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: const Text(
              '{ }',
              style: TextStyle(
                color: _ConverterPageState.mint,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 11),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ModelMint',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                'JSON → safe Dart models',
                style: TextStyle(
                  fontSize: 11,
                  color: _ConverterPageState.muted,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF9F3),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFFBDEBD9)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 14, color: Color(0xFF188761)),
                SizedBox(width: 5),
                Text(
                  'Null-safe',
                  style: TextStyle(
                    color: Color(0xFF166B50),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ConverterPageState.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D17201B),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.eyebrow,
    required this.title,
    required this.actions,
    this.badge,
  });

  final String eyebrow;
  final String title;
  final String? badge;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _ConverterPageState.border)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: Color(0xFF779087),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (badge != null) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: _ConverterPageState.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: highlighted
            ? const Color(0xFF16855F)
            : _ConverterPageState.muted,
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.ok});

  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: ok ? _ConverterPageState.mint : const Color(0xFF718078),
        shape: BoxShape.circle,
        boxShadow: ok
            ? const [BoxShadow(color: Color(0x6643D19E), blurRadius: 6)]
            : null,
      ),
    );
  }
}
