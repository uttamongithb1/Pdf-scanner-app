import 'package:flutter/material.dart';

/// Long-press dragging complements (never replaces) accessible move commands.
class PageReorderTile extends StatelessWidget {
  const PageReorderTile({
    super.key,
    required this.id,
    required this.label,
    required this.enabled,
    required this.onMove,
    required this.child,
  });
  final String id, label;
  final bool enabled;
  final ValueChanged<String> onMove;
  final Widget child;

  @override
  Widget build(BuildContext context) => DragTarget<String>(
    onWillAcceptWithDetails: (details) => enabled && details.data != id,
    onAcceptWithDetails: (details) => onMove(details.data),
    builder: (context, candidates, rejected) => AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        border: Border.all(
          color: candidates.isEmpty
              ? Colors.transparent
              : Theme.of(context).colorScheme.primary,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LongPressDraggable<String>(
        data: id,
        maxSimultaneousDrags: enabled ? 1 : 0,
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          child: Padding(padding: const EdgeInsets.all(24), child: Text(label)),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: child),
        child: child,
      ),
    ),
  );
}
