import 'package:flutter/material.dart';

class ClubWizardOption {
  const ClubWizardOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

abstract final class ClubWizardOptions {
  static const sportTypes = <ClubWizardOption>[
    ClubWizardOption(
      id: 'all_sports',
      title: 'Все виды спорта',
      subtitle: 'Бег, велосипед, плавание и другие активности',
      icon: Icons.bolt_rounded,
    ),
    ClubWizardOption(
      id: 'cycling',
      title: 'Велосипед',
      subtitle: 'Шоссе, гравий, MTB и велотренировки',
      icon: Icons.directions_bike_rounded,
    ),
    ClubWizardOption(
      id: 'running',
      title: 'Бег',
      subtitle: 'Забег, виртуальный забег, трейл и дорожка',
      icon: Icons.directions_run_rounded,
    ),
    ClubWizardOption(
      id: 'triathlon',
      title: 'Триатлон',
      subtitle: 'Плавание, велосипед и бег в одном клубе',
      icon: Icons.pool_rounded,
    ),
    ClubWizardOption(
      id: 'alpine_skiing',
      title: 'Горные лыжи',
      subtitle: 'Склон, фрирайд и зимние тренировки',
      icon: Icons.downhill_skiing_rounded,
    ),
  ];

  static const clubTypes = <ClubWizardOption>[
    ClubWizardOption(
      id: 'casual',
      title: 'Просто так',
      subtitle: 'Неформальное сообщество без жёстких правил',
      icon: Icons.groups_rounded,
    ),
    ClubWizardOption(
      id: 'team',
      title: 'Команда',
      subtitle: 'Спортивная команда или тренировочная группа',
      icon: Icons.emoji_events_outlined,
    ),
    ClubWizardOption(
      id: 'brand',
      title: 'Бренд / магазин',
      subtitle: 'Клуб от бренда, магазина или организатора',
      icon: Icons.storefront_outlined,
    ),
    ClubWizardOption(
      id: 'company',
      title: 'Компания',
      subtitle: 'Корпоративный или рабочий спортивный клуб',
      icon: Icons.apartment_rounded,
    ),
  ];

  static const privacyOptions = <ClubWizardOption>[
    ClubWizardOption(
      id: 'open',
      title: 'Открытый',
      subtitle:
          'Вступить и просматривать активность клуба может любой пользователь.',
      icon: Icons.public_rounded,
    ),
    ClubWizardOption(
      id: 'closed',
      title: 'Закрытый',
      subtitle:
          'Участие возможно только после одобрения администратора клуба.',
      icon: Icons.lock_outline_rounded,
    ),
  ];

  static ClubWizardOption? sportById(String? id) =>
      sportTypes.where((item) => item.id == id).cast<ClubWizardOption?>().firstOrNull;

  static ClubWizardOption? clubTypeById(String? id) =>
      clubTypes.where((item) => item.id == id).cast<ClubWizardOption?>().firstOrNull;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

String clubSportLabel(String id) {
  return ClubWizardOptions.sportTypes
          .where((item) => item.id == id)
          .map((item) => item.title)
          .firstOrNull ??
      'Спорт';
}

String clubTypeLabel(String id) {
  return ClubWizardOptions.clubTypes
          .where((item) => item.id == id)
          .map((item) => item.title)
          .firstOrNull ??
      'Клуб';
}

String clubLocationLabel(String? label) {
  if (label != null && label.isNotEmpty) return label;
  return '';
}
