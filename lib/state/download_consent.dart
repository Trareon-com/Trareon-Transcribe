/// Consent for the first-run model download (QUALITY-PROFILE-BLUEPRINT §6,
/// issue #70).
///
/// The app counts every outbound path in the Privacy Report, so starting a
/// 700 MB download the moment onboarding opens, without saying so, broke its
/// own promise. The user now answers once, and the answer is kept.
library;

import 'dart:async';

import '../services/dart_prefs.dart';

/// What the user said to the first-run download.
enum DownloadConsent {
  /// Never asked: onboarding shows the consent dialog.
  notAsked,

  /// "Unduh sekarang": downloads may start without asking again.
  granted,

  /// "Nanti": nothing downloads until the user starts it themselves.
  postponed,
}

/// Whether a model download may start on its own right now.
///
/// [networkIsMetered] is `null` while the app has no way to tell (phase 1:
/// there is no metered-connection detection yet). Only a definite `true`
/// holds a granted download back, and only when the user ticked
/// "Tunda kalau koneksi metered" ([deferOnMetered]). Phase 2 plugs a real
/// detector into [networkIsMetered] without touching the UI.
///
/// [now] is part of the contract so that phase can add a time-based rule
/// (for example "after 22.00 only") without changing every caller; phase 1
/// does not use it.
bool shouldStartDownload({
  required DateTime now,
  required bool? networkIsMetered,
  required DownloadConsent consent,
  required bool deferOnMetered,
}) {
  if (consent != DownloadConsent.granted) return false;
  if (deferOnMetered && networkIsMetered == true) return false;
  return true;
}

/// One thing the first-run download fetches, as shown in the consent dialog.
class DownloadPlanItem {
  const DownloadPlanItem({
    required this.modelId,
    required this.label,
    required this.megabytes,
  });

  final String modelId;
  final String label;

  /// Approximate download size. The Rust catalog only knows the size of a
  /// file already on disk, so the figures for not-yet-downloaded models are
  /// the published file sizes, rounded the way onboarding has always shown
  /// them.
  final int megabytes;
}

/// The two models onboarding downloads, in order. Experimental models never
/// download on their own.
const kFirstRunDownloadPlan = [
  DownloadPlanItem(modelId: 'base', label: 'Model Cepat', megabytes: 142),
  DownloadPlanItem(
    modelId: 'large-v3-turbo-q5',
    label: 'Model Akurat',
    megabytes: 548,
  ),
];

int totalMegabytes(Iterable<DownloadPlanItem> plan) =>
    plan.fold(0, (sum, item) => sum + item.megabytes);

/// Where the answer is kept. An interface so tests do not touch the real
/// preferences file.
abstract class DownloadConsentStore {
  Future<DownloadConsent> read();
  Future<void> write(DownloadConsent consent);
}

/// Keeps the answer in [DartPrefs] next to `deferDownloads`, as a Dart-only
/// preference (blueprint §7): it says nothing about a session, so it does
/// not belong in the Rust settings file.
class DartPrefsDownloadConsentStore implements DownloadConsentStore {
  const DartPrefsDownloadConsentStore();

  static const key = 'downloadConsent';

  @override
  Future<DownloadConsent> read() async {
    await DartPrefs.instance.ensureLoaded();
    final raw = DartPrefs.instance.getString(key);
    return DownloadConsent.values.firstWhere(
      (c) => c.name == raw,
      orElse: () => DownloadConsent.notAsked,
    );
  }

  @override
  Future<void> write(DownloadConsent consent) async {
    DartPrefs.instance.setString(key, consent.name);
    await DartPrefs.instance.save();
  }
}

/// In-memory store for tests and previews.
class MemoryDownloadConsentStore implements DownloadConsentStore {
  MemoryDownloadConsentStore([this.consent = DownloadConsent.notAsked]);

  DownloadConsent consent;

  @override
  Future<DownloadConsent> read() async => consent;

  @override
  Future<void> write(DownloadConsent consent) async => this.consent = consent;
}
