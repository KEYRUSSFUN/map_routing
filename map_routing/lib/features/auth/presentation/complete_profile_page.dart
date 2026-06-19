import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/features/auth/data/auth_local_storage.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/shared/data/countries.dart';

class CompleteProfilePage extends StatefulWidget {
  final String token;
  final String? initialName;

  const CompleteProfilePage({
    super.key,
    required this.token,
    this.initialName,
  });

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  String _sex = 'male';
  String _country = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialName();
  }

  Future<void> _loadInitialName() async {
    final name = widget.initialName ?? await AuthLocalStorage.getPendingFullName();
    if (name != null && name.isNotEmpty && mounted) {
      _nameController.text = name;
    }
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final body = {
      'name': _nameController.text.trim(),
      'weight': double.parse(_weightController.text.trim()),
      'height': double.parse(_heightController.text.trim()),
      'sex': _sex,
      'age': int.parse(_ageController.text.trim()),
      'country': _country,
    };

    final response = await http.post(
      Uri.parse('$backendBaseUrl/api/user_info'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': widget.token,
      },
      body: jsonEncode(body),
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (response.statusCode == 200 || response.statusCode == 201) {
      await AuthLocalStorage.clearPendingFullName();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      AppSnackBar.show(context, 'Ошибка: ${response.body}');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
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
                Text('Заполните профиль', style: authTitleStyle()),
                const SizedBox(height: 8),
                Text(
                  'Расскажите о себе, чтобы приложение точнее считало вашу активность',
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
                  label: 'Вес (кг)',
                  controller: _weightController,
                  hint: '70',
                  prefixIcon: Icons.monitor_weight_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Введите вес' : null,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Рост (см)',
                  controller: _heightController,
                  hint: '175',
                  prefixIcon: Icons.height,
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Введите рост' : null,
                ),
                const SizedBox(height: 16),
                AuthDropdownField<String>(
                  label: 'Пол',
                  value: _sex,
                  items: [
                    DropdownMenuItem(
                      value: 'male',
                      child: Text('Мужской', style: authFieldStyle()),
                    ),
                    DropdownMenuItem(
                      value: 'female',
                      child: Text('Женский', style: authFieldStyle()),
                    ),
                  ],
                  onChanged: (value) => setState(() => _sex = value!),
                  validator: (value) =>
                      value == null ? 'Выберите пол' : null,
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Возраст',
                  controller: _ageController,
                  hint: '25',
                  prefixIcon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Введите возраст' : null,
                ),
                const SizedBox(height: 16),
                AuthDropdownField<String>(
                  label: 'Страна',
                  value: _country,
                  items: buildCountryDropdownItems(popularCountries),
                  onChanged: (value) =>
                      setState(() => _country = value ?? ''),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Выберите страну' : null,
                ),
                const SizedBox(height: 24),
                AuthPrimaryButton(
                  label: 'Сохранить',
                  isLoading: _isLoading,
                  onPressed: _submitProfile,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
