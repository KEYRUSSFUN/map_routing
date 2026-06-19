enum RoutingType {
  pedestrian(purpose: 'Пешеход'),
  publicTransport(purpose: 'Публичный транспорт');

  final String purpose;

  const RoutingType({required this.purpose});
}
