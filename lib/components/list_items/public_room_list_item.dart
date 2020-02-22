import 'package:famedlysdk/famedlysdk.dart';
import 'package:flutter/material.dart';

import '../../i18n/i18n.dart';
import '../../utils/app_route.dart';
import '../../views/chat.dart';
import '../avatar.dart';
import '../matrix.dart';

class PublicRoomListItem extends StatelessWidget {
  final PublicRoomEntry publicRoomEntry;

  const PublicRoomListItem(this.publicRoomEntry, {Key key}) : super(key: key);

  void joinAction(BuildContext context) async {
    final success = await Matrix.of(context)
        .tryRequestWithLoadingDialog(publicRoomEntry.join());
    if (success != false) {
      await Navigator.of(context).push(
        AppRoute.defaultRoute(
          context,
          ChatView(publicRoomEntry.roomId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasTopic =
        publicRoomEntry.topic != null && publicRoomEntry.topic.isNotEmpty;
    return ListTile(
      leading:
          Avatar(MxContent(publicRoomEntry.avatarUrl), publicRoomEntry.name),
      title: Text(hasTopic
          ? "${publicRoomEntry.name} (${publicRoomEntry.numJoinedMembers})"
          : publicRoomEntry.name),
      subtitle: Text(
        hasTopic
            ? publicRoomEntry.topic
            : I18n.of(context).countParticipants(
                publicRoomEntry.numJoinedMembers?.toString() ?? "0"),
        maxLines: 1,
      ),
      onTap: () => joinAction(context),
    );
  }
}