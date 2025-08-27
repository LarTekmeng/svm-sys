import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:online_doc_savimex/app_import.dart';
import 'package:online_doc_savimex/feature/screen/document/widget/first_section.dart';
import 'package:online_doc_savimex/feature/screen/document/widget/step.dart';

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
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ViewBloc, ViewState>(
      listenWhen: (prev, curr) => prev.flashId != curr.flashId && curr.flash != null,
      listener: (context, state) {
        if (state.flash != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.flash!)));
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
              appBar: AppBar(title: const Text('Document')),
              body: RefreshIndicator(
                onRefresh: () async => context.read<ViewBloc>().add(const ViewRefreshed()),
                child: ListView(
                  children: [
                    // Header (From + Date + Approve/Reject when allowed)
                    DocumentHeader(
                      uploaderName: d.uploaderName,
                      uploaderDepartmentName: d.uploaderDepartmentName,
                      postedAt: d.createdAt,
                      canAct: d.canAct,
                      onApprove: state.actBusy ? null : () => context.read<ViewBloc>().add(const ViewApprovePressed()),
                      onReject: state.actBusy ? null : () => context.read<ViewBloc>().add(const ViewRejectPressed()),
                    ),

                    // Steps (only for Step by Step)
                    DocumentSteps(
                      forwardMode: d.forwardMode,
                      flowsCount: d.flowsCount,
                      steps: d.steps,
                    ),

                    // Your document form / content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.title, style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 8),
                              Text(d.description ?? ''),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Attachments
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Attachments', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              if (state.files.isEmpty) const Text('No files'),
                              for (final f in state.files)
                                ListTile(
                                  dense: true,
                                  title: Text(f.fileName),
                                  subtitle: Text('${f.fileType} • ${(f.fileSize / 1024).toStringAsFixed(1)} KB'),
                                  trailing: Text(_fmt(f.uploadedAt), style: Theme.of(context).textTheme.bodySmall),
                                  onTap: () {
                                    // TODO: open f.fileUrl with url_launcher
                                  },
                                ),
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
              bottomNavigationBar: d.canAttach
                  ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.attach_file),
                          label: const Text('Add attachment'),
                          onPressed: state.uploadBusy ? null : () => _pickAndDispatchFiles(context),
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
      final mime = lookupMimeType(f.path ?? f.name, headerBytes: bytes) ?? 'application/octet-stream';

      files.add(UploadFilePayload(
        name: f.name,
        bytes: bytes,
        mime: mime,
      ));
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
