import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';

enum PostMomentMenuAction { edit, delete }

class PostMomentMenuButton extends StatelessWidget {
  const PostMomentMenuButton({
    super.key,
    this.onEditTap,
    this.onDeleteTap,
  });

  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;

  Future<void> _openMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );

    final action = await showMenu<PostMomentMenuAction>(
      context: context,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: HomeColors.cardBorder),
      ),
      constraints: const BoxConstraints(minWidth: 196),
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      ),
      items: [
        if (onEditTap != null)
          PopupMenuItem(
            value: PostMomentMenuAction.edit,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _PostMomentMenuTile(
              icon: Icons.edit_outlined,
              label: 'Редактировать',
              iconBackground: HomeColors.primaryGreen.withValues(alpha: 0.12),
              iconColor: HomeColors.primaryGreen,
              textColor: HomeColors.title,
            ),
          ),
        if (onDeleteTap != null)
          PopupMenuItem(
            value: PostMomentMenuAction.delete,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _PostMomentMenuTile(
              icon: Icons.delete_outline_rounded,
              label: 'Удалить',
              iconBackground: const Color(0xFFFFEBEE),
              iconColor: const Color(0xFFE53935),
              textColor: const Color(0xFFE53935),
            ),
          ),
      ],
    );

    if (action == null) return;
    switch (action) {
      case PostMomentMenuAction.edit:
        onEditTap?.call();
      case PostMomentMenuAction.delete:
        onDeleteTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _openMenu(context),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.more_horiz, color: HomeColors.body, size: 22),
        ),
      ),
    );
  }
}

class _PostMomentMenuTile extends StatelessWidget {
  const _PostMomentMenuTile({
    required this.icon,
    required this.label,
    required this.iconBackground,
    required this.iconColor,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color iconBackground;
  final Color iconColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.lexendDeca(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}
