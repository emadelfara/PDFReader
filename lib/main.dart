import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PdfReaderApp());
}

class PdfReaderApp extends StatelessWidget {
  const PdfReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF Reader',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101010),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF171717),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        useMaterial3: true,
      ),
      home: const ReaderHomePage(),
    );
  }
}

class ReaderHomePage extends StatefulWidget {
  const ReaderHomePage({super.key});

  @override
  State<ReaderHomePage> createState() => _ReaderHomePageState();
}

class _ReaderHomePageState extends State<ReaderHomePage> {
  static const MethodChannel _pdfChannel = MethodChannel('pdf_reader/native');

  String? _filePath;
  String? _fileName;
  int _pageCount = 0;
  int _pageIndex = 0;
  Uint8List? _pageImage;
  bool _loading = false;
  String? _error;

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: false,
      );
      if (result == null || result.files.single.path == null) return;

      setState(() {
        _loading = true;
        _error = null;
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
        _pageImage = null;
      });

      final count = await _pdfChannel.invokeMethod<int>(
        'openPdf',
        {'path': _filePath},
      );
      if (count == null || count < 1) {
        throw PlatformException(code: 'EMPTY_PDF', message: 'No pages found.');
      }

      setState(() {
        _pageCount = count;
        _pageIndex = 0;
      });
      await _loadPage();
    } on PlatformException catch (e) {
      setState(() {
        _error = e.message ?? 'Unable to open this PDF file.';
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not open this file. Please choose a valid PDF.';
        _loading = false;
      });
    }
  }

  Future<void> _loadPage() async {
    if (_filePath == null) return;
    setState(() => _loading = true);
    try {
      final bytes = await _pdfChannel.invokeMethod<Uint8List>(
        'renderPage',
        {'index': _pageIndex, 'maxWidth': 1800},
      );
      if (!mounted) return;
      setState(() {
        _pageImage = bytes;
        _loading = false;
        _error = null;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message ?? 'Could not render this page.';
        _loading = false;
      });
    }
  }

  Future<void> _changePage(int next) async {
    if (next < 0 || next >= _pageCount || next == _pageIndex) return;
    setState(() {
      _pageIndex = next;
      _pageImage = null;
    });
    await _loadPage();
  }

  @override
  void dispose() {
    _pdfChannel.invokeMethod<void>('closePdf');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPdf = _filePath != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Reader', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Open PDF',
            onPressed: _pickPdf,
            icon: const Icon(Icons.folder_open_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (hasPdf)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: const Color(0xFF191919),
              child: Text(
                _fileName ?? 'PDF document',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(
            child: Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : _error != null
                      ? _Message(icon: Icons.error_outline, text: _error!)
                      : _pageImage != null
                          ? InteractiveViewer(
                              minScale: 0.7,
                              maxScale: 5,
                              child: Image.memory(
                                _pageImage!,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            )
                          : _Message(
                              icon: Icons.picture_as_pdf_rounded,
                              text: 'Open a PDF file to get started',
                              action: FilledButton.icon(
                                onPressed: _pickPdf,
                                icon: const Icon(Icons.folder_open),
                                label: const Text('Choose PDF'),
                              ),
                            ),
            ),
          ),
          if (hasPdf && _pageCount > 0)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: const Color(0xFF191919),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _pageIndex > 0 ? () => _changePage(_pageIndex - 1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text(
                      '${_pageIndex + 1} / $_pageCount',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      onPressed: _pageIndex < _pageCount - 1
                          ? () => _changePage(_pageIndex + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: const Color(0xFFE53935)),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70)),
          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ),
    );
  }
}
