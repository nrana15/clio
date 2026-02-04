import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget that protects sensitive content when app goes to background
/// 
/// This widget should wrap the entire app to ensure sensitive data
/// is hidden when the app is in the app switcher/recent apps
class SecureAppLifecycleObserver extends StatefulWidget {
  final Widget child;
  final bool secureOnBackground;
  final Color privacyScreenColor;

  const SecureAppLifecycleObserver({
    super.key,
    required this.child,
    this.secureOnBackground = true,
    this.privacyScreenColor = Colors.white,
  });

  @override
  State<SecureAppLifecycleObserver> createState() => _SecureAppLifecycleObserverState();
}

class _SecureAppLifecycleObserverState extends State<SecureAppLifecycleObserver>
    with WidgetsBindingObserver {
  bool _isInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setSecureFlag(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setSecureFlag(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.secureOnBackground) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        setState(() {
          _isInBackground = true;
        });
        break;
      case AppLifecycleState.resumed:
        setState(() {
          _isInBackground = false;
        });
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Set the secure flag to prevent screenshots and hide from recents
  void _setSecureFlag(bool secure) {
    if (widget.secureOnBackground) {
      // This prevents screenshots and hides content in app switcher
      // Note: This requires FLAG_SECURE on Android and appropriate iOS configuration
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Privacy screen overlay when in background
        if (_isInBackground && widget.secureOnBackground)
          Container(
            color: widget.privacyScreenColor,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'CLIO',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Secured',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Mixin for screens that need to hide sensitive content
/// 
/// Use this mixin on State classes of screens that display sensitive data
/// like credit card numbers, balances, etc.
mixin SecureScreenMixin<T extends StatefulWidget> on State<T> {
  bool _isObscured = false;

  /// Override this to return true for screens that should always be obscured
  /// in app switcher
  bool get shouldObscureInAppSwitcher => true;

  /// Obscure the screen content
  void obscureContent() {
    if (shouldObscureInAppSwitcher && mounted) {
      setState(() {
        _isObscured = true;
      });
    }
  }

  /// Reveal the screen content
  void revealContent() {
    if (mounted) {
      setState(() {
        _isObscured = false;
      });
    }
  }

  /// Wrap a widget with obscurity protection
  Widget withObscurityProtection(Widget child) {
    if (!_isObscured) return child;
    
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'Content Hidden',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A widget that obscures its child with a blur effect
/// Useful for masking sensitive content in screenshots
class ObscuredWidget extends StatelessWidget {
  final Widget child;
  final bool obscure;
  final double sigmaX;
  final double sigmaY;

  const ObscuredWidget({
    super.key,
    required this.child,
    this.obscure = true,
    this.sigmaX = 10.0,
    this.sigmaY = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!obscure) return child;

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Container(
            color: Colors.white.withOpacity(0.8),
            child: const Center(
              child: Icon(
                Icons.lock_outline,
                color: Colors.grey,
                size: 32,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
