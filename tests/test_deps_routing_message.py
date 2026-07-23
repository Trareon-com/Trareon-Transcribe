from setup.deps import loopback_routing_message


def test_detected_shows_ok_regardless_of_platform():
    msg = loopback_routing_message(
        device_name="BlackHole", detected=True, is_windows=False, deps_installed=True
    )
    assert "terdeteksi" in msg and "✓" in msg


def test_windows_not_detected_after_install_suggests_restart():
    """choco reporting success doesn't mean Windows has enumerated the new
    VB-Cable endpoint yet — a driver install commonly needs a reboot."""
    msg = loopback_routing_message(
        device_name="VB-Cable", detected=False, is_windows=True, deps_installed=True
    )
    assert "restart" in msg.lower()


def test_windows_not_detected_without_install_attempt_no_restart_hint():
    msg = loopback_routing_message(
        device_name="VB-Cable", detected=False, is_windows=True, deps_installed=False
    )
    assert "restart" not in msg.lower()
    assert "tidak terdeteksi" in msg


def test_macos_not_detected_no_restart_hint():
    msg = loopback_routing_message(
        device_name="BlackHole", detected=False, is_windows=False, deps_installed=True
    )
    assert "restart" not in msg.lower()
    assert "tidak terdeteksi" in msg
