class HomePageController {
  HomePageController._();

  static final HomePageController instance = HomePageController._();

  Future<void> Function({bool force})? _refresh;
  void Function(String userId, bool isOnline)? _presenceUpdate;
  void Function()? _openProfileChallenges;

  void bind(Future<void> Function({bool force}) refresh) {
    _refresh = refresh;
  }

  void bindPresence(void Function(String userId, bool isOnline) handler) {
    _presenceUpdate = handler;
  }

  void bindOpenProfileChallenges(void Function() handler) {
    _openProfileChallenges = handler;
  }

  Future<void> refresh({bool force = false}) async {
    await _refresh?.call(force: force);
  }

  void updatePresence(String userId, bool isOnline) {
    _presenceUpdate?.call(userId, isOnline);
  }

  void openProfileChallenges() {
    _openProfileChallenges?.call();
  }
}
