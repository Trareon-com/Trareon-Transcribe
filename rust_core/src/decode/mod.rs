//! Pure-Rust audio decode (Symphonia) — no ffmpeg, no external binaries.
//! Decodes WAV/MP3/M4A/AAC/OGG/FLAC/Opus (and audio streams inside MP4/MKV)
//! into 16kHz mono f32 PCM ready for VAD/STT.

use std::fs::File;
use std::path::Path;

use symphonia::core::audio::GenericAudioBufferRef;
use symphonia::core::codecs::audio::AudioDecoderOptions;
use symphonia::core::formats::probe::Hint;
use symphonia::core::formats::{FormatOptions, FormatReader, Track, TrackType};
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;

use crate::error::TranscribeError;

pub const TARGET_SAMPLE_RATE: u32 = 16_000;

/// Decoded audio, resampled to mono f32 PCM at [`TARGET_SAMPLE_RATE`].
#[derive(Debug, Clone)]
pub struct AudioBuffer {
    pub samples: Vec<f32>,
    pub original_sample_rate: u32,
    pub original_channels: u16,
    pub duration_secs: f64,
}

/// Decode any Symphonia-supported audio file (or the audio track of an
/// MP4/MKV container) into mono PCM, then resample to 16kHz.
/// Not FRB-exposed directly (takes `&Path`); see `api::decode_audio_file`
/// for the `String`-path wrapper Dart calls into.
#[flutter_rust_bridge::frb(ignore)]
pub fn decode_audio_file(path: &Path) -> Result<AudioBuffer, TranscribeError> {
    let file = File::open(path).map_err(TranscribeError::from)?;
    let mss = MediaSourceStream::new(Box::new(file), Default::default());

    let mut hint = Hint::new();
    if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
        hint.with_extension(ext);
    }

    let mut format = open_format(&hint, mss)?;
    let track = audio_track(format.as_ref())?;
    let params = track
        .codec_params
        .as_ref()
        .and_then(|p| p.audio())
        .ok_or_else(|| TranscribeError::AudioDecode("no decodable audio track found".into()))?
        .clone();
    let track_id = track.id;

    let original_sample_rate = params.sample_rate.unwrap_or(TARGET_SAMPLE_RATE);
    let original_channels = params
        .channels
        .as_ref()
        .map(|c| c.count() as u16)
        .unwrap_or(1);

    let mut decoder = symphonia::default::get_codecs()
        .make_audio_decoder(&params, &AudioDecoderOptions::default())
        .map_err(|e| TranscribeError::AudioDecode(format!("unsupported codec: {e}")))?;

    let mut mono_samples: Vec<f32> = Vec::new();
    let mut scratch: Vec<f32> = Vec::new();

    loop {
        let packet = match format.next_packet() {
            // symphonia 0.6 signals end of stream with `Ok(None)`.
            Ok(Some(p)) => p,
            Ok(None) => break,
            Err(symphonia::core::errors::Error::IoError(e))
                if e.kind() == std::io::ErrorKind::UnexpectedEof =>
            {
                break;
            }
            Err(e) => return Err(TranscribeError::AudioDecode(format!("read error: {e}"))),
        };

        if packet.track_id != track_id {
            continue;
        }

        match decoder.decode(&packet) {
            Ok(decoded) => append_as_mono(&decoded, &mut scratch, &mut mono_samples),
            Err(symphonia::core::errors::Error::DecodeError(_)) => continue,
            Err(e) => return Err(TranscribeError::AudioDecode(format!("decode error: {e}"))),
        }
    }

    if mono_samples.is_empty() {
        return Err(TranscribeError::AudioDecode(
            "file contains no audio samples".into(),
        ));
    }

    let duration_secs = mono_samples.len() as f64 / original_sample_rate as f64;
    let resampled = resample_to_target(&mono_samples, original_sample_rate)?;

    Ok(AudioBuffer {
        samples: resampled,
        original_sample_rate,
        original_channels,
        duration_secs,
    })
}

/// Length of an audio file without decoding it.
///
/// Reads the container's frame count, which every format this app records
/// or imports carries. Returns `None` when the header does not declare one
/// (some streamed MP3s) — the caller then has to decode to find out, and
/// should say so rather than guessing.
///
/// The coverage check runs on every session save, including three-hour
/// ones; decoding 1.4 GB of WAV to learn how long it is would make saving
/// a meeting slower than recording it.
#[flutter_rust_bridge::frb(ignore)]
pub fn probe_duration_secs(path: &Path) -> Result<Option<f64>, TranscribeError> {
    let file = File::open(path).map_err(TranscribeError::from)?;
    let mss = MediaSourceStream::new(Box::new(file), Default::default());
    let mut hint = Hint::new();
    if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
        hint.with_extension(ext);
    }
    let format = open_format(&hint, mss)?;
    let track = audio_track(format.as_ref())?;
    let rate = track
        .codec_params
        .as_ref()
        .and_then(|p| p.audio())
        .and_then(|a| a.sample_rate);
    let (Some(frames), Some(rate)) = (track.num_frames, rate) else {
        return Ok(None);
    };
    if rate == 0 {
        return Ok(None);
    }
    Ok(Some(frames as f64 / rate as f64))
}

fn open_format(
    hint: &Hint,
    mss: MediaSourceStream<'static>,
) -> Result<Box<dyn FormatReader>, TranscribeError> {
    symphonia::default::get_probe()
        .probe(
            hint,
            mss,
            FormatOptions::default(),
            MetadataOptions::default(),
        )
        .map_err(|e| TranscribeError::AudioDecode(format!("unsupported or corrupt file: {e}")))
}

/// The track to decode: the container's default audio track, else the
/// first audio track with a codec symphonia knows.
fn audio_track(format: &dyn FormatReader) -> Result<&Track, TranscribeError> {
    format
        .default_track(TrackType::Audio)
        .ok_or_else(|| TranscribeError::AudioDecode("no decodable audio track found".into()))
}

/// Average every channel of `decoded` into `out`. `scratch` holds the
/// interleaved f32 copy between calls so a long file does not allocate
/// once per packet.
fn append_as_mono(decoded: &GenericAudioBufferRef, scratch: &mut Vec<f32>, out: &mut Vec<f32>) {
    let channels = decoded.spec().channels().count().max(1);
    scratch.resize(decoded.samples_interleaved(), 0.0);
    decoded.copy_to_slice_interleaved(&mut scratch[..]);
    out.extend(
        scratch
            .chunks_exact(channels)
            .map(|frame| frame.iter().sum::<f32>() / channels as f32),
    );
}

/// Resample mono PCM to [`TARGET_SAMPLE_RATE`] using rubato (SIMD-accelerated).
/// Internal helper, not FRB-exposed.
#[flutter_rust_bridge::frb(ignore)]
pub fn resample_to_target(samples: &[f32], from_rate: u32) -> Result<Vec<f32>, TranscribeError> {
    if from_rate == TARGET_SAMPLE_RATE {
        return Ok(samples.to_vec());
    }
    if samples.is_empty() {
        return Ok(Vec::new());
    }

    use rubato::audioadapter_buffers::direct::InterleavedSlice;
    use rubato::{
        Async, FixedAsync, Resampler, SincInterpolationParameters, SincInterpolationType,
        WindowFunction,
    };

    let params = SincInterpolationParameters {
        sinc_len: 256,
        f_cutoff: Some(0.95),
        interpolation: SincInterpolationType::Linear,
        oversampling_factor: 256,
        window: WindowFunction::BlackmanHarris2,
    };

    let ratio = TARGET_SAMPLE_RATE as f64 / from_rate as f64;
    // rubato 1.0+ resamples a whole clip with `process_all`, which also trims
    // the sinc filter's startup delay. The old single `process` call sized to
    // the clip left that delay as leading silence.
    let mut resampler = Async::<f32>::new_sinc(ratio, 2.0, &params, 1024, 1, FixedAsync::Input)
        .map_err(|e| TranscribeError::AudioDecode(format!("resampler init failed: {e}")))?;

    let input = InterleavedSlice::new(samples, 1, samples.len())
        .map_err(|e| TranscribeError::AudioDecode(format!("resample input invalid: {e}")))?;
    let output = resampler
        .process_all(&input, samples.len(), None)
        .map_err(|e| TranscribeError::AudioDecode(format!("resample failed: {e}")))?;

    // Mono, so the interleaved buffer is the channel itself.
    Ok(output.take_data())
}

/// Stateful streaming resampler to [`TARGET_SAMPLE_RATE`].
///
/// `resample_to_target` builds a brand-new sinc resampler per call, so using it
/// on tiny live chunks (ScreenCaptureKit delivers ~10 ms buffers) drops the
/// filter-delay samples of every chunk (~27% at 480 in -> 160 out) and leaves a
/// discontinuity between chunks. This keeps one resampler alive and feeds it
/// fixed-size blocks, carrying leftover input to the next `push`.
pub struct StreamResampler {
    inner: Option<rubato::Async<f32>>,
    pending: Vec<f32>,
}

impl StreamResampler {
    const BLOCK: usize = 480;

    pub fn new(from_rate: u32) -> Result<Self, TranscribeError> {
        if from_rate == TARGET_SAMPLE_RATE {
            return Ok(Self {
                inner: None,
                pending: Vec::new(),
            });
        }
        use rubato::{
            Async, FixedAsync, SincInterpolationParameters, SincInterpolationType, WindowFunction,
        };
        let params = SincInterpolationParameters {
            sinc_len: 128,
            f_cutoff: Some(0.95),
            interpolation: SincInterpolationType::Linear,
            oversampling_factor: 128,
            window: WindowFunction::BlackmanHarris2,
        };
        let ratio = TARGET_SAMPLE_RATE as f64 / from_rate as f64;
        let rs = Async::<f32>::new_sinc(ratio, 2.0, &params, Self::BLOCK, 1, FixedAsync::Input)
            .map_err(|e| TranscribeError::AudioDecode(format!("resampler init failed: {e}")))?;
        Ok(Self {
            inner: Some(rs),
            pending: Vec::new(),
        })
    }

    /// Feed mono samples at the source rate; returns whatever 16 kHz output is ready.
    pub fn push(&mut self, mono: &[f32]) -> Result<Vec<f32>, TranscribeError> {
        use rubato::audioadapter_buffers::direct::InterleavedSlice;
        use rubato::Resampler;
        let Some(rs) = self.inner.as_mut() else {
            return Ok(mono.to_vec());
        };
        self.pending.extend_from_slice(mono);
        let mut out = Vec::new();
        loop {
            let need = rs.input_frames_next();
            if self.pending.len() < need {
                break;
            }
            let input = InterleavedSlice::new(&self.pending[..need], 1, need).map_err(|e| {
                TranscribeError::AudioDecode(format!("resample input invalid: {e}"))
            })?;
            let res = rs
                .process(&input, None)
                .map_err(|e| TranscribeError::AudioDecode(format!("resample failed: {e}")))?;
            self.pending.drain(..need);
            // Mono: the interleaved output is the channel itself.
            out.extend(res.take_data());
        }
        Ok(out)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stream_resampler_keeps_sample_count_over_small_chunks() {
        let mut rs = StreamResampler::new(48_000).unwrap();
        let chunk = vec![0.1f32; 480];
        let mut total = 0usize;
        for _ in 0..1000 {
            total += rs.push(&chunk).unwrap().len();
        }
        // 1000 x 10 ms at 48 kHz -> ~160000 samples at 16 kHz, minus a
        // one-off filter delay. The per-chunk resampler lost ~27%.
        assert!(total > 158_000 && total <= 160_000, "got {total}");
    }

    #[test]
    fn resample_noop_when_same_rate() {
        let samples = vec![0.1, 0.2, 0.3];
        let out = resample_to_target(&samples, TARGET_SAMPLE_RATE).unwrap();
        assert_eq!(out, samples);
    }

    #[test]
    fn resample_empty_is_empty() {
        let out = resample_to_target(&[], 44_100).unwrap();
        assert!(out.is_empty());
    }

    #[test]
    fn resample_changes_length_proportionally() {
        let samples = vec![0.0f32; 44_100];
        let out = resample_to_target(&samples, 44_100).unwrap();
        // 44.1k -> 16k over 1 second: expect ~16000 samples, generous tolerance
        assert!(
            out.len() > 15_000 && out.len() < 17_000,
            "len={}",
            out.len()
        );
    }

    #[test]
    fn decode_missing_file_errors() {
        let result = decode_audio_file(Path::new("/nonexistent/path/does-not-exist.wav"));
        assert!(result.is_err());
    }

    #[test]
    fn decode_corrupt_file_errors() {
        let dir = std::env::temp_dir();
        let path = dir.join("transcribe_test_corrupt.wav");
        std::fs::write(&path, b"not a real wav file at all").unwrap();
        let result = decode_audio_file(&path);
        assert!(result.is_err());
        let _ = std::fs::remove_file(&path);
    }
}
