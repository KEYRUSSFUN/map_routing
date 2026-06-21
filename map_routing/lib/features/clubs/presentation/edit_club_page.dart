import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map_routing/core/network/backend_urls.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/models/club.dart';
import 'package:map_routing/data/services/club_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/clubs/presentation/club_ui.dart';
import 'package:map_routing/features/clubs/presentation/club_wizard_options.dart';
import 'package:map_routing/features/home/presentation/home_ui.dart';

class EditClubPage extends StatefulWidget {
  const EditClubPage({
    super.key,
    required this.clubService,
    required this.club,
  });

  final ClubService clubService;
  final ClubSummary club;

  @override
  State<EditClubPage> createState() => _EditClubPageState();
}

class _EditClubPageState extends State<EditClubPage> {
  static const _avatarSize = 72.0;

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;

  final _picker = ImagePicker();
  File? _avatarFile;
  File? _coverFile;
  late String _sportType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final club = widget.club;
    _titleController = TextEditingController(text: club.title);
    _descriptionController = TextEditingController(text: club.description);
    _locationController = TextEditingController(text: club.locationLabel ?? '');
    _sportType = club.sportType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool cover}) async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: cover ? 1800 : 1200,
      imageQuality: 88,
    );
    if (image == null || !mounted) return;
    setState(() {
      if (cover) {
        _coverFile = File(image.path);
      } else {
        _avatarFile = File(image.path);
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      AppSnackBar.show(context, 'Укажите название клуба');
      return;
    }
    if (_saving) return;

    setState(() => _saving = true);
    try {
      final updated = await widget.clubService.updateClub(
        clubId: widget.club.id,
        payload: UpdateClubPayload(
          title: title,
          sportType: _sportType,
          description: _descriptionController.text.trim(),
          locationLabel: _locationController.text.trim(),
        ),
        avatar: _avatarFile,
        cover: _coverFile,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.show(context, error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildAvatar(ClubSummary club) {
    if (_avatarFile != null) {
      return Image.file(
        _avatarFile!,
        fit: BoxFit.cover,
        width: _avatarSize,
        height: _avatarSize,
      );
    }

    final avatarUrl = absoluteBackendUrl(club.avatarUrl);
    if (isLoadableNetworkUrl(avatarUrl)) {
      return Image.network(
        avatarUrl!,
        key: ValueKey(avatarUrl),
        fit: BoxFit.cover,
        width: _avatarSize,
        height: _avatarSize,
        errorBuilder: (_, __, ___) => ClubAvatarFallback(title: club.title),
      );
    }

    return ClubAvatarFallback(title: club.title);
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Редактировать клуб',
          style: GoogleFonts.lexendDeca(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: HomeColors.title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'СОХРАНИТЬ',
                    style: GoogleFonts.lexendDeca(
                      fontWeight: FontWeight.w800,
                      color: HomeColors.title,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => _pickImage(cover: true),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: _coverFile != null
                        ? Image.file(_coverFile!, fit: BoxFit.cover)
                        : isLoadableNetworkUrl(absoluteBackendUrl(club.coverUrl))
                            ? Image.network(
                                absoluteBackendUrl(club.coverUrl)!,
                                fit: BoxFit.cover,
                              )
                            : const _EditCoverFallback(),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: FilledButton.icon(
                  onPressed: () => _pickImage(cover: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: HomeColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Заменить'),
                ),
              ),
              Positioned(
                left: 16,
                bottom: -(_avatarSize / 2),
                child: GestureDetector(
                  onTap: () => _pickImage(cover: false),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: _avatarSize,
                        height: _avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: ClipOval(child: _buildAvatar(club)),
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: HomeColors.title,
                          child: const Icon(Icons.edit, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: (_avatarSize / 2) + 12),
          ClubOutlinedField(label: 'Название клуба', controller: _titleController),
          const SizedBox(height: 16),
          _DropdownField(
            label: 'Вид спорта',
            value: clubSportLabel(_sportType),
            onTap: () => _pickOption(
              title: 'Вид спорта',
              options: ClubWizardOptions.sportTypes,
              current: _sportType,
              onSelected: (value) => setState(() => _sportType = value),
            ),
          ),
          const SizedBox(height: 16),
          ClubOutlinedField(
            label: 'Описание',
            controller: _descriptionController,
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          ClubOutlinedField(
            label: 'Местоположение',
            controller: _locationController,
          ),
        ],
      ),
    );
  }

  Future<void> _pickOption({
    required String title,
    required List<ClubWizardOption> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (context, scrollController) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(title, style: clubPageTitleStyle()),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: options
                      .map(
                        (option) => ListTile(
                          leading: Icon(option.icon),
                          title: Text(option.title),
                          subtitle: Text(option.subtitle),
                          trailing: option.id == current
                              ? const Icon(
                                  Icons.check_circle,
                                  color: HomeColors.primaryGreen,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, option.id),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      onSelected(selected);
    }
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: authLabelStyle(),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AuthColors.border),
          ),
        ),
        child: Row(
          children: [
            Expanded(child: Text(value, style: authFieldStyle())),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }
}

class _EditCoverFallback extends StatelessWidget {
  const _EditCoverFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFECEFF1),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 40, color: HomeColors.body),
      ),
    );
  }
}
