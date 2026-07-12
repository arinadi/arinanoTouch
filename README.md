<div align="center">
  <h1>📱 arinanoTouch</h1>
  <p><strong>Your phone runs a mobile-native desktop — Phosh on Debian 13.</strong></p>
  <p>
    <a href="https://arinano.work"><img src="https://img.shields.io/badge/site-arinano.work-blue"></a>
    <a href="https://github.com/arinadi/arinanoTouch/actions"><img src="https://img.shields.io/github/actions/workflow/status/arinadi/arinanoTouch/build-image.yml?label=build"></a>
    <a href="https://github.com/arinadi/arinanoTouch/blob/main/LICENSE"><img src="https://img.shields.io/github/license/arinadi/arinanoTouch"></a>
  </p>

  ```bash
curl -sL https://raw.githubusercontent.com/arinadi/arinanoTouch/main/bootstrap.sh | bash
```

  <p>
    Debian 13 &nbsp;·&nbsp; Phosh &nbsp;·&nbsp; Firefox ESR &nbsp;·&nbsp; Dev tools<br>
    <small>TermuX&nbsp;→&nbsp;X11&nbsp;→&nbsp;Openbox&nbsp;→&nbsp;Cage&nbsp;→&nbsp;Phoc&nbsp;→&nbsp;Phosh</small>
  </p>
</div>

---

## ⚡ Why

arinanoTouch brings the **native mobile shell experience** to your Android device. Unlike desktop environments forced onto touchscreens, [Phosh](https://phosh.mobi) is designed for phones — swipe gestures, app drawer, lock screen, on-screen keyboard. Built on the same declarative, prebuilt-image foundation as [arinanoX](https://github.com/arinadi/arinanoX).

| | arinanoTouch |
|---|---|
| 📱 | **Mobile-native.** Phosh shell — not a desktop forced onto touch. |
| 🏗️ | **Declarative.** Single Dockerfile defines the entire system. |
| ⚡ | **Prebuilt.** 580MB image from CI. Extract and run — 30 seconds. |
| 🔄 | **Atomic.** Updates to a fresh image. Old one kept as backup. Instant rollback. |
| 🎯 | **Proot-aware.** Nested compositor (Openbox→Cage→Phoc). No seatd/logind needed. |
| 📱 | **Termux:API.** Battery, clipboard, voice, camera — from inside proot. |

---

### Requirements

- Android **12+** (recommended) for VirGL GPU acceleration. Android 8-11 works with software rendering only.
- [Termux](https://f-droid.org/en/packages/com.termux/) (F-Droid, NOT Play Store)
- [Termux:X11](https://github.com/termux/termux-x11/releases/tag/nightly) — display server
- [Termux:API](https://f-droid.org/en/packages/com.termux.api/) (optional — TAPI utilities)
- [Termux:Widget](https://f-droid.org/en/packages/com.termux.widget/) (recommended — home screen launchers)

---

## 🏗️ How It Works

```
┌─────────────────────────────────────┐
│  USER LAYER (mutable)                │  ← Your packages, configs, data
│  Preserved across updates            │
├─────────────────────────────────────┤
│  CORE LAYER (declarative)            │  ← Built from Dockerfile in CI
│  Debian 13 + Phosh + Phoc + dev      │     ghcr.io/arinadi/arinanotouch
└─────────────────────────────────────┘
```

### Compositor Chain

Phosh needs a Wayland compositor — but proot has no systemd, no seatd, no logind. The solution: a **nested compositor chain** that delegates hardware access to Termux:X11:

```
Termux:X11 (X server, Android side)
  └─ Openbox  (WM, fixes resolution detection)
       └─ Cage  (Wayland-in-X11 compositor)
            └─ Phoc  (wlroots Wayland compositor)
                 └─ Phosh  (mobile shell)
```

Phoc runs as a simple Wayland client inside Cage's socket — never touches `/dev/dri/*` directly. GPU and input are delegated up the chain to Termux:X11. **No seatd, no logind required.**

### GPU Acceleration (virglrenderer)

| GPU | Flag | Priority |
|-----|------|----------|
| Xclipse (Exynos RDNA2) | `--angle-vulkan` | Tier 1 |
| Adreno / Mali / Others | `virgl_test_server_android` | Tier 1 |
| Any (null backend) | `virgl_test_server --use-egl-surfaceless` | Tier 2 |
| CPU fallback | `LIBGL_ALWAYS_SOFTWARE=1` | Tier 3 |

**Xclipse 940 reference:** Samsung Galaxy S24 FE (SM-S721B). Confirmed working with `--angle-vulkan` flag. See [community findings](https://github.com/phoenixbyrd/Termux_XFCE/issues/85).

---

## 🚀 Usage

```bash
arinanotouch start        # Launch Phosh desktop
arinanotouch stop         # Stop everything
arinanotouch status       # System overview
arinanotouch doctor       # Full health-check
arinanotouch backup       # Backup to /sdcard
arinanotouch snapshot     # Instant checkpoint (hardlinked)
arinanotouch update       # Fresh image + re-apply configs
arinanotouch help         # All commands
```

### 📱 Termux:Widget (home screen)

| Shortcut | Action |
|----------|--------|
| 🟢 `1-start-arinanotouch.sh` | Full startup |
| 🔴 `0-stop-arinanotouch.sh` | Full stop |

### Input / Keyboard

Squeekboard is installed as the default on-screen keyboard but [known to be problematic inside proot](https://ivonblog.com/en-us/posts/postmarketos-in-termux-proot/). **Fallback:** press the Android back button to bring up the system keyboard.

### Right-Click on Touchscreen

`Ctrl+Alt+R` triggers right-click via xdotool (auto-installed).

Add to `~/.termux/termux.properties`:
```properties
extra-keys = [ \
 ['ESC','/',{key: '-', popup: '|'},'HOME','UP','END','PGUP',{macro: "CTRL ALT r", display: "🖱️R"}], \
 ['TAB','CTRL','ALT','LEFT','DOWN','RIGHT','PGDN','KEYBOARD'] \
]
```

---

## 📋 Termux:API (inside proot)

| Command | Action |
|---------|--------|
| `battery` | Battery % and health |
| `clipget` / `clipset` | Android clipboard |
| `vol-up` / `vol-down` | Media volume |
| `bright 50` | Brightness 0-100 |
| `toast "msg"` | Toast popup |
| `buzz` | Short vibration |
| `speak "hello"` | Text-to-speech |
| `listen` | Speech-to-text |
| `whereami` / `wifi` | GPS / WiFi |
| `photo` / `flash` | Camera / flashlight |

---

## ⚠️ Known Limitations

This is a **v0.1 experimental release**. The Phosh-in-proot approach is fragile — please read this before opening issues.

| # | Issue | Status |
|---|-------|--------|
| 1 | **Phosh may fail to start** occasionally, requiring a full Termux restart | Known. `stop.sh` kills everything cleanly. |
| 2 | **Phantom Process Killer** (Android 12+) can kill Phosh under load — the Developer Options toggle may not be enough | Run the 3 ADB commands in `bootstrap.sh`. Fixed in §3. |
| 3 | **Squeekboard broken in proot** — on-screen keyboard unreliable | Use Android keyboard (back button fallback). Documented. |
| 4 | **GNOME Control Center / Software** likely won't open in proot | Configure via `gsettings` / `xdg-mime` / `apt` manually. |
| 5 | **Auto-rotation** (portrait/landscape) untested — proot can't access sensors directly | Fixed orientation only in v0.1. |
| 6 | **Nested compositor overhead** (Openbox→Cage→Phoc) vs direct X11 (XFCE) — not yet benchmarked | To be measured. |
| 7 | **(Xclipse only) Wrong virgl flag** → black screen with cursor | Use `--angle-vulkan`, not plain `virgl_test_server`. |
| 8 | **firefox-esr** may be auto-removed in Debian trixie due to RC bugs | Check package status during build; fallback to GNOME Web. |
| 9 | **Vulkan ICD layer** installed outside Dockerfile → black screen | Don't install ICD manually. |
| 10 | Android 8-11: **software rendering only**, UI may crash | Not recommended. |

---

## 🛑 Android 12+ Phantom Process Killer

**Required** for reliable operation on Samsung Exynos devices:

```bash
adb shell "/system/bin/device_config set_sync_disabled_for_tests persistent"
adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
adb shell settings put global settings_enable_monitor_phantom_procs false
```

Also: Developer Options → Disable child process restrictions.

---

## 📂 Structure

```
arinanoTouch/
├── bootstrap.sh          ← one-command entry point
├── image/                ← System definition (Dockerfile)
│   ├── Dockerfile        ←   4 layers: base, Phosh, dev, user
│   └── configs-target/    ←     autostart, tools, bashrc
├── scripts/              ← setup, rollback, status, doctor
├── launchers/            ← start/stop shortcuts
├── docs/
└── .github/workflows/    ← CI → GHCR image on push
```

---

## 📜 License

GPLv3 — see [LICENSE](LICENSE).

---

## 🔗 References

- [arinanoX](https://github.com/arinadi/arinanoX) — parent project (XFCE desktop)
- [postmarketOS in Termux proot](https://ivonblog.com/en-us/posts/postmarketos-in-termux-proot/) — nested compositor technique
- [Phosh](https://phosh.mobi) — mobile shell
- [Debian Mobile](https://wiki.debian.org/Mobile) — Phosh in Debian
- [Xclipse GPU findings](https://github.com/phoenixbyrd/Termux_XFCE/issues/85) — community thread
- [dw5/termux-phosh](https://github.com/dw5/termux-phosh) — precedent project (archived)
- [olivia1246/postmarketOS-termux](https://github.com/olivia1246/postmarketOS-termux) — precedent project
