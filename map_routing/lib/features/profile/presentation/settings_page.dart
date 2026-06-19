import 'package:flutter/material.dart';
import 'package:map_routing/core/widgets/app_snackbar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_routing/core/services/notification_service.dart';
import 'package:map_routing/data/services/app_settings_service.dart';
import 'package:map_routing/data/services/user_service.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';
import 'package:map_routing/features/profile/presentation/edit_profile.dart';
import 'package:map_routing/features/profile/presentation/profile_ui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settings = AppSettingsService.instance;
  final _userService = UserService();

  bool _pushNotifications = true;
  bool _autoPause = true;
  bool _hideMapEndpoints = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final push = await _settings.getPushNotificationsEnabled();
    final autoPause = await _settings.getAutoPauseEnabled();
    final hideEndpoints = await _settings.getHideMapEndpoints();
    if (!mounted) return;
    setState(() {
      _pushNotifications = push;
      _autoPause = autoPause;
      _hideMapEndpoints = hideEndpoints;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final response = await _userService.logout();
    if (!mounted) return;
    if (response != null) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login_page',
        (route) => false,
      );
    } else {
      AppSnackBar.show(context, 'Ошибка выхода');
    }
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Настройки',
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
                _SettingsSection(
                  title: 'АККАУНТ',
                  children: [
                    _SettingsTile(
                      icon: Icons.person_outline,
                      title: 'Редактировать профиль',
                      subtitle: 'Имя, параметры и фото',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EditProfilePage(),
                          ),
                        );
                      },
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: ProfileColors.body,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SettingsSection(
                  title: 'ПРЕДПОЧТЕНИЯ',
                  children: [
                    _SettingsTile(
                      icon: Icons.straighten,
                      title: 'Единицы измерения',
                      subtitle: 'Метрическая система (км, м, кг)',
                      trailing: const Icon(
                        Icons.chevron_right,
                        color: ProfileColors.body,
                      ),
                      onTap: () {
                        AppSnackBar.show(
                          context,
                          'Сейчас доступна только метрическая система',
                        );
                      },
                    ),
                    _SettingsSwitchTile(
                      icon: Icons.directions_run,
                      title: 'Автопауза',
                      subtitle: 'Пауза, когда вы останавливаетесь',
                      value: _autoPause,
                      onChanged: (value) async {
                        setState(() => _autoPause = value);
                        await _settings.setAutoPauseEnabled(value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SettingsSection(
                  title: 'ПРИВАТНОСТЬ',
                  children: [
                    _SettingsSwitchTile(
                      icon: Icons.map_outlined,
                      title: 'Скрывать старт и финиш',
                      subtitle: 'Не показывать точки на карте',
                      value: _hideMapEndpoints,
                      onChanged: (value) async {
                        setState(() => _hideMapEndpoints = value);
                        await _settings.setHideMapEndpoints(value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _SettingsSection(
                  title: 'УВЕДОМЛЕНИЯ',
                  children: [
                    _SettingsSwitchTile(
                      icon: Icons.notifications_outlined,
                      title: 'Push-уведомления',
                      subtitle: 'Запросы в друзья и активность',
                      value: _pushNotifications,
                      onChanged: (value) async {
                        setState(() => _pushNotifications = value);
                        await _settings.setPushNotificationsEnabled(value);
                        if (!value) {
                          await NotificationService.instance.cancelAll();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _SettingsActionButton(
                  label: 'Выйти',
                  outlined: true,
                  onPressed: _logout,
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'StrideTrack v1.0.0',
                    style: GoogleFonts.lexendDeca(
                      fontSize: 12,
                      color: ProfileColors.body,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.lexendDeca(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ProfileColors.body,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          decoration: profileElevatedDecoration(),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(height: 1, indent: 56, color: Color(0xFFEEEEEE)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _SettingsIcon(icon: icon),
      title: Text(
        title,
        style: GoogleFonts.lexendDeca(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: ProfileColors.title,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: GoogleFonts.lexendDeca(
                fontSize: 12,
                color: ProfileColors.body,
              ),
            )
          : null,
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _SettingsIcon(icon: icon),
      title: Text(
        title,
        style: GoogleFonts.lexendDeca(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: ProfileColors.title,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.lexendDeca(
          fontSize: 12,
          color: ProfileColors.body,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: ProfileColors.primaryGreen,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: ProfileColors.primaryGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: ProfileColors.primaryGreen),
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: ProfileColors.title,
            side: const BorderSide(color: Color(0xFFD9D9D9)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.lexendDeca(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return AuthPrimaryButton(label: label, onPressed: onPressed);
  }
}
