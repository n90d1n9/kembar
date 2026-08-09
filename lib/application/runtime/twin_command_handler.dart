import '../../domain/core/twin_command.dart';

abstract class TwinCommandHandler {
  bool supports(TwinCommand command);

  Future<void> handle(
    TwinCommand command,
  );
}
