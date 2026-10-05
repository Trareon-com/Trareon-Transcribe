//! Runs the real sherpa-onnx diarizer, when the feature is compiled in and
//! the models are installed.
//!
//! ```bash
//! cargo test --features neural-diarization --test neural_diarization_live -- --nocapture
//! ```
//!
//! Not part of the default test run: the feature downloads a 23 MB
//! prebuilt native library at build time (see `Cargo.toml`), and the
//! models are another 34 MB the user opts into. Skips with a message when
//! either is absent, because "the models are not installed" is not a test
//! failure — it is the ordinary state of a fresh checkout.

#![cfg(feature = "neural-diarization")]

use rust_core::diarization::neural::{configure, is_active, relabel_segments, DiarizationModels};
use rust_core::export::Segment;

fn models() -> Option<DiarizationModels> {
    let dir = dirs::home_dir()?
        .join("Library")
        .join("Caches")
        .join("TrareonTranscribe")
        .join("models");
    let models = DiarizationModels {
        segmentation: dir.join("sherpa-onnx-pyannote-segmentation-3-0.onnx"),
        embedding: dir.join("3dspeaker_speech_campplus_sv_zh-cn_16k-common.onnx"),
    };
    (models.segmentation.exists() && models.embedding.exists()).then_some(models)
}

fn seg(timestamp: f64, duration: f64) -> Segment {
    Segment {
        source: "file".into(),
        speaker: "Pembicara 9".into(),
        text: "halo".into(),
        timestamp,
        duration,
        language: "id".into(),
        confidence: 0.9,
        avg_log_prob: -0.3,
        is_partial: false,
        low_confidence: false,
        words: Vec::new(),
    }
}

/// Two alternating synthetic "voices": a 150 Hz and a 320 Hz harmonic
/// stack, four seconds each.
///
/// Not speech, so the diarizer may legitimately find one speaker or none.
/// What this test is for is the integration: the models load, `process`
/// returns, the turns come back in time order, and the labels that land on
/// the transcript are the ones `speaker_label` produces. A DER measurement
/// needs a labelled corpus and does not belong in a unit test.
fn two_voices() -> Vec<f32> {
    const RATE: f64 = 16_000.0;
    let mut samples = Vec::with_capacity(16_000 * 16);
    for block in 0..4 {
        let base = if block % 2 == 0 { 150.0 } else { 320.0 };
        for i in 0..(RATE as usize * 4) {
            let t = i as f64 / RATE;
            let value = (t * base * std::f64::consts::TAU).sin() * 0.3
                + (t * base * 2.0 * std::f64::consts::TAU).sin() * 0.15
                + (t * base * 3.0 * std::f64::consts::TAU).sin() * 0.08;
            samples.push(value as f32);
        }
    }
    samples
}

#[test]
fn the_real_diarizer_loads_and_labels_a_transcript() {
    let Some(models) = models() else {
        eprintln!("diarization models not installed; skipping");
        return;
    };
    configure(true, Some(models));
    assert!(is_active(), "feature compiled in and models present");

    let samples = two_voices();
    let mut segments: Vec<Segment> = (0..4).map(|i| seg(i as f64 * 4.0 + 0.5, 3.0)).collect();
    let speakers = relabel_segments(&samples, &mut segments).expect("diarization must not error");
    eprintln!("speakers found: {speakers}");
    for segment in &segments {
        eprintln!("  {:.1}s -> {}", segment.timestamp, segment.speaker);
    }

    // Whatever it found, every label must be one this app produces — a
    // raw `speaker_00` reaching the transcript would be a wiring bug.
    for segment in &segments {
        assert!(
            segment.speaker == "Pembicara 9"
                || segment.speaker.starts_with("Pembicara ")
                || segment.speaker.starts_with("Peserta ")
                || segment.speaker == "Saya",
            "unexpected label: {}",
            segment.speaker
        );
    }
    configure(false, None);
}

#[test]
fn silence_produces_no_speakers_and_changes_no_labels() {
    let Some(models) = models() else {
        eprintln!("diarization models not installed; skipping");
        return;
    };
    configure(true, Some(models));
    let silence = vec![0.0f32; 16_000 * 10];
    let mut segments = vec![seg(1.0, 2.0)];
    let speakers = relabel_segments(&silence, &mut segments).expect("must not error on silence");
    assert_eq!(speakers, 0, "silence holds no speakers");
    assert_eq!(segments[0].speaker, "Pembicara 9", "labels untouched");
    configure(false, None);
}

/// Real Indonesian speech, when the sprint's sample clip is on this
/// machine. Proves the pipeline works on audio, not just on tones.
#[test]
fn real_indonesian_speech_is_diarized() {
    let Some(models) = models() else {
        eprintln!("diarization models not installed; skipping");
        return;
    };
    let clip = std::path::Path::new("/home/kali/trareon-sprints/rapat_id.mp3");
    if !clip.exists() {
        eprintln!("sample clip not present; skipping");
        return;
    }
    let audio = rust_core::decode::decode_audio_file(clip).expect("decode");
    configure(true, Some(models));
    // One segment per two seconds, as a live pass would produce.
    let mut segments: Vec<Segment> = (0..(audio.duration_secs / 2.0) as usize)
        .map(|i| seg(i as f64 * 2.0, 2.0))
        .collect();
    let speakers = relabel_segments(&audio.samples, &mut segments).expect("diarization");
    eprintln!(
        "{:.1}s of speech -> {speakers} speaker(s) over {} segments",
        audio.duration_secs,
        segments.len()
    );
    for segment in &segments {
        eprintln!("  {:5.1}s {}", segment.timestamp, segment.speaker);
    }
    assert!(
        speakers >= 1,
        "a clip of a person talking has a speaker in it"
    );
    configure(false, None);
}
