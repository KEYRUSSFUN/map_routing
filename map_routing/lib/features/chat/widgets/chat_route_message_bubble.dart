import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';

class ChatRouteMessageBubble extends StatelessWidget {
  const ChatRouteMessageBubble({
    super.key,
    required this.title,
    required this.fileName,
    required this.fileSize,
    required this.isCurrentUser,
    required this.isDownloading,
    required this.onDownload,
  });

  final String title;
  final String fileName;
  final int? fileSize;
  final bool isCurrentUser;
  final bool isDownloading;
  final VoidCallback? onDownload;

  String get _sizeLabel {
    final bytes = fileSize;
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? Colors.white.withValues(alpha: 0.55)
            : const Color(0xFFF4FBF7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AuthColors.primaryGreen.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AuthColors.primaryGreen.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.route_rounded,
              color: AuthColors.primaryGreen,
            ),
          ),
          const SizedBox(width: 10),
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
                  [
                    fileName,
                    if (_sizeLabel.isNotEmpty) _sizeLabel,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lexendDeca(
                    fontSize: 11,
                    color: AuthColors.body,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 34,
            child: TextButton.icon(
              onPressed: isDownloading ? null : onDownload,
              style: TextButton.styleFrom(
                backgroundColor: AuthColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: isDownloading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 16),
              label: Text(
                isDownloading ? '...' : 'Скачать',
                style: GoogleFonts.lexendDeca(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
