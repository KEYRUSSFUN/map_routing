import 'package:flutter/material.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/services/registration_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/shared/utils/validators.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _registrationService = RegistrationService();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  String? _noticeMessage;
  AuthNoticeVariant? _noticeVariant;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearNotice() {
    _noticeMessage = null;
    _noticeVariant = null;
  }

  Future<void> _sendCode({bool isResend = false}) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _clearNotice();
        _noticeMessage = 'Введите корректный email';
        _noticeVariant = AuthNoticeVariant.error;
      });
      return;
    }

    if (isResend) {
      final emailError = Validators.validateEmail(email);
      if (emailError != null) {
        setState(() {
          _clearNotice();
          _noticeMessage = emailError;
          _noticeVariant = AuthNoticeVariant.error;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _clearNotice();
      if (!isResend) {
        _codeSent = false;
      }
    });

    final result = await _registrationService.requestPasswordReset(email);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.suggestRegistration) {
      setState(() {
        _noticeMessage = result.message ?? 'Аккаунт с таким email не найден.';
        _noticeVariant = AuthNoticeVariant.info;
      });
      return;
    }

    if (result.error != null) {
      setState(() {
        _noticeMessage = result.error;
        _noticeVariant = AuthNoticeVariant.error;
      });
      return;
    }

    final devCode = result.resetCode;
    var noticeMessage = isResend
        ? 'Код повторно отправлен на $email. Проверьте почту и папку «Спам».'
        : (result.message ??
            'Письмо отправлено. Если код не пришёл в течение минуты, проверьте папку «Спам».');
    var noticeVariant = AuthNoticeVariant.success;

    if (devCode != null && devCode.isNotEmpty) {
      _codeController.text = devCode;
      noticeMessage =
          '$noticeMessage\n\nКод для разработки (SMTP не настроен): $devCode';
      noticeVariant = AuthNoticeVariant.info;
    } else {
      _codeController.clear();
    }

    setState(() {
      _codeSent = true;
      _noticeMessage = noticeMessage;
      _noticeVariant = noticeVariant;
    });
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _clearNotice();
    });

    final result = await _registrationService.resetPassword(
      email: _emailController.text.trim(),
      code: _codeController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (result.error != null) {
      setState(() {
        _noticeMessage = result.error;
        _noticeVariant = AuthNoticeVariant.error;
      });
      return;
    }

    AppSnackBar.show(
      context,
      result.message ?? 'Пароль успешно изменён',
      variant: AppSnackBarVariant.success,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: AuthFormCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Восстановление пароля',
                        style: authTitleStyle().copyWith(fontSize: 24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _codeSent
                      ? 'Введите код из письма и новый пароль'
                      : 'Укажите email — мы отправим код для сброса пароля',
                  style: authSubtitleStyle(),
                ),
                if (_noticeMessage != null && _noticeVariant != null) ...[
                  const SizedBox(height: 16),
                  AuthNoticeBanner(
                    message: _noticeMessage!,
                    variant: _noticeVariant!,
                  ),
                ],
                const SizedBox(height: 24),
                AuthTextField(
                  label: 'Электронная почта',
                  controller: _emailController,
                  hint: 'you@domain.com',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 16),
                  AuthTextField(
                    label: 'Код подтверждения',
                    controller: _codeController,
                    hint: '123456',
                    prefixIcon: Icons.pin_outlined,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите код';
                      }
                      if (value.trim().length != 6) {
                        return 'Код должен содержать 6 цифр';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    label: 'Новый пароль',
                    controller: _passwordController,
                    hint: 'Введите новый пароль',
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    showVisibilityToggle: true,
                    validator: Validators.validatePassword,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    label: 'Подтвердите пароль',
                    controller: _confirmPasswordController,
                    hint: 'Повторите пароль',
                    prefixIcon: Icons.lock_outline,
                    obscureText: true,
                    showVisibilityToggle: true,
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Пароли не совпадают';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: _codeSent ? 'Сохранить пароль' : 'Отправить код',
                  isLoading: _isLoading,
                  onPressed: _codeSent ? _resetPassword : _sendCode,
                ),
                if (_codeSent) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading ? null : () => _sendCode(isResend: true),
                    child: Text(
                      'Отправить код повторно',
                      style: authLinkStyle(color: AuthColors.forgotPassword),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
