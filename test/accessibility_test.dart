import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/settings_screen.dart';
import 'package:transcribe/screens/transcript_player_screen.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/theme/app_theme.dart';
import 'package:transcribe/theme/app_tokens.dart';
import 'package:transcribe/widgets/bookmark_bar.dart';
import 'package:transcribe/widgets/setup_overlay.dart';
import 'package:transcribe/widgets/transcript_view.dart';

import 'test_helpers.dart';

/// Audit item 25: the app had essentially no screen-reader support outside the
/// upload zone, which is a procurement blocker in the public sector this
/// product is aimed at.
///
/// Three things are checked here: every icon-only button has a tooltip (which
/// is also its screen-reader label), the live transcript announces itself, and
/// interactive targets are big enough. Text scaling has its own file.
void main() {
  group('icon-only buttons are labelled', () {
    test(
      'every IconButton in lib/ has a tooltip, or sits inside a Tooltip',
      () {
        final offenders = <String>[];
        for (final file in _uiSources()) {
          final source = file.readAsStringSync();
          // Matches Material's `IconButton(` and the kit's own
          // `AppIconButton(`. The kit declares `tooltip` as a required
          // parameter, so its call sites are compiler-enforced, but scanning
          // them anyway means the rule survives someone making it optional.
          for (final match in RegExp(
            r'(?<![A-Za-z])(?:App)?IconButton\(',
          ).allMatches(source)) {
            final block = _balancedCall(source, match.start);
            if (block == null) continue;
            if (block.contains('tooltip:')) continue;
            // The kit's own constructor declaration, not a call site.
            if (block.contains('required this.tooltip')) continue;
            // `Tooltip(message: …, child: IconButton(…))` is equally good —
            // and sometimes necessary, because a disabled IconButton swallows
            // its own tooltip.
            final before = source.substring(
              (match.start - 220).clamp(0, source.length),
              match.start,
            );
            if (before.contains('Tooltip(')) continue;
            final line = source.substring(0, match.start).split('\n').length;
            offenders.add('${_relative(file)}:$line');
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'An icon with no tooltip is unreadable to a screen reader and '
              'a guess for everyone else:\n  ${offenders.join('\n  ')}',
        );
      },
    );

    test('the scan would actually catch an untooltipped button', () {
      const sample = 'IconButton(icon: Icon(AppIcons.close), onPressed: x)';
      final block = _balancedCall(sample, 0);
      expect(block, isNotNull);
      expect(block!.contains('tooltip:'), isFalse);
    });
  });

  group('live transcript announces itself', () {
    TranscriptSegment segment(String text, double at) => TranscriptSegment(
      source: 'mic',
      speaker: 'Pembicara 1',
      text: text,
      timestamp: at,
      duration: 2,
      language: 'id',
      confidence: 0.9,
      isPartial: false,
    );

    testWidgets('a new segment produces one live region, not one per row', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final segments = [segment('baris pertama', 0)];

      Widget host(List<TranscriptSegment> rows, int revision) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TranscriptView(segments: rows, revision: revision),
        ),
      );

      await tester.pumpWidget(host(segments, 0));
      // Nothing has "arrived" yet from the widget's point of view.
      expect(tester.takeAnnouncements(), isEmpty);

      segments.add(segment('baris kedua', 2));
      await tester.pumpWidget(host(segments, 1));
      await tester.pump();

      final announcements = tester.takeAnnouncements();
      expect(announcements.length, 1);
      expect(announcements.single.message, contains('baris kedua'));

      // The segment counter is itself a live region, so a reader re-reads it
      // without being asked.
      expect(_liveRegions(tester), contains('2 segmen'));

      handle.dispose();
    });

    testWidgets('a burst is summarised rather than read line by line', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final segments = [segment('satu', 0)];

      Widget host(int revision) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TranscriptView(segments: segments, revision: revision),
        ),
      );

      await tester.pumpWidget(host(0));
      // Three segments inside one throttle window.
      segments.add(segment('dua', 2));
      await tester.pumpWidget(host(1));
      segments.add(segment('tiga', 4));
      await tester.pumpWidget(host(2));
      segments.add(segment('empat', 6));
      await tester.pumpWidget(host(3));
      await tester.pump();

      // The first batch is announced immediately …
      final immediate = tester.takeAnnouncements();
      expect(immediate.length, 1);
      expect(immediate.single.message, contains('dua'));

      // … and the two that followed inside the throttle window are
      // summarised into exactly one more announcement, not read line by line.
      await tester.pump(TranscriptView.kAnnounceThrottle);
      final summarised = tester.takeAnnouncements();
      expect(summarised.length, 1);
      expect(summarised.single.message, contains('baris baru'));
      expect(summarised.single.message, contains('empat'));

      handle.dispose();
    });

    testWidgets('the player does not announce anything unprompted', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final segments = [segment('satu', 0)];
      final active = ValueNotifier<int?>(0);
      addTearDown(active.dispose);

      Widget host(int revision) => MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TranscriptView(
            segments: segments,
            revision: revision,
            activeSegmentIndex: active,
          ),
        ),
      );

      await tester.pumpWidget(host(0));
      segments.add(segment('dua', 2));
      await tester.pumpWidget(host(1));
      await tester.pump(TranscriptView.kAnnounceThrottle);

      expect(
        tester.takeAnnouncements(),
        isEmpty,
        reason:
            'in the player the user is navigating; an unprompted '
            'announcement fights with them',
      );

      handle.dispose();
    });
  });

  group('touch targets', () {
    // `TouchTarget.minimum` claims "every icon-only button in the app is
    // wrapped to at least this". That is a claim about rendered geometry, so
    // it is checked against rendered geometry on the screens the user spends
    // their time on, rather than left as a comment.
    testWidgets('every icon button on the main surfaces is at least 48 px', (
      tester,
    ) async {
      final undersized = <String>[];

      Future<void> check(String where, Widget screen) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [rustBridgeProvider.overrideWithValue(NoopBridge())],
            child: MaterialApp(theme: AppTheme.light(), home: screen),
          ),
        );
        await tester.pumpAndSettle();
        for (final element in find.byType(IconButton).evaluate()) {
          final size = element.renderObject! as RenderBox;
          if (size.size.shortestSide + 0.01 < TouchTarget.minimum) {
            final icon = element.widget as IconButton;
            undersized.add(
              '$where: ${icon.tooltip ?? icon.icon} is '
              '${size.size.width}x${size.size.height}',
            );
          }
        }
      }

      skipPreflightChecks = true;
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await check('settings', const SettingsScreen());
      await check(
        'player',
        const TranscriptPlayerScreen(
          title: 'Rapat',
          durationSeconds: 600,
          segments: [
            TranscriptSegment(
              source: 'mic',
              speaker: 'Pembicara 1',
              text: 'halo',
              timestamp: 0,
              duration: 2,
              language: 'id',
              confidence: 0.9,
              isPartial: false,
            ),
          ],
        ),
      );
      await check(
        'bookmarks',
        Scaffold(
          body: BookmarkBar(
            bookmarks: const [Bookmark(timestamp: 65, note: 'keputusan')],
            live: true,
            onAdd: () {},
            onAddWithNote: () {},
            onRemove: (_) {},
            onEditNote: (_) {},
          ),
        ),
      );

      expect(
        undersized,
        isEmpty,
        reason:
            'a target under 48 px fails WCAG 2.2 AA 2.5.8 and is a miss '
            'for anyone without a steady hand:\n  ${undersized.join('\n  ')}',
      );
    });

    testWidgets('bookmark jump-list rows meet the 48 px minimum height', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BookmarkJumpList(
              bookmarks: const [
                Bookmark(timestamp: 65, note: 'keputusan'),
                Bookmark(timestamp: 312, note: ''),
              ],
              onJump: (_) {},
              onRemove: (_) {},
              onEditNote: (_) {},
            ),
          ),
        ),
      );

      final chips = find.byType(InputChip);
      expect(chips, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final size = tester.getSize(chips.at(i));
        expect(
          size.height,
          greaterThanOrEqualTo(TouchTarget.minimum),
          reason: 'row $i is ${size.height} px tall',
        );
      }
    });

    testWidgets('the "Tandai" control is reachable and labelled', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: BookmarkBar(
              bookmarks: const [],
              live: true,
              onAdd: () {},
              onAddWithNote: () {},
              onRemove: (_) {},
              onEditNote: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Tandai'), findsOneWidget);
      expect(
        find.byTooltip('Tandai poin penting di posisi sekarang (Ctrl+B)'),
        findsOneWidget,
      );
      expect(find.byTooltip('Tandai dan tulis catatan'), findsOneWidget);
    });
  });
}

/// Labels of every live region currently in the semantics tree.
List<String> _liveRegions(WidgetTester tester) {
  final found = <String>[];
  void visit(SemanticsNode node) {
    if (node.flagsCollection.isLiveRegion && node.label.trim().isNotEmpty) {
      found.add(node.label);
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  final root = tester.binding.rootElement!.renderObject!.debugSemantics;
  if (root != null) visit(root);
  return found;
}

/// Source text of a balanced `Name(...)` call starting at [start].
String? _balancedCall(String source, int start) {
  final open = source.indexOf('(', start);
  if (open < 0) return null;
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (char == '(') depth++;
    if (char == ')') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }
  return null;
}

Iterable<File> _uiSources() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !_relative(f).startsWith('lib/src/rust/'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

String _relative(File file) => file.path.replaceAll(r'\', '/');
