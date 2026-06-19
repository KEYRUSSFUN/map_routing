import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:map_routing/core/network/config.dart';
import 'package:map_routing/core/network/network_errors.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/services/google_auth_service.dart';
import 'package:map_routing/features/auth/data/auth_local_storage.dart';
import 'package:map_routing/features/auth/presentation/complete_profile_page.dart';

class AuthFlow {
  static Future<bool> needsProfileCompletion(String token) async {
    try {
      final checkResponse = await http.get(
        Uri.parse('$backendBaseUrl/api/user_info/check'),
        headers: {'Authorization': token},
      );

      if (checkResponse.statusCode == 404) {
        return true;
      }

      if (checkResponse.statusCode == 200) {
        final data = jsonDecode(checkResponse.body);
        if (data is Map<String, dynamic>) {
          return data['filled'] != true;
        }
      }
    } catch (e) {
      final message = userFacingNetworkError(e);
      if (message != null) {
        throw Exception(message);
      }
      rethrow;
    }

    return false;
  }

  static Future<void> continueAfterAuth(
    BuildContext context, {
    required String token,
    String? initialName,
  }) async {
    final needsProfile = await needsProfileCompletion(token);
    if (!context.mounted) return;

    if (needsProfile) {
      if (initialName != null && initialName.trim().isNotEmpty) {
        await AuthLocalStorage.savePendingFullName(initialName.trim());
      }
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CompleteProfilePage(
            token: token,
            initialName: initialName,
          ),
        ),
      );
      return;
    }

    Navigator.pushReplacementNamed(context, '/home');
  }

  static Future<void> handleGoogleSignIn(
    BuildContext context, {
    required GoogleAuthService googleAuthService,
    required ValueNotifier<bool> loadingNotifier,
  }) async {
    if (loadingNotifier.value) return;

    loadingNotifier.value = true;
    try {
      final result = await googleAuthService.signIn();
      if (!context.mounted) return;

      if (result == null) {
        return;
      }

      if (result.isNewUser) {
        AppSnackBar.show(
          context,
          'Добро пожаловать! Заполните профиль.',
          variant: AppSnackBarVariant.success,
        );
      }

      await continueAfterAuth(
        context,
        token: result.token,
        initialName: result.name,
      );
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.show(context, e.toString());
    } finally {
      loadingNotifier.value = false;
    }
  }
}
