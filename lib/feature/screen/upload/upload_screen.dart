import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:online_doc_savimex/app_import.dart';
import 'package:online_doc_savimex/feature/widget/color.dart';

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
  bool _submitting   = false;     // kept for button disable/opacity only
  String? _error;

  // repos
  late final DoctypeRepository _doctypeRepo;
  // REMOVE direct repository usage for creating documents:
  // late final DocumentRepository _docRepo;
  late final AuthRepository _authRepo;

  @override
  void initState() {
    super.initState();
    _doctypeRepo = context.read<DoctypeRepository>();
    _authRepo    = context.read<AuthRepository>();
    _initRepoAndLoadTypes();
  }

  Future<void> _initRepoAndLoadTypes() async {
    // If you need token here for other calls, keep it — not needed for upload now
    await _authRepo.getPersistedToken();
    // _docRepo = DocumentRepository(); // <-- remove
    await _loadDoctypes();
  }

  Future<void> _loadDoctypes() async {
    setState(() { _loadingTypes = true; _error = null; });
    try {
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

    // Gather files for the event
    final files = _files
        .where((pf) => pf.path != null)
        .map((pf) => File(pf.path!))
        .toList();

    // Dispatch to UploadBloc instead of calling repo directly
    context.read<UploadBloc>().add(
      UploadSubmitted(
        documentTypeId: _selectedType!.id as int,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        files: files,
      ),
    );

    // Flip local “submitting” just for disabling the button/opacity (UI unchanged)
    setState(() { _submitting = true; _error = null; });
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
    // Wrap body with a BlocListener to respond to success/failure
    return BlocListener<UploadBloc, UploadState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == UploadStatus.success) {
          // Show toast
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploaded successfully')),
          );
          // Reset local submitting flag
          if (mounted) setState(() => _submitting = false);
          // Pop to previous page (Home will already be refreshed by UploadBloc -> HomeBloc)
          if (mounted) Navigator.of(context).pop(true);
        } else if (state.status == UploadStatus.failure) {
          if (mounted) {
            setState(() { _submitting = false; _error = state.error; });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: ${state.error ?? 'Unknown error'}')),
            );
          }
        }
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final ready = !_submitting && !_loadingTypes;
    final textTitle = Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.white, fontWeight: FontWeight.bold);
    final textSubTitle = Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.white);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text('Document form', style: textTitle),
        centerTitle: true,
      ),
      body: Container(
        color: AppColors.background,
        child: SafeArea(
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
                      Text('Document title:', style: textSubTitle,),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.white,
                          hintText: 'title',
                          hintStyle: TextStyle(color: AppColors.black26),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.black38, width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.black38, width: 1),
                            borderRadius: BorderRadius.circular(8),
                          )
                        ),
                        onTapOutside: (event){FocusScope.of(context).unfocus();},
                        validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 10),
                      Text('Document type:', style: textSubTitle,),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<DocumentType>(
                              isExpanded: true,
                              value: _selectedType,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.white,
                                hintText: 'choose type',
                                hintStyle: TextStyle(color: AppColors.black26),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: AppColors.black38, width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.black38, width: 1),
                                )
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
                      const SizedBox(height: 10),

                      Text('Description (optional):',style: textSubTitle),
                      TextFormField(
                        controller: _descController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'type here...',
                          hintStyle: TextStyle(color: AppColors.black26),
                          filled: true,
                          fillColor: AppColors.white,
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.black38,width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.black38,width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onTapOutside: (event){FocusScope.of(context).unfocus();},
                      ),
                      const SizedBox(height: 10),
                      Text('Files here:(image, pdf, word, excel...)', style: textSubTitle,),
                      // file picker trigger
                      UploadBlock(onTapPickFiles: _pickFiles),
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
                      Text('Schedule date', style: textSubTitle,),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        onTap: _pickDate,
                        decoration: InputDecoration(
                          hintText: 'dd/mm/yyyy',
                          filled: true,
                          fillColor: AppColors.white,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.black38, width: 1)
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.black38, width: 1),
                            borderRadius: BorderRadius.circular(8)
                          ),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!, style: const TextStyle(color: Colors.red)),
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
      ),
    );
  }
}
