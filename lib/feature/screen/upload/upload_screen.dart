import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:online_doc_savimex/app_import.dart';
import 'package:online_doc_savimex/feature/repositories/doctype_repo.dart';

class UploadScreen extends StatefulWidget {
  final String employeeID;
  const UploadScreen({super.key, required this.employeeID});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime? selectedDate;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController  = TextEditingController();

  List<DocumentType> _types = [];
  DocumentType? _selectedType;

  // files picked on this screen
  final List<PlatformFile> _files = [];

  bool _loadingTypes = true;
  bool _submitting   = false;
  String? _error;

  // repos
  late final DoctypeRepository _doctypeRepo;
  late final DocumentRepository _docRepo;
  late final AuthRepository _authRepo; // whatever you use for tokens

  @override
  void initState() {
    super.initState();
    _doctypeRepo = DoctypeRepository();
    _authRepo    = AuthRepository.instance; // or get it via DI if you have one
    _initRepoAndLoadTypes();
  }

  Future<void> _initRepoAndLoadTypes() async {
    // get token once for now; you can switch to a sync getter if you keep it in memory
    final token = await _authRepo.getPersistedToken();
    _docRepo = DocumentRepository(tokenProvider: () => token ?? '');

    await _loadDoctypes();
  }

  Future<void> _loadDoctypes() async {
    setState(() { _loadingTypes = true; _error = null; });
    try {
      // adjust to your actual method name; most likely fetchDocumentTypes()
      final types = await _doctypeRepo.getDoctypeById(widget.employeeID);
      setState(() {
        _types = types;
        if (_types.isNotEmpty) _selectedType = _selectedType ?? _types.first;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load types: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load types: $e')),
      );
    } finally {
      setState(() => _loadingTypes = false);
    }
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null) return;

    // merge & dedupe by path+size
    final incoming = result.files.where((f) => f.path != null);
    final existingKeys = _files.map((f) => '${f.path}|${f.size}').toSet();

    final toAdd = <PlatformFile>[];
    for (final f in incoming) {
      final key = '${f.path}|${f.size}';
      if (!existingKeys.contains(key)) {
        toAdd.add(f);
      }
    }

    if (toAdd.isEmpty) return;
    setState(() => _files.addAll(toAdd));
  }

  void _removeFileAt(int index) {
    setState(() => _files.removeAt(index));
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a document type')),
      );
      return;
    }

    setState(() { _submitting = true; _error = null; });

    try {
      final files = _files
          .where((pf) => pf.path != null)
          .map((pf) => File(pf.path!))
          .toList();

      // If you want to store schedule date later, add it to backend & repo; currently unused
      final res = await _docRepo.createDocumentWithFiles(
        documentTypeId: _selectedType!.id as int,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        files: files,
      );

      // success UX
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploaded successfully')),
        );
        Navigator.of(context).pop(true); // or push to home
      }
    } catch (e) {
      setState(() => _error = '$e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_submitting && !_loadingTypes;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Document form', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: AbsorbPointer(
            absorbing: !ready,
            child: Opacity(
              opacity: ready ? 1 : 0.6,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LabelWithAsterisk('Document title'),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'document title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Title is required'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    const LabelWithAsterisk('Document type'),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<DocumentType>(
                            isExpanded: true,
                            value: _selectedType,
                            decoration: const InputDecoration(
                              hintText: 'choose document type',
                              border: OutlineInputBorder(),
                            ),
                            items: _types
                                .map((dt) => DropdownMenuItem(
                              value: dt,
                              child: Text(dt.docTitle),
                            ))
                                .toList(),
                            onChanged: (dt) => setState(() => _selectedType = dt),
                            validator: (_) =>
                            _selectedType == null ? 'Please select a type' : null,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.blue),
                          onPressed: () {
                            // optional: open create-type screen
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Description (optional):'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'type here...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const LabelWithAsterisk(
                        'Upload your file: (image, pdf, word, excel...)'),
                    const SizedBox(height: 8),

                    // single block that triggers file picker
                    UploadBlock(onTapPickFiles: _pickFiles),

                    // show selected files
                    if (_files.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_files.length, (i) {
                          final f = _files[i];
                          return InputChip(
                            label: Text(
                              f.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onDeleted: () => _removeFileAt(i),
                          );
                        }),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Text('Schedule date'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: const InputDecoration(
                        hintText: 'dd/mm/yyyy',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                    ),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child:
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),

                    const SizedBox(height: 24),
                    Center(
                      child: FilledButton(
                        onPressed: ready ? _onSubmit : null,
                        child: _submitting
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text('Submit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LabelWithAsterisk extends StatelessWidget {
  final String label;
  const LabelWithAsterisk(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Colors.black, fontSize: 16),
        children: const [
          TextSpan(text: ' *', style: TextStyle(color: Colors.red))
        ],
      ),
    );
  }
}
