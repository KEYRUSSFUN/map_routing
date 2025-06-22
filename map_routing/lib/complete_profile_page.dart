import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CompleteProfilePage extends StatefulWidget {
  final String token;

  const CompleteProfilePage({super.key, required this.token});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  String _sex = 'male';

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final body = {
      'name': _nameController.text,
      'weight': _weightController.text,
      'height': _heightController.text,
      'sex': _sex,
      'age': _ageController.text,
      'country': _countryController.text,
    };

    final response = await http.post(
      Uri.parse('http://192.168.1.105:5000/api/user_info'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': widget.token,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: ${response.body}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Заполните ваш профиль',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Имя',
                  floatingLabelStyle: TextStyle(color: Colors.black87),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Введите имя' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Вес (кг)',
                  floatingLabelStyle: TextStyle(color: Colors.black87),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Введите вес' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heightController,
                decoration: const InputDecoration(
                  labelText: 'Рост (см)',
                  floatingLabelStyle: TextStyle(color: Colors.black87),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Введите рост' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _sex,
                decoration: const InputDecoration(
                  labelText: 'Пол',
                  floatingLabelStyle: TextStyle(color: Colors.black87),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'male',
                    child: Text(
                      'Мужской',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'female',
                    child: Text(
                      'Женский',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _sex = value!),
                dropdownColor: Colors.white,
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey,
                  size: 24,
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(
                  labelText: 'Возраст',
                  floatingLabelStyle: TextStyle(color: Colors.black87),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || value.isEmpty ? 'Введите возраст' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(
                  labelText: 'Страна',
                  floatingLabelStyle: TextStyle(color: Colors.black87),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Введите страну' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitProfile,
                child: const Text(
                  'Сохранить',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
