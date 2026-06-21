import 'package:flutter/material.dart';

enum ChatMessageStatus {
  sending,
  sent,
  delivered,
  read,
}

ChatMessageStatus chatMessageStatusFromRaw(dynamic raw) {
  switch (raw?.toString()) {
    case 'sent':
      return ChatMessageStatus.sent;
    case 'delivered':
      return ChatMessageStatus.delivered;
    case 'read':
      return ChatMessageStatus.read;
    default:
      return ChatMessageStatus.sending;
  }
}

String chatMessageStatusToRaw(ChatMessageStatus status) {
  switch (status) {
    case ChatMessageStatus.sending:
      return 'sending';
    case ChatMessageStatus.sent:
      return 'sent';
    case ChatMessageStatus.delivered:
      return 'delivered';
    case ChatMessageStatus.read:
      return 'read';
  }
}

class ChatMessageStatusIcon extends StatelessWidget {
  const ChatMessageStatusIcon({
    super.key,
    required this.status,
    this.size = 14,
  });

  final ChatMessageStatus status;
  final double size;

  static const _readColor = Color(0xFF6AA7D8);
  static const _neutralColor = Color(0xFF9AA0A6);

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ChatMessageStatus.sending:
        return Icon(
          Icons.access_time_rounded,
          size: size,
          color: _neutralColor,
        );
      case ChatMessageStatus.sent:
        return Icon(
          Icons.done_rounded,
          size: size,
          color: _neutralColor,
        );
      case ChatMessageStatus.delivered:
        return Icon(
          Icons.done_all_rounded,
          size: size,
          color: _neutralColor,
        );
      case ChatMessageStatus.read:
        return Icon(
          Icons.done_all_rounded,
          size: size,
          color: _readColor,
        );
    }
  }
}

class ChatMessageStatusHelper {
  static ChatMessageStatus statusForMessage({
    required Map<String, dynamic> message,
    required String? currentUserId,
    required Map<String, DateTime?> memberReadAt,
    required Map<String, DateTime?> memberReceivedAt,
    required Iterable<String> participantIds,
  }) {
    if (currentUserId == null ||
        message['sender_id']?.toString() != currentUserId) {
      return ChatMessageStatus.sending;
    }

    if (message['id'] == null) {
      return ChatMessageStatus.sending;
    }

    final messageAt = _parseTimestamp(message['timestamp']);
    final others = participantIds
        .where((id) => id.isNotEmpty && id != currentUserId)
        .toList();
    if (others.isEmpty) {
      return ChatMessageStatus.read;
    }

    if (memberReadAt.isNotEmpty || memberReceivedAt.isNotEmpty) {
      var allRead = true;
      var allDelivered = true;
      for (final memberId in others) {
        final readAt = memberReadAt[memberId];
        if (readAt == null || readAt.isBefore(messageAt)) {
          allRead = false;
        }

        final receivedAt = _effectiveReceivedAt(
          memberReadAt[memberId],
          memberReceivedAt[memberId],
        );
        if (receivedAt == null || receivedAt.isBefore(messageAt)) {
          allDelivered = false;
        }
      }

      if (allRead) return ChatMessageStatus.read;
      if (allDelivered) return ChatMessageStatus.delivered;
      return ChatMessageStatus.sent;
    }

    final serverStatus = message['status']?.toString();
    if (serverStatus != null && serverStatus.isNotEmpty) {
      return chatMessageStatusFromRaw(serverStatus);
    }

    return ChatMessageStatus.sent;
  }

  static DateTime? _effectiveReceivedAt(
    DateTime? readAt,
    DateTime? receivedAt,
  ) {
    if (readAt == null) return receivedAt;
    if (receivedAt == null) return readAt;
    return readAt.isAfter(receivedAt) ? readAt : receivedAt;
  }

  static DateTime _parseTimestamp(dynamic raw) {
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final value = raw.toString();
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return parsed.toUtc();
  }
}
