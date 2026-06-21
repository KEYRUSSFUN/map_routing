import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/models/moment.dart';
import 'package:map_routing/data/services/moment_service.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';

Future<MomentItem?> showEditMomentSheet(
  BuildContext context, {
  required MomentService momentService,
  required MomentItem moment,
}) {
  return showModalBottomSheet<MomentItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => EditMomentSheet(
      momentService: momentService,
      moment: moment,
    ),
  );
}

class EditMomentSheet extends StatefulWidget {
  const EditMomentSheet({
    super.key,
    required this.momentService,
    required this.moment,
  });

  final MomentService momentService;
  final MomentItem moment;

  @override
  State<EditMomentSheet> createState() => _EditMomentSheetState();
}

class _EditMomentSheetState extends State<EditMomentSheet> {
  late final TextEditingController _textController;
  File? _newPhoto;
  bool _removeExistingPhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.moment.text ?? '');
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String? get _existingPhotoUrl => absoluteBackendUrl(widget.moment.photoUrl);

  bool get _hasPhotoPreview {
    if (_removeExistingPhoto) return _newPhoto != null;
    return _newPhoto != null || isLoadableNetworkUrl(_existingPhotoUrl);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() {
      _newPhoto = File(file.path);
      _removeExistingPhoto = false;
    });
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    final hasExistingPhoto =
        !_removeExistingPhoto && isLoadableNetworkUrl(_existingPhotoUrl);
    if (text.isEmpty && _newPhoto == null && !hasExistingPhoto) {
      AppSnackBar.show(context, 'Добавьте текст или фото');
      return;
    }
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final updated = await widget.momentService.updateMoment(
        momentId: widget.moment.id,
        text: text,
        photo: _newPhoto,
        removePhoto: _removeExistingPhoto && _newPhoto == null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(context, 'Не удалось сохранить: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final previewHeight =
        (MediaQuery.sizeOf(context).height * 0.28).clamp(140.0, 240.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Редактировать запись',
              style: GoogleFonts.lexendDeca(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: HomeColors.title,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: 'Текст записи',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_hasPhotoPreview)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    if (_newPhoto != null)
                      Image.file(
                        _newPhoto!,
                        height: previewHeight,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    else
                      Image.network(
                        _existingPhotoUrl!,
                        height: previewHeight,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                        onPressed: () => setState(() {
                          _newPhoto = null;
                          _removeExistingPhoto = true;
                        }),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Галерея'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Камера'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: HomeColors.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}
