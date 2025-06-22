import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';

class SocketChatService {
  IO.Socket? _socket;
  String? _token;
  bool _isInitialized = false;

  Future<void> initialize(String baseUrl) async {
    if (_isInitialized) {
      print('[SocketChatService] Уже инициализирован, пропускаем...');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');

    if (_token == null || _token!.isEmpty) {
      throw Exception('Токен не найден. Пожалуйста, войдите в систему');
    }

    print('[SocketChatService] Инициализация сокета с токеном: $_token');

    _socket = IO.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'extraHeaders': {'Authorization': '$_token'},
      'autoConnect': false, // Отключаем автоподключение для контроля
    });

    // Обработчики событий
    _socket!.onConnect((_) {
      print('[SocketChatService] Подключен к серверу');
    });

    _socket!.onDisconnect((_) {
      print('[SocketChatService] Отключен от сервера');
      _isInitialized = false;
    });

    _socket!.onConnectError((error) {
      print('[SocketChatService] Ошибка подключения: $error');
    });

    _socket!.onError((error) {
      print('[SocketChatService] Ошибка сокета: $error');
    });

    _socket!.on('joined', (data) {
      print('[SocketChatService] Событие joined: $data');
    });

    try {
      await _connect();
      _isInitialized = true;
    } catch (e) {
      print('[SocketChatService] Не удалось подключиться: $e');
      rethrow;
    }
  }

  Future<void> _connect() async {
    if (_socket != null && !_socket!.connected) {
      print('[SocketChatService] Пытаемся подключиться...');
      _socket!.connect();
      // Ждём до 5 секунд для подключения
      await Future.any([
        Future.delayed(const Duration(seconds: 5)),
        Future(() async {
          while (!_socket!.connected) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }),
      ]);
      if (!_socket!.connected) {
        throw Exception('Не удалось установить соединение с сервером');
      }
    }
  }

  void joinChat(String chatId) {
    if (_socket != null && _socket!.connected && _token != null) {
      print('[SocketChatService] Присоединяемся к чату: $chatId');
      _socket!.emit('join_chat', {
        'chat_id': chatId,
        'token': _token, // Токен в теле
      });
    } else {
      print('[SocketChatService] Сокет не подключён или токен отсутствует');
    }
  }

  void sendMessage(String chatId, String content) {
    if (_socket != null && _socket!.connected && _token != null) {
      print(
          '[SocketChatService] Отправляем сообщение: chatId=$chatId, content=$content');
      _socket!.emit('send_message', {
        'chat_id': chatId,
        'content': content,
        'token': _token, // Токен в теле
      });
    } else {
      print('[SocketChatService] Сокет не подключён или токен отсутствует');
    }
  }

  void on(String event, Function(dynamic) callback) {
    if (_socket != null) {
      print('[SocketChatService] Добавляем обработчик для события: $event');
      _socket!.on(event, callback);
    }
  }

  void off(String event) {
    if (_socket != null) {
      print('[SocketChatService] Удаляем обработчик для события: $event');
      _socket!.off(event);
    }
  }

  void disconnect() {
    if (_socket != null) {
      print('[SocketChatService] Отключаем сокет...');
      _socket!.disconnect();
      _socket!.clearListeners();
      _socket = null;
      _isInitialized = false;
    }
  }

  bool get isConnected => _socket != null && _socket!.connected;
}
