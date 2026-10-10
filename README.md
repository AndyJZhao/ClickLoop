# ClickLoop

A small native macOS auto-clicker, forked from [mmmelson/SnapClick](https://github.com/mmmelson/SnapClick). Built with SwiftUI and AppKit; macOS 13 or later.

[中文](README.zh-CN.md)

## What's new

- **Long durations:** enter positive durations beyond 60 seconds, including minutes or hours (in seconds).
- **Unlimited clicking:** turn on **Run indefinitely**. Click Count and Every (sec) set the rate: `10 / 1` means 10 clicks per second, continuously until stopped.
- **Immediate stop:** press the same preset hotkey again, press **Esc**, or use **Stop clicking** in the main window or menu-bar popover. Disabling presets, editing a preset, and quitting also stop active clicks.
- **Launch animation:** the app icon animates in the window header and the menu-bar icon pulses briefly at launch. Reduce Motion is respected.

Finite mode keeps SnapClick's count/rate convention: the first click happens immediately, subsequent clicks are spaced by `duration / count`, and execution ends at the requested count. The maximum rate remains 200 CPS. Mouse clicks follow the current pointer position; timing is best effort under system load.

## Build and run

Install Apple's Xcode Command Line Tools, then:

```sh
git clone https://github.com/AndyJZhao/ClickLoop.git
cd ClickLoop
./Scripts/build_app.sh --launch
```

This produces an ad-hoc signed `ClickLoop.app` for the current Mac architecture. To install, copy it to Applications. Enable **ClickLoop** in System Settings → Privacy & Security → Accessibility before enabling a preset; the app does not grant itself this permission. Default presets are disabled and use ⌥1 (left) and ⌥2 (right).

The app uses a separate bundle ID (`com.andyjzhao.clickloop`) and stores presets in `~/Library/Application Support/ClickLoop/schemes.json`. SnapClick's settings are left untouched. To reuse them, quit ClickLoop and copy SnapClick's `schemes.json` into that directory; records without an unlimited flag load as finite presets.

If Swift reports an SDK/compiler version mismatch, select an installed SDK compatible with your compiler using `SDKROOT=/path/to/compatible/MacOSX.sdk` before the build/test command. No global toolchain change is needed.

## Validation

```sh
./Scripts/test.sh
./Scripts/build_app.sh
```

Smoke checks cover long durations, invalid input and rate limits, finite completion, unlimited repetition, immediate cancellation, replacing a running preset, and new/legacy preset persistence. They inject a click sink and **never send mouse events**. For a manual end-to-end check, grant Accessibility, set a preset to 10 clicks / 1 second with Run indefinitely enabled, move over a harmless target, and press its hotkey. Verify that Esc and the same hotkey both stop it. Also verify that 600 seconds saves and survives reopening the editor.

## Upstream and license

Derived from SnapClick commit `b2e2dc97281d0baf1e53a7988c8ba10cbc265483`. Original code, icon assets, and Git history are retained. See [LICENSE](LICENSE) for the MIT license and original copyright notice. Older screenshots under `images/` depict the upstream application.
