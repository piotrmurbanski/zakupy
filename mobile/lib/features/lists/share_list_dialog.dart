import 'package:flutter/material.dart';

Future<String?> showShareListDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      return const _ShareListDialog();
    },
  );
}

class _ShareListDialog extends StatefulWidget {
  const _ShareListDialog();

  @override
  State<_ShareListDialog> createState() => _ShareListDialogState();
}

class _ShareListDialogState extends State<_ShareListDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(_emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share list'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _emailController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'User email',
            hintText: 'second-user@example.com',
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          validator: (value) {
            final trimmed = value?.trim() ?? '';

            if (trimmed.isEmpty) {
              return 'Email is required';
            }

            final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

            if (!emailPattern.hasMatch(trimmed)) {
              return 'Enter a valid email address';
            }

            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Share'),
        ),
      ],
    );
  }
}
