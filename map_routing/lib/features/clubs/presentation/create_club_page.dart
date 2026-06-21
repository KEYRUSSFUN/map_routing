import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/models/club.dart';
import 'package:map_routing/data/services/club_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/clubs/presentation/club_wizard_options.dart';

class CreateClubPage extends StatefulWidget {
  const CreateClubPage({super.key, required this.clubService});

  final ClubService clubService;

  @override
  State<CreateClubPage> createState() => _CreateClubPageState();
}

class _CreateClubPageState extends State<CreateClubPage> {
  static const _stepCount = 4;

  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _picker = ImagePicker();

  int _step = 0;
  bool _submitting = false;
  File? _avatarFile;

  String _sportType = 'all_sports';
  String _privacy = 'open';

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _locationController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String get _stepTitle {
    return switch (_step) {
      0 => 'Вид спорта',
      1 => 'Название клуба',
      2 => 'Конфиденциальность',
      _ => 'Местоположение',
    };
  }

  bool get _canContinue {
    return switch (_step) {
      1 => _nameController.text.trim().isNotEmpty,
      _ => true,
    };
  }

  Future<void> _pickAvatar() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (image == null || !mounted) return;
    setState(() => _avatarFile = File(image.path));
  }

  void _goBack() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step -= 1);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goNext() async {
    if (!_canContinue || _submitting) return;

    if (_step < _stepCount - 1) {
      setState(() => _step += 1);
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      final club = await widget.clubService.createClub(
        payload: CreateClubPayload(
          title: _nameController.text.trim(),
          sportType: _sportType,
          privacy: _privacy,
          description: _descriptionController.text.trim(),
          locationLabel: _locationController.text.trim(),
        ),
        avatar: _avatarFile,
      );

      if (!mounted) return;
      AppSnackBar.show(context, 'Клуб «${club.title}» создан');
      Navigator.pop(context, club);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackBar.show(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AuthColors.title,
          onPressed: _submitting ? null : _goBack,
        ),
        title: Text(
          _stepTitle,
          style: GoogleFonts.lexendDeca(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AuthColors.title,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.pop(context),
            child: Text(
              'ЗАКРЫТЬ',
              style: GoogleFonts.lexendDeca(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AuthColors.body,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _ClubWizardProgress(currentStep: _step, stepCount: _stepCount),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _SportTypeStep(
                  selectedId: _sportType,
                  onChanged: (value) => setState(() => _sportType = value),
                ),
                _ConfigureClubStep(
                  nameController: _nameController,
                  descriptionController: _descriptionController,
                  avatarFile: _avatarFile,
                  onPickAvatar: _pickAvatar,
                ),
                _OptionListStep(
                  title: 'Открытый или закрытый клуб?',
                  subtitle: 'Определите, кто может вступить в сообщество.',
                  sectionLabel: 'КОНФИДЕНЦИАЛЬНОСТЬ',
                  options: ClubWizardOptions.privacyOptions,
                  selectedId: _privacy,
                  onChanged: (value) => setState(() => _privacy = value),
                ),
                _LocationStep(
                  locationController: _locationController,
                ),
              ],
            ),
          ),
          _ClubWizardFooter(
            primaryLabel: _step == _stepCount - 1 ? 'Создать клуб' : 'Далее',
            enabled: _canContinue && !_submitting,
            loading: _submitting,
            onPressed: _goNext,
          ),
        ],
      ),
    );
  }
}

class _ClubWizardProgress extends StatelessWidget {
  const _ClubWizardProgress({
    required this.currentStep,
    required this.stepCount,
  });

  final int currentStep;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(stepCount, (index) {
        final isPast = index < currentStep;
        final isCurrent = index == currentStep;
        final color = isCurrent || isPast
            ? AuthColors.primaryGreen
            : const Color(0xFFE6E6E6);

        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: index == stepCount - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _ClubWizardFooter extends StatelessWidget {
  const _ClubWizardFooter({
    required this.primaryLabel,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final String primaryLabel;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Эту настройку можно изменить в любой момент.',
              textAlign: TextAlign.center,
              style: authSubtitleStyle(),
            ),
            const SizedBox(height: 12),
            AuthPrimaryButton(
              label: primaryLabel,
              isLoading: loading,
              onPressed: enabled ? onPressed : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SportTypeStep extends StatelessWidget {
  const _SportTypeStep({
    required this.selectedId,
    required this.onChanged,
  });

  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _OptionListStep(
      title: 'Укажите вид спорта в клубе',
      subtitle:
          'Выберите конкретный или отметьте вариант «Все виды спорта».',
      sectionLabel: 'ВИД СПОРТА',
      options: ClubWizardOptions.sportTypes,
      selectedId: selectedId,
      onChanged: onChanged,
    );
  }
}

class _OptionListStep extends StatelessWidget {
  const _OptionListStep({
    required this.title,
    required this.subtitle,
    required this.sectionLabel,
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String sectionLabel;
  final List<ClubWizardOption> options;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(title, style: authTitleStyle().copyWith(fontSize: 24)),
        const SizedBox(height: 8),
        Text(subtitle, style: authSubtitleStyle()),
        const SizedBox(height: 24),
        Text(
          sectionLabel,
          style: GoogleFonts.lexendDeca(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AuthColors.body,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),
        ...options.map(
          (option) => _SelectableOptionTile(
            option: option,
            selected: selectedId == option.id,
            onTap: () => onChanged(option.id),
          ),
        ),
      ],
    );
  }
}

class _SelectableOptionTile extends StatelessWidget {
  const _SelectableOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ClubWizardOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AuthColors.primaryGreen : AuthColors.border,
                width: selected ? 1.5 : 1,
              ),
              color: selected
                  ? AuthColors.primaryGreen.withValues(alpha: 0.06)
                  : Colors.white,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AuthColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(option.icon, color: AuthColors.title, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        style: GoogleFonts.lexendDeca(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AuthColors.title,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(option.subtitle, style: authSubtitleStyle()),
                    ],
                  ),
                ),
                _RadioDot(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AuthColors.primaryGreen : AuthColors.border,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AuthColors.primaryGreen,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _ConfigureClubStep extends StatelessWidget {
  const _ConfigureClubStep({
    required this.nameController,
    required this.descriptionController,
    required this.avatarFile,
    required this.onPickAvatar,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final File? avatarFile;
  final VoidCallback onPickAvatar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text('Настройте клуб', style: authTitleStyle().copyWith(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          'Придумайте название, загрузите фото и добавьте описание.',
          style: authSubtitleStyle(),
        ),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onTap: onPickAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AuthColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AuthColors.border),
                    image: avatarFile != null
                        ? DecorationImage(
                            image: FileImage(avatarFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: avatarFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.photo_outlined,
                              color: AuthColors.body,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Загрузить фото',
                              style: GoogleFonts.lexendDeca(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AuthColors.body,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AuthColors.border),
                    ),
                    child: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        AuthTextField(
          label: 'Название клуба',
          controller: nameController,
          hint: 'Название клуба',
        ),
        const SizedBox(height: 16),
        Text('Описание', style: authLabelStyle()),
        const SizedBox(height: 8),
        TextField(
          controller: descriptionController,
          maxLines: 4,
          style: authFieldStyle(),
          decoration: InputDecoration(
            hintText: 'Описание',
            hintStyle: authHintStyle(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AuthColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AuthColors.primaryGreen,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, size: 18, color: AuthColors.body),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Название клуба и его описание должны соответствовать правилам сообщества.',
                style: authSubtitleStyle(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocationStep extends StatelessWidget {
  const _LocationStep({
    required this.locationController,
  });

  final TextEditingController locationController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          'Где находится ваш клуб?',
          style: authTitleStyle().copyWith(fontSize: 24),
        ),
        const SizedBox(height: 8),
        Text(
          'Укажите город или регион. Поле можно оставить пустым, если клуб не привязан к месту.',
          style: authSubtitleStyle(),
        ),
        const SizedBox(height: 24),
        AuthTextField(
          label: 'Местоположение',
          controller: locationController,
          hint: 'Например, Новосибирск',
        ),
      ],
    );
  }
}
