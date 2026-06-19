import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:map_routing/data/models/workout_activity_type.dart';
import 'package:map_routing/data/models/workout_summary.dart';
import 'package:map_routing/data/services/gpx_workout_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/map/presentation/map_ui_styles.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';

class EditWorkoutPage extends StatefulWidget {
  const EditWorkoutPage({
    super.key,
    required this.workout,
  });

  final WorkoutSummary workout;

  @override
  State<EditWorkoutPage> createState() => _EditWorkoutPageState();
}

class _EditWorkoutPageState extends State<EditWorkoutPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _tagsController;

  late int _effortLevel;
  late WorkoutPrivacy _privacy;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final workout = widget.workout;
    _titleController = TextEditingController(text: workout.title);
    _descriptionController =
        TextEditingController(text: workout.description ?? '');
    _tagsController = TextEditingController(text: workout.tags.join(', '));
    _effortLevel = workout.effortLevel ?? 3;
    _privacy = workout.privacy ?? WorkoutPrivacy.friends;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final updated = await GpxWorkoutService().updateWorkoutDetails(
        widget.workout,
        title: _titleController.text,
        description: _descriptionController.text,
        tags: tags,
        effortLevel: _effortLevel,
        privacy: _privacy,
      );

      if (!mounted) return;
      Navigator.pop(context, updated);
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Ошибка сохранения: $e');
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
        title: Text('Редактировать маршрут', style: authTitleStyle()),
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
                  AuthTextField(
                    label: 'Описание',
                    controller: _descriptionController,
                    hint: 'Как прошла тренировка?',
                  ),
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
                  Text('Видимость', style: authLabelStyle()),
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
                  if (widget.workout.isImported) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Маршрут из чата — изменения сохраняются только на этом устройстве.',
                      style: GoogleFonts.lexendDeca(
                        fontSize: 12,
                        color: ProfileColors.body,
                      ),
                    ),
                  ],
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
