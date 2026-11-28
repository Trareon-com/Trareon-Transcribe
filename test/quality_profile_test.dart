import 'package:flutter_test/flutter_test.dart';

import 'package:transcribe/state/quality_profile.dart';

/// The resolver decides two switches that can make a transcript *worse* if
/// they are wrong, so the boundaries are pinned here rather than discovered
/// later in a complaint about dropped words.
void main() {
  QualityProfile resolve({
    AudioMeasurement? measurement,
    bool gpuAvailable = true,
    bool refineInstalled = true,
    TuningSource source = TuningSource.auto,
    bool userNr = false,
    bool userAgc = false,
    bool userVad = true,
  }) => resolveQualityProfile(
    measurement: measurement,
    gpuAvailable: gpuAvailable,
    refineModelInstalled: refineInstalled,
    tuningSource: source,
    userNoiseReduction: userNr,
    userAgc: userAgc,
    userVad: userVad,
  );

  group('room classification', () {
    test('14.9 dB is noisy, 15.0 is tolerable', () {
      expect(
        const AudioMeasurement(snrDb: 14.9, peakDbfs: -12).room(),
        AudioRoom.noisy,
      );
      expect(
        const AudioMeasurement(snrDb: 15.0, peakDbfs: -12).room(),
        AudioRoom.tolerable,
      );
    });

    test('24.9 dB is tolerable, 25.0 is clean', () {
      expect(
        const AudioMeasurement(snrDb: 24.9, peakDbfs: -12).room(),
        AudioRoom.tolerable,
      );
      expect(
        const AudioMeasurement(snrDb: 25.0, peakDbfs: -12).room(),
        AudioRoom.clean,
      );
    });
  });

  group('unmeasured', () {
    test('denoise and AGC stay off, and the reason says so', () {
      final p = resolve();
      expect(p.noiseReduction, isFalse);
      expect(p.agc, isFalse);
      expect(p.decidedByMeasurement, isFalse);
      expect(p.reason, contains('Belum terukur'));
    });

    test('progressive follows what is actually installed', () {
      expect(resolve(refineInstalled: false).progressive, isFalse);
      expect(resolve(refineInstalled: true).progressive, isTrue);
    });
  });

  group('clean room', () {
    test('both switches stay off — denoising clean speech costs words', () {
      final p = resolve(
        measurement: const AudioMeasurement(snrDb: 31, peakDbfs: -30),
      );
      expect(p.noiseReduction, isFalse);
      expect(p.agc, isFalse);
      expect(p.decidedByMeasurement, isTrue);
      expect(p.reason, contains('Ruangan bersih'));
    });
  });

  group('tolerable room', () {
    test('gain is used only when the level is genuinely low', () {
      final quiet = resolve(
        measurement: const AudioMeasurement(snrDb: 20, peakDbfs: -30),
      );
      expect(quiet.agc, isTrue);
      expect(quiet.noiseReduction, isFalse);

      final loud = resolve(
        measurement: const AudioMeasurement(snrDb: 20, peakDbfs: -6),
      );
      expect(loud.agc, isFalse);
      expect(loud.noiseReduction, isFalse);
    });

    test('the peak threshold itself: -24 is the boundary', () {
      expect(
        resolve(measurement: const AudioMeasurement(snrDb: 20, peakDbfs: -23.9))
            .agc,
        isFalse,
      );
      expect(
        resolve(measurement: const AudioMeasurement(snrDb: 20, peakDbfs: -24.1))
            .agc,
        isTrue,
      );
    });
  });

  group('noisy room', () {
    test(
      'denoising stays off (measured to cost words), gain follows the level',
      () {
        final p = resolve(
          measurement: const AudioMeasurement(snrDb: 8, peakDbfs: -12),
        );
        expect(p.noiseReduction, isFalse);
        expect(p.agc, isFalse);
        expect(p.reason, contains('Derau tinggi'));
        expect(p.decidedByMeasurement, isTrue);
      },
    );

    test('no measured room ever turns denoising on by itself', () {
      for (final snr in [-5.0, 0.0, 5.0, 14.9, 15.0, 24.9, 25.0, 60.0]) {
        for (final peak in [-60.0, -30.0, -12.0]) {
          final p = resolve(
            measurement: AudioMeasurement(snrDb: snr, peakDbfs: peak),
          );
          expect(p.noiseReduction, isFalse, reason: 'snr=$snr peak=$peak');
        }
      }
    });

    test('a quiet noisy room still gets gain', () {
      final p = resolve(
        measurement: const AudioMeasurement(snrDb: 8, peakDbfs: -40),
      );
      expect(p.noiseReduction, isFalse);
      expect(p.agc, isTrue);
    });
  });

  group('user override wins', () {
    test('a manual choice survives every room classification', () {
      for (final snr in [5.0, 20.0, 40.0]) {
        final p = resolve(
          measurement: AudioMeasurement(snrDb: snr, peakDbfs: -30),
          source: TuningSource.user,
          userNr: true,
          userAgc: false,
        );
        expect(p.noiseReduction, isTrue, reason: 'snr=$snr');
        expect(p.agc, isFalse, reason: 'snr=$snr');
        expect(p.reason, 'Dipilih manual');
        expect(p.decidedByMeasurement, isFalse);
      }
    });

    test('a manual choice survives a missing measurement too', () {
      final p = resolve(
        source: TuningSource.user,
        userNr: false,
        userAgc: true,
      );
      expect(p.agc, isTrue);
      expect(p.noiseReduction, isFalse);
    });

    test('turning VAD off by hand is respected', () {
      final p = resolve(
        measurement: const AudioMeasurement(snrDb: 30, peakDbfs: -10),
        source: TuningSource.user,
        userVad: false,
      );
      expect(p.vad, isFalse);
    });
  });

  group('progressive applicability', () {
    test('CrispASR tiers never get a second pass', () {
      expect(progressiveApplies(experimentalModel: true), isFalse);
      expect(progressiveApplies(experimentalModel: false), isTrue);
    });

    test('nothing installed means nothing to refine with', () {
      expect(
        resolve(refineInstalled: false, gpuAvailable: false).progressive,
        isFalse,
      );
    });
  });
}
