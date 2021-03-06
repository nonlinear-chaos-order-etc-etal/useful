import 'dart:async';

import 'package:fluffychat/components/default_app_bar_search_field.dart';
import 'package:flushbar/flushbar_helper.dart';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:famedlysdk/matrix_api.dart';
import 'package:fluffychat/components/adaptive_page_layout.dart';
import 'package:fluffychat/components/avatar.dart';
import 'package:future_loading_dialog/future_loading_dialog.dart';
import 'package:fluffychat/components/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

import '../utils/localized_exception_extension.dart';
import 'chat_list.dart';

class InvitationSelection extends StatefulWidget {
  final Room room;
  const InvitationSelection(this.room, {Key key}) : super(key: key);

  @override
  _InvitationSelectionState createState() => _InvitationSelectionState();
}

class _InvitationSelectionState extends State<InvitationSelection> {
  TextEditingController controller = TextEditingController();
  String currentSearchTerm;
  bool loading = false;
  List<Profile> foundProfiles = [];
  Timer coolDown;

  Future<List<User>> getContacts(BuildContext context) async {
    var client2 = Matrix.of(context).client;
    final client = client2;
    var participants = await widget.room.requestParticipants();
    participants.removeWhere(
      (u) => ![Membership.join, Membership.invite].contains(u.membership),
    );
    var contacts = <User>[];
    var userMap = <String, bool>{};
    for (var i = 0; i < client.rooms.length; i++) {
      var roomUsers = client.rooms[i].getParticipants();

      for (var j = 0; j < roomUsers.length; j++) {
        if (userMap[roomUsers[j].id] != true &&
            participants.indexWhere((u) => u.id == roomUsers[j].id) == -1) {
          contacts.add(roomUsers[j]);
        }
        userMap[roomUsers[j].id] = true;
      }
    }
    contacts.sort(
      (a, b) => a.calcDisplayname().toLowerCase().compareTo(
            b.calcDisplayname().toLowerCase(),
          ),
    );
    return contacts;
  }

  void inviteAction(BuildContext context, String id) async {
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => widget.room.invite(id),
    );
    if (success.error == null) {
      await FlushbarHelper.createSuccess(
              message: L10n.of(context).contactHasBeenInvitedToTheGroup)
          .show(context);
    }
  }

  void searchUserWithCoolDown(BuildContext context, String text) async {
    coolDown?.cancel();
    coolDown = Timer(
      Duration(seconds: 1),
      () => searchUser(context, text),
    );
  }

  void searchUser(BuildContext context, String text) async {
    coolDown?.cancel();
    if (text.isEmpty) {
      setState(() {
        foundProfiles = [];
      });
    }
    currentSearchTerm = text;
    if (currentSearchTerm.isEmpty) return;
    if (loading) return;
    setState(() => loading = true);
    final matrix = Matrix.of(context);
    UserSearchResult response;
    try {
      response = await matrix.client.searchUser(text, limit: 10);
    } catch (e) {
      FlushbarHelper.createError(
          message: (e as Object).toLocalizedString(context));
      return;
    } finally {
      setState(() => loading = false);
    }
    setState(() {
      foundProfiles = List<Profile>.from(response.results);
      if ('@$text'.isValidMatrixId &&
          foundProfiles.indexWhere((profile) => '@$text' == profile.userId) ==
              -1) {
        setState(() => foundProfiles = [
              Profile.fromJson({'user_id': '@$text'}),
            ]);
      }
      final participants = widget.room
          .getParticipants()
          .where((user) =>
              [Membership.join, Membership.invite].contains(user.membership))
          .toList();
      foundProfiles.removeWhere((profile) =>
          participants.indexWhere((u) => u.id == profile.userId) != -1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupName = widget.room.name?.isEmpty ?? false
        ? L10n.of(context).group
        : widget.room.name;
    return AdaptivePageLayout(
      primaryPage: FocusPage.SECOND,
      firstScaffold: ChatList(activeChat: widget.room.id),
      secondScaffold: Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: DefaultAppBarSearchField(
              autofocus: true,
              hintText: L10n.of(context).inviteContactToGroup(groupName),
              onChanged: (String text) => searchUserWithCoolDown(context, text),
            ),
          ),
          body: foundProfiles.isNotEmpty
              ? ListView.builder(
                  itemCount: foundProfiles.length,
                  itemBuilder: (BuildContext context, int i) => ListTile(
                    leading: Avatar(
                      foundProfiles[i].avatarUrl,
                      foundProfiles[i].displayname ?? foundProfiles[i].userId,
                    ),
                    title: Text(
                      foundProfiles[i].displayname ??
                          foundProfiles[i].userId.localpart,
                    ),
                    subtitle: Text(foundProfiles[i].userId),
                    onTap: () => inviteAction(context, foundProfiles[i].userId),
                  ),
                )
              : FutureBuilder<List<User>>(
                  future: getContacts(context),
                  builder: (BuildContext context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                    var contacts = snapshot.data;
                    return ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (BuildContext context, int i) => ListTile(
                        leading: Avatar(
                          contacts[i].avatarUrl,
                          contacts[i].calcDisplayname(),
                        ),
                        title: Text(contacts[i].calcDisplayname()),
                        subtitle: Text(contacts[i].id),
                        onTap: () => inviteAction(context, contacts[i].id),
                      ),
                    );
                  },
                )),
    );
  }
}
