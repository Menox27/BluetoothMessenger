import 'package:flutter/material.dart';

class CreateChannelResult {
  const CreateChannelResult({
    required this.password,
    required this.advertise,
  });

  final String? password;
  final bool advertise;
}

Future<CreateChannelResult?> showCreateChannelDialog(BuildContext context) {
  final formKey = GlobalKey<FormState>();
  final controller = TextEditingController();
  var advertise = true;

  return showDialog<CreateChannelResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Kanal erstellen'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: 'Passwort (optional)',
                    ),
                    maxLength: 32,
                    obscureText: true,
                    validator: (value) {
                      if (value != null &&
                          value.isNotEmpty &&
                          value.length < 8) {
                        return 'Mindestens 8 Zeichen';
                      }
                      return null;
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('BLE Werbung aktiv lassen'),
                    value: advertise,
                    onChanged: (value) => setState(() => advertise = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.pop(
                      dialogContext,
                      CreateChannelResult(
                        password: controller.text.trim().isEmpty
                            ? null
                            : controller.text.trim(),
                        advertise: advertise,
                      ),
                    );
                  }
                },
                child: const Text('Starten'),
              ),
            ],
          );
        },
      );
    },
  );
}
