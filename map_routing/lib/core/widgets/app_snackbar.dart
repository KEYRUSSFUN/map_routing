import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppSnackBarVariant { info, success, error }

abstract final class AppSnackBarColors {
  static const primaryGreen = Color(0xFF00E676);
  static const title = Color(0xFF212121);
  static const body = Color(0xFF757575);
  static const border = Color(0xFFE8E8E8);
  static const error = Color(0xFFE53935);
}

class AppSnackBar {
  AppSnackBar._();

  static const _displayDuration = Duration(milliseconds: 2800);
  static const _fadeInDuration = Duration(milliseconds: 280);
  static const _fadeOutDuration = Duration(milliseconds: 420);

  static void show(
    BuildContext context,
    String message, {
    AppSnackBarVariant? variant,
  }) {
    final resolvedVariant = variant ?? _variantFromMessage(message);
    final host = AppSnackBarHost.maybeOf(context);
    if (host != null) {
      host.show(
        message,
        variant: resolvedVariant,
        displayDuration: _displayDuration,
        fadeInDuration: _fadeInDuration,
        fadeOutDuration: _fadeOutDuration,
      );
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        _buildSnackBar(
          message: message,
          variant: resolvedVariant,
        ),
      );
  }

  static AppSnackBarVariant _variantFromMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('ошибка') ||
        lower.contains('не удалось') ||
        lower.contains('невозможно') ||
        lower.contains('не возможно')) {
      return AppSnackBarVariant.error;
    }
    if (lower.contains('сохранён') ||
        lower.contains('сохранен') ||
        lower.contains('отправлен') ||
        lower.contains('принят') ||
        lower.contains('обновлён') ||
        lower.contains('обновлен') ||
        lower.contains('очищен')) {
      return AppSnackBarVariant.success;
    }
    return AppSnackBarVariant.info;
  }

  static SnackBar _buildSnackBar({
    required String message,
    required AppSnackBarVariant variant,
  }) {
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: _displayDuration,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      elevation: 0,
      dismissDirection: DismissDirection.horizontal,
      content: _AppSnackBarBody(message: message, variant: variant),
    );
  }
}

class AppSnackBarHost extends StatefulWidget {
  const AppSnackBarHost({super.key, required this.child});

  final Widget child;

  static AppSnackBarHostState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<AppSnackBarHostState>();
  }

  @override
  State<AppSnackBarHost> createState() => AppSnackBarHostState();
}

class AppSnackBarHostState extends State<AppSnackBarHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  String? _message;
  AppSnackBarVariant _variant = AppSnackBarVariant.info;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void show(
    String message, {
    AppSnackBarVariant variant = AppSnackBarVariant.info,
    required Duration displayDuration,
    required Duration fadeInDuration,
    required Duration fadeOutDuration,
  }) {
    _hideTimer?.cancel();
    if (_controller.isAnimating) {
      _controller.stop();
    }

    setState(() {
      _message = message;
      _variant = variant;
    });

    _controller.duration = fadeInDuration;
    _controller.forward(from: 0).then((_) {
      _hideTimer = Timer(displayDuration, () => _hide(fadeOutDuration));
    });
  }

  Future<void> _hide(Duration fadeOutDuration) async {
    if (!mounted || _message == null) return;
    _controller.duration = fadeOutDuration;
    await _controller.reverse();
    if (!mounted) return;
    setState(() => _message = null);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_message != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.viewPaddingOf(context).bottom + 88,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Material(
                  color: Colors.transparent,
                  child: _AppSnackBarBody(
                    message: _message!,
                    variant: _variant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AppSnackBarBody extends StatelessWidget {
  const _AppSnackBarBody({
    required this.message,
    required this.variant,
  });

  final String message;
  final AppSnackBarVariant variant;

  @override
  Widget build(BuildContext context) {
    final accent = switch (variant) {
      AppSnackBarVariant.success => AppSnackBarColors.primaryGreen,
      AppSnackBarVariant.error => AppSnackBarColors.error,
      AppSnackBarVariant.info => AppSnackBarColors.primaryGreen,
    };

    final icon = switch (variant) {
      AppSnackBarVariant.success => Icons.check_circle_outline_rounded,
      AppSnackBarVariant.error => Icons.error_outline_rounded,
      AppSnackBarVariant.info => Icons.info_outline_rounded,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppSnackBarColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.lexendDeca(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppSnackBarColors.title,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension AppSnackBarContext on BuildContext {
  void showAppSnackBar(
    String message, {
    AppSnackBarVariant? variant,
  }) {
    AppSnackBar.show(this, message, variant: variant);
  }
}
