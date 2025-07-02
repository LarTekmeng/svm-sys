import 'package:online_doc_savimex/app_import.dart';

class DrawerHomeScreen extends StatefulWidget {
  final String employeeID;
  const DrawerHomeScreen({super.key, required this.employeeID});

  @override
  State<DrawerHomeScreen> createState() => _DrawerHomeScreenState();
}

class _DrawerHomeScreenState extends State<DrawerHomeScreen> {
  late Future<Employee> _employee;

  @override
  void initState() {
    super.initState();
    _employee = context.read<EmployeeRepository>().fetchEmployeeByID(
      widget.employeeID,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Color.fromRGBO(0, 105, 133, 1),
      child: FutureBuilder(
        future: _employee,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading profile: ${snapshot.error}'),
            );
          }
          final employee = snapshot.data;
          return ListView(
            padding: EdgeInsets.zero,
            children: [_buildHeader(employee!), ..._buildMenuTiles()],
          );
        },
      ),
    );
  }

  Widget _buildHeader(Employee e) {
    final hasAvatar = e.profileImageUrl.trim().isNotEmpty ?? false;
    return DrawerHeader(
      decoration: const BoxDecoration(color: Color.fromRGBO(0, 105, 133, 1)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage:
                hasAvatar
                    ? NetworkImage(e.profileImageUrl)
                    : AssetImage('assets/images/user.png'),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: ${e.employeeID}', style: _headerTextStyle),
              Text('Name: ${e.employeeName}', style: _headerTextStyle),
              Text('Dept: ${e.departmentName}', style: _headerTextStyle),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuTiles() {
    return [
      _drawerTile(Icons.category, 'Document Type', () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DocumentTypeScreen(employeeID: widget.employeeID),
          ),
        );
      }),
      _drawerTile(Icons.logout, 'Logout', () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }),
    ];
  }

  TextStyle get _headerTextStyle => const TextStyle(
    color: Colors.white,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  Widget _drawerTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
      onTap: onTap,
    );
  }
}
