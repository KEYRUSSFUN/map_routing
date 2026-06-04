import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/data/services/registration_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/auth/presentation/complete_profile_page.dart';
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
  bool _isLoading = false;
  String? _errorMessage;

  final registrationService = RegistrationService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

    final token = await registrationService.loginUser(email, password);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (token != null) {
      final checkResponse = await http.get(
        Uri.parse('$backendBaseUrl/api/user_info/check'),
        headers: {'Authorization': token},
      );

      if (!mounted) return;

      if (checkResponse.statusCode == 404) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CompleteProfilePage(token: token)),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      setState(() {
        _errorMessage = 'Ошибка входа. Неверный email или пароль';
      });
    }
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
                const AuthSocialButtons(),
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
