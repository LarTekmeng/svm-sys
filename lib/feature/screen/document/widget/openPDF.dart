import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

class PdfViewerPage extends StatefulWidget {
  final String url;
  const PdfViewerPage({super.key, required this.url});

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  PdfController? _pdfController;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      // Convert String → Uri
      final uri = Uri.parse(widget.url);

      // Download bytes
      final bytes = await http.readBytes(uri);

      // Create PDF Controller
      _pdfController = PdfController(
        document: PdfDocument.openData(bytes),
        initialPage: 1,
      );

      setState(() => _loading = false);
    } catch (e) {
      print("PDF load error: $e");
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load PDF")),
      );
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF Viewer'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : PdfView(
        controller: _pdfController!,
        onDocumentLoaded: (doc) =>
            print("PDF Loaded. Pages: ${doc.pagesCount}"),
        onPageChanged: (page) => print("Page: $page"),
      ),
    );
  }
}
