import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/src/rust/session.dart' as rust_session;
import 'package:transcribe/theme/app_theme.dart';
import 'package:transcribe/widgets/capture_health_view.dart';

rust_session.ChannelCapture channel({
  required String source,
  bool expected = true,
  bool confirmed = true,
  double secondsCaptured = 300,
  double secondsVoiced = 200,
  double percentSilent = 33,
  double silentForSecs = 0,
  bool writingToDisk = true,
}) {
  return rust_session.ChannelCapture(
    source: source,
    expected: expected,
    confirmed: confirmed,
    secondsCaptured: secondsCaptured,
    secondsVoiced: secondsVoiced,
    percentSilent: percentSilent,
    silentForSecs: silentForSecs,
    writingToDisk: writingToDisk,
  );
}

rust_session.CaptureHealth health({
  required List<rust_session.ChannelCapture> channels,
  List<String> warnings = const [],
  double elapsedSecs = 300,
  int segmentCount = 12,
}) {
  return rust_session.CaptureHealth(
    sessionId: 's',
    elapsedSecs: elapsedSecs,
    segmentCount: segmentCount,
    channels: channels,
    warnings: warnings,
  );
}

Future<void> pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('allExpectedConfirmed', () {
    test('needs every expected source, not just one', () {
      expect(
        allExpectedConfirmed(
          health(
            channels: [
              channel(source: 'mic'),
              channel(source: 'spk', confirmed: false),
            ],
          ),
        ),
        isFalse,
      );
      expect(
        allExpectedConfirmed(
          health(
            channels: [channel(source: 'mic'), channel(source: 'spk')],
          ),
        ),
        isTrue,
      );
    });

    test('a source nobody asked for cannot block confirmation', () {
      expect(
        allExpectedConfirmed(
          health(
            channels: [
              channel(source: 'mic'),
              channel(source: 'spk', expected: false, confirmed: false),
            ],
          ),
        ),
        isTrue,
      );
    });

    test('no expected source at all is not "confirmed"', () {
      expect(allExpectedConfirmed(health(channels: const [])), isFalse);
    });
  });

  group('CaptureConfirmationBadge', () {
    testWidgets('waits for real sound before claiming confirmation', (
      tester,
    ) async {
      await pump(
        tester,
        CaptureConfirmationBadge(
          health: health(channels: [channel(source: 'mic', confirmed: false)]),
        ),
      );
      // An open stream is not a recording — this is the distinction the
      // VU meter cannot make.
      expect(find.textContaining('Menunggu suara dari Mikrofon'), findsOneWidget);
      expect(find.text('Rekaman terkonfirmasi'), findsNothing);
    });

    testWidgets('confirms once every expected source has delivered', (
      tester,
    ) async {
      await pump(
        tester,
        CaptureConfirmationBadge(
          health: health(
            channels: [channel(source: 'mic'), channel(source: 'spk')],
          ),
        ),
      );
      expect(find.text('Rekaman terkonfirmasi'), findsOneWidget);
    });

    testWidgets('warns when a confirmed source has gone quiet', (tester) async {
      await pump(
        tester,
        CaptureConfirmationBadge(
          health: health(
            channels: [
              channel(source: 'mic', silentForSecs: 120),
              channel(source: 'spk'),
            ],
          ),
        ),
      );
      expect(find.text('Mikrofon senyap'), findsOneWidget);
    });

    testWidgets('renders nothing before a session exists', (tester) async {
      await pump(tester, const CaptureConfirmationBadge(health: null));
      expect(find.byType(Row), findsNothing);
    });
  });

  group('CaptureIntegritySummary', () {
    testWidgets('states duration, segments and per-channel silence', (
      tester,
    ) async {
      await pump(
        tester,
        CaptureIntegritySummary(
          health: health(
            elapsedSecs: 5400,
            segmentCount: 87,
            channels: [channel(source: 'mic', percentSilent: 40)],
          ),
        ),
      );
      expect(
        find.text('Durasi 1 jam 30 menit · 87 segmen transkrip'),
        findsOneWidget,
      );
      expect(find.textContaining('Mikrofon: 5 menit terekam, 40% senyap'),
          findsOneWidget);
    });

    testWidgets('says plainly when a channel delivered nothing', (tester) async {
      await pump(
        tester,
        CaptureIntegritySummary(
          health: health(
            channels: [
              channel(
                source: 'spk',
                confirmed: false,
                secondsCaptured: 5400,
                percentSilent: 100,
              ),
            ],
            warnings: const ['Audio sistem tidak menghasilkan suara sama sekali.'],
          ),
        ),
      );
      expect(
        find.textContaining('Audio sistem: tidak ada suara sama sekali'),
        findsOneWidget,
      );
      expect(
        find.text('Audio sistem tidak menghasilkan suara sama sekali.'),
        findsOneWidget,
      );
    });

    testWidgets('omits channels the user never asked for', (tester) async {
      await pump(
        tester,
        CaptureIntegritySummary(
          health: health(
            channels: [
              channel(source: 'mic'),
              channel(source: 'spk', expected: false),
            ],
          ),
        ),
      );
      expect(find.textContaining('Mikrofon:'), findsOneWidget);
      expect(find.textContaining('Audio sistem:'), findsNothing);
    });
  });
}
