import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/services/auth_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_overlay.dart';
import '../main/main_screen.dart';

class OtpScreen extends StatefulWidget {
  final String? phoneNumber;
  final String? email;

  const OtpScreen({
    super.key,
    this.phoneNumber,
    this.email,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _authService = AuthService();
  final _focusNode = FocusNode();
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Resend timer
  int _resendSeconds = 60;
  Timer? _resendTimer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Auto-focus the OTP field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendSeconds = 60;
      _canResend = false;
    });
    
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  Future<void> _onVerifyPressed() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.verifyOtp(
        phoneNumber: widget.phoneNumber,
        email: widget.email,
        otp: otp,
      );

      if (mounted) {
        context.read<AuthBloc>().add(AuthOtpSubmitted(
          otp: otp,
          phoneNumber: widget.phoneNumber,
          email: widget.email,
        ));
        
        // Navigate to main screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to verify OTP. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onResendPressed() async {
    if (!_canResend) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.phoneNumber != null) {
        await _authService.requestPhoneOtp(widget.phoneNumber!);
      } else if (widget.email != null) {
        await _authService.requestEmailOtp(widget.email!);
      }
      _startResendTimer();
      _otpController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New code sent successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to resend code. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getDisplayContact() {
    if (widget.phoneNumber != null) {
      final phone = widget.phoneNumber!;
      if (phone.length > 4) {
        return '••••••${phone.substring(phone.length - 4)}';
      }
      return phone;
    } else if (widget.email != null) {
      final email = widget.email!;
      final atIndex = email.indexOf('@');
      if (atIndex > 2) {
        return '${email.substring(0, 2)}•••••@${email.substring(atIndex + 1)}';
      }
      return email;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Enter Verification Code',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                SizedBox(height: 8.h),
                Text(
                  'We sent a 6-digit code to ${_getDisplayContact()}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
                SizedBox(height: 40.h),
                // OTP Input
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  controller: _otpController,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                    fieldHeight: 56.h,
                    fieldWidth: 48.w,
                    activeFillColor: AppColors.lightSurface,
                    inactiveFillColor: AppColors.lightSurface,
                    selectedFillColor: AppColors.primary.withOpacity(0.1),
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.lightBorder,
                    selectedColor: AppColors.primary,
                  ),
                  enableActiveFill: true,
                  onChanged: (value) {
                    if (_errorMessage != null) {
                      setState(() => _errorMessage = null);
                    }
                  },
                ),
                if (_errorMessage != null) ...[
                  SizedBox(height: 16.h),
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
                // Verify button
                AppButton(
                  label: 'Verify',
                  onPressed: _onVerifyPressed,
                  isFullWidth: true,
                ),
                SizedBox(height: 24.h),
                // Resend section
                Center(
                  child: _canResend
                    ? TextButton(
                        onPressed: _onResendPressed,
                        child: Text(
                          'Resend Code',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : Text(
                        'Resend code in ${_resendSeconds}s',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
