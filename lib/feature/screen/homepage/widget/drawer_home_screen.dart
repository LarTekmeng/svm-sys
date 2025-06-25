import 'package:online_doc_savimex/app_import.dart';

class DrawerHomeScreen extends StatefulWidget {
  final String employeeID;
  const DrawerHomeScreen({super.key, required this.employeeID});

  @override
  State<DrawerHomeScreen> createState() => _DrawerHomeScreenState();
}

class _DrawerHomeScreenState extends State<DrawerHomeScreen> {
  Employee?   _employee;
  bool        _loading = true;
  String?     _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  /// 1) load employee, then load that employee's department
  Future<void> _loadAll() async {
    try {
      final empRepo = context.read<EmployeeRepository>();
      final empRaw = await empRepo.fetchEmployeeByID(widget.employeeID);
      final employee = Employee.fromJson(empRaw);
      setState(() {
        _employee   = employee;
        _loading    = false;
      });
    } catch (e) {
      setState(() {
        _error    = e.toString();
        _loading  = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 2) while loading, show spinner
    if (_loading) {
      return Drawer(child: Center(child: CircularProgressIndicator()));
    }
    // 3) if error, show it
    if (_error != null) {
      return Drawer(child: Center(child: Text('Error: $_error')));
    }
    // 4) now both _employee and _department are non-null
    final e = _employee!;
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                  AssetImage('assets/images/tiger-beer-logo.jpg'),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${e.employeeID}',
                        style:
                        const TextStyle(color: Colors.white, fontSize: 14)),
                    Text('Name: ${e.employeeName}',
                        style:
                        const TextStyle(color: Colors.white, fontSize: 14)),
                    Text('DEP: ${e.departmentName}',
                        style:
                        const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.type_specimen),
            title: const Text('Document Type'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    DocumentTypeScreen(employeeID: widget.employeeID),
              ),
            ),
          ),

          // … other menu items …

          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

