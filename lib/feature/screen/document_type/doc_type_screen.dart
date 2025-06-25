import 'package:online_doc_savimex/app_import.dart';

class DocumentTypeScreen extends StatefulWidget {
  final String employeeID;
  const DocumentTypeScreen({super.key, required this.employeeID});

  @override
  State<DocumentTypeScreen> createState() => _DocumentTypeScreenState();
}

class _DocumentTypeScreenState extends State<DocumentTypeScreen> {
  late Future<List<DocumentType>> _futureDocTypes;

  @override
  void initState() {
    super.initState();
    _loadType();
  }

  void _loadType(){
    setState(() {
      _futureDocTypes = fetchDocTypes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF006080),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006080),
        leading: IconButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => Homescreen(employeeID: widget.employeeID,))),
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Document type',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              // Search bar
              const SearchBarField(showIcon: false),
              const SizedBox(height: 20),

              // List of document types
              Expanded(
                child: FutureBuilder<List<DocumentType>>(
                  future: _futureDocTypes,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    final docTypes = snapshot.data!;
                    if (docTypes.isEmpty) {
                      return const Center(
                        child: Text(
                          'No document types found',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: docTypes.length,
                      itemBuilder: (context, index) {
                        final dt = docTypes[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DocTypeCard(
                            id: dt.id as int,
                            title: dt.docTitle,
                            description: dt.docDesc,
                            onDeleted:   _loadType,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // New Document Type button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 32,
                  ),
                ),
                onPressed: () async {
                  final created = await
                  Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateDocumentTypeScreen(),
                    ),
                  );
                  if (created == true) _loadType();
                },
                child: const Text(
                  'New Document Type',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
