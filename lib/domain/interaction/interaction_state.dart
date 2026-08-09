class InteractionState {
  final String? hoveredEntityId;

  final String? selectedEntityId;

  final String? focusedEntityId;

  const InteractionState({
    this.hoveredEntityId,
    this.selectedEntityId,
    this.focusedEntityId,
  });

  InteractionState copyWith({
    String? hoveredEntityId,
    String? selectedEntityId,
    String? focusedEntityId,
    bool clearHovered = false,
    bool clearSelected = false,
    bool clearFocused = false,
  }) {
    return InteractionState(
      hoveredEntityId:
          clearHovered
              ? null
              : hoveredEntityId ?? this.hoveredEntityId,

      selectedEntityId:
          clearSelected
              ? null
              : selectedEntityId ?? this.selectedEntityId,

      focusedEntityId:
          clearFocused
              ? null
              : focusedEntityId ?? this.focusedEntityId,
    );
  }
}
