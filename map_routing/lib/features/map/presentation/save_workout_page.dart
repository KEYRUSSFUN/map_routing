import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map_routing/data/activity_calculator.dart';
import 'package:map_routing/data/geometry_provider.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/data/models/workout_metadata.dart';
import 'package:map_routing/data/models/workout_session_data.dart';
import 'package:map_routing/data/services/gpx_workout_service.dart';
import 'package:map_routing/data/services/registration_service.dart';
import 'package:map_routing/data/services/route_service.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';
import 'package:map_routing/features/map/presentation/workout_celebration_page.dart';
import 'package:map_routing/features/profile/presentation/workout_detail_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SaveWorkoutPage extends StatefulWidget {
  const SaveWorkoutPage({
    super.key,
    required this.session,
    this.onWorkoutSaved,
  });

  final WorkoutSessionData session;
  final VoidCallback? onWorkoutSaved;

  @override
  State<SaveWorkoutPage> createState() => _SaveWorkoutPageState();
}

class _SaveWorkoutPageState extends State<SaveWorkoutPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;
  late final TextEditingController _tagsController;

  late WorkoutActivityType _activityType;
  WorkoutPrivacy _privacy = WorkoutPrivacy.friends;
  int _effortLevel = 3;
  String? _photoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _activityType = widget.session.activityType;
    _titleController = TextEditingController(
      text: defaultWorkoutTitle(_activityType, widget.session.startedAt),
    );
    _descriptionController = TextEditingController();
    _notesController = TextEditingController();
    _tagsController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _deleteWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить тренировку?'),
        content: const Text('Данные тренировки не будут сохранены.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final points = widget.session.points;
      final gpxPath = await GeometryProvider.saveTrackedRouteAsGpx(points);
      if (gpxPath == null) throw Exception('Не удалось сохранить GPX');

      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final metadata = WorkoutMetadata(
        title: _titleController.text.trim().isEmpty
            ? defaultWorkoutTitle(_activityType, widget.session.startedAt)
            : _titleController.text.trim(),
        activityType: _activityType,
        description: _descriptionController.text.trim(),
        photoPath: _photoPath,
        tags: tags,
        effortLevel: _effortLevel,
        notes: _notesController.text.trim(),
        privacy: _privacy,
        distanceMeters: widget.session.distanceMeters,
        durationSeconds: widget.session.duration.inSeconds,
        calories: widget.session.calories.round(),
        elevationGainM: widget.session.elevationGainM,
        avgSpeedKmh: widget.session.avgSpeedKmh,
        startedAtIso: widget.session.startedAt.toIso8601String(),
      );
      await WorkoutMetadata.saveToFile(gpxPath, metadata);

      try {
        await RouteService().uploadRoute(
          RouteService.trackPointsToGeoJson(points),
        );
      } catch (_) {}

      final userInfo = await UserService().fetchUserInfo();
      final weight = (userInfo?['weight'] as num?)?.toDouble() ?? 70.0;
      final calculator = ActivityCalculator(weightKg: weight);
      final steps = calculator.estimateStepsByDistance(widget.session.distanceMeters);
      final calories = calculator.calculateWalkingCalories(
        distanceMeters: widget.session.distanceMeters,
        met: _activityType.met,
      );

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token != null) {
        await RegistrationService().saveTrackingData(
          distance: widget.session.distanceMeters,
          steps: steps,
          calories: calories,
          token: token,
        );
      }

      final summary = GpxWorkoutService().buildFromSession(
        session: widget.session,
        metadata: metadata,
        gpxPath: gpxPath,
      );

      widget.onWorkoutSaved?.call();

      if (!mounted) return;
      final navigator = Navigator.of(context);
      navigator.pop();
      await navigator.push(
        MaterialPageRoute(builder: (_) => const WorkoutCelebrationPage()),
      );
      if (!navigator.mounted) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => WorkoutDetailPage(workout: summary),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Сохранить тренировку', style: authTitleStyle()),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(
                    label: 'Название',
                    controller: _titleController,
                    hint: 'Например, Утренний забег',
                  ),
                  const SizedBox(height: 16),
                  Text('Тип тренировки', style: authLabelStyle()),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: WorkoutActivityType.values.map((type) {
                      final selected = type == _activityType;
                      return ChoiceChip(
                        label: Text(type.labelRu),
                        selected: selected,
                        onSelected: (_) => setState(() => _activityType = type),
                        selectedColor: MapUiColors.primaryGreen.withValues(alpha: 0.2),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    label: 'Описание / ощущения',
                    controller: _descriptionController,
                    hint: 'Как прошла тренировка?',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.photo_outlined),
                    label: Text(_photoPath == null ? 'Добавить фото' : 'Фото выбрано'),
                  ),
                  if (_photoPath != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_photoPath!),
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AuthTextField(
                    label: 'Теги',
                    controller: _tagsController,
                    hint: 'парк, интервал, лёгкая',
                  ),
                  const SizedBox(height: 16),
                  Text('Уровень нагрузки', style: authLabelStyle()),
                  Slider(
                    value: _effortLevel.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$_effortLevel',
                    activeColor: MapUiColors.primaryGreen,
                    onChanged: (v) => setState(() => _effortLevel = v.round()),
                  ),
                  const SizedBox(height: 8),
                  AuthTextField(
                    label: 'Заметка',
                    controller: _notesController,
                    hint: 'Дополнительные мысли',
                  ),
                  const SizedBox(height: 16),
                  Text('Конфиденциальность', style: authLabelStyle()),
                  const SizedBox(height: 8),
                  ...WorkoutPrivacy.values.map((p) {
                    return RadioListTile<WorkoutPrivacy>(
                      value: p,
                      groupValue: _privacy,
                      onChanged: (v) => setState(() => _privacy = v!),
                      title: Text(p.labelRu, style: authFieldStyle()),
                      activeColor: MapUiColors.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _deleteWorkout,
                    child: Text(
                      'Удалить тренировку',
                      style: GoogleFonts.lexendDeca(
                        color: MapUiColors.stopRed,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: AuthPrimaryButton(
                label: 'Сохранить',
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
