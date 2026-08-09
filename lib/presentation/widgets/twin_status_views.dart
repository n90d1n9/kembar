import 'package:flutter/material.dart';

/// Small, generic, reusable state widgets — no knowledge of containers,
/// terminals, or twins. Usable anywhere an async widget needs a loading
/// or error state.
class TwinLoadingView extends StatelessWidget {
  final String message;

  const TwinLoadingView({super.key, this.message = 'Loading digital twin…'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class TwinErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const TwinErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 32, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
