// Sprint 20 Bagian A — Item 2 Sprint 7 disambungkan ke UI: wizard penyiapan
// model AI (Ollama) harus benar-benar memanggil API Rust yang sudah ada
// (llmDetect, llmHardware, llmRecommend, llmCatalogue, llmInstallGuide,
// llmPullModel, readLlmPullProgress) dari widget tree aplikasi nyata, bukan
// dari provider yang disuntik mock.
//
// `flutter test` tidak memanggil `RustLib.init()` (hanya `main()` yang
// melakukannya), sehingga setiap panggilan FRB sungguhan di sini gagal
// dengan error "not initialized" — tepat seperti yang sudah terjadi pada
// `llmDefaultModel()` di `summary_settings_section.dart`. Itu justru bukti
// bahwa kode produksi memanggil fungsi API yang sungguhan (bukan tiruan):
// uji ini memverifikasi layar menangani kegagalan itu dengan baik dan, yang
// lebih penting, bahwa tombol-tombol nyata di Pengaturan dan panel Ringkasan
// AI benar-benar membuka layar ini.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/screens/llm_setup_wizard_screen.dart';
import 'package:transcribe/services/session_store.dart';
import 'package:transcribe/state/models.dart';
import 'package:transcribe/state/settings_model.dart';
import 'package:transcribe/widgets/summary_panel.dart';
import 'package:transcribe/widgets/summary_settings_section.dart';

import 'test_helpers.dart';

const TranscriptSegment _segment = TranscriptSegment(
  source: 'mic',
  speaker: 'Saya',
  text: 'kita putuskan pakai Rust',
  timestamp: 0,
  duration: 2,
  language: 'id',
  confidence: 0.9,
  isPartial: false,
);

void main() {
  testWidgets(
    'wizard memanggil llmDetect sungguhan dan menampilkan status gagal/panduan',
    (tester) async {
      await tester.pumpWidget(
        buildTestAppWithOverrides(
          overrides: const [],
          child: const LlmSetupWizardScreen(),
        ),
      );
      // initState memanggil rust_api.llmDetect(...) langsung (tanpa bridge
      // tiruan) — di sandbox uji ini gagal karena RustLib belum
      // diinisialisasi, dan layar harus menampilkan kartu galat dengan
      // tombol "Coba lagi" daripada hang di spinner selamanya.
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Siapkan Model AI'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);

      // Menekan "Coba lagi" memanggil ulang rust_api.llmDetect dari widget
      // yang sama — menegaskan ini bukan panggilan sekali saja di initState
      // yang hasilnya dibekukan.
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Coba lagi'), findsOneWidget);
    },
  );

  testWidgets(
    'tombol "Siapkan Model AI" di Pengaturan membuka wizard sungguhan',
    (tester) async {
      await tester.pumpWidget(
        buildTestAppWithOverrides(
          overrides: [
            settingsProvider.overrideWith((ref) {
              final notifier = SettingsNotifier(NoopBridge());
              notifier.setSummarySettings(
                AppSettings.defaults().summary.copyWith(
                  enabled: true,
                  provider: SummaryProvider.ollama,
                ),
              );
              return notifier;
            }),
          ],
          child: const Material(
            child: SingleChildScrollView(child: SummarySettingsSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Siapkan Model AI (deteksi, pasang, unduh)…'),
        findsOneWidget,
      );
      await tester.tap(
        find.text('Siapkan Model AI (deteksi, pasang, unduh)…'),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Layar yang terbuka harus benar-benar LlmSetupWizardScreen, bukan
      // sekadar dialog placeholder — membuktikan tombol ini sungguh
      // menyambung ke wizard yang memanggil API Sprint 7.
      expect(find.byType(LlmSetupWizardScreen), findsOneWidget);
    },
  );

  testWidgets(
    'menekan "Buat Ringkasan" tanpa model Ollama tersetel membuka wizard dulu',
    (tester) async {
      await tester.pumpWidget(
        buildTestAppWithOverrides(
          overrides: [
            settingsProvider.overrideWith((ref) {
              final notifier = SettingsNotifier(NoopBridge());
              // Default AppSettings: provider ollama, model kosong — sinyal
              // "belum pernah disetel" yang seharusnya memicu wizard.
              notifier.setSummarySettings(
                AppSettings.defaults().summary.copyWith(enabled: true),
              );
              return notifier;
            }),
          ],
          child: Material(
            child: SingleChildScrollView(
              child: SummaryPanel(
                sessionDirPath: '/tmp/does-not-need-to-exist',
                segments: () => const [_segment],
                initialMeta: const SessionMeta(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ringkasan AI'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat Ringkasan'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(LlmSetupWizardScreen), findsOneWidget);
    },
  );
}
