
import 'package:intl/intl.dart';
import 'package:online_doc_savimex/app_import.dart';

class UploadScreen extends StatefulWidget {
  final String employeeID;
  const UploadScreen({super.key, required this.employeeID});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? selectedDate;
  List<DocumentType> type = [];
  DocumentType? selectedType;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();


  bool isloading = false;

  List<int> additionalFiles = [];
  int fileIdCounter = 0;
  String _error     = '';

  void _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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


  Future<void> _loadDoctype() async {
    try {
      final d_type = await fetchDocTypes();
      setState(() => type = d_type);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load types: $e')));
    }
  }

  Future<void> _onSubmit() async {

    if (!_formKey.currentState!.validate()) {
      return; // validation will show errors
    }

    setState(() {
      isloading = true;
      _error     = '';
    });
    try {
      await addDocument(
        selectedType?.id,
        _titleController.text.trim(),
        _descController.text.trim(),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Homescreen(employeeID: widget.employeeID),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => isloading = false);
    }
  }


  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _loadDoctype();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.black),
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Document form',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
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
                  validator: (v) =>
                  v == null || v.isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),

                const LabelWithAsterisk('Document type'),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<DocumentType>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          hintText: 'choose document type',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            type
                                .map(
                                  (dt) => DropdownMenuItem(
                                    value: dt,
                                    child: Text(dt.docTitle),
                                  ),
                                )
                                .toList(),
                        onChanged: (dt) {
                          setState(() {
                            selectedType = dt;
                          });
                        },
                        validator:
                            (_) =>
                                selectedType == null
                                    ? 'Please select a type'
                                    : null,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.blue),
                      onPressed: () {
                        // Add new document type logic
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
                  'Upload your file: (image, pdf, word, excel...)',
                ),
                const SizedBox(height: 8),
                UploadBlock(),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      additionalFiles.add(fileIdCounter++);
                    });
                  },
                  child: Row(
                    children: const [
                      Icon(Icons.add_circle_outline, color: Colors.blue),
                      SizedBox(width: 4),
                      Text(
                        'Add more file',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (additionalFiles.isNotEmpty)
                  Column(
                    children: [
                      for (var id in additionalFiles)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: UploadBlock(
                            onRemove: () {
                              setState(() {
                                additionalFiles.remove(id);
                              });
                            },
                          ),
                        ),
                    ],
                  ),

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
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 50,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed:_onSubmit,
                    child:
                    const Text(
                      'Submit',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
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
          TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}
