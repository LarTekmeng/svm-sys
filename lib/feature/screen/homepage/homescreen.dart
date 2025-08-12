// import 'package:online_doc_savimex/app_import.dart';
//
// class HomeScreen extends StatefulWidget {
//   final HomeRepo repo;
//   const HomeScreen({super.key, required this.repo});
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
//   late TabController _tab;
//   bool loading = true;
//   String? error;
//   List<Document> uploaded = [];
//   List<Document> assigned = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _tab = TabController(length: 2, vsync: this);
//     _load();
//   }
//
//   Future<void> _load() async {
//     setState(() { loading = true; error = null; });
//     try {
//       final o = await widget.repo.fetView();
//       setState(() {
//         uploaded = o.uploadedByMe;
//         assigned = o.assignedToMe;
//       });
//     } catch (e) {
//       setState(() { error = '$e'; });
//     } finally {
//       setState(() { loading = false; });
//     }
//   }
//
//   @override
//   void dispose() {
//     _tab.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Documents'),
//         bottom: const PreferredSize(
//           preferredSize: Size.fromHeight(1),
//           child: Divider(height: 1),
//         ),
//       ),
//       body: Column(
//         children: [
//           const SizedBox(height: 8),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12),
//             child: DecoratedBox(
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(12),
//                 color: Theme.of(context).colorScheme.surfaceContainerHighest,
//               ),
//               child: TabBar(
//                 controller: _tab,
//                 dividerColor: Colors.transparent,
//                 indicator: BoxDecoration(
//                   borderRadius: BorderRadius.circular(12),
//                   color: Theme.of(context).colorScheme.primaryContainer,
//                 ),
//                 labelColor: Theme.of(context).colorScheme.onPrimaryContainer,
//                 unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
//                 tabs: const [
//                   Tab(text: 'Uploaded by Me'),
//                   Tab(text: 'Assigned to Me'),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 8),
//           Expanded(
//             child: loading
//                 ? const Center(child: CircularProgressIndicator())
//                 : error != null
//                 ? Center(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text('Failed to load: $error'),
//                   const SizedBox(height: 8),
//                   FilledButton(onPressed: _load, child: const Text('Retry'))
//                 ],
//               ),
//             )
//                 : TabBarView(
//               controller: _tab,
//               children: [
//                 _ListView(uploaded, emptyText: 'No uploads yet.'),
//                 _ListView(assigned, emptyText: 'Nothing assigned to you.'),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _ListView extends StatelessWidget {
//   final List<Document> items;
//   final String emptyText;
//   const _ListView(this.items, {required this.emptyText});
//
//   @override
//   Widget build(BuildContext context) {
//     if (items.isEmpty) {
//       return Center(child: Text(emptyText));
//     }
//     return RefreshIndicator(
//       onRefresh: () async {
//         // parent handles refresh; let the gesture complete
//       },
//       child: ListView.separated(
//         padding: const EdgeInsets.all(12),
//         itemCount: items.length,
//         separatorBuilder: (_, __) => const SizedBox(height: 8),
//         itemBuilder: (ctx, i) {
//           final d = items[i];
//           final subtitle = <String>[
//             if (d.documentTypeTitle != null) d.documentTypeTitle!,
//             if (d.stepAction != null && d.sequence != null) 'Step ${d.sequence} • ${d.stepAction}',
//           ].join(' • ');
//           return Card(
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//             child: ListTile(
//               title: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis),
//               subtitle: Text(subtitle.isEmpty ? (d.description ?? '') : subtitle,
//                   maxLines: 2, overflow: TextOverflow.ellipsis),
//               trailing: Column(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   _StatusChip(d.status),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Updated ${_ago(d.updatedAt)}',
//                     style: Theme.of(context).textTheme.bodySmall,
//                   ),
//                 ],
//               ),
//               onTap: () {
//                 // TODO: navigate to detail
//               },
//             ),
//           );
//         },
//       ),
//     );
//   }
//
//   static String _ago(DateTime t) {
//     final d = DateTime.now().difference(t);
//     if (d.inMinutes < 60) return '${d.inMinutes}m ago';
//     if (d.inHours < 24) return '${d.inHours}h ago';
//     return '${d.inDays}d ago';
//   }
// }
//
// class _StatusChip extends StatelessWidget {
//   final String status;
//   const _StatusChip(this.status);
//
//   @override
//   Widget build(BuildContext context) {
//     final s = status.toUpperCase();
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(999),
//         border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
//       ),
//       child: Text(s, style: Theme.of(context).textTheme.labelSmall),
//     );
//     // Keep styles neutral; you can theme by status if you want
//   }
// }


import 'package:online_doc_savimex/app_import.dart';

class Homescreen extends StatefulWidget {
  final String employeeID;
  const Homescreen({super.key, required this.employeeID});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> with SingleTickerProviderStateMixin {
  // New: load both "uploaded" and "assigned" via HomeRepo.getView()
  late Future<HomeView> _futureView;

  // Cache lists for selection ("Edit" mode uses these)
  List<Document> _uploaded = const [];
  List<Document> _assigned = const [];

  // track which docs are checked (by doc id):
  final Set<int> _selectedDocIds = {};

  bool _isEdit = false;

  // Tabs for Uploaded / Assigned
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tab.indexIsChanging) {
          // Clear selection when switching buckets to avoid confusion
          setState(_selectedDocIds.clear);
        }
      });
    _fetchUser();
    _loadView();
  }

  Future<void> _fetchUser() async {
    // keeps your existing behavior
    final empRepo = context.read<EmployeeRepository>();
    await empRepo.fetchEmployeeByID(widget.employeeID);
  }

  void _loadView() {
    setState(() {
      _futureView = _fetchAndCache();
    });
  }

  Future<HomeView> _fetchAndCache() async {
    final homeRepo = context.read<HomeRepo>();
    final view = await homeRepo.getView();
    // cache for selection logic
    _uploaded = view.uploadedByMe;
    _assigned = view.assignedToMe;
    return view;
  }

  List<Document> get _currentDocs => _tab.index == 0 ? _uploaded : _assigned;

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
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF006080),
      drawer: _isEdit ? null : DrawerHomeScreen(employeeID: widget.employeeID),
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
                      _selectedDocIds.isEmpty ? 'Select All' : 'Unselect All',
                      style: const TextStyle(color: Colors.yellow),
                    ),
                  )
                      : Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.yellow),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                  const Text(
                    'Document',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isEdit = !_isEdit;
                        if (!_isEdit) _selectedDocIds.clear();
                      });
                    },
                    child: Text(_isEdit ? 'Cancel' : 'Edit', style: const TextStyle(color: Colors.yellow)),
                  ),
                ],
              ),

              // Keep your existing search widget
              SearchBarField(showIcon: true),
              const SizedBox(height: 12),

              // New: tabs under search (Uploaded / Assigned) — matches your earlier request
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
                  tabs: const [
                    Tab(text: 'Uploaded by Me'),
                    Tab(text: 'Assigned to Me'),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Documents list(s)
              Expanded(
                child: FutureBuilder<HomeView>(
                  future: _futureView,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Error: ${snap.error}', style: const TextStyle(color: Colors.white)),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _loadView,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    // Ensure cache is in sync in case of hot reload or re-run
                    final view = snap.data!;
                    _uploaded = view.uploadedByMe;
                    _assigned = view.assignedToMe;

                    return TabBarView(
                      controller: _tab,
                      children: [
                        _DocsList(
                          docs: _uploaded,
                          isEdit: _isEdit,
                          selectedDocIds: _selectedDocIds,
                          onChanged: _onCheckboxChanged,
                        ),
                        _DocsList(
                          docs: _assigned,
                          isEdit: _isEdit,
                          selectedDocIds: _selectedDocIds,
                          onChanged: _onCheckboxChanged,
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              if (_isEdit)
                btnListAction(
                      () {
                    // Trash the selected Document List here
                    // You have selected IDs in _selectedDocIds
                    debugPrint('Trash: $_selectedDocIds');
                  },
                      () {
                    // Archive the selected Document List here
                    debugPrint('Archive: $_selectedDocIds');
                  },
                ),

              const SizedBox(height: 10),

              mainButton(
                    () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UploadScreen(employeeID: widget.employeeID),
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

// List for one tab (reuses your DocumentItem and checkbox behavior)
class _DocsList extends StatelessWidget {
  final List<Document> docs;
  final bool isEdit;
  final Set<int> selectedDocIds;
  final void Function(bool? checked, int docId) onChanged;

  const _DocsList({
    required this.docs,
    required this.isEdit,
    required this.selectedDocIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return const Center(child: Text('No Document Data is Found!', style: TextStyle(color: Colors.white)));
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
                  // You can map real status here if available:
                  status: (doc.status),
                  desc: doc.description as String,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
