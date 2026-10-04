/// Motion tokens. `docs/DESIGN-SYSTEM.md` §8 is the spec, including the
/// catalogue of every animation in the app and the one-sentence justification
/// each one has to carry.
///
/// `MOTION_INTENSITY` is 3: feedback, orientation and state transition only.
/// Nothing animates longer than 240 ms except two deliberate loops (the record
/// button's breathing pulse and the skeleton shimmer), and both stop under
/// reduce motion.
library;

import 'package:flutter/material.dart';

/// Durations. Read them through [AppMotion.of] so reduce motion collapses
/// them, or use the raw constants where a `Duration` is needed at compile
/// time (a `const` widget field) and the widget handles reduce motion itself.
abstract final class Motion {
  /// 80 ms: press-down, level-meter follow.
  static const Duration instant = Duration(milliseconds: 80);

  /// 120 ms: hover, focus ring, colour change, icon swap.
  static const Duration fast = Duration(milliseconds: 120);

  /// 160 ms: toggle travel, list-item insert, partial to final text.
  static const Duration base = Duration(milliseconds: 160);

  /// 200 ms: panel, menu and toast enter, tab underline, sidebar collapse.
  static const Duration slow = Duration(milliseconds: 200);

  /// 240 ms: dialog and sheet enter, pane transition.
  static const Duration slowest = Duration(milliseconds: 240);

  /// 1600 ms: the record button's breathing pulse. The one continuous
  /// animation in the app, and it exists because "is this actually
  /// recording?" is the category's biggest complaint.
  static const Duration breathe = Duration(milliseconds: 1600);

  /// 1400 ms: skeleton shimmer sweep.
  static const Duration shimmer = Duration(milliseconds: 1400);

  /// 1200 ms: indeterminate progress sweep.
  static const Duration indeterminate = Duration(milliseconds: 1200);
}

/// AppEasing. No spring, no overshoot, no bounce: `DESIGN_VARIANCE` 3 and a tool
/// somebody keeps open for three hours.
abstract final class AppEasing {
  /// Default. Anything moving between two states.
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// Entering: menus, toasts, dialogs.
  static const Curve decelerate = Cubic(0.05, 0.7, 0.1, 1);

  /// Exiting.
  static const Curve accelerate = Cubic(0.3, 0, 1, 1);

  /// Sidebar collapse, pane transition. Same cubic as [standard] at a longer
  /// duration, which is what makes a large displacement read as deliberate
  /// rather than slow.
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);
}

/// Motion settings for the current build context, with reduce motion already
/// applied.
///
/// Flutter maps the platform "reduce motion" accessibility setting to
/// [MediaQueryData.disableAnimations]. Read it once at the top of a widget's
/// `build` and pass the durations down; never check the raw flag at twenty
/// call sites.
@immutable
class AppMotion {
  const AppMotion({required this.reduced});

  /// True when the user has asked the system for reduced motion.
  final bool reduced;

  static AppMotion of(BuildContext context) =>
      AppMotion(reduced: MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  /// A duration, collapsed to zero under reduce motion.
  Duration d(Duration value) => reduced ? Duration.zero : value;

  Duration get instant => d(Motion.instant);
  Duration get fast => d(Motion.fast);
  Duration get base => d(Motion.base);
  Duration get slow => d(Motion.slow);
  Duration get slowest => d(Motion.slowest);

  /// Whether a continuous loop (the record pulse, the skeleton shimmer) may
  /// run at all. Under reduce motion these do not slow down, they stop and
  /// hold a static frame.
  bool get allowLoops => !reduced;

  /// An offset to translate a list item in from, zeroed under reduce motion.
  Offset slideFrom(double dy) => reduced ? Offset.zero : Offset(0, dy);

  /// A scale to press a control down to, neutral under reduce motion.
  double get pressScale => reduced ? 1.0 : 0.98;

  @override
  bool operator ==(Object other) =>
      other is AppMotion && other.reduced == reduced;

  @override
  int get hashCode => reduced.hashCode;
}

/// How far a list item rises as it enters, and the cutoff past which the
/// animation is skipped entirely.
abstract final class ListMotion {
  /// Vertical travel of a newly inserted transcript segment.
  static const double insertRise = 6;

  /// Past this many rows the insert animation is dropped. A three-hour
  /// meeting produces thousands of segments and the Sprint 2 perf tests hold
  /// the list to 60 fps at 5,000; an entry animation per row would not.
  static const int animateBelowCount = 200;
}
