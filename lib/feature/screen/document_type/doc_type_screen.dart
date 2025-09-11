import 'package:online_doc_savimex/app_import.dart';

class DocumentTypeScreen extends StatefulWidget {
  final String employeeID;
  const DocumentTypeScreen({super.key, required this.employeeID});

  @override
  State<DocumentTypeScreen> createState() => _DocumentTypeScreenState();
}

class _DocumentTypeScreenState extends State<DocumentTypeScreen> {
  late final DoctypeRepository _repo;
  late final AuthRepository     _authRepo;
  late Future<List<DocumentType>> _futureDocTypes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo     = context.read<DoctypeRepository>();
    _authRepo = context.read<AuthRepository>();
    _loadDocTypes();
  }

  void _loadDocTypes() {
    setState(() {
      _futureDocTypes = _prepareDocTypes();
    });
  }

  Future<List<DocumentType>> _prepareDocTypes() async {
    final authState = context.read<AuthLoginBloc>().state;
    // If not authenticated, kick to login screen
    if (authState is! AuthAuthenticated) {
      redirectToLogin();
      return [];
    }

    // Even if authenticated, check if token is still valid or refresh it
    final isValid = await _authRepo.hasValidToken();
    if (!isValid) {
      redirectToLogin();
      return [];
    }
    // Proceed with loading the document types
    return _repo.getDoctypeById(authState.employee.employeeID);
  }

  void redirectToLogin(){
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacementNamed('/login');
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF006080),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006080),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
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
              const SearchBarField(showIcon: false),
              const SizedBox(height: 20),

              Expanded(
                child: FutureBuilder<List<DocumentType>>(
                  future: _futureDocTypes,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snap.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }
                    final docTypes = snap.data!;
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
                      itemBuilder: (ctx, i) {
                        final dt = docTypes[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DocTypeCard(
                            id: dt.id as int,
                            title: dt.docTitle,
                            description: dt.docDesc,
                            onDeleted: _loadDocTypes,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

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
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateDocumentTypeScreen(),
                    ),
                  );
                  if (created == true) _loadDocTypes();
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
