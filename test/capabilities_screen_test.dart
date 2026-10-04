/// "Apa jalan di mana" (F14), Flutter side.
///
/// The rows come from Rust, where they are checked against the source.
/// What is only checkable here is the presentation, and the thing that
/// would actually mislead a user: painting a networked-but-off feature
/// as if it were running, or describing an endpoint feature as local.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe/screens/capabilities_screen.dart';
import 'package:transcribe/src/rust/capabilities.dart' as rust;
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';

import 'test_helpers.dart';

const _rows = [
  rust.Capability(
    id: 'transcribe',
    name: 'Transkripsi (Whisper)',
    detail: 'Mengubah suara menjadi teks di komputer ini.',
    runsAt: rust.RunsAt.local,
    whereLabel: 'Lokal (di komputer ini)',
    enabled: true,
    disabledReason: '',
    module: 'stt/mod.rs',
  ),
  rust.Capability(
    id: 'summary',
    name: 'Ringkasan AI',
    detail: 'Mengirim teks transkrip ke endpoint yang Anda atur.',
    runsAt: rust.RunsAt.summaryEndpoint,
    whereLabel: 'Endpoint ringkasan: http://127.0.0.1:11434',
    enabled: false,
    disabledReason: 'Ringkasan AI dimatikan di Pengaturan.',
    module: 'summary.rs',
  ),
  rust.Capability(
    id: 'model_download',
    name: 'Unduh model Whisper',
    detail: 'Hanya saat Anda menekan tombol unduh.',
    runsAt: rust.RunsAt.internet,
    whereLabel: 'huggingface.co',
    enabled: true,
    disabledReason: '',
    module: 'model.rs',
  ),
];

class _CapabilityBridge extends NoopBridge {
  _CapabilityBridge({this.rows = _rows, this.fail = false});

  final List<rust.Capability> rows;
  final bool fail;
  int calls = 0;

  @override
  Future<List<rust.Capability>> describeCapabilities(
    AppSettings settings,
  ) async {
    calls++;
    if (fail) throw StateError('daftar tidak terbaca');
    return rows;
  }
}

Widget _app(_CapabilityBridge bridge) => buildTestAppWithOverrides(
  overrides: [rustBridgeProvider.overrideWithValue(bridge)],
  child: const CapabilitiesScreen(),
);

void main() {
  testWidgets('lists every capability with where it runs', (tester) async {
    final bridge = _CapabilityBridge();
    await tester.pumpWidget(_app(bridge));
    await tester.pumpAndSettle();

    expect(bridge.calls, 1);
    expect(find.text('Transkripsi (Whisper)'), findsOneWidget);
    expect(find.text('Ringkasan AI'), findsOneWidget);
    expect(find.text('Unduh model Whisper'), findsOneWidget);
    expect(find.text('Lokal (di komputer ini)'), findsOneWidget);
    expect(
      find.text('Endpoint ringkasan: http://127.0.0.1:11434'),
      findsOneWidget,
    );
    expect(find.text('huggingface.co'), findsOneWidget);
  });

  testWidgets('a networked feature that is off says so, and says why', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_CapabilityBridge()));
    await tester.pumpAndSettle();

    // Two enabled rows, one not.
    expect(find.text('Tidak aktif'), findsOneWidget);
    expect(find.text('Aktif'), findsNWidgets(2));
    expect(find.text('Ringkasan AI dimatikan di Pengaturan.'), findsOneWidget);
  });

  testWidgets('the summary counts local against networked honestly', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_CapabilityBridge()));
    await tester.pumpAndSettle();

    // One local of three; two networked, one of them active.
    expect(
      find.textContaining('1 dari 3 kemampuan berjalan sepenuhnya'),
      findsOneWidget,
    );
    expect(
      find.textContaining('2 kemampuan bisa memakai jaringan; 1 di antaranya'),
      findsOneWidget,
    );
  });

  testWidgets('each row names the module, so the claim can be checked', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_CapabilityBridge()));
    await tester.pumpAndSettle();
    expect(find.text('Kode: rust_core/src/stt/mod.rs'), findsOneWidget);
    expect(find.text('Kode: rust_core/src/summary.rs'), findsOneWidget);
  });

  testWidgets('a library with nothing networked says that plainly', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_CapabilityBridge(rows: [_rows.first])));
    await tester.pumpAndSettle();
    expect(
      find.text('Tidak ada kemampuan yang memakai jaringan.'),
      findsOneWidget,
    );
  });

  testWidgets('a failure to read the list is shown, not an empty table', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_CapabilityBridge(fail: true)));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Daftar kemampuan tidak bisa dibaca'),
      findsOneWidget,
    );
  });

  test('every RunsAt value has an Indonesian label', () {
    for (final runsAt in rust.RunsAt.values) {
      expect(runsAtLabel(runsAt), isNotEmpty);
    }
    expect(
      rust.RunsAt.values.map(runsAtLabel).toSet(),
      hasLength(rust.RunsAt.values.length),
      reason: 'two destinations must not render as the same word',
    );
  });
}
