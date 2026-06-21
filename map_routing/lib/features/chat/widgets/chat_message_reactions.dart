import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';

class ChatMessageReactions extends StatelessWidget {
  const ChatMessageReactions({
    super.key,
    required this.reactions,
    required this.currentUserId,
    this.onReactionTap,
  });

  final List<Map<String, dynamic>> reactions;
  final String? currentUserId;
  final void Function(String emoji)? onReactionTap;

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final reaction in reactions) {
      final emoji = reaction['emoji']?.toString() ?? '';
      if (emoji.isEmpty) continue;
      grouped.putIfAbsent(emoji, () => []).add(reaction);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: _grouped.entries.map((entry) {
          final emoji = entry.key;
          final users = entry.value;
          final reactedByMe =
              currentUserId != null &&
              users.any((user) => user['user_id']?.toString() == currentUserId);

          return InkWell(
            onTap: onReactionTap == null ? null : () => onReactionTap!(emoji),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: reactedByMe
                    ? AuthColors.primaryGreen.withValues(alpha: 0.18)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: reactedByMe
                      ? AuthColors.primaryGreen.withValues(alpha: 0.5)
                      : const Color(0xFFD8D8D8),
                ),
              ),
              child: Text(
                users.length > 1 ? '$emoji ${users.length}' : emoji,
                style: GoogleFonts.lexendDeca(fontSize: 13),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
