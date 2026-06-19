import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/navigation/open_user_profile.dart';
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/core/widgets/user_avatar.dart';
import 'package:map_routing/data/models/chat.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';

class CommunityNotificationsSheet {
  CommunityNotificationsSheet._();

  static Future<void> show(
    BuildContext context, {
    required List<Map<String, dynamic>> friendRequests,
    required List<Chat> unreadChats,
    required Future<void> Function(String requestId) onAcceptRequest,
    required Future<void> Function(String requestId) onRejectRequest,
    required Future<void> Function(Chat chat) onOpenChat,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuthColors.scaffoldBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        var requests = List<Map<String, dynamic>>.from(friendRequests);
        var messages = List<Chat>.from(unreadChats);

        return StatefulBuilder(
          builder: (context, sheetSetState) {
            Future<void> handleAccept(String requestId) async {
              await onAcceptRequest(requestId);
              if (!sheetContext.mounted) return;
              sheetSetState(() {
                requests.removeWhere(
                  (request) => request['fromUserId']?.toString() == requestId,
                );
              });
            }

            Future<void> handleReject(String requestId) async {
              await onRejectRequest(requestId);
              if (!sheetContext.mounted) return;
              sheetSetState(() {
                requests.removeWhere(
                  (request) => request['fromUserId']?.toString() == requestId,
                );
              });
            }

            Future<void> handleOpenChat(Chat chat) async {
              Navigator.pop(sheetContext);
              await onOpenChat(chat);
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.72,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AuthColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Уведомления',
                              style: authTitleStyle(),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Закрыть',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          _SectionLabel(
                            title: 'Заявки в друзья',
                            count: requests.length,
                            badgeColor: const Color(0xFFFFB300),
                          ),
                          if (requests.isEmpty)
                            const _EmptyHint(
                              text: 'Новых заявок нет',
                            )
                          else
                            ...requests.map(
                              (request) => _FriendRequestNotificationTile(
                                userId: request['fromUserId']?.toString() ?? '',
                                userName: request['fromUserName']
                                        ?.toString() ??
                                    'Неизвестный пользователь',
                                avatarUrl: request['fromUserAvatarUrl']
                                    ?.toString(),
                                onAccept: () => handleAccept(
                                  request['fromUserId']?.toString() ?? '',
                                ),
                                onReject: () => handleReject(
                                  request['fromUserId']?.toString() ?? '',
                                ),
                              ),
                            ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1, color: AuthColors.border),
                          ),
                          _SectionLabel(
                            title: 'Сообщения',
                            count: messages.length,
                            badgeColor: AuthColors.primaryGreen,
                          ),
                          if (messages.isEmpty)
                            const _EmptyHint(
                              text: 'Нет непрочитанных сообщений',
                            )
                          else
                            ...messages.map(
                              (chat) => _MessageNotificationTile(
                                chat: chat,
                                onTap: () => handleOpenChat(chat),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    required this.count,
    required this.badgeColor,
  });

  final String title;
  final int count;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.lexendDeca(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AuthColors.title,
              ),
            ),
          ),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: GoogleFonts.lexendDeca(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: authSubtitleStyle(),
      ),
    );
  }
}

class _FriendRequestNotificationTile extends StatelessWidget {
  const _FriendRequestNotificationTile({
    required this.userId,
    required this.userName,
    this.avatarUrl,
    required this.onAccept,
    required this.onReject,
  });

  final String userId;
  final String userName;
  final String? avatarUrl;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Row(
        children: [
          UserAvatar(
            name: userName,
            avatarUrl: absoluteBackendUrl(avatarUrl),
            radius: 20,
            onTap: userId.isEmpty
                ? null
                : () => openUserProfile(context, userId),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AuthColors.title,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Хочет добавить вас в друзья',
                  style: authSubtitleStyle(),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onAccept,
            icon: const Icon(
              Icons.check_circle_rounded,
              color: AuthColors.primaryGreen,
            ),
            tooltip: 'Принять',
          ),
          IconButton(
            onPressed: onReject,
            icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
            tooltip: 'Отклонить',
          ),
        ],
      ),
    );
  }
}

class _MessageNotificationTile extends StatelessWidget {
  const _MessageNotificationTile({
    required this.chat,
    required this.onTap,
  });

  final Chat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = chat.title.isNotEmpty ? chat.title : 'Чат';
    final preview = chat.isInvitationUnread && chat.unreadCount == 0
        ? (chat.creatorName != null && chat.creatorName!.isNotEmpty
            ? '${chat.creatorName} добавил(а) вас в группу'
            : 'Вас добавили в группу')
        : chat.lastMessagePreview;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE7E7E7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AuthColors.primaryGreen.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AuthColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexendDeca(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AuthColors.title,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: authSubtitleStyle(),
                      ),
                    ],
                  ),
                ),
                if (chat.unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AuthColors.primaryGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                      style: GoogleFonts.lexendDeca(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ] else if (chat.isInvitationUnread) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A00),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Новая',
                      style: GoogleFonts.lexendDeca(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AuthColors.hint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
