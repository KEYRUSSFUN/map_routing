import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/services/story_service.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';

Future<bool?> showPublishStoryDialog(
  BuildContext context, {
  required StoryService storyService,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => PublishStorySheet(storyService: storyService),
  );
}

class PublishStorySheet extends StatefulWidget {
  const PublishStorySheet({super.key, required this.storyService});

  final StoryService storyService;

  @override
  State<PublishStorySheet> createState() => _PublishStorySheetState();
}

class _PublishStorySheetState extends State<PublishStorySheet> {
  final _captionController = TextEditingController();
  File? _image;
  bool _publishing = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    setState(() => _image = File(file.path));
  }

  Future<void> _publish() async {
    if (_image == null || _publishing) return;

    setState(() => _publishing = true);
    try {
      await widget.storyService.publishStory(
        _image!,
        caption: _captionController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось опубликовать историю: $e');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final previewHeight =
        (MediaQuery.sizeOf(context).height * 0.32).clamp(160.0, 260.0);

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Новая история',
              style: GoogleFonts.lexendDeca(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: HomeColors.title,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'История будет доступна друзьям 24 часа.',
              style: homeSubtitleStyle(),
            ),
            const SizedBox(height: 16),
            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: previewHeight,
                  width: double.infinity,
                  child: Image.file(_image!, fit: BoxFit.cover),
                ),
              )
            else
              SizedBox(
                height: previewHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: HomeColors.cardBorder),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.photo_outlined,
                        size: 42,
                        color: HomeColors.body,
                      ),
                      const SizedBox(height: 8),
                      Text('Выберите фото', style: homeSubtitleStyle()),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _publishing
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Галерея'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _publishing
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Камера'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _captionController,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Подпись (необязательно)',
                hintStyle: homeSubtitleStyle(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _image == null || _publishing ? null : _publish,
              style: FilledButton.styleFrom(
                backgroundColor: HomeColors.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _publishing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Опубликовать',
                      style: GoogleFonts.lexendDeca(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
