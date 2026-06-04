import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/data/services/registration_service.dart';
import 'package:map_routing/features/auth/data/auth_local_storage.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/shared/utils/validators.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final RegistrationService _registrationService = RegistrationService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _acceptedTerms = false;
  bool _isLoading = false;
  String? _termsError;

  Future<void> _register() async {
    if (!_acceptedTerms) {
      setState(() {
        _termsError = 'Примите условия использования';
      });
    } else {
      setState(() => _termsError = null);
    }

    if (!_formKey.currentState!.validate() || !_acceptedTerms) return;

    setState(() => _isLoading = true);

    final email = _emailController.text;
    final password = _passwordController.text;

    final registrationResult =
        await _registrationService.registerUser(email, password);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (registrationResult) {
      await AuthLocalStorage.savePendingFullName(_nameController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Регистрация прошла успешно!')),
      );
      Navigator.pushReplacementNamed(context, '/login_page');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка регистрации. Попробуйте снова.')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
                Text('Создать аккаунт', style: authTitleStyle()),
                const SizedBox(height: 8),
                Text(
                  'Начните отслеживать свою активность сегодня',
                  style: authSubtitleStyle(),
                ),
                const SizedBox(height: 24),
                AuthTextField(
                  label: 'Полное имя',
                  controller: _nameController,
                  hint: 'Имя Фамилия',
                  prefixIcon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Введите имя';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Электронная почта',
                  controller: _emailController,
                  hint: 'you@domain.com',
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Пароль',
                  controller: _passwordController,
                  hint: 'Создайте пароль',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  showVisibilityToggle: true,
                  validator: Validators.validatePassword,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Подтвердите пароль',
                  controller: _confirmPasswordController,
                  hint: 'Введите пароль ещё раз',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  showVisibilityToggle: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Подтвердите пароль';
                    }
                    if (value != _passwordController.text) {
                      return 'Пароли не совпадают';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _TermsCheckbox(
                  value: _acceptedTerms,
                  errorText: _termsError,
                  onChanged: (value) {
                    setState(() {
                      _acceptedTerms = value ?? false;
                      if (_acceptedTerms) _termsError = null;
                    });
                  },
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: 'Создать аккаунт',
                  isLoading: _isLoading,
                  onPressed: _register,
                ),
                const SizedBox(height: 24),
                const AuthDivider(label: 'или зарегистрируйтесь с помощью'),
                const SizedBox(height: 16),
                const AuthSocialButtons(),
                const SizedBox(height: 24),
                AuthFooterLink(
                  prefix: 'Уже есть аккаунт? ',
                  action: 'Войти',
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/login_page');
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

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.lexendDeca(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AuthColors.body,
      height: 1.4,
    );
    final linkStyle = baseStyle.copyWith(
      color: AuthColors.primaryGreen,
      fontWeight: FontWeight.w500,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
                activeColor: AuthColors.primaryGreen,
                side: const BorderSide(color: Color(0xFFCFCFCF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: baseStyle,
                  children: [
                    const TextSpan(text: 'Я согласен с '),
                    TextSpan(
                      text: 'Условиями',
                      style: linkStyle,
                      recognizer: TapGestureRecognizer()..onTap = () {},
                    ),
                    const TextSpan(text: ' и '),
                    TextSpan(
                      text: 'Политикой конфиденциальности',
                      style: linkStyle,
                      recognizer: TapGestureRecognizer()..onTap = () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: baseStyle.copyWith(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
