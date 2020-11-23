import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:famedlysdk/famedlysdk.dart';
import 'package:fluffychat/components/adaptive_page_layout.dart';
import 'package:fluffychat/components/dialogs/simple_dialogs.dart';
import 'package:fluffychat/components/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

import 'chat_list.dart';

class Settings3PidView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AdaptivePageLayout(
      primaryPage: FocusPage.SECOND,
      firstScaffold: ChatList(),
      secondScaffold: Settings3Pid(),
    );
  }
}

class Settings3Pid extends StatefulWidget {
  static int sendAttempt = 0;

  @override
  _Settings3PidState createState() => _Settings3PidState();
}

class _Settings3PidState extends State<Settings3Pid> {
  void _add3PidAction(BuildContext context) async {
    final input = await showTextInputDialog(
      context: context,
      title: L10n.of(context).enterAnEmailAddress,
      textFields: [
        DialogTextField(
          hintText: L10n.of(context).enterAnEmailAddress,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
    if (input == null) return;
    final clientSecret = DateTime.now().millisecondsSinceEpoch.toString();
    final response = await SimpleDialogs(context).tryRequestWithLoadingDialog(
      Matrix.of(context).client.requestEmailToken(
            input.single,
            clientSecret,
            Settings3Pid.sendAttempt++,
          ),
    );
    if (response == false) return;
    final ok = await showOkAlertDialog(
      context: context,
      title: L10n.of(context).weSentYouAnEmail,
      message: L10n.of(context).pleaseClickOnLink,
      okLabel: L10n.of(context).iHaveClickedOnLink,
    );
    if (ok == null) return;
    final password = await showTextInputDialog(
      context: context,
      title: L10n.of(context).pleaseEnterYourPassword,
      textFields: [
        DialogTextField(
          hintText: '******',
          obscureText: true,
        ),
      ],
    );
    if (password == null) return;
    final success = await SimpleDialogs(context).tryRequestWithLoadingDialog(
      Future.microtask(() async {
        final Function request = ({Map<String, dynamic> auth}) async =>
            Matrix.of(context).client.addThirdPartyIdentifier(
                  clientSecret,
                  (response as RequestTokenResponse).sid,
                  auth: auth,
                );
        try {
          await request();
        } on MatrixException catch (exception) {
          if (!exception.requireAdditionalAuthentication) rethrow;
          await request(
            auth: {
              'type': 'm.login.password',
              'identifier': {
                'type': 'm.id.user',
                'user': Matrix.of(context).client.userID,
              },
              'user': Matrix.of(context).client.userID,
              'password': password.single,
              'session': exception.session,
            },
          );
        }
        return;
      }),
    );
    if (success == false) return;
    setState(() => _request = null);
  }

  Future<List<ThirdPartyIdentifier>> _request;

  void _delete3Pid(
      BuildContext context, ThirdPartyIdentifier identifier) async {
    if (await showOkCancelAlertDialog(
          context: context,
          title: L10n.of(context).areYouSure,
        ) !=
        OkCancelResult.ok) {
      return;
    }
    final success = await SimpleDialogs(context).tryRequestWithLoadingDialog(
        Matrix.of(context).client.deleteThirdPartyIdentifier(
              identifier.address,
              identifier.medium,
            ));
    if (success == false) return;
    setState(() => _request = null);
  }

  @override
  Widget build(BuildContext context) {
    _request ??= Matrix.of(context).client.requestThirdPartyIdentifiers();
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).passwordRecovery),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _add3PidAction(context),
          )
        ],
      ),
      body: FutureBuilder<List<ThirdPartyIdentifier>>(
        future: _request,
        builder: (BuildContext context,
            AsyncSnapshot<List<ThirdPartyIdentifier>> snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final identifier = snapshot.data;
          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  foregroundColor:
                      identifier.isEmpty ? Colors.orange : Colors.grey,
                  child: Icon(
                    identifier.isEmpty ? Icons.warning : Icons.info,
                  ),
                ),
                title: Text(
                  identifier.isEmpty
                      ? L10n.of(context).noPasswordRecoveryDescription
                      : L10n.of(context).withTheseAddressesRecoveryDescription,
                ),
              ),
              Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: identifier.length,
                  itemBuilder: (BuildContext context, int i) => ListTile(
                    leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        foregroundColor: Colors.grey,
                        child: Icon(identifier[i].iconData)),
                    title: Text(identifier[i].address),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_forever),
                      color: Colors.red,
                      onPressed: () => _delete3Pid(context, identifier[i]),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension on ThirdPartyIdentifier {
  IconData get iconData {
    switch (medium) {
      case ThirdPartyIdentifierMedium.email:
        return Icons.mail_outline_rounded;
      case ThirdPartyIdentifierMedium.msisdn:
        return Icons.phone_android_outlined;
    }
    return Icons.device_unknown_outlined;
  }
}