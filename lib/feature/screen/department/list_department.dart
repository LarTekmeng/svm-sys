import 'package:online_doc_savimex/app_import.dart';
import 'create_department.dart';

class ListDepartment extends StatefulWidget {
  const ListDepartment({super.key});

  @override
  State<ListDepartment> createState() => _ListDepartmentState();
}

class _ListDepartmentState extends State<ListDepartment> {
  late DepartmentRepository _repo;
  late Future<List<Department>> _future;
  bool _wiredUp = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wiredUp) return; // run once
    _repo = context.read<DepartmentRepository>(); // provided in main.dart
    _future = _repo.fetchDepartments();
    _wiredUp = true;
  }

  Future<void> _reload() async {
    final next = _repo.fetchDepartments(); // kick off new request
    if (!mounted) return;
    setState(() {
      _future = next; // assign synchronously
    });
    await next; // optional: lets pull-to-refresh spinner wait
  }

  void _goCreate() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CreateDepartment()));
    if (created == true && mounted) _reload();
  }

  void _goEdit(Department department) async {
    final updated = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => CreateDepartment(department: department,)));
    if (updated == true && mounted) _reload();
  }

  Future<void> _delete(Department department) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Department'),
            content: Text(
              'Are you sure you want to delete "${department.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await _repo.deleteDepartment(department.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${department.name} deleted')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Departments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goCreate,
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Department>>(
          future: _future,
          builder: (context, snap) {
            if (!_wiredUp || snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Center(child: Text('Failed to load departments')),
                  const SizedBox(height: 8),
                  Center(
                    child: FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
              );
            }
            final items = snap.data ?? const <Department>[];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 80),
                  const Icon(Icons.folder_open, size: 48),
                  const SizedBox(height: 12),
                  Center(child: Text('No departments yet')),
                  const SizedBox(height: 8),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: _goCreate,
                      icon: const Icon(Icons.add),
                      label: const Text('Create one'),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final d = items[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(d.id.toString() ?? '-')),
                  title: Text(d.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _goEdit(d),
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        onPressed: () => _delete(d),
                        icon: Icon(Icons.delete),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
