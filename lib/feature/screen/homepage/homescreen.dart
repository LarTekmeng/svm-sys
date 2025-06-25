import 'package:online_doc_savimex/app_import.dart';

class Homescreen extends StatefulWidget {
  final String employeeID;
  const Homescreen({super.key, required this.employeeID});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  late Future<List<Document>> _futureDocument;
  // track which docs are checked:
  final Set<int> _selectedDocIds = {};

  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    _fetchUser();
    _loadDocument();
  }

  Future<void> _fetchUser()async {
    final authRepo = context.read<EmployeeRepository>();
    await authRepo.fetchEmployeeByID(widget.employeeID);
  }

  void _loadDocument() {
    setState(() {
      _futureDocument = fetchDocument();
    });
  }

  void _toggleSelectAll(List<Document> docs) {
    setState(() {
      if (_selectedDocIds.length == docs.length) {
        _selectedDocIds.clear();
      } else {
        _selectedDocIds
          ..clear()
          ..addAll(docs.map((d) => d.id as int));
      }
    });
  }

  void _onCheckboxChanged(bool? checked, int docId) {
    setState(() {
      if (checked == true) {
        _selectedDocIds.add(docId);
      } else {
        _selectedDocIds.remove(docId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF006080),
      drawer: _isEdit
          ? null
          : DrawerHomeScreen(employeeID: widget.employeeID),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              // header row with Select All / Cancel
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _isEdit
                      ? TextButton(
                    onPressed: () async {
                      // need the current list to know how many items:
                      final docs = await _futureDocument;
                      _toggleSelectAll(docs);
                    },
                    child: Text(
                      _selectedDocIds.isEmpty
                          ? 'Select All'
                          : 'Unselect All',
                      style: const TextStyle(color: Colors.yellow),
                    ),
                  )
                      : Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu,
                          color: Colors.yellow),
                      onPressed: () =>
                          Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const Text(
                    'Document',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isEdit = !_isEdit;
                        if (!_isEdit) {
                          // clear selections when exiting edit mode?
                          _selectedDocIds.clear();
                        }
                      });
                    },
                    child: Text(
                      _isEdit ? 'Cancel' : 'Edit',
                      style: const TextStyle(color: Colors.yellow),
                    ),
                  ),
                ],
              ),

              SearchBarField(showIcon: true),
              const SizedBox(height: 16),

              // documents list
              Expanded(
                child: FutureBuilder<List<Document>>(
                  future: _futureDocument,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(
                          child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child:
                          Text('Error: ${snapshot.error}'));
                    }
                    final docs = snapshot.data!;
                    if (docs.isEmpty) {
                      return Center(
                          child:
                          Text('No Document Data is Found!'));
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final isChecked =
                        _selectedDocIds.contains(doc.id);
                        return Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            if (_isEdit)
                              Checkbox(
                                value: isChecked,
                                onChanged: (val) =>
                                    _onCheckboxChanged(val, doc.id as int),
                                shape: CircleBorder(),
                              ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                    left: _isEdit ? 5.0 : 0.0),
                                child: DocumentItem(
                                  title: doc.title,
                                  status: 'In Progress',
                                  desc: doc.description,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),
              if (_isEdit)
                btnListAction(
                    (){
                      /* Trash the selected Document List here */
                      print('Trash');
                    },
                        (){
                      /* Archive the selected Document List here  */
                      print('Archive');
                }
                ), // you can now act on _selectedDocIds

              const SizedBox(height: 10),
              mainButton(
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        UploadScreen(employeeID: widget.employeeID),
                  ),
                ),
                'New Document',
                Colors.green,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

