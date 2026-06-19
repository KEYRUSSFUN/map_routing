import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';

class UserProfileCache {
  UserProfileCache._();

  static final UserProfileCache instance = UserProfileCache._();

  String? userId;
  String? userName;

  Future<void> ensureLoaded({
    UserService? userService,
    String? expectedUserId,
  }) async {
    if (userId != null &&
        userName != null &&
        (expectedUserId == null || userId == expectedUserId)) {
      return;
    }

    if (expectedUserId != null && userId != null && userId != expectedUserId) {
      clear();
    }

    final service = userService ?? UserService();
    final userInfo = await service.fetchUserInfo();
    if (userInfo == null) {
      throw Exception('Не удалось загрузить данные пользователя');
    }

    userId = userInfo['id']?.toString();
    userName = userInfo['name']?.toString();
    if (userId != null) {
      await UserWorkoutStorage.instance.setCurrentUserId(userId!);
    }
  }

  void apply({
    required String id,
    required String name,
  }) {
    userId = id;
    userName = name;
  }

  void clear() {
    userId = null;
    userName = null;
  }
}
