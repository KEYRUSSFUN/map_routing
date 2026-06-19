import 'package:flutter/material.dart';
import 'package:map_routing/features/profile/presentation/user_profile_page.dart';

Future<void> openUserProfile(BuildContext context, dynamic userId) {
  final id = userId?.toString().trim() ?? '';
  if (id.isEmpty || id == 'unknown' || id == '0') {
    return Future.value();
  }

  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => UserProfilePage(userId: id),
    ),
  );
}
