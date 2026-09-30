//! Redirects ALSA-lib's own error printing away from stderr.
//!
//! Enumerating ALSA pcms makes libasound print its plugins' failures straight
//! to stderr, with no way to ask it not to except by installing a handler:
//!
//! ```text
//! ALSA lib pcm_oss.c:404:(_snd_pcm_oss_open) [error.] Cannot open device /dev/dsp
//! ALSA lib pcm_dmix.c:973:(snd_pcm_dmix_open) [error.pcm] The dmix plugin supports only playback stream
//! ALSA lib pcm_dsnoop.c:546:(snd_pcm_dsnoop_open) [error.pcm] The dsnoop plugin supports only capture stream
//! ```
//!
//! None of it is actionable — it is libasound reporting that plugins the user
//! never asked for aren't usable — but it is dozens of lines every time the
//! device list is refreshed, and in a GUI build it lands in the user's
//! terminal or journal.
//!
//! Linux device enumeration now goes through PulseAudio/PipeWire
//! ([`crate::audio::pulse`]), which avoids this entirely; the handler covers
//! the remaining cpal fallback paths, where ALSA is still touched.

/// Installs the handler once per process. Cheap and idempotent; call it before
/// any cpal call that may enumerate or open an ALSA pcm.
#[flutter_rust_bridge::frb(ignore)]
pub fn silence_once() {
    #[cfg(target_os = "linux")]
    {
        use std::sync::OnceLock;
        static INSTALLED: OnceLock<()> = OnceLock::new();
        INSTALLED.get_or_init(|| {
            // SAFETY: `snd_lib_error_set_handler` only stores the pointer; it
            // does not call it here. libasound is already linked into this
            // binary by cpal's `alsa-sys` dependency.
            unsafe {
                imp::snd_lib_error_set_handler(Some(imp::swallow));
            }
        });
    }
}

#[cfg(target_os = "linux")]
mod imp {
    use std::ffi::{c_char, c_int};

    // The real C callback is variadic:
    //
    //   void (*)(const char *file, int line, const char *function,
    //            int err, const char *fmt, ...)
    //
    // Rust cannot *define* a variadic `extern "C"` function on stable, so the
    // handler is declared with only the five named parameters. A non-variadic
    // callee reached through a variadic call site is safe on the C ABIs in
    // play here: the extra arguments are simply never read, and `swallow`
    // reads none of its parameters at all. This is the same shape every other
    // language binding uses to mute libasound.
    type Handler =
        Option<unsafe extern "C" fn(*const c_char, c_int, *const c_char, c_int, *const c_char)>;

    // `pub(super)`, not `pub`: a `pub` item here is picked up by the
    // flutter_rust_bridge codegen and exposed to Dart as a callable API.
    extern "C" {
        pub(super) fn snd_lib_error_set_handler(handler: Handler) -> c_int;
    }

    pub(super) unsafe extern "C" fn swallow(
        _file: *const c_char,
        _line: c_int,
        _function: *const c_char,
        _err: c_int,
        _fmt: *const c_char,
    ) {
        // Deliberately empty. Reading `fmt` would mean interpreting a
        // printf format string against varargs this signature cannot see.
        //
        // Nothing is logged even at debug level: the callback can fire
        // thousands of times during a single enumeration, which is the flood
        // problem this module exists to remove, not relocate.
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn installing_the_handler_is_idempotent_and_does_not_crash() {
        // Also covers the non-Linux no-op path.
        silence_once();
        silence_once();
    }

    /// The point of the handler: enumerating ALSA must not print to stderr.
    /// Asserted indirectly — a real capture of the process's fd 2 from inside
    /// a test is not worth the plumbing — by confirming enumeration still
    /// works with the handler installed, so muting libasound has not broken
    /// device discovery.
    #[cfg(target_os = "linux")]
    #[test]
    fn enumeration_still_works_with_the_handler_installed() {
        use cpal::traits::HostTrait;
        silence_once();
        let host = cpal::default_host();
        assert!(host.input_devices().is_ok());
    }
}
