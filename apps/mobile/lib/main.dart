import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'src/core/security/secure_lifecycle.dart';
import 'src/core/security/security_check.dart';
import 'src/core/theme/app_theme.dart';
import 'src/presentation/blocs/auth/auth_bloc.dart';
export 'src/presentation/blocs/auth/auth_bloc.dart';
import 'src/presentation/screens/auth/login_screen.dart';
import 'src/presentation/screens/main/main_screen.dart';
import 'src/presentation/screens/splash/splash_screen.dart';
import 'src/presentation/widgets/loading_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const ClioApp());
}

class ClioApp extends StatelessWidget {
  const ClioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'CLIO',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.system,
          home: SecureAppLifecycleObserver(
            secureOnBackground: true,
            child: BlocProvider(
              create: (context) => AuthBloc()..add(AuthStarted()),
              child: const SecurityWrapper(),
            ),
          ),
        );
      },
    );
  }
}

/// SecurityWrapper handles security checks and authentication state
class SecurityWrapper extends StatefulWidget {
  const SecurityWrapper({super.key});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> {
  bool _securityChecked = false;
  SecurityCheckResult? _securityResult;
  bool _showSecurityWarning = false;

  @override
  void initState() {
    super.initState();
    _performSecurityCheck();
  }

  Future<void> _performSecurityCheck() async {
    // Perform security checks
    final result = await SecurityCheckService.performSecurityCheck();
    
    setState(() {
      _securityResult = result;
      _securityChecked = true;
      _showSecurityWarning = !result.isSecure && 
          SecurityCheckService.shouldBlockUsage(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking security
    if (!_securityChecked) {
      return const SplashScreen();
    }

    // Show security warning if compromised
    if (_showSecurityWarning) {
      return _SecurityWarningScreen(
        result: _securityResult!,
        onContinueAnyway: () {
          setState(() => _showSecurityWarning = false);
        },
      );
    }

    // Normal auth flow
    return const AuthWrapper();
  }
}

/// Security warning screen for compromised devices
class _SecurityWarningScreen extends StatelessWidget {
  final SecurityCheckResult result;
  final VoidCallback onContinueAnyway;

  const _SecurityWarningScreen({
    required this.result,
    required this.onContinueAnyway,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.security_update_warning,
                size: 80.w,
                color: AppColors.warning,
              ),
              SizedBox(height: 24.h),
              Text(
                'Security Warning',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Your device may be compromised. The following security issues were detected:',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: 24.h),
              ...result.threats.map((threat) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.warning_amber,
                      size: 20.w,
                      color: AppColors.warning,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      SecurityCheckService.getThreatDescription(threat),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )),
              SizedBox(height: 32.h),
              ElevatedButton.icon(
                onPressed: onContinueAnyway,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue Anyway'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: Size(double.infinity, 48.h),
                ),
              ),
              SizedBox(height: 16.h),
              TextButton(
                onPressed: () {
                  // Close the app
                  SystemNavigator.pop();
                },
                child: const Text('Exit App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AuthWrapper handles navigation based on authentication state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        // Listen for state changes that should trigger navigation
        return previous.runtimeType != current.runtimeType;
      },
      listener: (context, state) {
        // Handle any side effects if needed
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        // Show splash screen while checking auth status
        if (state is AuthInitial || state is AuthLoading) {
          return const SplashScreen();
        }
        
        // User is authenticated
        if (state is AuthAuthenticated) {
          return const MainScreen();
        }
        
        // User is not authenticated - show login
        if (state is AuthUnauthenticated || state is AuthError) {
          return const LoginScreen();
        }
        
        // OTP sent state - this is handled by navigation in LoginScreen
        if (state is AuthOtpSent) {
          return const LoginScreen();
        }
        
        // Default fallback
        return const SplashScreen();
      },
    );
  }
}
