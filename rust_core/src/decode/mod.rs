//! Pure-Rust audio decode (Symphonia) — no ffmpeg, no external binaries.
//! Decodes WAV/MP3/M4A/AAC/OGG/FLAC/Opus (and audio streams inside MP4/MKV)
//! into 16kHz mono f32 PCM ready for VAD/STT.

use std::fs::File;
use std::path::Path;

use symphonia::core::audio::{AudioBufferRef, Signal};
use symphonia::core::codecs::{DecoderOptions, CODEC_TYPE_NULL};
use symphonia::core::conv::FromSample;
use symphonia::core::formats::FormatOptions;
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia::core::probe::Hint;

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

    let probed = symphonia::default::get_probe()
        .format(
            &hint,
            mss,
            &FormatOptions::default(),
            &MetadataOptions::default(),
        )
        .map_err(|e| TranscribeError::AudioDecode(format!("unsupported or corrupt file: {e}")))?;

    let mut format = probed.format;

    let track = format
        .tracks()
        .iter()
        .find(|t| t.codec_params.codec != CODEC_TYPE_NULL)
        .ok_or_else(|| TranscribeError::AudioDecode("no decodable audio track found".into()))?
        .clone();

    let original_sample_rate = track.codec_params.sample_rate.unwrap_or(TARGET_SAMPLE_RATE);
    let original_channels = track
        .codec_params
        .channels
        .map(|c| c.count() as u16)
        .unwrap_or(1);

    let mut decoder = symphonia::default::get_codecs()
        .make(&track.codec_params, &DecoderOptions::default())
        .map_err(|e| TranscribeError::AudioDecode(format!("unsupported codec: {e}")))?;

    let track_id = track.id;
    let mut mono_samples: Vec<f32> = Vec::new();

    loop {
        let packet = match format.next_packet() {
            Ok(p) => p,
            Err(symphonia::core::errors::Error::IoError(e))
                if e.kind() == std::io::ErrorKind::UnexpectedEof =>
            {
                break;
            }
            Err(e) => return Err(TranscribeError::AudioDecode(format!("read error: {e}"))),
        };

        if packet.track_id() != track_id {
            continue;
        }

        match decoder.decode(&packet) {
            Ok(decoded) => append_as_mono(&decoded, &mut mono_samples),
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
    let probed = symphonia::default::get_probe()
        .format(
            &hint,
            mss,
            &FormatOptions::default(),
            &MetadataOptions::default(),
        )
        .map_err(|e| TranscribeError::AudioDecode(format!("unsupported or corrupt file: {e}")))?;
    let Some(track) = probed
        .format
        .tracks()
        .iter()
        .find(|t| t.codec_params.codec != CODEC_TYPE_NULL)
    else {
        return Err(TranscribeError::AudioDecode(
            "no decodable audio track found".into(),
        ));
    };
    let (Some(frames), Some(rate)) = (track.codec_params.n_frames, track.codec_params.sample_rate)
    else {
        return Ok(None);
    };
    if rate == 0 {
        return Ok(None);
    }
    Ok(Some(frames as f64 / rate as f64))
}

fn append_as_mono(decoded: &AudioBufferRef, out: &mut Vec<f32>) {
    let spec = *decoded.spec();
    let channels = spec.channels.count().max(1);

    macro_rules! mixdown {
        ($buf:expr) => {{
            let planes = $buf.planes();
            let planes = planes.planes();
            let frames = $buf.frames();
            for i in 0..frames {
                let mut sum = 0.0f32;
                for ch in 0..channels.min(planes.len()) {
                    sum += f32::from_sample(planes[ch][i]);
                }
                out.push(sum / channels as f32);
            }
        }};
    }

    match decoded {
        AudioBufferRef::F32(buf) => mixdown!(buf),
        AudioBufferRef::F64(buf) => mixdown!(buf),
        AudioBufferRef::U8(buf) => mixdown!(buf),
        AudioBufferRef::U16(buf) => mixdown!(buf),
        AudioBufferRef::U24(buf) => mixdown!(buf),
        AudioBufferRef::U32(buf) => mixdown!(buf),
        AudioBufferRef::S8(buf) => mixdown!(buf),
        AudioBufferRef::S16(buf) => mixdown!(buf),
        AudioBufferRef::S24(buf) => mixdown!(buf),
        AudioBufferRef::S32(buf) => mixdown!(buf),
    }
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

    use rubato::{
        Resampler, SincFixedIn, SincInterpolationParameters, SincInterpolationType, WindowFunction,
    };

    let params = SincInterpolationParameters {
        sinc_len: 256,
        f_cutoff: 0.95,
        interpolation: SincInterpolationType::Linear,
        oversampling_factor: 256,
        window: WindowFunction::BlackmanHarris2,
    };

    let ratio = TARGET_SAMPLE_RATE as f64 / from_rate as f64;
    let mut resampler = SincFixedIn::<f32>::new(ratio, 2.0, params, samples.len(), 1)
        .map_err(|e| TranscribeError::AudioDecode(format!("resampler init failed: {e}")))?;

    let output = resampler
        .process(&[samples.to_vec()], None)
        .map_err(|e| TranscribeError::AudioDecode(format!("resample failed: {e}")))?;

    Ok(output.into_iter().next().unwrap_or_default())
}

#[cfg(test)]
mod tests {
    use super::*;

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
