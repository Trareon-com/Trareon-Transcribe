import 'package:flutter/material.dart';

class SpeakerAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;

  const SpeakerAvatar({
    super.key,
    required this.name,
    required this.color,
    this.size = 28,
  });

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // The initials are a visual shorthand for the speaker name, which is
    // always rendered next to this avatar. Announcing "BS" before "Budi
    // Santoso" is noise, so the glyph is excluded and the avatar carries the
    // full name as its label instead.
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Center(
          child: Text(
            _initials,
            style: TextStyle(
              fontSize: size * 0.38,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
