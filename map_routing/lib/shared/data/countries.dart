import 'package:flutter/material.dart';
import 'package:map_routing/features/auth/presentation/auth_ui.dart';

/// Популярные страны для выбора в профиле (русские названия).
const List<String> popularCountries = [
  'Россия',
  'Беларусь',
  'Казахстан',
  'Украина',
  'Армения',
  'Азербайджан',
  'Грузия',
  'Кыргызстан',
  'Молдова',
  'Таджикистан',
  'Туркменистан',
  'Узбекистан',
  'США',
  'Канада',
  'Великобритания',
  'Германия',
  'Франция',
  'Италия',
  'Испания',
  'Польша',
  'Нидерланды',
  'Бельгия',
  'Швейцария',
  'Австрия',
  'Швеция',
  'Норвегия',
  'Финляндия',
  'Дания',
  'Чехия',
  'Словакия',
  'Португалия',
  'Греция',
  'Румыния',
  'Венгрия',
  'Болгария',
  'Сербия',
  'Хорватия',
  'Литва',
  'Латвия',
  'Эстония',
  'Ирландия',
  'Турция',
  'Китай',
  'Япония',
  'Южная Корея',
  'Индия',
  'Индонезия',
  'Таиланд',
  'Вьетнам',
  'Сингапур',
  'Малайзия',
  'Филиппины',
  'ОАЭ',
  'Саудовская Аравия',
  'Израиль',
  'Иран',
  'Пакистан',
  'Австралия',
  'Новая Зеландия',
  'Бразилия',
  'Аргентина',
  'Мексика',
  'Чили',
  'Колумбия',
  'ЮАР',
  'Египет',
];

const Map<String, String> _englishCountryAliases = {
  'russia': 'Россия',
  'belarus': 'Беларусь',
  'kazakhstan': 'Казахстан',
  'ukraine': 'Украина',
  'armenia': 'Армения',
  'azerbaijan': 'Азербайджан',
  'georgia': 'Грузия',
  'kyrgyzstan': 'Кыргызстан',
  'moldova': 'Молдова',
  'tajikistan': 'Таджикистан',
  'turkmenistan': 'Туркменистан',
  'uzbekistan': 'Узбекистан',
  'usa': 'США',
  'united states': 'США',
  'canada': 'Канада',
  'united kingdom': 'Великобритания',
  'uk': 'Великобритания',
  'germany': 'Германия',
  'france': 'Франция',
  'italy': 'Италия',
  'spain': 'Испания',
  'poland': 'Польша',
  'netherlands': 'Нидерланды',
  'belgium': 'Бельгия',
  'switzerland': 'Швейцария',
  'austria': 'Австрия',
  'sweden': 'Швеция',
  'norway': 'Норвегия',
  'finland': 'Финляндия',
  'denmark': 'Дания',
  'czech republic': 'Чехия',
  'czechia': 'Чехия',
  'slovakia': 'Словакия',
  'portugal': 'Португалия',
  'greece': 'Греция',
  'romania': 'Румыния',
  'hungary': 'Венгрия',
  'bulgaria': 'Болгария',
  'serbia': 'Сербия',
  'croatia': 'Хорватия',
  'lithuania': 'Литва',
  'latvia': 'Латвия',
  'estonia': 'Эстония',
  'ireland': 'Ирландия',
  'turkey': 'Турция',
  'china': 'Китай',
  'japan': 'Япония',
  'south korea': 'Южная Корея',
  'korea': 'Южная Корея',
  'india': 'Индия',
  'indonesia': 'Индонезия',
  'thailand': 'Таиланд',
  'vietnam': 'Вьетнам',
  'singapore': 'Сингапур',
  'malaysia': 'Малайзия',
  'philippines': 'Филиппины',
  'uae': 'ОАЭ',
  'united arab emirates': 'ОАЭ',
  'saudi arabia': 'Саудовская Аравия',
  'israel': 'Израиль',
  'iran': 'Иран',
  'pakistan': 'Пакистан',
  'australia': 'Австралия',
  'new zealand': 'Новая Зеландия',
  'brazil': 'Бразилия',
  'argentina': 'Аргентина',
  'mexico': 'Мексика',
  'chile': 'Чили',
  'colombia': 'Колумбия',
  'south africa': 'ЮАР',
  'egypt': 'Египет',
};

/// Приводит сохранённое значение страны к элементу списка.
String resolveCountry(String? raw) {
  if (raw == null) return '';
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed == 'null') return '';

  final alias = _englishCountryAliases[trimmed.toLowerCase()];
  if (alias != null) return alias;

  for (final country in popularCountries) {
    if (country.toLowerCase() == trimmed.toLowerCase()) {
      return country;
    }
  }

  return trimmed;
}

/// Список стран для селектора, включая ранее сохранённое значение.
List<String> countriesForSelection({String? existing}) {
  final resolved = resolveCountry(existing);
  if (resolved.isEmpty) {
    return List<String>.from(popularCountries);
  }
  if (popularCountries.contains(resolved)) {
    return List<String>.from(popularCountries);
  }
  return [resolved, ...popularCountries];
}

List<DropdownMenuItem<String>> buildCountryDropdownItems(
  List<String> countries,
) {
  return [
    DropdownMenuItem(
      value: '',
      child: Text('Выберите страну', style: authHintStyle()),
    ),
    ...countries.map(
      (country) => DropdownMenuItem(
        value: country,
        child: Text(country, style: authFieldStyle()),
      ),
    ),
  ];
}
