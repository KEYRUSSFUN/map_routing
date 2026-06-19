import 'package:flutter/material.dart';
import 'package:map_routing/data/services/google_auth_service.dart';
import 'package:map_routing/data/services/registration_service.dart';
import 'package:map_routing/features/auth/presentation/auth_flow.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/auth/presentation/create_account_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _googleLoading = ValueNotifier<bool>(false);
  bool _isLoading = false;
  String? _errorMessage;

  final registrationService = RegistrationService();
  final googleAuthService = GoogleAuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _googleLoading.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text;
    final password = _passwordController.text;

    final loginResult = await registrationService.loginUser(email, password);

    if (!mounted) return;

    setState(() => _isLoading = false);

    final token = loginResult.token;
    if (token != null) {
      try {
        await AuthFlow.continueAfterAuth(context, token: token);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
      return;
    }

    setState(() {
      _errorMessage =
          loginResult.error ?? 'Ошибка входа. Неверный email или пароль';
    });
  }

  Future<void> _signInWithGoogle() async {
    await AuthFlow.handleGoogleSignIn(
      context,
      googleAuthService: googleAuthService,
      loadingNotifier: _googleLoading,
    );
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
                Text('С возвращением', style: authTitleStyle()),
                const SizedBox(height: 8),
                Text(
                  'Войдите, чтобы продолжить\nсвой фитнес-путь',
                  style: authSubtitleStyle(),
                ),
                const SizedBox(height: 24),
                AuthTextField(
                  label: 'Электронная почта',
                  controller: _emailController,
                  hint: 'you@domain.com',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите email';
                    }
                    if (!value.contains('@')) {
                      return 'Неверный формат email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Пароль',
                  controller: _passwordController,
                  hint: 'Введите ваш пароль',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  showVisibilityToggle: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите пароль';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: AuthColors.forgotPassword,
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Забыли пароль?',
                      style: authLinkStyle(color: AuthColors.forgotPassword),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: authFooterStyle().copyWith(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                ],
                AuthPrimaryButton(
                  label: 'Войти',
                  isLoading: _isLoading,
                  onPressed: _login,
                ),
                const SizedBox(height: 24),
                const AuthDivider(label: 'или продолжите с помощью'),
                const SizedBox(height: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: _googleLoading,
                  builder: (context, googleLoading, _) {
                    return AuthSocialButtons(
                      isGoogleLoading: googleLoading,
                      onGooglePressed: googleAuthService.isConfigured
                          ? _signInWithGoogle
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 24),
                AuthFooterLink(
                  prefix: 'Нет аккаунта? ',
                  action: 'Зарегистрироваться',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateAccountPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
