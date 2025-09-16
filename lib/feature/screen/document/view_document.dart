import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:online_doc_savimex/app_import.dart';
import 'package:online_doc_savimex/feature/screen/document/widget/first_section.dart';
import 'package:online_doc_savimex/feature/screen/document/widget/step.dart';
import 'package:online_doc_savimex/feature/widget/color.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cannot open: $url')));
      return;
    }
    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onDownloadPressed(DocumentFile f) async {
    // On web/desktop, let the browser handle the download.
    if (kIsWeb) {
      await _openUrl(context, f.fileUrl);
      return;
    }

    final isImg = _isImage(f);

    // Build the choices based on type
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
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

    // Download bytes (in-memory is fine for typical office/media files)
    final bytes = await _fetchBytes(f.fileUrl);
    if (bytes == null) return;

    final fileName = _suggestFileName(f);

    if (choice == 'gallery' && isImg) {
      final r = await SaverGallery.saveImage(bytes, fileName: fileName, skipIfExists: true);
      if (r.isSuccess) {
        _snack('Saved to Photos');
      } else {
        _snack(r.errorMessage ?? 'Failed to save to Photos');
      }
      return;
    }

    // Default: Save to Files (Android SAF / iOS Files)
    await _saveToFiles(bytes, fileName);
  }

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
      params: SaveFileDialogParams(
        sourceFilePath: tmpPath,
        fileName: fileName,
      ),
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


  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ViewBloc, ViewState>(
      listenWhen:
          (prev, curr) => prev.flashId != curr.flashId && curr.flash != null,
      listener: (context, state) {
        if (state.flash != null) {
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
            return Scaffold(
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
                    // Header (From + Date + Approve/Reject when allowed)
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

                    // Steps (only for Step by Step)
                    DocumentSteps(
                      forwardMode: d.forwardMode,
                      flowsCount: d.flowsCount,
                      steps: d.steps,
                    ),

                    // Your document form / content
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
                                d.description ?? '',
                                style: TextStyle(color: AppColors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Attachments
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
                                'Attachments',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: AppColors.white),
                              ),
                              const SizedBox(height: 8),
                              if (state.files.isEmpty)
                                const Text(
                                  'No files',
                                  style: TextStyle(color: AppColors.white),
                                ),
                              Builder(
                                builder: (_) {
                                  final images =
                                      state.files.where(_isImage).toList();
                                  if (images.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                          childAspectRatio: 1,
                                        ),
                                    itemCount: images.length,
                                    itemBuilder: (_, i) {
                                      final f = images[i];
                                      return GestureDetector(
                                        onTap:
                                            () => _onDownloadPressed(f),
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
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 4,
                                                  ),
                                                  color: Colors.black54,
                                                  child: Text(
                                                    f.fileName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: AppColors.white,
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
                                  );
                                },
                              ),

                              const SizedBox(height: 12),

                              ...state.files.where((f) => !_isImage(f)).map((
                                f,
                              ) {
                                final kb = (f.fileSize / 1024).toStringAsFixed(
                                  1,
                                );
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
                                    '${f.fileType} · ${kb} KB',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  trailing: IconButton(
                                    onPressed:
                                        () => _onDownloadPressed(f),
                                    icon: Icon(
                                      Icons.download,
                                      color: AppColors.white,
                                    ),
                                    tooltip: 'Open / Download',
                                  ),
                                  onTap: () => _onDownloadPressed(f),
                                );
                              }).toList(),
                              const SizedBox(height: 4),
                              if (state.uploadBusy)
                                const LinearProgressIndicator(minHeight: 2),
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
            );
        }
      },
    );
  }

  Future<void> _pickAndDispatchFiles(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb, // web: bytes provided; mobile: we'll read from path
    );
    if (result == null) return;

    final files = <UploadFilePayload>[];

    for (final f in result.files) {
      // 1) Get bytes: prefer in-memory; else read from disk (mobile/desktop)
      List<int>? bytes = f.bytes; // Uint8List implements List<int>
      if (bytes == null && f.path != null) {
        try {
          bytes = await File(f.path!).readAsBytes();
        } catch (_) {
          // unreadable file (permissions/uri), skip
        }
      }
      if (bytes == null) continue;

      // 2) Determine MIME reliably (don’t rely on PlatformFile.mimeType)
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
