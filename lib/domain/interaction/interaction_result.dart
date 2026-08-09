enum InteractionResultStatus {
  accepted,
  rejected,
  ignored,
}

class InteractionResult {
  final InteractionResultStatus status;

  final String? reason;

  const InteractionResult({
    required this.status,
    this.reason,
  });

  const InteractionResult.accepted()
      : status = InteractionResultStatus.accepted,
        reason = null;

  const InteractionResult.rejected(String reason)
      : status = InteractionResultStatus.rejected,
        reason = reason;

  const InteractionResult.ignored()
      : status = InteractionResultStatus.ignored,
        reason = null;
}
