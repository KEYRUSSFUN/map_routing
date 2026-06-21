import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/profile/presentation/profile_cover_background.dart';
import 'package:map_routing/features/profile/presentation/profile_cover_presets.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';

class ProfileCoverPickerPage extends StatefulWidget {
  const ProfileCoverPickerPage({super.key});

  @override
  State<ProfileCoverPickerPage> createState() => _ProfileCoverPickerPageState();
}

class _ProfileCoverPickerPageState extends State<ProfileCoverPickerPage> {
  final _userService = UserService();
  final _picker = ImagePicker();

  String? _coverUrl;
  String? _coverPresetId;
  File? _pickedFile;
  bool _loading = true;
  bool _saving = false;
  String? _selectedPresetId;

  @override
  void initState() {
    super.initState();
    _loadCurrentCover();
  }

  Future<void> _loadCurrentCover() async {
    final data = await _userService.fetchUserInfo(force: true);
    if (!mounted) return;

    setState(() {
      _coverUrl = data?['cover_url']?.toString();
      _coverPresetId = data?['cover_preset']?.toString();
      _selectedPresetId = _coverPresetId;
      _loading = false;
    });
  }

  Future<void> _savePreset(String presetId) async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _selectedPresetId = presetId;
      _pickedFile = null;
    });

    final result = await _userService.setCoverPreset(presetId);
    if (!mounted) return;

    if (result == null) {
      setState(() => _saving = false);
      AppSnackBar.show(context, 'Не удалось сохранить фон');
      return;
    }

    setState(() {
      _coverUrl = result['cover_url']?.toString();
      _coverPresetId = result['cover_preset']?.toString();
      _saving = false;
    });
    AppSnackBar.show(context, 'Фон профиля обновлён');
    Navigator.pop(context, true);
  }

  Future<void> _pickCustomCover() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 88,
    );
    if (image == null || !mounted) return;

    setState(() {
      _pickedFile = File(image.path);
      _selectedPresetId = null;
    });
  }

  Future<void> _saveCustomCover() async {
    final file = _pickedFile;
    if (file == null || _saving) return;

    setState(() => _saving = true);

    final result = await _userService.uploadCover(file);
    if (!mounted) return;

    if (result == null) {
      setState(() => _saving = false);
      AppSnackBar.show(context, 'Не удалось загрузить изображение');
      return;
    }

    setState(() {
      _coverUrl = result['cover_url']?.toString();
      _coverPresetId = result['cover_preset']?.toString();
      _pickedFile = null;
      _saving = false;
    });
    AppSnackBar.show(context, 'Фон профиля обновлён');
    Navigator.pop(context, true);
  }

  bool get _hasCustomSelection => _pickedFile != null;

  String? get _previewCoverUrl {
    if (_pickedFile != null) return null;
    return _coverUrl;
  }

  String? get _previewPresetId {
    if (_pickedFile != null) return null;
    if (_selectedPresetId != null) return _selectedPresetId;
    return _coverPresetId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AuthColors.scaffoldBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AuthColors.title,
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Фон профиля',
          style: GoogleFonts.lexendDeca(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AuthColors.title,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE8E8E8)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'Предпросмотр',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ProfileColors.body,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: _pickedFile != null
                        ? Image.file(_pickedFile!, fit: BoxFit.cover)
                        : ProfileCoverBackground(
                            coverUrl: _previewCoverUrl,
                            coverPresetId: _previewPresetId,
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'СТАНДАРТНЫЕ ФОНЫ',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ProfileColors.body,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ProfileCoverPresets.all.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.55,
                  ),
                  itemBuilder: (context, index) {
                    final preset = ProfileCoverPresets.all[index];
                    final selected = !_hasCustomSelection &&
                        (_selectedPresetId ?? _coverPresetId) == preset.id &&
                        (_coverUrl == null || _coverUrl!.isEmpty);

                    return _PresetTile(
                      preset: preset,
                      selected: selected,
                      saving: _saving,
                      onTap: () => _savePreset(preset.id),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'СВОЁ ИЗОБРАЖЕНИЕ',
                  style: GoogleFonts.lexendDeca(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ProfileColors.body,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickCustomCover,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Выбрать из галереи'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: ProfileColors.title,
                    side: const BorderSide(color: Color(0xFFE8E8E8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_pickedFile != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : _saveCustomCover,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: ProfileColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                        : const Text('Сохранить изображение'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.saving,
    required this.onTap,
  });

  final ProfileCoverPreset preset;
  final bool selected;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: saving ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? ProfileColors.primaryGreen : const Color(0xFFE8E8E8),
              width: selected ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ProfileCoverBackground(
                  coverPresetId: preset.id,
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Text(
                    preset.title,
                    style: GoogleFonts.lexendDeca(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          color: Color(0x99000000),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: ProfileColors.primaryGreen,
                      child: Icon(Icons.check, size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
