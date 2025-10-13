import 'dart:async'; // for StreamSubscription
import 'package:online_doc_savimex/app_import.dart';
import 'package:online_doc_savimex/feature/bloc/editBLoC/edit_profile_bloc.dart';
import 'package:online_doc_savimex/feature/bloc/editBLoC/edit_profile_event.dart';
import 'package:online_doc_savimex/feature/bloc/editBLoC/edit_profile_state.dart';
import 'package:online_doc_savimex/feature/screen/document/view_document.dart';

// ⬇️ If you want to prefetch avatar here (optional), uncomment the two lines below
import 'package:cached_network_image/cached_network_image.dart';
import 'package:online_doc_savimex/feature/screen/homepage/widget/avatar_cache_manager.dart';

class Homescreen extends StatefulWidget {
  final String employeeID;
  const Homescreen({super.key, required this.employeeID});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen>
    with SingleTickerProviderStateMixin {
  // HomeView data
  late Future<HomeView> _futureView;

  // Single fetch of the current employee (Option A: lifted state)
  late Future<Employee> _employeeFut;
  Employee? _employeeCached;

  // Cache lists for selection ("Edit" mode uses these)
  List<Document> _uploaded = const [];
  List<Document> _assigned = const [];

  // track which docs are checked (by doc id):
  final Set<int> _selectedDocIds = {};

  bool _isEdit = false;

  // Tabs for INBOX(assigned) / UPLOAD(uploaded)
  late final TabController _tab;

  // Realtime (SSE) wiring
  late HomeRepo _homeRepo;
  StreamSubscription<void>? _rtSub;

  Future<void> _openDoc(Document doc) async {
    final bool? changed = await Navigator.push<bool?>(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentScreen(documentId: doc.id as int),
      ),
    );
    if (mounted && (changed ?? false)) {
      _loadView(); // <- refresh the HomeView so status updates immediately
    }
  }

  @override
  void initState() {
    super.initState();

    _tab = TabController(length: 2, vsync: this)..addListener(() {
      if (!_tab.indexIsChanging) {
        setState(() {
          _selectedDocIds.clear();
        });
      }
    });

    _homeRepo = context.read<HomeRepo>();

    // 🔹 Fetch Employee ONCE here, cache it, and (optionally) prefetch avatar
    final empRepo = context.read<EmployeeRepository>();
    _employeeFut = empRepo.fetchEmployeeByID(widget.employeeID).then((e) {
      _employeeCached = e;

      // OPTIONAL: prefetch avatar here so the Drawer image is instant
      final url = e.profileImageUrl.trim();
      if (url.isNotEmpty) {
        _prefetchAvatar(url, cacheKey: 'avatar:${widget.employeeID}');
      }

      return e;
    });

    // Load HomeView initially
    _loadView();

    // Connect SSE once and refresh when a new row arrives
    _homeRepo.connectRealtime();
    _rtSub = _homeRepo.realtime.listen((_) {
      if (!mounted) return;
      _loadView();
    });
  }

  // OPTIONAL avatar prefetch (uncomment imports + call above to enable)
  void _prefetchAvatar(String url, {required String cacheKey}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await AvatarCacheManager.instance.getSingleFile(url, key: cacheKey);
        if (!mounted) return;
        await precacheImage(
          CachedNetworkImageProvider(
            url,
            cacheManager: AvatarCacheManager.instance,
            cacheKey: cacheKey,
          ),
          context,
        );
      } catch (_) {}
    });
  }

  void _loadView() {
    setState(() {
      _futureView = _fetchAndCache();
    });
  }

  Future<HomeView> _fetchAndCache() async {
    final view = await _homeRepo.getView();
    _uploaded = view.uploadedByMe;
    _assigned = view.assignedToMe;
    return view;
  }

  List<Document> get _currentDocs => _tab.index == 0 ? _assigned : _uploaded;

  void _toggleSelectAll() {
    final docs = _currentDocs;
    setState(() {
      if (docs.isEmpty) {
        _selectedDocIds.clear();
        return;
      }
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
  void dispose() {
    _rtSub?.cancel();
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Employee>(
      future: _employeeFut,
      builder: (context, empSnap) {
        // We render even while loading; Drawer will accept null and show a skeleton
        final employee = empSnap.data ?? _employeeCached;

        return BlocProvider(
          create:
              (context) =>
                  EmployeeProfileBloc(repo: context.read<EmployeeRepository>())
                    ..add(EmployeeProfileStarted(widget.employeeID)),
          child: Scaffold(
            backgroundColor: const Color(0xFF006080),

            // ⬇️ Drawer now takes the already-fetched employee (NO fetching inside)
            drawer:
                _isEdit
                    ? null
                    : BlocBuilder<EmployeeProfileBloc, EmployeeProfileState>(
                      buildWhen:
                          (prev, curr) =>
                              prev.employee != curr.employee ||
                              prev.status != curr.status,
                      builder: (context, state) {
                        final empForDrawer = state.employee ?? employee;
                        return DrawerHomeScreen(employee: empForDrawer);
                      },
                    ),

            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Header row with menu / title / edit toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _isEdit
                            ? TextButton(
                              onPressed: _toggleSelectAll,
                              child: Text(
                                _selectedDocIds.isEmpty
                                    ? 'Select All'
                                    : 'Unselect All',
                                style: const TextStyle(color: Colors.yellow),
                              ),
                            )
                            : Builder(
                              builder:
                                  (ctx) => IconButton(
                                    icon: const Icon(
                                      Icons.menu,
                                      color: Colors.yellow,
                                    ),
                                    onPressed:
                                        () => Scaffold.of(ctx).openDrawer(),
                                  ),
                            ),
                        const Text(
                          'Document',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isEdit = !_isEdit;
                              if (!_isEdit) _selectedDocIds.clear();
                            });
                          },
                          child: Text(
                            _isEdit ? 'Cancel' : 'Edit',
                            style: const TextStyle(color: Colors.yellow),
                          ),
                        ),
                      ],
                    ),

                    // Keep your existing search widget
                    SearchBarField(showIcon: true),
                    const SizedBox(height: 12),

                    // Tabs under search (INBOX / UPLOAD)
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tab,
                        indicator: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        dividerColor: Colors.transparent,
                        tabs: const [Tab(text: 'INBOX'), Tab(text: 'UPLOAD')],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Documents list(s)
                    Expanded(
                      child: FutureBuilder<HomeView>(
                        future: _futureView,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snap.hasError) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Error: ${snap.error}',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  FilledButton(
                                    onPressed: _loadView,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            );
                          }

                          final view = snap.data!;
                          _uploaded = view.uploadedByMe;
                          _assigned = view.assignedToMe;

                          return TabBarView(
                            controller: _tab,
                            children: [
                              _DocsList(
                                docs: _assigned,
                                isEdit: _isEdit,
                                selectedDocIds: _selectedDocIds,
                                onChanged: _onCheckboxChanged,
                                onOpen: _openDoc,
                              ),
                              _DocsList(
                                docs: _uploaded,
                                isEdit: _isEdit,
                                selectedDocIds: _selectedDocIds,
                                onChanged: _onCheckboxChanged,
                                onOpen: _openDoc,
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (_isEdit)
                      btnListAction(
                        () => debugPrint('Trash: $_selectedDocIds'),
                        () => debugPrint('Archive: $_selectedDocIds'),
                      ),

                    const SizedBox(height: 10),

                    mainButton(
                      () async {
                        final refreshed = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (_) =>
                                    UploadScreen(employeeID: widget.employeeID),
                          ),
                        );
                        if (refreshed == true && mounted) _loadView();
                      },
                      'New Document',
                      Colors.green,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// List for one tab (unchanged)
class _DocsList extends StatelessWidget {
  final List<Document> docs;
  final bool isEdit;
  final Set<int> selectedDocIds;
  final void Function(bool? checked, int docId) onChanged;
  final Future<void> Function(Document doc) onOpen;

  const _DocsList({
    required this.docs,
    required this.isEdit,
    required this.selectedDocIds,
    required this.onChanged,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return const Center(
        child: Text(
          'No Document Data is Found!',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final isChecked = selectedDocIds.contains(doc.id);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isEdit)
              Checkbox(
                value: isChecked,
                onChanged: (val) => onChanged(val, doc.id as int),
                shape: const CircleBorder(),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: isEdit ? 5.0 : 0.0),
                child: DocumentItem(
                  title: doc.title,
                  status: (doc.status),
                  desc: doc.description as String,
                  documentId: doc.id as int,
                  isReadOnly: doc.inboxType == 'SHARED',
                  onTap: () => onOpen(doc),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
