import '../../../app_import.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // track when we first showed this screen
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
  }

  /// Ensures we stay on splash screen for at least [minDuration]
  Future<void> _maybeDelayThen(VoidCallback navAction) async {
    const minDuration = Duration(seconds: 2);
    final elapsed = DateTime.now().difference(_startedAt);
    final remaining = minDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    navAction();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthLoginBloc, AuthLoginState>(
      listener: (ctx, state) {
        if (state is AuthAuthenticated) {
          _maybeDelayThen(() {
            Navigator.of(ctx).pushReplacementNamed(
              '/home',
              arguments: state.employee,
            );
          });
        } else if (state is Unauthenticated) {
          _maybeDelayThen(() {
            Navigator.of(ctx).pushReplacementNamed('/login');
          });
        }
      },
      child: Scaffold(
        // 1) Customize your background color here
        backgroundColor: Color.fromRGBO(0, 105, 133, 1),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Optional: your logo
              Image.asset(
                'assets/images/company_logo.png',
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}