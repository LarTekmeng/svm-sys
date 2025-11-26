import 'package:flutter/material.dart';
import 'package:online_doc_savimex/app_import.dart';

class EmployeeManagement extends StatefulWidget {
  const EmployeeManagement({super.key});

  @override
  State<EmployeeManagement> createState() => _EmployeeManagementState();
}

class _EmployeeManagementState extends State<EmployeeManagement> {
  List<Employee> _employees = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<EmployeeRepository>();
      final employees = await repo.getAllEmployee();
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load employees: $e';
        _isLoading = false;
      });
    }
  }

  void _navigateToEdit(Employee employee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterScreen(employeeToEdit: employee),
      ),
    ).then((_) => _loadEmployees()); // Reload after returning
  }

  void _navigateToCreate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(), // No employee = create mode
      ),
    ).then((_) => _loadEmployees()); // Reload after returning
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Employee'),
        content: Text(
          'Are you sure you want to delete ${employee.employeeName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Call delete API here
        // await context.read<EmployeeRepository>().deleteEmployee(employee.id!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${employee.employeeName} deleted successfully'),
          ),
        );
        _loadEmployees();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete employee: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEmployees,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _employees.isEmpty
          ? const Center(
        child: Text('No employees found'),
      )
          : RefreshIndicator(
        onRefresh: _loadEmployees,
        child: ListView.builder(
          itemCount: _employees.length,
          itemBuilder: (context, index) {
            final employee = _employees[index];
            return Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage: employee.profileImageUrl.isNotEmpty
                      ? NetworkImage(employee.profileImageUrl)
                      : null,
                  child: employee.profileImageUrl.isEmpty
                      ? Text(
                    employee.employeeName.isNotEmpty
                        ? employee.employeeName[0].toUpperCase()
                        : '?',
                  )
                      : null,
                ),
                title: Text(
                  employee.employeeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ID: ${employee.employeeID}'),
                    Text('Email: ${employee.email}'),
                    Text('Department: ${employee.departmentName}'),
                    if (employee.roleCode != null)
                      Text('Role: ${employee.roleCode}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      color: Colors.blue,
                      onPressed: () => _navigateToEdit(employee),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      color: Colors.red,
                      onPressed: () => _deleteEmployee(employee),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        icon: const Icon(Icons.add),
        label: const Text('Add Employee'),
      ),
    );
  }
}