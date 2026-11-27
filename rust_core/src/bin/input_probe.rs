//! Manual check for issue #69: prints what the pre-session probe measures.
//!
//!     cargo run --bin input_probe -- [millis] [device name]
//!
//! Expect roughly -60 dBFS peak and a small SNR in a silent room, and a
//! peak near -20 dBFS with a large SNR while speaking.

use rust_core::audio::probe::probe_input;

fn main() {
    let mut args = std::env::args().skip(1);
    let millis = args.next().and_then(|a| a.parse().ok()).unwrap_or(3_000);
    let device: Option<String> = {
        let rest: Vec<String> = args.collect();
        (!rest.is_empty()).then(|| rest.join(" "))
    };
    match probe_input(device.clone(), millis) {
        Ok(p) => println!(
            "device={} ms={} snr_db={:.1} peak_dbfs={:.1}",
            device.as_deref().unwrap_or("(default)"),
            p.ms,
            p.snr_db,
            p.peak_dbfs
        ),
        Err(e) => {
            eprintln!("probe failed: {e}");
            std::process::exit(1);
        }
    }
}
