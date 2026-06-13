enum RoutingType {
  pedestrian(purpose: "Пешеход"),
  driving(purpose: "Водитель"),
  publicTransport(purpose: "Публичный транспорт");

  final String purpose;

  const RoutingType({required this.purpose});
}
