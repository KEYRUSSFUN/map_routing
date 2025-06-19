import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:map_routing/complete_profile_page.dart';
import 'usersData/requests.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false; // Индикатор загрузки
  String? _errorMessage; // Сообщение об ошибке

  final registrationService =
      RegistrationService(baseUrl: 'http://192.168.1.81:5000');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text;
    final password = _passwordController.text;

    final token = await registrationService.loginUser(email, password);

    setState(() => _isLoading = false);

    if (token != null) {
      final checkResponse = await http.post(
        Uri.parse('http://192.168.1.81:5000/login'),
        headers: {'Authorization': token},
      );

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
        _errorMessage = 'Ошибка входа. Неправильный пароль или email';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/start_page'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  floatingLabelStyle: TextStyle(color: Colors.blue),
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    // Граница при фокусировке
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите email';
                  }
                  if (!value.contains('@')) {
                    return 'Неправильный формат email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    // Граница при фокусировке
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  floatingLabelStyle: TextStyle(color: Colors.blue),
                ),
                obscureText: true, // Скрывает пароль
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите пароль';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null) // Отображаем сообщение об ошибке
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : _login, // Отключаем кнопку во время загрузки
                child:
                    _isLoading // Показываем индикатор загрузки или текст кнопки
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color.fromARGB(255, 21, 217, 243)),
                            ),
                          )
                        : const Text(
                            'Войти',
                            style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255)),
                          ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  // Обработка перехода на страницу регистрации
                },
                child: const Text('Нет аккаунта? Зарегистрироваться'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
