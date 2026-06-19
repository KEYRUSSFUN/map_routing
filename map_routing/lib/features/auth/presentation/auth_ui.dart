import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/widgets/stride_track_logo.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';

abstract final class AuthColors {
  static const primaryGreen = Color(0xFF00E676);
  static const title = Color(0xFF030303);
  static const body = Color(0xFF6B6B6B);
  static const hint = Color(0xFF94A3B8);
  static const border = Color(0xFFD9D9D9);
  static const forgotPassword = Color(0xFFFF9800);
  static const divider = Color(0xFFE6E6E6);
  static const dividerText = Color(0xFF8A8A8A);
  static const socialBorder = Color(0xFFDCDCDC);
  static const scaffoldBackground = Color(0xFFF7F7F7);
}

TextStyle authTitleStyle() => GoogleFonts.lexendDeca(
  fontSize: 28,
  fontWeight: FontWeight.w700,
  color: AuthColors.title,
  height: 1.2,
);

TextStyle authSubtitleStyle() => GoogleFonts.lexendDeca(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: AuthColors.body,
  height: 1.4,
);

TextStyle authLabelStyle() => GoogleFonts.lexendDeca(
  fontSize: 13,
  fontWeight: FontWeight.w400,
  color: AuthColors.body,
);

TextStyle authFieldStyle() => GoogleFonts.lexendDeca(
  fontSize: 15,
  fontWeight: FontWeight.w400,
  color: AuthColors.title,
);

TextStyle authHintStyle() => GoogleFonts.lexendDeca(
  fontSize: 15,
  fontWeight: FontWeight.w400,
  color: AuthColors.hint,
);

TextStyle authButtonStyle() => GoogleFonts.lexendDeca(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: Colors.white,
);

TextStyle authLinkStyle({Color color = AuthColors.primaryGreen}) =>
    GoogleFonts.lexendDeca(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: color,
    );

TextStyle authFooterStyle() => GoogleFonts.lexendDeca(
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: AuthColors.body,
);

TextStyle authHeaderBrandStyle() => GoogleFonts.lexendDeca(
  fontSize: 16,
  fontWeight: FontWeight.w800,
  color: AuthColors.primaryGreen,
  letterSpacing: -0.4,
);

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrandHeader(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: StrideTrackLogo(size: 28),
    );
  }
}

class AuthFormCard extends StatelessWidget {
  const AuthFormCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.showVisibilityToggle = false,
    this.errorText,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool showVisibilityToggle;
  final String? errorText;
  final String? Function(String?)? validator;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: authLabelStyle()),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: _obscure,
          validator: widget.validator,
          style: authFieldStyle(),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: authHintStyle(),
            errorText: widget.errorText,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, color: AuthColors.body, size: 20)
                : null,
            suffixIcon: widget.showVisibilityToggle
                ? IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AuthColors.body,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AuthColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AuthColors.primaryGreen,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthColors.primaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AuthColors.primaryGreen.withValues(
            alpha: 0.6,
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(label, style: authButtonStyle().copyWith(height: 1.2)),
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AuthColors.divider, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: authFooterStyle().copyWith(color: AuthColors.dividerText),
          ),
        ),
        const Expanded(child: Divider(color: AuthColors.divider, thickness: 1)),
      ],
    );
  }
}

class AuthSocialButtons extends StatelessWidget {
  const AuthSocialButtons({
    super.key,
    this.onGooglePressed,
    this.isGoogleLoading = false,
  });

  final VoidCallback? onGooglePressed;
  final bool isGoogleLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            label: 'Google',
            icon: FontAwesomeIcons.google,
            onPressed: isGoogleLoading ? null : onGooglePressed,
            isLoading: isGoogleLoading,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            label: 'Яндекс',
            icon: FontAwesomeIcons.yandex,
            onPressed: () {
              AppSnackBar.show(
                context,
                'Вход через Яндекс скоро будет доступен',
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final FaIconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AuthColors.title,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AuthColors.socialBorder),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(icon, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: AuthColors.title,
                  ),
                ),
              ],
            ),
    );
  }
}

class AuthDropdownField<T> extends StatelessWidget {
  const AuthDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: authLabelStyle()),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          style: authFieldStyle(),
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AuthColors.body,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AuthColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AuthColors.primaryGreen,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prefix,
    required this.action,
    required this.onTap,
  });

  final String prefix;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prefix, style: authFooterStyle()),
        GestureDetector(
          onTap: onTap,
          child: Text(action, style: authLinkStyle()),
        ),
      ],
    );
  }
}
