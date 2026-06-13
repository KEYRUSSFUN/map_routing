import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/shared/data/countries.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final UserService userService = UserService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  String _sex = 'male';
  String _country = '';
  List<String> _countries = List<String>.from(popularCountries);
  File? _profileImage;
  String? _avatarUrl;
  bool _isLoading = false;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  String _readFieldValue(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    return text == 'null' ? '' : text;
  }

  String _readAge(Map<String, dynamic> data) {
    return _readFieldValue(data['age'] ?? data['Age']);
  }

  String _normalizeSex(String? raw) {
    final value = raw?.toLowerCase().trim() ?? '';
    if (value == 'male' || value == 'm' || value == 'м' || value == 'мужской') {
      return 'male';
    }
    if (value == 'female' ||
        value == 'f' ||
        value == 'ж' ||
        value == 'женский') {
      return 'female';
    }
    return 'male';
  }

  Future<void> _loadUserInfo() async {
    try {
      final data = await userService.fetchUserInfo();
      if (!mounted) return;

      if (data != null) {
        final country = resolveCountry(_readFieldValue(data['country']));
        setState(() {
          _nameController.text = _readFieldValue(data['name']);
          _countries = countriesForSelection(existing: country);
          _country = country;
          _heightController.text = _readFieldValue(data['height']);
          _weightController.text = _readFieldValue(data['weight']);
          _ageController.text = _readAge(data);
          _sex = _normalizeSex(data['sex']?.toString());
          _avatarUrl = data['avatar_url']?.toString();
          _isInitialLoading = false;
        });
      } else {
        setState(() => _isInitialLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить данные профиля')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isInitialLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  Future<void> _saveProfile() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final country = _country;
    final height = double.tryParse(_heightController.text.trim()) ?? 0.0;
    final weight = double.tryParse(_weightController.text.trim()) ?? 0.0;
    final age = int.tryParse(_ageController.text.trim()) ?? 0;

    if (name.isEmpty ||
        country.isEmpty ||
        height <= 0 ||
        weight <= 0 ||
        age <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните все обязательные поля корректно'),
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await userService.updateUserInfo({
        'name': name,
        'country': country,
        'height': height,
        'weight': weight,
        'age': age,
        'sex': _sex,
      });

      if (!mounted) return;

      if (response != null && response['success'] == true) {
        if (_profileImage != null) {
          final avatarUrl = await userService.uploadAvatar(_profileImage!);
          if (!mounted) return;

          if (avatarUrl == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Профиль сохранён, но не удалось загрузить фото',
                ),
              ),
            );
            Navigator.pop(context);
            return;
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Профиль обновлён')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка сохранения профиля')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(),
            Expanded(
              child: _isInitialLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: AuthFormCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Редактирование профиля',
                                  style: authTitleStyle()),
                              const SizedBox(height: 8),
                              Text(
                                'Обновите данные профиля и сохраните изменения',
                                style: authSubtitleStyle(),
                              ),
                              const SizedBox(height: 24),
                              Center(child: _buildAvatar()),
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
                              AuthDropdownField<String>(
                                label: 'Страна',
                                value: _country,
                                items: buildCountryDropdownItems(_countries),
                                onChanged: (value) =>
                                    setState(() => _country = value ?? ''),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Выберите страну';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              AuthTextField(
                                label: 'Рост (см)',
                                controller: _heightController,
                                hint: '175',
                                prefixIcon: Icons.height,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Введите рост';
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
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Введите вес';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              AuthTextField(
                                label: 'Возраст',
                                controller: _ageController,
                                hint: '25',
                                prefixIcon: Icons.cake_outlined,
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Введите возраст';
                                  }
                                  final age = int.tryParse(value.trim());
                                  if (age == null || age <= 0) {
                                    return 'Введите корректный возраст';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              AuthDropdownField<String>(
                                label: 'Пол',
                                value: _sex,
                                items: [
                                  DropdownMenuItem(
                                    value: 'male',
                                    child: Text('Мужской',
                                        style: authFieldStyle()),
                                  ),
                                  DropdownMenuItem(
                                    value: 'female',
                                    child: Text('Женский',
                                        style: authFieldStyle()),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _sex = value!),
                                validator: (value) =>
                                    value == null ? 'Выберите пол' : null,
                              ),
                              const SizedBox(height: 24),
                              AuthPrimaryButton(
                                label: 'Сохранить',
                                isLoading: _isLoading,
                                onPressed: _saveProfile,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AuthColors.title,
            onPressed: () => Navigator.pop(context),
          ),
          Text('StrideTrack', style: authHeaderBrandStyle()),
        ],
      ),
    );
  }

  ImageProvider _avatarImageProvider() {
    if (_profileImage != null) {
      return FileImage(_profileImage!);
    }
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return NetworkImage(_avatarUrl!);
    }
    return const AssetImage('assets/images/profile.png');
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _avatarImageProvider(),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AuthColors.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
