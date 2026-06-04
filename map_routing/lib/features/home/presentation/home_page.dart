import 'package:flutter/material.dart';
import 'package:map_routing/core/widgets/stride_track_logo.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.scaffoldBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StrideTrackLogo(size: 28),
              const SizedBox(height: 28),
              Text('Главная', style: authTitleStyle()),
              const SizedBox(height: 8),
              Text(
                'Добро пожаловать! Здесь будет ваша лента активности и сводка тренировок.',
                style: authSubtitleStyle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
