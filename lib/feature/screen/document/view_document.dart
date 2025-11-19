import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:online_doc_savimex/app_import.dart';
import 'package:online_doc_savimex/feature/screen/document/widget/first_section.dart';
import 'package:online_doc_savimex/feature/screen/document/widget/openPDF.dart';
import 'package:online_doc_savimex/feature/screen/document/widget/step.dart';
import 'package:online_doc_savimex/feature/widget/color.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentScreen extends StatelessWidget {
  final int documentId;
  const DocumentScreen({super.key, required this.documentId});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<DocumentRepository>();

    return BlocProvider(
      create: (_) => ViewBloc(repo: repo)..add(ViewStarted(documentId)),
      child: const _DocumentView(),
    );
  }
}

class _DocumentView extends StatefulWidget {
  const _DocumentView();

  @override
  State<_DocumentView> createState() => _DocumentViewState();
}

class _DocumentViewState extends State<_DocumentView> {
  bool _shouldRefresh = false;

  // -----------------------------
  // Type helpers
  // -----------------------------
  bool _isImage(DocumentFile f) {
    final t = (f.fileType).toLowerCase();
    if (t.startsWith('image/')) return true;

    final n = (f.fileName).toLowerCase();
    return n.endsWith('.jpg') ||
        n.endsWith('.jpeg') ||
        n.endsWith('.png') ||
        n.endsWith('.gif') ||
        n.endsWith('.webp') ||
        n.endsWith('.bmp') ||
        n.endsWith('.heic');
  }

  bool _isPdf(DocumentFile f) {
    final t = (f.fileType).toLowerCase();
    final n = (f.fileName).toLowerCase();
    return t == 'application/pdf' || n.endsWith('.pdf');
  }

  /// We will mark stamped copies by naming them *_signed.png.
  bool _isSigned(DocumentFile f) {
    final n = (f.fileName).toLowerCase();
    return n.endsWith('_signed.png');
  }

  /// Only show Signature when backend step_action == 'SIGNATURE' and user can act.
  bool _canSignature(DocumentDetail d) {
    final a = (d.currentActionableStepAction ?? '').toUpperCase();
    return d.canAct == true && a == 'SIGNATURE';
  }

  // -----------------------------
  // Common UI helpers
  // -----------------------------
  Future<void> _openUrl(BuildContext context, String url) async {

    if (url.toLowerCase().endsWith('.pdf')) {
      // Open in in-app PDF viewer
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerPage(url: url),
        ),
      );
      return;
    }
    final uri = Uri.parse(url);

    // Use external app for PDF/DOCX (fixes iOS crash)
    try {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open: $url')),
        );
      }
    } catch (e) {
      // Last fallback
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file: $url')),
        );
      }
    }
  }


  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // -----------------------------
  // Attachment actions (with Signature)
  // -----------------------------
  Future<void> _onAttachmentPressed(DocumentDetail d, DocumentFile f) async {
    final isImg = _isImage(f);
    final isPdf = _isPdf(f);
    final canSign = _canSignature(d) && (isImg || isPdf);

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder:
          (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canSign)
                  ListTile(
                    leading: const Icon(Icons.draw),
                    title: const Text('Signature'),
                    subtitle: Text(
                      isImg ? 'Stamp on this image' : 'Stamp on this PDF page',
                    ),
                    onTap: () => Navigator.pop(context, 'signature'),
                  ),
                if (isImg)
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Save to Photos/Gallery'),
                    onTap: () => Navigator.pop(context, 'gallery'),
                  ),
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('Save to Files'),
                  onTap: () => Navigator.pop(context, 'files'),
                ),
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Open in viewer'),
                  onTap: () => Navigator.pop(context, 'open'),
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context, 'cancel'),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
    );

    if (choice == null || choice == 'cancel') return;

    switch (choice) {
      case 'signature':
        await _openSignatureStampSheet(documentId: d.id, file: f, isPdf: isPdf);
        return;
      case 'gallery':
      case 'files':
        await _onDownloadPressed(f); // reuse existing downloader
        return;
      case 'open':
        await _openUrl(context, f.fileUrl);
        return;
    }
  }

  Future<int> _askUserForPdfPage(BuildContext context, int totalPages) async {
    return await showModalBottomSheet<int>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView.builder(
          itemCount: totalPages,
          itemBuilder: (_, i) => ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: Text('Page ${i + 1}'),
            onTap: () => Navigator.pop(context, i + 1),
          ),
        ),
      ),
    ) ?? 1;
  }


  // -----------------------------
  // Existing download flow (kept)
  // -----------------------------
  Future<void> _onDownloadPressed(DocumentFile f) async {
    // On web/desktop, let the browser handle the download.
    if (kIsWeb) {
      await _openUrl(context, f.fileUrl);
      return;
    }

    final isImg = _isImage(f);

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder:
          (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isImg)
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('Save to Photos/Gallery'),
                    onTap: () => Navigator.pop(context, 'gallery'),
                  ),
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('Save to Files'),
                  onTap: () => Navigator.pop(context, 'files'),
                ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(context, 'cancel'),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
    );

    if (choice == null || choice == 'cancel') return;

    final bytes = await _fetchBytes(f.fileUrl);
    if (bytes == null) return;

    final fileName = _suggestFileName(f);

    if (choice == 'gallery' && isImg) {
      final r = await SaverGallery.saveImage(
        bytes,
        fileName: fileName,
        skipIfExists: true,
      );
      if (r.isSuccess) {
        _snack('Saved to Photos');
      } else {
        _snack(r.errorMessage ?? 'Failed to save to Photos');
      }
      return;
    }

    await _saveToFiles(bytes, fileName);
  }

  // -----------------------------
  // Signature stamping bottom sheet
  // -----------------------------
  Future<void> _openSignatureStampSheet({
    required int documentId,
    required DocumentFile file,
    required bool isPdf,
  }) async {
    try {
      Uint8List? baseBytes;

      // If PDF → let user choose the page
      if (isPdf) {
        final pdfData = await _fetchBytes(file.fileUrl);
        if (pdfData == null) {
          _snack('Cannot load PDF.');
          return;
        }

        final pdf = await PdfDocument.openData(pdfData);
        final pageCount = pdf.pagesCount;

        // Ask user which page to sign
        final chosenPage = await _askUserForPdfPage(context, pageCount);

        // Render chosen page
        baseBytes = await _renderPdfPageToPng(
          file.fileUrl,
          pageIndex: chosenPage,
        );

        await pdf.close();
      } else {
        // Normal image
        baseBytes = await _fetchBytes(file.fileUrl);
      }

      if (baseBytes == null) {
        _snack('Failed to open the file for signature.');
        return;
      }

      // Pick user's signature
      final sigBytes = await _pickSignatureImage();
      if (sigBytes == null) {
        _snack('No signature selected.');
        return;
      }

      // Open the signer sheet
      final stamped = await showModalBottomSheet<Uint8List>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.black87,
        builder: (_) => _SignatureStampSheet(
          baseImageBytes: baseBytes!,
          signaturePngBytes: sigBytes,
        ),
      );

      // Upload stamped file
      if (stamped != null) {
        final baseName = p.basenameWithoutExtension(file.fileName);
        final outName = '${baseName}_signed.png';

        final payload = UploadFilePayload(
          name: outName,
          bytes: stamped,
          mime: 'image/png',
        );

        if (!mounted) return;
        context.read<ViewBloc>().add(ViewUploadPicked([payload]));
      }
    } catch (e) {
      _snack('Signature failed: $e');
    }
  }

  // User chooses signature image (PNG/JPG) – no backend changes required
  Future<Uint8List?> _pickSignatureImage() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.first;
    if (f.bytes != null) return f.bytes!;
    if (f.path != null) {
      return await File(f.path!).readAsBytes();
    }
    return null;
  }

  // -----------------------------
  // Network / file helpers
  // -----------------------------
  Future<Uint8List?> _fetchBytes(String url) async {
    try {
      final r = await http.get(Uri.parse(url));
      if (r.statusCode == 200) return Uint8List.fromList(r.bodyBytes);
      _snack('Download failed (HTTP ${r.statusCode})');
    } catch (e) {
      _snack('Download failed: $e');
    }
    return null;
  }

  Future<void> _saveToFiles(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final tmpPath = p.join(dir.path, fileName);
    final f = File(tmpPath);
    await f.writeAsBytes(bytes);

    final savedPath = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(sourceFilePath: tmpPath, fileName: fileName),
    );

    if (savedPath == null) {
      _snack('Save canceled');
    } else {
      _snack('Saved to $savedPath');
    }
  }

  String _suggestFileName(DocumentFile f) {
    final name = (f.fileName).trim();
    if (name.isNotEmpty) return name;

    final segs = Uri.parse(f.fileUrl).pathSegments;
    if (segs.isNotEmpty) return segs.last;

    return 'file${_extFromMime(f.fileType)}';
  }

  String _extFromMime(String mime) {
    final m = mime.toLowerCase();
    if (m == 'image/jpeg') return '.jpg';
    if (m == 'image/png') return '.png';
    if (m == 'image/webp') return '.webp';
    if (m == 'image/gif') return '.gif';
    if (m == 'image/bmp') return '.bmp';
    if (m == 'image/heic') return '.heic';
    if (m == 'application/pdf') return '.pdf';
    return '';
  }

  // -----------------------------
  // PDF first-page renderer (PNG)
  // -----------------------------
  Future<Uint8List?> _renderPdfPageToPng(
    String url, {
    int pageIndex = 1,
    int scale = 2,
  }) async {
    try {
      final bytes = await _fetchBytes(url);
      if (bytes == null) return null;
      final doc = await PdfDocument.openData(bytes);
      final idx = pageIndex.clamp(1, doc.pagesCount);
      final page = await doc.getPage(idx);
      final img = await page.render(
        width: (page.width * scale).toDouble(),
        height: (page.height * scale).toDouble(),
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFFFF',
      );
      await page.close();
      await doc.close();
      return img?.bytes;
    } catch (_) {
      return null;
    }
  }

  // -----------------------------
  // BLoC + UI
  // -----------------------------
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ViewBloc, ViewState>(
      listenWhen:
          (prev, curr) => prev.flashId != curr.flashId && curr.flash != null,
      listener: (context, state) {
        if (state.flash != null) {
          final msg = state.flash!.toLowerCase();
          if (msg.contains('approve') ||
              msg.contains('rejected') ||
              msg.contains('uploaded') ||
              msg.contains('deleted') ||
              msg.contains('completed')) {
            _shouldRefresh = true;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.flash!)));
          context.read<ViewBloc>().add(const ViewClearFlash());
        }
      },
      builder: (context, state) {
        switch (state.status) {
          case ViewStatus.initial:
          case ViewStatus.loading:
            return Scaffold(
              appBar: AppBar(title: const Text('Document')),
              body: const Center(child: CircularProgressIndicator()),
            );
          case ViewStatus.error:
            return Scaffold(
              appBar: AppBar(title: const Text('Document')),
              body: Center(child: Text(state.error ?? 'Unknown error')),
            );
          case ViewStatus.loaded:
            final d = state.detail!;
            final allFiles = state.files;
            final signedFiles = allFiles.where(_isSigned).toList();
            final originalFiles = allFiles.where((f) => !_isSigned(f)).toList();

            final origImages = originalFiles.where(_isImage).toList();
            final origOthers =
                originalFiles.where((f) => !_isImage(f)).toList();

            final signedImages = signedFiles.where(_isImage).toList();
            final signedOthers =
                signedFiles.where((f) => !_isImage(f)).toList();

            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (bool didPop, Object? result) {
                if (didPop) return;
                Navigator.of(context).pop(_shouldRefresh);
              },
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('Document'),
                  backgroundColor: AppColors.background,
                  foregroundColor: AppColors.white,
                ),
                backgroundColor: AppColors.background,
                body: RefreshIndicator(
                  onRefresh:
                      () async =>
                          context.read<ViewBloc>().add(const ViewRefreshed()),
                  child: ListView(
                    children: [
                      // Header
                      DocumentHeader(
                        uploaderName: d.uploaderName,
                        uploaderDepartmentName: d.uploaderDepartmentName,
                        postedAt: d.createdAt,
                        canAct: d.canAct,
                        onApprove:
                            state.actBusy
                                ? null
                                : () => context.read<ViewBloc>().add(
                                  const ViewApprovePressed(),
                                ),
                        onReject:
                            state.actBusy
                                ? null
                                : () => context.read<ViewBloc>().add(
                                  const ViewRejectPressed(),
                                ),
                      ),

                      // Steps
                      DocumentSteps(
                        forwardMode: d.forwardMode,
                        flowsCount: d.flowsCount,
                        steps: d.steps,
                      ),

                      // Main content
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Card(
                          color: AppColors.card,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.title,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(color: AppColors.white),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  d.description,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Original Attachments
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Card(
                          color: AppColors.card,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Original attachments',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: AppColors.white),
                                ),
                                const SizedBox(height: 8),
                                if (originalFiles.isEmpty)
                                  const Text(
                                    'No files',
                                    style: TextStyle(color: AppColors.white),
                                  ),

                                // Image grid
                                if (origImages.isNotEmpty)
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                          childAspectRatio: 1,
                                        ),
                                    itemCount: origImages.length,
                                    itemBuilder: (_, i) {
                                      final f = origImages[i];
                                      return GestureDetector(
                                        onTap: () => _onAttachmentPressed(d, f),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.network(
                                                f.fileUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (_, __, ___) =>
                                                        const Center(
                                                          child: Icon(
                                                            Icons.broken_image,
                                                          ),
                                                        ),
                                              ),
                                              Align(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 4,
                                                      ),
                                                  color: Colors.black54,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        f.fileName,
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        style: TextStyle(
                                                          color:
                                                              AppColors.white,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      if (f.uploaderName !=
                                                              null &&
                                                          f.uploaderName!
                                                              .trim()
                                                              .isNotEmpty)
                                                        Text(
                                                          'From: ${f.uploaderName}',
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                          style: const TextStyle(
                                                            color:
                                                                Colors.white70,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                const SizedBox(height: 12),

                                // Non-image originals
                                ...origOthers.map((f) {
                                  final kb = (f.fileSize / 1024)
                                      .toStringAsFixed(1);
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      Icons.insert_drive_file,
                                      color: AppColors.white,
                                    ),
                                    title: Text(
                                      f.fileName,
                                      style: TextStyle(color: AppColors.white),
                                    ),
                                    subtitle: Text(
                                      '${f.fileType} · ${kb} KB'
                                      '${(f.uploaderName != null && f.uploaderName!.trim().isNotEmpty) ? ' · From: ${f.uploaderName}' : ''}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      onPressed:
                                          () => _onAttachmentPressed(d, f),
                                      icon: Icon(
                                        Icons.more_horiz,
                                        color: AppColors.white,
                                      ),
                                      tooltip: 'Actions',
                                    ),
                                    onTap: () => _onAttachmentPressed(d, f),
                                  );
                                }),
                                const SizedBox(height: 4),
                                if (state.uploadBusy)
                                  const LinearProgressIndicator(minHeight: 2),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Signed attachments (separate section)
                      if (signedFiles.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Card(
                            color: AppColors.card,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Signed attachments',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(color: Colors.greenAccent),
                                  ),
                                  const SizedBox(height: 8),

                                  if (signedImages.isNotEmpty)
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            crossAxisSpacing: 8,
                                            mainAxisSpacing: 8,
                                            childAspectRatio: 1,
                                          ),
                                      itemCount: signedImages.length,
                                      itemBuilder: (_, i) {
                                        final f = signedImages[i];
                                        return GestureDetector(
                                          onTap:
                                              () => _onAttachmentPressed(d, f),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                Image.network(
                                                  f.fileUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, __, ___) =>
                                                          const Center(
                                                            child: Icon(
                                                              Icons
                                                                  .broken_image,
                                                            ),
                                                          ),
                                                ),
                                                Align(
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 4,
                                                        ),
                                                    color: Colors.black54,
                                                    child: Text(
                                                      f.fileName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                  const SizedBox(height: 12),

                                  ...signedOthers.map((f) {
                                    final kb = (f.fileSize / 1024)
                                        .toStringAsFixed(1);
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.verified,
                                        color: Colors.greenAccent,
                                      ),
                                      title: Text(
                                        f.fileName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${f.fileType} · ${kb} KB'
                                        '${(f.uploaderName != null && f.uploaderName!.trim().isNotEmpty) ? ' · From: ${f.uploaderName}' : ''}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        onPressed:
                                            () => _onAttachmentPressed(d, f),
                                        icon: const Icon(
                                          Icons.more_horiz,
                                          color: Colors.white,
                                        ),
                                        tooltip: 'Actions',
                                      ),
                                      onTap: () => _onAttachmentPressed(d, f),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),

                // Bottom attachment bar (only when canAttach)
                bottomNavigationBar:
                    d.canAttach
                        ? SafeArea(
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.attach_file),
                                    label: const Text('Add attachment'),
                                    onPressed:
                                        state.uploadBusy
                                            ? null
                                            : () =>
                                                _pickAndDispatchFiles(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        : null,
              ),
            );
        }
      },
    );
  }

  // -----------------------------
  // Upload picker (same as before)
  // -----------------------------
  Future<void> _pickAndDispatchFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb, // web: bytes provided; mobile: we'll read from path
    );
    if (result == null) return;

    final files = <UploadFilePayload>[];

    for (final f in result.files) {
      List<int>? bytes = f.bytes; // Uint8List implements List<int>
      if (bytes == null && f.path != null) {
        try {
          bytes = await File(f.path!).readAsBytes();
        } catch (_) {
          // unreadable file (permissions/uri), skip
        }
      }
      if (bytes == null) continue;

      final mime =
          lookupMimeType(f.path ?? f.name, headerBytes: bytes) ??
          'application/octet-stream';

      files.add(UploadFilePayload(name: f.name, bytes: bytes, mime: mime));
    }

    if (files.isEmpty) return;
    context.read<ViewBloc>().add(ViewUploadPicked(files));
  }

  String _fmt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

// ===============================================================
// Bottom-sheet widget for placing the signature
// ===============================================================
class _SignatureStampSheet extends StatefulWidget {
  final Uint8List baseImageBytes;
  final Uint8List signaturePngBytes;
  const _SignatureStampSheet({
    required this.baseImageBytes,
    required this.signaturePngBytes,
  });

  @override
  State<_SignatureStampSheet> createState() => _SignatureStampSheetState();
}

class _SignatureStampSheetState extends State<_SignatureStampSheet> {
  final _stackKey = GlobalKey();
  Offset _sigPos = const Offset(40, 40);
  double _sigScale = 1.0;
  ui.Image? _baseImage, _sigImage;

  // Variables for storing scale and translation start values
  Offset _startFocalPoint = Offset.zero;
  Offset _startPos = Offset.zero;
  double _startScale = 1.0;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    final b = await ui.instantiateImageCodec(widget.baseImageBytes);
    final bf = await b.getNextFrame();
    final s = await ui.instantiateImageCodec(widget.signaturePngBytes);
    final sf = await s.getNextFrame();
    setState(() {
      _baseImage = bf.image;
      _sigImage = sf.image;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canRender = _baseImage != null && _sigImage != null;
    final insets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.92,
          child: Scaffold(
            backgroundColor: Colors.black87,
            appBar: AppBar(
              title: const Text('Place signature'),
              backgroundColor: Colors.black,
              actions: [
                TextButton(
                  onPressed: canRender ? _stampAndReturn : null,
                  child: const Text(
                    'Stamp',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            body: canRender
                ? _buildBody()
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Stack(
          key: _stackKey,
          children: [
            Image.memory(widget.baseImageBytes),
            Positioned(
              left: _sigPos.dx,
              top: _sigPos.dy,
              child: GestureDetector(
                // Handle both scale and drag using scale gesture only
                onScaleStart: (details) {
                  _startFocalPoint = details.focalPoint;
                  _startPos = _sigPos;
                  _startScale = _sigScale;
                },
                onScaleUpdate: (details) {
                  setState(() {
                    // Scale the signature
                    _sigScale = (_startScale * details.scale).clamp(0.2, 5.0);

                    // Drag (translate) the signature using focal point delta
                    final delta = details.focalPoint - _startFocalPoint;
                    _sigPos = _startPos + delta;
                  });
                },
                child: Transform.scale(
                  scale: _sigScale,
                  alignment: Alignment.topLeft,
                  child: Image.memory(widget.signaturePngBytes),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _stampAndReturn() async {
    final rb = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final painted = rb.size;

    final base = _baseImage!;
    final sig = _sigImage!;

    final scaleX = base.width / painted.width;
    final scaleY = base.height / painted.height;

    final dstLeft = (_sigPos.dx * scaleX).clamp(0.0, base.width.toDouble());
    final dstTop = (_sigPos.dy * scaleY).clamp(0.0, base.height.toDouble());
    final dstW = (sig.width * _sigScale * scaleX).clamp(
      1.0,
      base.width.toDouble(),
    );
    final dstH = (sig.height * _sigScale * scaleY).clamp(
      1.0,
      base.height.toDouble(),
    );

    final rec = ui.PictureRecorder();
    final canvas = Canvas(
      rec,
      Rect.fromLTWH(0, 0, base.width.toDouble(), base.height.toDouble()),
    );
    final paint = Paint();

    canvas.drawImage(base, Offset.zero, paint);
    canvas.drawImageRect(
      sig,
      Rect.fromLTWH(0, 0, sig.width.toDouble(), sig.height.toDouble()),
      Rect.fromLTWH(dstLeft, dstTop, dstW, dstH),
      paint,
    );

    final picture = rec.endRecording();
    final img = await picture.toImage(base.width, base.height);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (!mounted) return;
    Navigator.pop(context, data!.buffer.asUint8List());
  }
}



