import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:map_routing/data/services/user_workout_storage.dart';

enum SocketConnectionState {
  disconnected,
  connecting,
  connected,
}

/// Единый persistent WebSocket hub (как в production-мессенджерах).
class SocketChatService {
  SocketChatService._();

  static final SocketChatService instance = SocketChatService._();

  io.Socket? _socket;
  String? _token;
  String? _baseUrl;

  SocketConnectionState _state = SocketConnectionState.disconnected;
  Future<void>? _connectFuture;

  final Map<String, List<void Function(dynamic)>> _listeners = {};
  final Set<String> _nativeListenerEvents = {};
  final Set<String> _joinedChatIds = {};
  final Set<String> _pendingJoinChatIds = {};
  bool _joinedAllChats = false;
  bool _pendingJoinAll = false;
  bool _joinedUserRoom = false;
  bool _pendingJoinUser = false;
  bool _globalHandlersAttached = false;

  SocketConnectionState get connectionState => _state;

  bool get isConnected =>
      _state == SocketConnectionState.connected &&
      _socket != null &&
      _socket!.connected;

  /// Подключение в фоне. UI не блокируется, если [wait] = false.
  Future<void> ensureConnected(
    String baseUrl, {
    bool wait = false,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    _baseUrl = baseUrl;
    await _ensureTokenSynced(reconnectOnChange: true);

    if (isConnected) {
      _flushPendingJoins();
      return;
    }

    _connectFuture ??= _connectInternal(baseUrl).whenComplete(() {
      _connectFuture = null;
    });

    if (!wait) {
      unawaited(_connectFuture!.catchError((_) {}));
      return;
    }

    await _connectFuture!.timeout(timeout, onTimeout: () {
      throw TimeoutException('Socket connection timeout');
    });
  }

  Future<void> _connectInternal(String baseUrl) async {
    if (isConnected) return;

    if (_state == SocketConnectionState.connecting &&
        _socket != null &&
        _baseUrl == baseUrl) {
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (_socket != null &&
          !_socket!.connected &&
          _state == SocketConnectionState.connecting) {
        if (DateTime.now().isAfter(deadline)) {
          _state = SocketConnectionState.disconnected;
          throw Exception('Не удалось установить соединение с сервером');
        }
        await Future.delayed(const Duration(milliseconds: 50));
      }
      if (_socket != null && _socket!.connected) {
        _state = SocketConnectionState.connected;
        _flushPendingJoins();
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      disconnect();
      throw Exception('Токен не найден. Пожалуйста, войдите в систему');
    }

    await _ensureTokenSynced(token: token, reconnectOnChange: true);
    _baseUrl = baseUrl;

    final canReuseSocket =
        _socket != null && _state != SocketConnectionState.disconnected;

    if (!canReuseSocket) {
      if (_socket != null) {
        _socket!.disconnect();
        _socket!.clearListeners();
      }
      _socket = null;
      _nativeListenerEvents.clear();
      _socket = io.io(baseUrl, <String, dynamic>{
        'transports': ['websocket'],
        'extraHeaders': {'Authorization': token},
        'autoConnect': false,
        'reconnection': true,
        'reconnectionAttempts': 8,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
        'timeout': 12000,
        'forceNew': false,
      });

      _socket!.onConnect((_) {
        _state = SocketConnectionState.connected;
        _joinedUserRoom = false;
        _joinedAllChats = false;
        _flushPendingJoins();
      });

      _socket!.onDisconnect((_) {
        _state = SocketConnectionState.disconnected;
        _joinedAllChats = false;
        _joinedUserRoom = false;
        _pendingJoinUser = true;
      });

      _socket!.onConnectError((_) {
        _state = SocketConnectionState.disconnected;
      });

      _socket!.onError((_) {});

      _reattachAllNativeListeners();
    }

    if (_socket!.connected) {
      _state = SocketConnectionState.connected;
      _flushPendingJoins();
      return;
    }

    _state = SocketConnectionState.connecting;
    _socket!.connect();

    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (_socket != null && !_socket!.connected) {
      if (DateTime.now().isAfter(deadline)) {
        _state = SocketConnectionState.disconnected;
        throw Exception('Не удалось установить соединение с сервером');
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _state = SocketConnectionState.connected;
    _flushPendingJoins();
  }

  void _disposeSocketOnly() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.clearListeners();
    }
    _socket = null;
    _nativeListenerEvents.clear();
    _state = SocketConnectionState.disconnected;
  }

  void _reattachAllNativeListeners() {
    _nativeListenerEvents.clear();
    for (final event in _listeners.keys) {
      _ensureNativeListener(event);
    }
  }

  void _ensureNativeListener(String event) {
    if (_socket == null || _nativeListenerEvents.contains(event)) return;

    _nativeListenerEvents.add(event);
    _socket!.on(event, (data) {
      final callbacks = _listeners[event];
      if (callbacks == null || callbacks.isEmpty) return;
      for (final callback in List<void Function(dynamic)>.from(callbacks)) {
        callback(data);
      }
    });
  }

  Future<void> _ensureTokenSynced({
    String? token,
    bool reconnectOnChange = false,
  }) async {
    token ??= (await SharedPreferences.getInstance()).getString('jwt_token');
    if (token == null || token.isEmpty) {
      _token = null;
      return;
    }

    final previousToken = _token;
    _token = token;

    if (previousToken != null && previousToken != token) {
      final previousUserId =
          UserWorkoutStorage.instance.userIdFromToken(previousToken);
      final nextUserId = UserWorkoutStorage.instance.userIdFromToken(token);
      if (previousUserId != null &&
          nextUserId != null &&
          previousUserId == nextUserId) {
        return;
      }

      _resetJoinState();
      if (reconnectOnChange) {
        _disposeSocketOnly();
        _connectFuture = null;
      } else if (isConnected) {
        _flushPendingJoins();
      }
    }
  }

  void _resetJoinState() {
    _joinedUserRoom = false;
    _pendingJoinUser = true;
    _joinedAllChats = false;
    _pendingJoinAll = true;
    _joinedChatIds.clear();
  }

  /// Вызывать после входа под другим аккаунтом.
  Future<void> reconnectForAccountSwitch() async {
    _connectFuture = null;
    _resetJoinState();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      disconnect();
      return;
    }

    _token = token;
    _disposeSocketOnly();
    if (_baseUrl != null) {
      await ensureConnected(_baseUrl!, wait: false);
    }
  }

  void _flushPendingJoins() {
    if (_socket == null || !_socket!.connected || _token == null) return;

    if (_pendingJoinUser || !_joinedUserRoom) {
      joinUserRoom();
    }

    if (_pendingJoinAll || _pendingJoinChatIds.isNotEmpty) {
      if (!_joinedAllChats) {
        joinAllChats();
      }
    }

    for (final chatId in _pendingJoinChatIds.toList()) {
      joinChat(chatId);
    }
  }

  /// Персональная комната — доставка chat_deleted даже без join_all_chats.
  void joinUserRoom() {
    if (_joinedUserRoom) return;
    if (_socket == null || !_socket!.connected || _token == null) {
      _pendingJoinUser = true;
      return;
    }

    _pendingJoinUser = false;
    _joinedUserRoom = true;
    _socket!.emit('join_user', {'token': _token});
  }

  /// Переподписаться на комнаты чатов после обновления списка.
  void refreshChatRooms() {
    _joinedAllChats = false;
    joinAllChats();
  }

  /// Одним запросом подписаться на все чаты пользователя (вместо N join_chat).
  void joinAllChats() {
    if (_joinedAllChats) return;
    if (_socket == null || !_socket!.connected || _token == null) {
      _pendingJoinAll = true;
      return;
    }

    _pendingJoinAll = false;
    _joinedAllChats = true;
    _socket!.emit('join_all_chats', {'token': _token});
  }

  void joinChat(String chatId, {bool force = false}) {
    final alreadyJoined = _joinedChatIds.contains(chatId);
    if (alreadyJoined && !force) return;

    if (_socket == null || !_socket!.connected || _token == null) {
      _pendingJoinChatIds.add(chatId);
      return;
    }

    _joinedChatIds.add(chatId);
    _pendingJoinChatIds.remove(chatId);
    _socket!.emit('join_chat', {
      'chat_id': chatId,
      'token': _token,
    });
  }

  void ensureJoinedChats(Iterable<String> chatIds) {
    joinUserRoom();
    final ids = chatIds.toList();
    if (!_joinedAllChats) {
      joinAllChats();
      for (final chatId in ids) {
        _joinedChatIds.add(chatId);
        _pendingJoinChatIds.remove(chatId);
      }
      return;
    }
    for (final chatId in ids) {
      joinChat(chatId);
    }
  }

  /// Глобальные обработчики списка чатов — один раз на всё приложение.
  void ensureGlobalHandlers({
    required void Function(dynamic) onChatDeleted,
    required void Function(dynamic) onChatAdded,
    void Function(dynamic)? onChatUpdated,
    void Function(dynamic)? onPresenceUpdate,
  }) {
    if (_globalHandlersAttached) return;
    _globalHandlersAttached = true;
    on('chat_deleted', onChatDeleted);
    on('chat_added', onChatAdded);
    if (onChatUpdated != null) {
      on('chat_updated', onChatUpdated);
    }
    if (onPresenceUpdate != null) {
      on('presence_update', onPresenceUpdate);
    }
  }

  Future<void> sendTyping(String chatId, {required bool isTyping}) async {
    await _ensureTokenSynced(reconnectOnChange: true);

    if (!isConnected) {
      if (_baseUrl != null) {
        await ensureConnected(
          _baseUrl!,
          wait: true,
          timeout: const Duration(seconds: 2),
        );
      }
    }
    if (_socket == null || !_socket!.connected || _token == null) return;

    _socket!.emit('typing', {
      'chat_id': chatId,
      'typing': isTyping,
      'token': _token,
    });
  }

  Future<void> sendMessage(String chatId, String content) async {
    await _ensureTokenSynced(reconnectOnChange: true);

    if (!isConnected) {
      if (_baseUrl != null) {
        await ensureConnected(_baseUrl!, wait: true, timeout: const Duration(seconds: 3));
      }
    }
    if (_socket == null || !_socket!.connected || _token == null) return;

    _socket!.emit('send_message', {
      'chat_id': chatId,
      'content': content,
      'token': _token,
    });
  }

  void on(String event, void Function(dynamic) callback) {
    final callbacks = _listeners.putIfAbsent(event, () => []);
    if (!callbacks.contains(callback)) {
      callbacks.add(callback);
    }
    _ensureNativeListener(event);
  }

  void off(String event, [void Function(dynamic)? callback]) {
    final callbacks = _listeners[event];
    if (callbacks == null) return;

    if (callback != null) {
      callbacks.remove(callback);
    } else {
      callbacks.clear();
    }
  }

  /// Legacy alias — не блокирует UI.
  Future<void> initialize(String baseUrl) => ensureConnected(baseUrl);

  void forgetChat(String chatId) {
    _joinedChatIds.remove(chatId);
    _pendingJoinChatIds.remove(chatId);
  }

  void disconnect() {
    _connectFuture = null;
    _token = null;
    _disposeSocketOnly();
    _listeners.clear();
    _joinedChatIds.clear();
    _pendingJoinChatIds.clear();
    _joinedAllChats = false;
    _pendingJoinAll = false;
    _joinedUserRoom = false;
    _pendingJoinUser = false;
    _globalHandlersAttached = false;
  }
}
