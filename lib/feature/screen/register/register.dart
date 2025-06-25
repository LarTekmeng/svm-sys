import 'package:online_doc_savimex/app_import.dart';



class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _empIdCtrl = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  Department? _selectedDept;

  @override
  void initState() {
    super.initState();
    // kick off loading departments
    context.read<RegisterBloc>().add(LoadDepartments());
  }

  @override
  void dispose() {
    _empIdCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate() || _selectedDept == null) return;
    context.read<RegisterBloc>().add(
      RegisterRequested(
        _nameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passCtrl.text,
        _selectedDept!.id,
        _empIdCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RegisterBloc, RegisterState>(
      listener: (context, state) {
        if (state is RegisterSuccess) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        } else if (state is RegisterFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error)),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Register')),
        body: BlocBuilder<RegisterBloc, RegisterState>(
          builder: (context, state) {
            if (state is RegisterLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            List<Department> depts = [];
            if (state is DepartmentsLoadSuccess) {
              depts = state.departments;
              if (_selectedDept == null && depts.isNotEmpty) {
                _selectedDept = depts.first;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<Department>(
                      value: _selectedDept,
                      decoration: const InputDecoration(labelText: 'Department'),
                      items: depts
                          .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(d.name),
                      ))
                          .toList(),
                      onChanged: (d) => setState(() => _selectedDept = d),
                      validator: (_) => _selectedDept == null
                          ? 'Please select one'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _empIdCtrl,
                      decoration: const InputDecoration(labelText: 'Employee ID'),
                      validator: (v) => v == null || v.isEmpty ? 'Enter employee ID' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter email';
                        return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)
                            ? null
                            : 'Invalid email';
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passCtrl,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.length < 6) return 'Min 6 chars';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _onSubmit,
                      child: const Text('Register'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text('Have an account? Login'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
