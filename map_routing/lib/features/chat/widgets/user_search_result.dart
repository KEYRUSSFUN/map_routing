import 'package:flutter/material.dart';
import 'package:map_routing/core/navigation/open_user_profile.dart';
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/widgets/user_avatar.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';

class UserSearchResult extends StatefulWidget {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String relationshipStatus;
  final Future<void> Function(String userId) onAddFriend;

  const UserSearchResult({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.relationshipStatus = 'none',
    required this.onAddFriend,
  });

  @override
  State<UserSearchResult> createState() => _UserSearchResultState();
}

class _UserSearchResultState extends State<UserSearchResult> {
  bool _isFriendRequestSent = false;
  bool _isLoading = false;

  bool get _isFriend => widget.relationshipStatus == 'friend';

  bool get _isPendingOutgoing =>
      widget.relationshipStatus == 'pending_outgoing' || _isFriendRequestSent;

  bool get _isPendingIncoming =>
      widget.relationshipStatus == 'pending_incoming';

  bool get _canAdd =>
      !_isFriend && !_isPendingOutgoing && !_isPendingIncoming && !_isLoading;

  String get _buttonLabel {
    if (_isFriend) return 'В друзьях';
    if (_isPendingOutgoing) return 'Отправлено';
    if (_isPendingIncoming) return 'Заявка';
    return 'Добавить';
  }

  Future<void> _sendRequest() async {
    if (!_canAdd) return;

    setState(() => _isLoading = true);
    try {
      await widget.onAddFriend(widget.userId);
      if (!mounted) return;
      setState(() {
        _isFriendRequestSent = true;
        _isLoading = false;
      });
      AppSnackBar.show(context, 'Заявка отправлена');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.show(context, _mapErrorMessage(e));
    }
  }

  String _mapErrorMessage(Object error) {
    final text = error.toString();
    if (text.contains('Already friends')) {
      return 'Пользователь уже в друзьях';
    }
    if (text.contains('already sent')) {
      return 'Заявка уже отправлена';
    }
    if (text.contains('already received')) {
      return 'У вас уже есть заявка от этого пользователя';
    }
    return 'Не удалось отправить заявку';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            UserAvatar(
              name: widget.name,
              avatarUrl: absoluteBackendUrl(widget.avatarUrl),
              onTap: () => openUserProfile(context, widget.userId),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: authFieldStyle(),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: ElevatedButton(
                onPressed: _canAdd ? _sendRequest : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canAdd
                      ? AuthColors.primaryGreen
                      : AuthColors.border,
                  foregroundColor: _canAdd ? Colors.white : AuthColors.body,
                  disabledBackgroundColor: AuthColors.border,
                  disabledForegroundColor: AuthColors.body,
                  elevation: 0,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _buttonLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexendDeca(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
