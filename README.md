<div align="center">
  <h1>📱 arinanoTouch</h1>
  <p><strong>Your phone runs a mobile-native desktop — SXMO (dwm) on Debian 13.</strong></p>
  <p>
    <a href="https://github.com/arinadi/arinanoTouch/actions"><img src="https://img.shields.io/github/actions/workflow/status/arinadi/arinanoTouch/build-image.yml?label=build"></a>
    <a href="https://github.com/arinadi/arinanoTouch/blob/main/LICENSE"><img src="https://img.shields.io/github/license/arinadi/arinanoTouch"></a>
  </p>

  ```bash
curl -sL https://raw.githubusercontent.com/arinadi/arinanoTouch/main/bootstrap.sh | bash
```

  <p>
    Debian 13 &nbsp;·&nbsp; SXMO &nbsp;·&nbsp; dwm &nbsp;·&nbsp; Firefox ESR &nbsp;·&nbsp; Dev tools<br>
    <small>Termux&nbsp;→&nbsp;X11&nbsp;→&nbsp;dwm (SXMO) — no nested compositor</small>
  </p>
</div>

---

## ⚡ Why

arinanoTouch brings the **native mobile shell experience** to your Android device. Unlike desktop environments forced onto touchscreens, [SXMO](https://sxmo.org) is designed for phones — gesture swipe (`lisgd`), menu lewat tombol hardware, on-screen keyboard adaptif (`svkbd`/`wvkbd`), window manager dwm.

Built on the same declarative, prebuilt-image foundation as [arinanoX](https://github.com/arinadi/arinanoX).

| | arinanoTouch |
|---|---|
| 📱 | **Mobile-native.** SXMO shell — not a desktop forced onto touch. |
| 🏗️ | **Declarative.** Single Dockerfile defines the entire system. |
| ⚡ | **Prebuilt.** Image from CI. Extract and run — fast. |
| 🔄 | **Atomic.** Updates to a fresh image. Old one kept as backup. Instant rollback. |
| 🎯 | **X11 murni.** No nested Wayland compositor — arsitektur identik dengan arinanoX (XFCE) yang sudah terbukti jalan. |
| 📱 | **Termux:API.** Battery, clipboard, voice, camera — from inside proot. |

> **v0.1 experimental** — dibangun dan diuji di Samsung Galaxy S24 FE (Exynos 2400e, Xclipse 940).

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
│  Debian 13 + SXMO (dwm) + dev tools  │     ghcr.io/arinadi/arinanotouch
└─────────────────────────────────────┘
```

### Architecture

```
Termux:X11 (X server, Android side)
  └─ dwm (SXMO) — X11 native, no Wayland involved
       └─ svkbd/wvkbd (on-screen keyboard)
       └─ lisgd (gesture daemon — swipe navigation)
       └─ dmenu (launcher menu, triggered by hardware button)
       └─ Firefox ESR + mobile config
```

SXMO berjalan sebagai **X11 client langsung di atas Termux:X11** — tidak ada chain compositor. Pola ini identik dengan XFCE di arinanoX yang sudah stabil. GPU dan input diteruskan langsung ke Termux:X11.

### GPU Acceleration (virglrenderer)

| GPU | Flag | Priority |
|-----|------|----------|
| Xclipse (Exynos RDNA2) | `--angle-vulkan` | Tier 1 — **wajib** |
| Adreno / Mali / Others | `virgl_test_server_android` | Tier 1 |
| Any (null backend) | `virgl_test_server --use-egl-surfaceless` | Tier 2 |
| CPU fallback | `LIBGL_ALWAYS_SOFTWARE=1` | Tier 3 |

**Xclipse 940 reference:** Samsung Galaxy S24 FE (SM-S721B). Confirmed working with `--angle-vulkan` flag. See [community findings](https://github.com/phoenixbyrd/Termux_XFCE/issues/85).

---

## 🚀 Usage

```bash
arinanotouch start        # Launch SXMO desktop
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

SXMO menggunakan **svkbd**/**wvkbd** sebagai on-screen keyboard bawaan, diaktifkan otomatis melalui hook `sxmo_hooks`. **Fallback:** tekan tombol back Android untuk memunculkan system keyboard.

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

## 🛑 Wajib: Android 12+ Phantom Process Killer & Xclipse GPU

**Kedua fix ini dijalankan otomatis oleh `bootstrap.sh` (pre-flight check).** Bukan sekadar catatan pasif.

### 1. Disable Phantom Process Killer (via ADB)

Lebih reliable dari toggle Developer Options. Diperlukan untuk Samsung Exynos devices:

```bash
adb shell "/system/bin/device_config set_sync_disabled_for_tests persistent"
adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
adb shell settings put global settings_enable_monitor_phantom_procs false
```

Sumber: [mshzhb/android-glibc-samsung-exynos](https://github.com/mshzhb/android-glibc-samsung-exynos)

### 2. GPU: Wajib flag `--angle-vulkan`

Untuk Xclipse (Exynos RDNA2), **jangan** jalankan `virgl_test_server` tanpa flag, dan **jangan** instal Vulkan ICD layer manual di luar Dockerfile — pernah dilaporkan menyebabkan black screen cuma cursor muncul. Kami handle ini di `launchers/start.sh`.

---

## ⚠️ Known Limitations

| # | Issue | Status |
|---|-------|--------|
| 1 | **Phantom Process Killer** (Android 12+) dapat kill SXMO/dwm saat render berat | Fix ADB 3 commands wajib dijalankan. `bootstrap.sh` cek secara aktif. |
| 2 | **Xclipse GPU** — flag `--angle-vulkan` wajib; tanpa flag atau install ICD manual → black screen | Handle otomatis di `start.sh`. |
| 3 | **Auto-rotation** (portrait/landscape) — proot tidak bisa akses sensor Android langsung | Fixed orientation only di v0.1. |
| 4 | **`firefox-esr`** mungkin di-auto-removal di Debian trixie karena RC bugs | Cek status saat build; fallback GNOME Web. |
| 5 | **`sxmo-utils`** di Debian adalah community package, bukan jalur resmi (resminya postmarketOS) | Bagian yang kita pakai (dwm/dmenu/lisgd/svkbd) tidak menyentuh fitur telephony yang rawan breakage. |
| 6 | **Gesture `lisgd`** didesain untuk tombol volume/power PinePhone — mapping tombol Android bisa beda | Perlu validasi di S24 FE saat PoC; override config tersedia. |
| 7 | Android 8-11: **software rendering only**, UI mungkin crash | Tidak direkomendasikan. |

---

## 📂 Structure

```
arinanoTouch/
├── bootstrap.sh          ← one-command entry point (dengan pre-flight checks)
├── image/                ← System definition (Dockerfile)
│   ├── Dockerfile        ←   4 layers: base, SXMO, dev, user
│   └── configs-target/   ←     SXMO config, tools, bashrc
├── scripts/              ← setup, rollback, status, doctor
├── launchers/            ← start/stop shortcuts
├── docs/
└── .github/workflows/    ← CI → GHCR image on push
```

---

## Roadmap

1. ✅ PoC di Samsung Galaxy S24 FE — `sxmo-utils` via Termux:X11
2. ⬜ Validasi gesture/tombol hardware, sesuaikan config SXMO
3. ⬜ Setup CI → push ke GHCR
4. ⬜ Rilis v0.1 (experimental)
5. ⬜ Kumpulkan feedback sebelum pertimbangkan RDP (v0.2)

---

## 📜 License

GPLv3 — see [LICENSE](LICENSE).

---

## 🔗 References

- [arinanoX](https://github.com/arinadi/arinanoX) — parent project (XFCE desktop), struktur & Dockerfile sumber
- [SXMO](https://sxmo.org) · [Install docs](https://sxmo.org/docs/install/) — situs resmi
- [Debian sxmo-utils package](https://packages.debian.org/trixie/sxmo-utils) — konfirmasi paket resmi trixie
- [sxmo man page](https://manpages.debian.org/experimental/sxmo-utils/sxmo.7) — dokumentasi lengkap
- [LWN review SXMO](https://lwn.net/Articles/981320/) — ulasan mendalam
- [Xclipse GPU findings](https://github.com/phoenixbyrd/Termux_XFCE/issues/85) — root cause & fix
- [ADB phantom process killer fix](https://github.com/mshzhb/android-glibc-samsung-exynos) — sumber fix
- [Termux-UbuntuBox](https://github.com/RobertSzujo/Termux-UbuntuBox) — konfirmasi GPU Xclipse 920
