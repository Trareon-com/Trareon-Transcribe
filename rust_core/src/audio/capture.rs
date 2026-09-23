//! Live audio capture: opens a cpal input stream and forwards resampled
//! 16kHz mono f32 PCM to a channel. Runs the stream on a dedicated OS
//! thread since `cpal::Stream` isn't `Send` on most platforms.
//!
//! Config resolution and error paths are unit-tested; actually opening a
//! stream requires a real audio device and is exercised via manual smoke
//! test (see the project test plan), not CI.

use std::sync::mpsc;
use std::thread::JoinHandle;

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{Sample, SampleFormat, StreamConfig};

use crate::decode::resample_to_target;
use crate::error::TranscribeError;

/// A running capture session. Dropping this stops the stream and joins
/// the capture thread. Not FRB-exposed — driven from Rust-side session
/// orchestration, not directly from Dart.
#[flutter_rust_bridge::frb(ignore)]
pub struct AudioCapture {
    pub(crate) stop_tx: Option<mpsc::Sender<()>>,
    pub(crate) thread: Option<JoinHandle<()>>,
}

impl AudioCapture {
    /// Wrap an externally-created capture thread (used by loopback capture
    /// on platforms where the capture path differs from cpal).
    pub fn new(stop_tx: mpsc::Sender<()>, thread: JoinHandle<()>) -> Self {
        Self {
            stop_tx: Some(stop_tx),
            thread: Some(thread),
        }
    }

    /// Start capturing from the named device (or the system default input
    /// if `device_name` is `None`). Resampled mono f32 PCM chunks are sent
    /// on `samples_tx` as they arrive; the receiver end typically feeds a
    /// [`crate::audio::RingBuffer`].
    pub fn start(
        device_name: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
    ) -> Result<Self, TranscribeError> {
        let (ready_tx, ready_rx) = mpsc::channel::<Result<(), TranscribeError>>();
        let (stop_tx, stop_rx) = mpsc::channel::<()>();

        let thread = std::thread::spawn(move || {
            let outcome = Self::run_capture_thread(device_name, samples_tx, stop_rx, &ready_tx);
            // If run_capture_thread returned before signaling readiness
            // (e.g. device/config resolution failed), make sure the
            // caller's ready_rx.recv() below still unblocks.
            let _ = ready_tx.send(outcome);
        });

        // A hard timeout here is deliberate: on some Windows machines
        // (observed with Intel Smart Sound Technology audio drivers),
        // `cpal::Device::build_input_stream()` — specifically the
        // underlying WASAPI `IAudioClient::Initialize()` call — can hang
        // indefinitely at the OS/driver level with no error returned.
        // Without a timeout, the UI's "Mulai" button would spin forever
        // with no way to cancel. The spawned thread stays blocked forever
        // in that case (a blocking Win32 call can't be safely interrupted
        // from Rust), but it does nothing else and the caller is freed to
        // show an actionable error instead of hanging.
        match ready_rx.recv_timeout(std::time::Duration::from_secs(8)) {
            Ok(Ok(())) => Ok(Self {
                stop_tx: Some(stop_tx),
                thread: Some(thread),
            }),
            Ok(Err(e)) => Err(e),
            Err(mpsc::RecvTimeoutError::Timeout) => Err(TranscribeError::AudioDevice(
                "Audio input device did not respond within 8 seconds. This is a known \
                 issue with some audio drivers (e.g. Intel Smart Sound Technology) where \
                 Windows' WASAPI initialization hangs. Try restarting the Windows Audio \
                 service, updating your audio driver, or selecting a different \
                 microphone in Settings."
                    .into(),
            )),
            Err(mpsc::RecvTimeoutError::Disconnected) => Err(TranscribeError::AudioDevice(
                "capture thread exited before signaling readiness".into(),
            )),
        }
    }

    fn run_capture_thread(
        device_name: Option<String>,
        samples_tx: mpsc::Sender<Vec<f32>>,
        stop_rx: mpsc::Receiver<()>,
        ready_tx: &mpsc::Sender<Result<(), TranscribeError>>,
    ) -> Result<(), TranscribeError> {
        let host = cpal::default_host();
        let device = resolve_device(&host, device_name.as_deref())?;
        let config = resolve_input_config(&device)?;

        let stream = build_input_stream(&device, &config, samples_tx)?;
        stream
            .play()
            .map_err(|e| TranscribeError::AudioDevice(format!("failed to start stream: {e}")))?;

        // Signal readiness now that the stream is actually playing.
        let _ = ready_tx.send(Ok(()));

        // Block until told to stop; the stream keeps running on cpal's
        // own callback thread(s) in the meantime.
        let _ = stop_rx.recv();
        drop(stream);
        Ok(())
    }

    pub fn stop(&mut self) {
        if let Some(tx) = self.stop_tx.take() {
            let _ = tx.send(());
        }
        if let Some(handle) = self.thread.take() {
            let _ = handle.join();
        }
    }
}

impl Drop for AudioCapture {
    fn drop(&mut self) {
        self.stop();
    }
}

fn resolve_device(
    host: &cpal::Host,
    device_name: Option<&str>,
) -> Result<cpal::Device, TranscribeError> {
    match device_name {
        None => host.default_input_device().ok_or_else(|| {
            TranscribeError::AudioDevice("no default input device available".into())
        }),
        Some(name) => resolve_named_device(host, name),
    }
}

fn resolve_named_device(host: &cpal::Host, name: &str) -> Result<cpal::Device, TranscribeError> {
    if let Some(device) = host
        .input_devices()
        .map_err(|e| TranscribeError::AudioDevice(e.to_string()))?
        .find(|d| d.name().map(|n| n == name).unwrap_or(false))
    {
        return Ok(device);
    }
    if let Some(device) = host
        .output_devices()
        .map_err(|e| TranscribeError::AudioDevice(e.to_string()))?
        .find(|d| d.name().map(|n| n == name).unwrap_or(false))
    {
        return Ok(device);
    }
    Err(TranscribeError::AudioDevice(format!(
        "device '{name}' not found"
    )))
}

fn resolve_input_config(
    device: &cpal::Device,
) -> Result<cpal::SupportedStreamConfig, TranscribeError> {
    device
        .default_input_config()
        .map_err(|e| TranscribeError::AudioDevice(format!("no supported input config: {e}")))
}

fn build_input_stream(
    device: &cpal::Device,
    supported_config: &cpal::SupportedStreamConfig,
    samples_tx: mpsc::Sender<Vec<f32>>,
) -> Result<cpal::Stream, TranscribeError> {
    let config: StreamConfig = supported_config.config();
    let sample_format = supported_config.sample_format();
    let channels = config.channels as usize;
    let source_rate = config.sample_rate.0;

    let err_fn = |e: cpal::StreamError| {
        tracing::error!("audio input stream error: {e}");
    };

    let stream = match sample_format {
        SampleFormat::F32 => build_generic_input_stream::<f32>(
            device,
            &config,
            channels,
            source_rate,
            samples_tx,
            err_fn,
        )
        .map_err(|e| TranscribeError::AudioDevice(format!("failed to build input stream: {e}")))?,
        SampleFormat::I16 => build_generic_input_stream::<i16>(
            device,
            &config,
            channels,
            source_rate,
            samples_tx,
            err_fn,
        )
        .map_err(|e| TranscribeError::AudioDevice(format!("failed to build input stream: {e}")))?,
        SampleFormat::U16 => build_generic_input_stream::<u16>(
            device,
            &config,
            channels,
            source_rate,
            samples_tx,
            err_fn,
        )
        .map_err(|e| TranscribeError::AudioDevice(format!("failed to build input stream: {e}")))?,
        SampleFormat::I8 => build_generic_input_stream::<i8>(
            device,
            &config,
            channels,
            source_rate,
            samples_tx,
            err_fn,
        )
        .map_err(|e| TranscribeError::AudioDevice(format!("failed to build input stream: {e}")))?,
        SampleFormat::U8 => build_generic_input_stream::<u8>(
            device,
            &config,
            channels,
            source_rate,
            samples_tx,
            err_fn,
        )
        .map_err(|e| TranscribeError::AudioDevice(format!("failed to build input stream: {e}")))?,
        SampleFormat::I32 => build_generic_input_stream::<i32>(
            device,
            &config,
            channels,
            source_rate,
            samples_tx,
            err_fn,
        )
        .map_err(|e| TranscribeError::AudioDevice(format!("failed to build input stream: {e}")))?,
        SampleFormat::U32 => build_generic_input_stream::<u32>(
            device,
            &config,
            channels,
            source_rate,
            samples_tx,
            err_fn,
        )
        .map_err(|e| TranscribeError::AudioDevice(format!("failed to build input stream: {e}")))?,
        SampleFormat::I64 => build_generic_input_stream::<i64>(
            device,
            &config,
            channels,
            source_rate,
            samples_tx,
            err_fn,
        )
        .map_err(|e| TranscribeError::AudioDevice(format!("failed to build input stream: {e}")))?,
        SampleFormat::U64 => build_generic_input_stream::<u64>(
            device,
            &config,
            channels,
            source_rate,
            samples_tx,
            err_fn,
        )
        .map_err(|e| TranscribeError::AudioDevice(format!("failed to build input stream: {e}")))?,
        SampleFormat::F64 => build_generic_input_stream::<f64>(
            device,
            &config,
            channels,
            source_rate,
            samples_tx,
            err_fn,
        )
        .map_err(|e| TranscribeError::AudioDevice(format!("failed to build input stream: {e}")))?,
        other => {
            return Err(TranscribeError::AudioDevice(format!(
                "unsupported sample format: {other:?}"
            )));
        }
    };

    Ok(stream)
}

fn build_generic_input_stream<T>(
    device: &cpal::Device,
    config: &StreamConfig,
    channels: usize,
    source_rate: u32,
    samples_tx: mpsc::Sender<Vec<f32>>,
    err_fn: impl FnMut(cpal::StreamError) + Send + 'static,
) -> Result<cpal::Stream, cpal::BuildStreamError>
where
    T: Sample + cpal::SizedSample + Send + 'static,
    f32: cpal::FromSample<T>,
{
    let tx = samples_tx;
    // ~100ms of raw source-rate audio per resample call — big enough that
    // the fresh-resampler-per-call overhead (see comment below) is a small
    // fraction of the batch, small enough to keep VAD/live latency low.
    let batch_threshold = (source_rate as usize) / 10;
    let mut accum: Vec<f32> = Vec::with_capacity(batch_threshold * 2);
    device.build_input_stream(
        config,
        move |data: &[T], _| {
            let mono = downmix_generic(data, channels);
            accum.extend_from_slice(&mono);
            // A fresh resampler is built per call (`resample_to_target`
            // has no persistent state across calls), and its filter
            // startup/padding overhead is roughly constant regardless of
            // input size. Calling it on tiny per-callback buffers (e.g.
            // ~512 raw samples) means that fixed overhead can exceed the
            // entire output, so it never reaches even one 10ms VAD frame
            // — accumulate a larger batch first so the fixed overhead is
            // a small fraction of a much bigger resample call.
            if accum.len() >= batch_threshold {
                if let Ok(resampled) = resample_to_target(&accum, source_rate) {
                    let _ = tx.send(resampled);
                }
                accum.clear();
            }
        },
        err_fn,
        None,
    )
}

fn downmix_generic<T>(data: &[T], channels: usize) -> Vec<f32>
where
    T: Sample,
    f32: cpal::FromSample<T>,
{
    if channels <= 1 {
        return data
            .iter()
            .map(|sample| sample.to_sample::<f32>())
            .collect();
    }
    data.chunks(channels)
        .map(|frame| {
            frame
                .iter()
                .map(|sample| sample.to_sample::<f32>())
                .sum::<f32>()
                / channels as f32
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn downmix_mono_passthrough() {
        let data = vec![0.1, 0.2, 0.3];
        assert_eq!(downmix_generic(&data, 1), data);
    }

    #[test]
    fn downmix_stereo_averages_channels() {
        let data = vec![1.0, -1.0, 0.5, 0.5];
        let mono = downmix_generic(&data, 2);
        assert_eq!(mono, vec![0.0, 0.5]);
    }

    #[test]
    fn downmix_generic_u16_converts_to_float() {
        let data = vec![u16::MIN, u16::MAX];
        let mono = downmix_generic(&data, 1);
        assert_eq!(mono.len(), 2);
        assert!((mono[0] + 1.0).abs() < 0.01);
        assert!((mono[1] - 1.0).abs() < 0.01);
    }

    #[test]
    fn downmix_empty_is_empty() {
        let empty: Vec<f32> = Vec::new();
        assert!(downmix_generic(&empty, 2).is_empty());
    }

    #[test]
    fn resolve_named_device_not_found_errors_not_panics() {
        let host = cpal::default_host();
        let result = resolve_device(&host, Some("definitely-not-a-real-device-xyz123"));
        assert!(result.is_err());
    }

    #[test]
    fn start_capture_on_missing_device_errors_not_panics() {
        // No real device on CI runners is fine — this must return Err
        // cleanly rather than panicking or hanging.
        let (tx, _rx) = mpsc::channel();
        let result =
            AudioCapture::start(Some("definitely-not-a-real-device-xyz123".to_string()), tx);
        assert!(result.is_err());
    }

    #[test]
    fn target_sample_rate_matches_decode_module() {
        // Sanity check that capture and decode agree on the pipeline's
        // target rate — a mismatch here would silently produce
        // double-resampled or wrong-rate audio downstream.
        assert_eq!(crate::decode::TARGET_SAMPLE_RATE, 16_000);
    }
}
