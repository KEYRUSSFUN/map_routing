class ChatParticipant {
  const ChatParticipant({
    required this.name,
    this.userId,
    this.isCreator = false,
  });

  final String name;
  final String? userId;
  final bool isCreator;

  static List<ChatParticipant> fromJsonList(
    dynamic raw, {
    int? creatorId,
  }) {
    if (raw is! List) return const [];

    final participants = raw.map<ChatParticipant>((item) {
      if (item is Map) {
        final id = item['id']?.toString() ?? item['userId']?.toString();
        final name = item['name']?.toString() ??
            item['username']?.toString() ??
            'Пользователь';
        final isCreator = item['isCreator'] == true ||
            (creatorId != null &&
                id != null &&
                id == creatorId.toString());
        return ChatParticipant(
          name: name,
          userId: id,
          isCreator: isCreator,
        );
      }
      return ChatParticipant(name: item.toString());
    }).toList();

    participants.sort((a, b) {
      if (a.isCreator != b.isCreator) {
        return a.isCreator ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return participants;
  }

  static String? creatorNameFrom(List<ChatParticipant> participants) {
    for (final participant in participants) {
      if (participant.isCreator) return participant.name;
    }
    return null;
  }
}
