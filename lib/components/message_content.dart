import 'package:bubble/bubble.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/style.dart';
import 'package:url_launcher/url_launcher.dart';

import 'matrix.dart';

class MessageContent extends StatelessWidget {
  final Event event;
  final Color textColor;
  final bool textOnly;

  const MessageContent(this.event, {this.textColor, this.textOnly = false});

  @override
  Widget build(BuildContext context) {
    final int maxLines = textOnly ? 1 : null;

    switch (event.type) {
      case EventTypes.Image:
        if (textOnly) {
          return Text(
            "${event.sender.calcDisplayname()} has sent an image",
            maxLines: maxLines,
            style: TextStyle(
              color: textColor,
              decoration: event.redacted ? TextDecoration.lineThrough : null,
            ),
          );
        }
        final int size = 400;
        final String src = MxContent(event.content["url"]).getThumbnail(
          Matrix.of(context).client,
          width: size * MediaQuery.of(context).devicePixelRatio,
          height: size * MediaQuery.of(context).devicePixelRatio,
          method: ThumbnailMethod.scale,
        );
        return Bubble(
          padding: BubbleEdges.all(0),
          radius: Radius.circular(10),
          elevation: 0,
          child: InkWell(
            onTap: () => launch(
              MxContent(event.content["url"])
                  .getDownloadLink(Matrix.of(context).client),
            ),
            child: kIsWeb
                ? Image.network(
                    src,
                    width: size.toDouble(),
                  )
                : CachedNetworkImage(
                    imageUrl: src,
                    width: size.toDouble(),
                  ),
          ),
        );
      case EventTypes.Audio:
      case EventTypes.File:
      case EventTypes.Video:
        return Container(
          width: 200,
          child: RaisedButton(
            color: Colors.blueGrey,
            child: Text(
              "Download ${event.getBody()}",
              overflow: TextOverflow.fade,
              softWrap: false,
              maxLines: 1,
            ),
            onPressed: () => launch(
              MxContent(event.content["url"])
                  .getDownloadLink(Matrix.of(context).client),
            ),
          ),
        );
      case EventTypes.Text:
      case EventTypes.Reply:
      case EventTypes.Notice:
        final String senderPrefix =
            textOnly && event.senderId != event.room.directChatMatrixID
                ? event.senderId == Matrix.of(context).client.userID
                    ? "You: "
                    : "${event.sender.calcDisplayname()}: "
                : "";
        if (event.formattedText.isNotEmpty) {
          final style = Style.fromTextStyle(
            TextStyle(
              color: textColor,
              decoration: event.redacted ? TextDecoration.lineThrough : null,
            ),
          );
          style.whiteSpace = WhiteSpace.PRE;

          return Html(
            data: senderPrefix + event.formattedText,
            shrinkWrap: true,
            style: {
              "html": style,
              "body": Style(margin: EdgeInsets.zero),
            },
          );
        }
        return Text(
          senderPrefix + event.getBody(),
          maxLines: maxLines,
          overflow: textOnly ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: textColor,
            decoration: event.redacted ? TextDecoration.lineThrough : null,
          ),
        );
      case EventTypes.Emote:
        return Text(
          "* " + event.getBody(),
          maxLines: maxLines,
          overflow: textOnly ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: textColor,
            fontStyle: FontStyle.italic,
            decoration: event.redacted ? TextDecoration.lineThrough : null,
          ),
        );
      case EventTypes.RoomCreate:
        return Text(
          "${event.sender.calcDisplayname()} has created the chat",
          maxLines: maxLines,
          overflow: textOnly ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: textColor,
          ),
        );
      case EventTypes.RoomAvatar:
        return Text(
          "${event.sender.calcDisplayname()} has changed the chat avatar",
          maxLines: maxLines,
          overflow: textOnly ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: textColor,
          ),
        );
      case EventTypes.RoomName:
        return Text(
          "${event.sender.calcDisplayname()} has changed the chat name to '${event.content['name']}'",
          maxLines: maxLines,
          overflow: textOnly ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: textColor,
          ),
        );
      case EventTypes.RoomMember: // Display what has changed
        String text = "Failed to parse member event";
        // Has the membership changed?
        final String newMembership = event.content["membership"] ?? "";
        final String oldMembership =
            event.unsigned["prev_content"] is Map<String, dynamic>
                ? event.unsigned["prev_content"]["membership"] ?? ""
                : "";
        if (newMembership != oldMembership) {
          if (oldMembership == "invite" && newMembership == "join") {
            text =
                "${event.stateKeyUser.calcDisplayname()} has accepted the invitation";
          } else if (oldMembership == "leave" && newMembership == "join") {
            text =
                "${event.stateKeyUser.calcDisplayname()} has joined the chat";
          } else if (oldMembership == "join" && newMembership == "ban") {
            text =
                "${event.sender.calcDisplayname()} has kicked and banned ${event.stateKeyUser.calcDisplayname()}";
          } else if (oldMembership == "join" &&
              newMembership == "leave" &&
              event.stateKey != event.senderId) {
            text =
                "${event.sender.calcDisplayname()} has kicked ${event.stateKeyUser.calcDisplayname()}";
          } else if (oldMembership == "join" &&
              newMembership == "leave" &&
              event.stateKey == event.senderId) {
            text = "${event.stateKeyUser.calcDisplayname()} has left the room";
          } else if (oldMembership == "invite" && newMembership == "ban") {
            text =
                "${event.sender.calcDisplayname()} has banned ${event.stateKeyUser.calcDisplayname()}";
          } else if (oldMembership == "leave" && newMembership == "ban") {
            text =
                "${event.sender.calcDisplayname()} has banned ${event.stateKeyUser.calcDisplayname()}";
          } else if (oldMembership == "ban" && newMembership == "leave") {
            text =
                "${event.sender.calcDisplayname()} has unbanned ${event.stateKeyUser.calcDisplayname()}";
          } else if (newMembership == "invite") {
            text =
                "${event.sender.calcDisplayname()} has invited ${event.stateKeyUser.calcDisplayname()}";
          } else if (newMembership == "join") {
            text = "${event.stateKeyUser.calcDisplayname()} has joined";
          }
        } else if (newMembership == "join") {
          final String newAvatar = event.content["avatar_url"] ?? "";
          final String oldAvatar =
              event.unsigned["prev_content"] is Map<String, dynamic>
                  ? event.unsigned["prev_content"]["avatar_url"] ?? ""
                  : "";

          final String newDisplayname = event.content["displayname"] ?? "";
          final String oldDisplayname =
              event.unsigned["prev_content"] is Map<String, dynamic>
                  ? event.unsigned["prev_content"]["displayname"] ?? ""
                  : "";

          // Has the user avatar changed?
          if (newAvatar != oldAvatar) {
            text =
                "${event.stateKeyUser.calcDisplayname()} has changed the profile avatar";
          }
          // Has the user avatar changed?
          else if (newDisplayname != oldDisplayname) {
            text =
                "${event.stateKeyUser.calcDisplayname()} has changed the displayname to '$newDisplayname'";
          }
        }

        return Text(
          text,
          maxLines: maxLines,
          overflow: textOnly ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: textColor,
          ),
        );
      case EventTypes.RoomTopic:
        return Text(
          "${event.sender.calcDisplayname()} has changed the chat topic to '${event.content['topic']}'",
          maxLines: maxLines,
          overflow: textOnly ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: textColor,
          ),
        );
      case EventTypes.RoomPowerLevels:
        return Text(
          "${event.sender.calcDisplayname()} has changed the power levels of the chat",
          maxLines: maxLines,
          overflow: textOnly ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: textColor,
          ),
        );
      case EventTypes.HistoryVisibility:
        return Text(
          "${event.sender.calcDisplayname()} has changed the history visibility of the chat to '${event.content['history_visibility']}'",
          maxLines: maxLines,
          overflow: textOnly ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: textColor,
          ),
        );
      case EventTypes.RoomJoinRules:
        return Text(
          "${event.sender.calcDisplayname()} has changed the join rules of the chat to '${event.content['join_rule']}'",
          maxLines: maxLines,
          overflow: textOnly ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: textColor,
          ),
        );
      case EventTypes.RoomCanonicalAlias:
        if (event.content['canonical_alias']?.isEmpty ?? true) {
          return Text(
            "${event.sender.calcDisplayname()} has removed the canonical alias.",
            maxLines: maxLines,
            style: TextStyle(
              color: textColor,
            ),
          );
        }
        return Text(
          "${event.sender.calcDisplayname()} has changed the canonical alias to: ${event.content['canonical_alias']}",
          maxLines: maxLines,
          overflow: textOnly ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: textColor,
          ),
        );
      default:
        return Text(
          "${event.sender.calcDisplayname()} sent a ${event.typeKey} event",
          maxLines: maxLines,
          overflow: textOnly ? TextOverflow.ellipsis : null,
          style: TextStyle(
            color: textColor,
            decoration: event.redacted ? TextDecoration.lineThrough : null,
          ),
        );
    }
  }
}
