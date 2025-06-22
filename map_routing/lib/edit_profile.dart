import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:map_routing/usersData/user_service.dart'; // Предполагаем, что он есть

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final UserService userService = UserService();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String _sex = 'М'; // Начальное значение
  File? _profileImage;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserInfo();
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      final data = await userService.fetchUserInfo();
      if (data != null) {
        final nameParts = (data['name'] ?? '').split(' ');
        final serverSex = data['sex']?.toString().toUpperCase() ?? 'М';
        setState(() {
          _firstNameController.text = nameParts.isNotEmpty ? nameParts[0] : '';
          _countryController.text = data['country'] ?? '';
          _heightController.text = (data['height']?.toString() ?? '');
          _weightController.text = (data['weight']?.toString() ?? '');
          _ageController.text = (data['Age']?.toString() ?? '');
          _sex = (serverSex == 'MALE' || serverSex == 'М') ? 'М' : 'Ж';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить данные профиля')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    final firstName = _firstNameController.text;
    final country = _countryController.text;
    final height = double.tryParse(_heightController.text) ?? 0.0;
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final age = int.tryParse(_ageController.text) ?? 0;

    if (firstName.isEmpty ||
        country.isEmpty ||
        height <= 0 ||
        weight <= 0 ||
        age <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Заполните все обязательные поля корректно')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await userService.updateUserInfo({
        'name': firstName,
        'country': country,
        'height': height,
        'weight': weight,
        'age': age,
        'sex': _sex,
      });

      if (response != null && response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Профиль обновлён: $firstName, $country')),
        );
        Navigator.pushReplacementNamed(
            context, '/profile_page'); // Вернуться на предыдущий экран
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка сохранения профиля')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final response = await userService.logout();
    if (response != null) {
      Navigator.pushNamedAndRemoveUntil(
          context, '/login_page', (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка выхода')),
      );
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _countryController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Изменить профиль'),
        surfaceTintColor: Colors.white,
        backgroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            color: Colors.grey[300],
            height: 1.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage: _profileImage != null
                      ? FileImage(_profileImage!)
                      : const AssetImage('assets/default_profile.jpg')
                          as ImageProvider,
                  child: _profileImage == null
                      ? const Icon(Icons.camera_alt,
                          size: 40, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Имя',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _countryController,
                      decoration: const InputDecoration(
                        labelText: 'Страна',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _heightController,
                      decoration: const InputDecoration(
                        labelText: 'Рост (см)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Вес (кг)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ageController,
                      decoration: const InputDecoration(
                        labelText: 'Возраст',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _sex,
                      decoration: const InputDecoration(
                        labelText: 'Пол',
                        border: OutlineInputBorder(),
                        floatingLabelStyle: TextStyle(color: Colors.black87),
                      ),
                      items: ['М', 'Ж'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _sex = value!),
                      dropdownColor: Colors.white,
                    ),
                  )
                ],
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: _saveProfile,
                      child: const Text('Сохранить'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
