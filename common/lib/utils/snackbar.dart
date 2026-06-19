import 'package:common/utils/extension_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

bool showSnackBar(BuildContext? context, String text) {
  final isShown = context?.let((it) {
    final snackBar = _getSnackBar(it, text);
    ScaffoldMessenger.of(it)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
    return true;
  });
  return isShown ?? false;
}

SnackBar _getSnackBar(BuildContext context, String text) {
  const accent = Color(0xFF00E676);

  return SnackBar(
    behavior: SnackBarBehavior.floating,
    duration: const Duration(milliseconds: 2800),
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    padding: EdgeInsets.zero,
    backgroundColor: Colors.transparent,
    elevation: 0,
    dismissDirection: DismissDirection.horizontal,
    content: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.lexendDeca(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF212121),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
