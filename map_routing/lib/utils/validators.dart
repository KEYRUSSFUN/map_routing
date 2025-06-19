class Validators {
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Пожалуйста, введите email';
    }

    // Проверка на правильный формат email
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(email)) {
      return 'Пожалуйста, введите корректный email';
    }

    return null;
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Пожалуйста, введите пароль';
    }

    if (password.length < 8) {
      return 'Пароль должен содержать минимум 8 символов';
    }

    return null;
  }
}
