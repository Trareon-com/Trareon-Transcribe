import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/diagnostics_screen.dart';
import 'package:transcribe/services/preflight_service.dart';
import 'package:transcribe/src/rust/doctor.dart';
import 'package:transcribe/theme/app_theme.dart';
import 'package:transcribe/widgets/setup_overlay.dart';
import 'package:transcribe/theme/app_icons.dart';

Check ok(String name) => Check(name: name, status: const CheckStatus.ok());

Check warn(String name, String message) =>
    Check(name: name, status: CheckStatus.warn(message));

Check fail(String name, String message, String fix) =>
    Check(name: name, status: CheckStatus.fail(message), remediation: fix);

Widget host(Widget child) => MaterialApp(theme: AppTheme.light(), home: child);

void main() {
  group('DiagnosticsScreen', () {
    testWidgets('shows a marker, an Indonesian title and the remediation',
        (tester) async {
      await tester.pumpWidget(host(DiagnosticsScreen(
        runChecks: () async => PreflightResult([
          ok('library_path'),
          warn('model', 'model "base" tidak ditemukan di /x'),
          fail('audio_input', 'Tidak ada perangkat masukan audio.',
              'Colokkan mikrofon.'),
        ]),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Folder penyimpanan'), findsOneWidget);
      expect(find.text('Model transkripsi'), findsOneWidget);
      expect(find.text('Perangkat mikrofon'), findsOneWidget);
      expect(find.text('✓'), findsOneWidget);
      expect(find.text('!'), findsOneWidget);
      expect(find.text('✗'), findsOneWidget);
      expect(find.text('Colokkan mikrofon.'), findsOneWidget);
      expect(find.textContaining('perlu diperbaiki'), findsOneWidget);
    });

    testWidgets('an all-clear run says so', (tester) async {
      await tester.pumpWidget(host(DiagnosticsScreen(
        runChecks: () async => PreflightResult([
          ok('library_path'),
          ok('model'),
          ok('config_dir'),
          ok('audio_input'),
          ok('disk_space'),
        ]),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Semua siap. Aplikasi bisa merekam.'), findsOneWidget);
      expect(find.text('✗'), findsNothing);
    });

    testWidgets('a preflight that itself throws is reported, not swallowed',
        (tester) async {
      await tester.pumpWidget(host(DiagnosticsScreen(
        runChecks: () async =>
            const PreflightResult([], error: 'library tidak termuat'),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Pemeriksaan gagal dijalankan'), findsOneWidget);
      expect(find.textContaining('library tidak termuat'), findsOneWidget);
    });

    testWidgets('re-runs on demand', (tester) async {
      var runs = 0;
      await tester.pumpWidget(host(DiagnosticsScreen(
        runChecks: () async {
          runs++;
          return PreflightResult([ok('library_path')]);
        },
      )));
      await tester.pumpAndSettle();
      expect(runs, 1);

      await tester.tap(find.text('Periksa ulang'));
      await tester.pumpAndSettle();
      expect(runs, 2);
    });
  });

  group('SetupOverlay', () {
    setUp(() => skipPreflightChecks = false);
    tearDown(() => skipPreflightChecks = true);

    testWidgets('the app is usable while the checks are still running',
        (tester) async {
      // The old overlay put a full-screen spinner in front of everything
      // until preflight finished.
      final gate = Completer<PreflightResult>();
      await tester.pumpWidget(host(SetupOverlay(
        runChecks: () => gate.future,
        child: const Scaffold(body: Text('aplikasi')),
      )));

      expect(find.text('aplikasi'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      gate.complete(PreflightResult([ok('library_path')]));
      await tester.pumpAndSettle();
      expect(find.text('aplikasi'), findsOneWidget);
    });

    testWidgets('a warning is a dismissible banner, not a wall', (tester) async {
      await tester.pumpWidget(host(SetupOverlay(
        runChecks: () async => PreflightResult([
          ok('library_path'),
          warn('model', 'model belum diunduh'),
        ]),
        child: const Scaffold(body: Text('aplikasi')),
      )));
      await tester.pumpAndSettle();

      expect(find.text('aplikasi'), findsOneWidget,
          reason: 'a warning must never hide the app');
      expect(find.textContaining('Perlu diperiksa: Model transkripsi'),
          findsOneWidget);

      await tester.tap(find.byIcon(AppIcons.close));
      await tester.pumpAndSettle();
      expect(find.textContaining('Perlu diperiksa'), findsNothing);
      expect(find.text('aplikasi'), findsOneWidget);
    });

    testWidgets('a hard failure blocks, but always offers a way past',
        (tester) async {
      var attempts = 0;
      await tester.pumpWidget(host(SetupOverlay(
        runChecks: () async {
          attempts++;
          return PreflightResult([
            fail('library_path', '/x tidak bisa ditulis', 'Periksa izinnya.'),
          ]);
        },
        child: const Scaffold(body: Text('aplikasi')),
      )));
      await tester.pumpAndSettle();

      expect(find.text('aplikasi'), findsNothing);
      expect(find.text('Trareon belum siap merekam'), findsOneWidget);
      expect(find.text('Periksa izinnya.'), findsOneWidget);

      await tester.tap(find.text('Periksa Ulang'));
      await tester.pumpAndSettle();
      expect(attempts, 2);

      await tester.tap(find.text('Lanjutkan saja'));
      await tester.pumpAndSettle();
      expect(find.text('aplikasi'), findsOneWidget,
          reason: 'a preflight that is wrong about the machine must not be '
              'able to lock the user out of their recordings');
    });

    testWidgets('an all-clear run shows nothing at all', (tester) async {
      await tester.pumpWidget(host(SetupOverlay(
        runChecks: () async => PreflightResult([ok('library_path')]),
        child: const Scaffold(body: Text('aplikasi')),
      )));
      await tester.pumpAndSettle();

      expect(find.text('aplikasi'), findsOneWidget);
      expect(find.textContaining('Perlu diperiksa'), findsNothing);
    });
  });
}
