import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'src/core/theme/app_theme.dart';
import 'src/presentation/blocs/auth/auth_bloc.dart';
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
          home: BlocProvider(
            create: (context) => AuthBloc()..add(AuthStarted()),
            child: const AuthWrapper(),
          ),
        );
      },
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
