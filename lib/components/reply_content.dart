import 'package:famedlysdk/famedlysdk.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:flutter/material.dart';

class ReplyContent extends StatelessWidget {
  final Event replyEvent;
  final bool lightText;

  const ReplyContent(this.replyEvent, {this.lightText = false, Key key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 3,
          height: 36,
          color: lightText ? Colors.white : Theme.of(context).primaryColor,
        ),
        SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                (replyEvent?.sender?.calcDisplayname() ?? "") + ":",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      lightText ? Colors.white : Theme.of(context).primaryColor,
                ),
              ),
              Text(
                replyEvent?.getLocalizedBody(
                      L10n.of(context),
                      withSenderNamePrefix: false,
                      hideReply: true,
                    ) ??
                    "",
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                    color: lightText
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyText2.color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
