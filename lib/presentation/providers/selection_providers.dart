import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected container id, if any — plain manual `Notifier`, no
/// `@riverpod` annotation / build_runner required.
class SelectedContainerController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? containerId) => state = containerId;
}

final selectedContainerProvider = NotifierProvider<SelectedContainerController, String?>(
  SelectedContainerController.new,
);
