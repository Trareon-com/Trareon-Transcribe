import '../l10n/l10n.dart';

/// Where the noise-reduction / AGC decision comes from.
///
/// The point of separating these is that a machine decision must never
/// overwrite a person's. Once the user touches either switch in
/// Pengaturan → Audio & Suara, `autoAudioTuning` flips to false and this
/// resolver stops having an opinion about those two fields.
enum TuningSource {
  /// Nobody has expressed a preference: the resolver decides.
  auto,

  /// The user moved a switch by hand; their values win outright.
  user,
}

/// What the first seconds of the active input actually measured.
///
/// [snrDb] is speech-band energy against the quiet band, in dB — the number
/// that says whether a room is clean, tolerable or noisy. [peakDbfs] is the
/// loudest sample seen, 0 dBFS being full scale; it decides whether automatic
/// gain has anything left to do.
class AudioMeasurement {
  const AudioMeasurement({required this.snrDb, required this.peakDbfs});

  final double snrDb;
  final double peakDbfs;

  /// Below this the room is noisy enough that denoising earns its risk.
  static const double noisySnrDb = 15.0;

  /// Above this the room is clean enough that denoising only costs words.
  static const double cleanSnrDb = 25.0;

  /// Automatic gain only helps when speech peaks sit well below full scale.
  static const double quietPeakDbfs = -24.0;

  /// `noisy` / `tolerable` / `clean`.
  AudioRoom room() {
    if (snrDb >= cleanSnrDb) return AudioRoom.clean;
    if (snrDb >= noisySnrDb) return AudioRoom.tolerable;
    return AudioRoom.noisy;
  }
}

enum AudioRoom { noisy, tolerable, clean }

/// The audio-tuning decision for one session, plus the one line the settings
/// panel shows so that "otomatis" is never a black box.
class QualityProfile {
  const QualityProfile({
    required this.noiseReduction,
    required this.agc,
    required this.vad,
    required this.progressive,
    required this.reason,
    required this.decidedByMeasurement,
  });

  final bool noiseReduction;
  final bool agc;
  final bool vad;
  final bool progressive;

  /// Indonesian, one line, written for the panel in §8 of the blueprint.
  final String reason;

  /// True when a real measurement drove the two audio switches.
  final bool decidedByMeasurement;
}

/// Resolves the audio tuning for a session.
///
/// Every branch is a plain decision over its arguments: no clock, no I/O, no
/// randomness — which is what makes the whole table in the blueprint testable
/// without a microphone.
///
/// Deliberately conservative when nothing was measured: denoise and AGC off.
/// The old factory default was AGC on, which on already-normalised speech only
/// lifts the noise floor and gives Whisper something to hallucinate over.
QualityProfile resolveQualityProfile({
  required AudioMeasurement? measurement,
  required bool gpuAvailable,
  required bool refineModelInstalled,
  required TuningSource tuningSource,
  bool userNoiseReduction = false,
  bool userAgc = false,
  bool userVad = true,
}) {
  // Two switches the user owns once they have touched them.
  if (tuningSource == TuningSource.user) {
    return QualityProfile(
      noiseReduction: userNoiseReduction,
      agc: userAgc,
      vad: userVad,
      progressive: refineModelInstalled,
      reason: currentL10n.qualityProfileReasonManual,
      decidedByMeasurement: false,
    );
  }

  if (measurement == null) {
    return QualityProfile(
      noiseReduction: false,
      agc: false,
      vad: userVad,
      progressive: refineModelInstalled,
      reason: currentL10n.qualityProfileReasonUnmeasured,
      decidedByMeasurement: false,
    );
  }

  final room = measurement.room();
  final wantsGain = measurement.peakDbfs < AudioMeasurement.quietPeakDbfs;

  switch (room) {
    case AudioRoom.clean:
      return QualityProfile(
        noiseReduction: false,
        agc: false,
        vad: userVad,
        progressive: refineModelInstalled,
        reason: currentL10n.qualityProfileReasonClean,
        decidedByMeasurement: true,
      );
    case AudioRoom.tolerable:
      return QualityProfile(
        noiseReduction: false,
        // Gain on a tolerable room only helps when the level is genuinely low.
        agc: wantsGain,
        vad: userVad,
        progressive: refineModelInstalled,
        reason: wantsGain
            ? currentL10n.qualityProfileReasonLightNoiseGain
            : currentL10n.qualityProfileReasonLightNoiseNoGain,
        decidedByMeasurement: true,
      );
    case AudioRoom.noisy:
      return QualityProfile(
        noiseReduction: true,
        agc: wantsGain,
        vad: userVad,
        progressive: refineModelInstalled,
        reason: currentL10n.qualityProfileReasonNoisy,
        decidedByMeasurement: true,
      );
  }
}

/// CrispASR (Qwen3-ASR) tiers have no second pass: one model, one pass, so the
/// progressive flag is meaningless for them and is forced off.
bool progressiveApplies({required bool experimentalModel}) => !experimentalModel;
