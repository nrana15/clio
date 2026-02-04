import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/security/biometric_auth.dart';
import '../../../core/security/security_check.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_overlay.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String? _biometricName;
  
  // User info
  String? _userPhone;
  String? _userEmail;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      // Check biometric availability
      final canCheck = await BiometricAuthService.canCheckBiometrics();
      final availableTypes = await BiometricAuthService.getAvailableBiometrics();
      final biometricName = await BiometricAuthService.getBiometricName();
      final biometricEnabled = await BiometricAuthService.isBiometricLockEnabled();
      
      // Load user info
      final phone = await SecureStorageService.getUserPhone();
      final email = await SecureStorageService.getUserEmail();
      
      setState(() {
        _biometricAvailable = canCheck && availableTypes.isNotEmpty;
        _biometricName = biometricName;
        _biometricEnabled = biometricEnabled;
        _userPhone = phone;
        _userEmail = email;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      // Authenticate before enabling
      final result = await BiometricAuthService.authenticate(
        localizedReason: 'Authenticate to enable biometric lock',
      );
      
      if (result.success) {
        await BiometricAuthService.enableBiometricLock();
        setState(() => _biometricEnabled = true);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Biometric lock enabled'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        setState(() => _biometricEnabled = false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Authentication failed'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } else {
      await BiometricAuthService.disableBiometricLock();
      setState(() => _biometricEnabled = false);
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthBloc>().add(AuthLogoutRequested());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    // TODO: Implement account deletion
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deletion coming soon'),
        ),
      );
    }
  }

  Future<void> _contactSupport() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@clio.app',
      queryParameters: {
        'subject': 'CLIO Support Request',
        'body': 'Hello CLIO Support,\n\n',
      },
    );
    
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _shareApp() async {
    await Share.share(
      'Check out CLIO - Credit Card Bill Aggregator! Download at https://clio.app',
      subject: 'CLIO - Credit Card Bill Aggregator',
    );
  }

  Future<void> _runSecurityCheck() async {
    setState(() => _isLoading = true);
    
    final result = await SecurityCheckService.performSecurityCheck();
    
    setState(() => _isLoading = false);
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                result.isSecure ? Icons.verified_user : Icons.warning,
                color: result.isSecure ? AppColors.success : AppColors.warning,
              ),
              SizedBox(width: 8.w),
              const Text('Security Check'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.isSecure
                    ? 'Your device appears to be secure.'
                    : 'Security issues detected:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (result.threats.isNotEmpty) ...[
                SizedBox(height: 12.h),
                ...result.threats.map((threat) => Padding(
                  padding: EdgeInsets.only(bottom: 4.h),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 16.w,
                        color: AppColors.warning,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          SecurityCheckService.getThreatDescription(threat),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: ListView(
          children: [
            // Account Section
            _SectionHeader(title: 'Account'),
            _SettingsCard(
              children: [
                _ProfileTile(
                  phone: _userPhone,
                  email: _userEmail,
                  onTap: () {
                    // TODO: Navigate to profile edit
                  },
                ),
              ],
            ),
            
            // Security Section
            _SectionHeader(title: 'Security'),
            _SettingsCard(
              children: [
                if (_biometricAvailable)
                  _SwitchTile(
                    icon: Icons.fingerprint,
                    iconColor: AppColors.primary,
                    title: _biometricName ?? 'Biometric Lock',
                    subtitle: 'Use biometrics to unlock the app',
                    value: _biometricEnabled,
                    onChanged: _toggleBiometric,
                  ),
                _ListTile(
                  icon: Icons.security,
                  iconColor: AppColors.success,
                  title: 'Security Check',
                  subtitle: 'Check device security status',
                  onTap: _runSecurityCheck,
                ),
                _ListTile(
                  icon: Icons.lock_outline,
                  iconColor: AppColors.warning,
                  title: 'Privacy Policy',
                  subtitle: 'How we handle your data',
                  onTap: () {
                    // TODO: Open privacy policy
                  },
                ),
              ],
            ),
            
            // Notifications Section
            _SectionHeader(title: 'Notifications'),
            _SettingsCard(
              children: [
                _SwitchTile(
                  icon: Icons.notifications_outlined,
                  iconColor: AppColors.primary,
                  title: 'Push Notifications',
                  subtitle: 'Get reminded about upcoming bills',
                  value: true, // TODO: Get from preferences
                  onChanged: (value) {
                    // TODO: Update notification preferences
                  },
                ),
                _ListTile(
                  icon: Icons.schedule,
                  iconColor: AppColors.primary,
                  title: 'Reminder Schedule',
                  subtitle: 'Configure when to receive reminders',
                  onTap: () {
                    // TODO: Open reminder settings
                  },
                ),
              ],
            ),
            
            // App Section
            _SectionHeader(title: 'App'),
            _SettingsCard(
              children: [
                _ListTile(
                  icon: Icons.share_outlined,
                  iconColor: AppColors.info,
                  title: 'Share CLIO',
                  subtitle: 'Tell your friends about the app',
                  onTap: _shareApp,
                ),
                _ListTile(
                  icon: Icons.star_outline,
                  iconColor: AppColors.warning,
                  title: 'Rate Us',
                  subtitle: 'Rate on the App Store',
                  onTap: () {
                    // TODO: Open app store
                  },
                ),
                _ListTile(
                  icon: Icons.help_outline,
                  iconColor: AppColors.success,
                  title: 'Help & Support',
                  subtitle: 'Contact us for assistance',
                  onTap: _contactSupport,
                ),
                _InfoTile(
                  icon: Icons.info_outline,
                  iconColor: AppColors.lightTextSecondary,
                  title: 'Version',
                  value: '1.0.0',
                ),
              ],
            ),
            
            // Danger Zone
            _SectionHeader(title: 'Account Actions', color: AppColors.error),
            _SettingsCard(
              children: [
                _ListTile(
                  icon: Icons.logout,
                  iconColor: AppColors.error,
                  title: 'Logout',
                  titleColor: AppColors.error,
                  onTap: _showLogoutDialog,
                ),
                _ListTile(
                  icon: Icons.delete_forever,
                  iconColor: AppColors.error,
                  title: 'Delete Account',
                  titleColor: AppColors.error,
                  onTap: _showDeleteAccountDialog,
                ),
              ],
            ),
            
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;

  const _SectionHeader({
    required this.title,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        24.h,
        AppSpacing.screenPadding,
        8.h,
      ),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: color ?? AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        children: _addDividers(children),
      ),
    );
  }

  List<Widget> _addDividers(List<Widget> widgets) {
    final result = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      result.add(widgets[i]);
      if (i < widgets.length - 1) {
        result.add(Divider(
          height: 1,
          indent: 56.w,
          endIndent: 16.w,
          color: AppColors.lightBorder,
        ));
      }
    }
    return result;
  }
}

class _ListTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? titleColor;

  const _ListTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 20.w,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.lightTextSecondary,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.lightTextSecondary,
      ),
      onTap: onTap,
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 20.w,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.lightTextSecondary,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppBorderRadius.sm),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 20.w,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final String? phone;
  final String? email;
  final VoidCallback onTap;

  const _ProfileTile({
    this.phone,
    this.email,
    required this.onTap,
  });

  String get _displayText {
    if (phone != null && phone!.isNotEmpty) return phone!;
    if (email != null && email!.isNotEmpty) return email!;
    return 'User Profile';
  }

  String? get _subtitle {
    if (phone != null && email != null && email!.isNotEmpty) {
      return email;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48.w,
        height: 48.w,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            _displayText.substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
            ),
          ),
        ),
      ),
      title: Text(
        _displayText,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: _subtitle != null
          ? Text(
              _subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.lightTextSecondary,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.lightTextSecondary,
      ),
      onTap: onTap,
    );
  }
}
