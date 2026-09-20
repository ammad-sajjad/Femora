import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Hidden demo setting (long-press the header): where the Femora server runs.
Future<void> showServerAddressDialog(BuildContext context) {
  final controller = TextEditingController(text: ApiService.baseUrl);
  final messenger = ScaffoldMessenger.maybeOf(context);
  String? error;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Server address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Where the Femora server runs, e.g. https://your-tunnel.trycloudflare.com'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(border: const OutlineInputBorder(), hintText: 'https://…', errorText: error),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ApiService.setServerOverride(null);
              if (ctx.mounted) Navigator.pop(ctx);
              messenger?.showSnackBar(SnackBar(content: Text('Using the default server: ${ApiService.baseUrl}')));
            },
            child: const Text('Reset'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!await ApiService.setServerOverride(controller.text)) {
                setState(() => error = 'Enter an address starting with http:// or https://');
                return;
              }
              if (ctx.mounted) Navigator.pop(ctx);
              messenger?.showSnackBar(SnackBar(content: Text('Server set to ${ApiService.baseUrl}')));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
