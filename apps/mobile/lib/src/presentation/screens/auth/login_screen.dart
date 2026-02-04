import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/loading_overlay.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLoading = false;
  bool _useEmail = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onContinuePressed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_useEmail) {
        await _authService.requestEmailOtp(_emailController.text.trim());
        if (mounted) {
          context.read<AuthBloc>().add(AuthLoginRequested(
            email: _emailController.text.trim(),
          ));
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                email: _emailController.text.trim(),
              ),
            ),
          );
        }
      } else {
        final phone = _formatPhoneNumber(_phoneController.text);
        await _authService.requestPhoneOtp(phone);
        if (mounted) {
          context.read<AuthBloc>().add(AuthLoginRequested(
            phoneNumber: phone,
          ));
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OtpScreen(
                phoneNumber: phone,
              ),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    // Add + prefix if not present
    if (!digits.startsWith('+')) {
      digits = '+$digits';
    }
    return digits;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.screenPadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 40.h),
                  // Logo
                  Center(
                    child: Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
                      ),
                      child: Icon(
                        Icons.credit_card,
                        size: 40.w,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(height: 32.h),
                  // Title
                  Text(
                    'Welcome to CLIO',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Manage all your credit card bills in one place',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                  SizedBox(height: 40.h),
                  // Toggle between phone and email
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _ToggleButton(
                            label: 'Phone',
                            isSelected: !_useEmail,
                            onTap: () => setState(() => _useEmail = false),
                          ),
                        ),
                        Expanded(
                          child: _ToggleButton(
                            label: 'Email',
                            isSelected: _useEmail,
                            onTap: () => setState(() => _useEmail = true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  // Input field
                  if (!_useEmail)
                    AppTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hint: '+1 (555) 000-0000',
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                      validator: _validatePhone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d\s\+\-\(\)]')),
                      ],
                    )
                  else
                    AppTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      validator: _validateEmail,
                    ),
                  if (_errorMessage != null) ...[
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppBorderRadius.md),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 20.w,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 32.h),
                  // Continue button
                  AppButton(
                    label: 'Continue',
                    onPressed: _onContinuePressed,
                    isFullWidth: true,
                  ),
                  SizedBox(height: 24.h),
                  // Terms text
                  Center(
                    child: Text(
                      'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: isSelected ? Colors.white : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }
}
