# ClickLoop

A small native macOS auto-clicker, forked from [mmmelson/SnapClick](https://github.com/mmmelson/SnapClick). Built with SwiftUI and AppKit; macOS 13 or later.

[中文](README.zh-CN.md)

## What's new

- **Long durations:** enter positive durations beyond 60 seconds, including minutes or hours (in seconds).
- **Unlimited clicking:** turn on **Run indefinitely**. Click Count and Every (sec) set the rate: `10 / 1` means 10 clicks per second, continuously until stopped.
- **Reliable hotkeys:** the window shows whether monitoring is ready or permission is missing. Granting Accessibility recovers automatically. Matched shortcuts are consumed so the foreground app does not also act on them.
- **Accurate scheduling:** clicks run on a dedicated serial timer with App Nap protection during execution; click events do not inherit shortcut modifiers.
- **Clicking indicator:** the menu bar shows a green click icon and **Clicking** while a preset is executing, then returns to its idle icon.
- **Immediate stop:** move the mouse (including dragging), press the same preset hotkey again, press **Esc**, or use **Stop clicking** in the main window or menu-bar popover. Disabling presets, editing a preset, and quitting also stop active clicks.
- **Launch animation:** the app icon animates in the window header and the menu-bar icon pulses briefly at launch. Reduce Motion is respected.

Finite mode keeps SnapClick's count/rate convention: the first click happens immediately, subsequent clicks are spaced by `duration / count`, and execution ends at the requested count. The maximum rate remains 200 CPS. Keep the pointer stationary over the target while clicking; timing is best effort under system load.

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

Smoke checks cover long durations, invalid input and rate limits, finite completion, unlimited repetition, immediate cancellation, replacing a running preset, and new/legacy preset persistence. They inject a click sink and **never send mouse events**. For a manual end-to-end check, grant Accessibility, set a preset to 10 clicks / 1 second with Run indefinitely enabled, move over a harmless target, and press its hotkey. Verify that the menu bar shows **Clicking**; moving the mouse stops clicks and restores the idle icon. Restart and verify that Esc and the same hotkey also stop it. Also verify that 600 seconds saves and survives reopening the editor.

`Tests/ClickTarget.html` is a harmless browser counter for end-to-end testing: open it in a browser, place the pointer in the blue area, reload to reset the counter, and trigger a 100-click / 1-second preset. Expect 100 mouse-down/up pairs, 100 click events, about 100 CPS, and zero modified clicks. The last-burst counter excludes manual clicks separated by more than one second. A physical-keyboard check on 2026-10-11 delivered all 100 clicks at 97.17 CPS in Chrome, with no shortcut modifiers; the internal timing check measured 100.00 CPS. The internal tests also measure 100 CPS while blocking the main thread and check hotkey consumption, held-key suppression, Esc routing, and immediate movement/drag cancellation in finite and unlimited modes.

Local ad-hoc builds have a new code signature after rebuilding. macOS may require removing/re-adding ClickLoop in Accessibility even if the old entry still appears enabled. The app reports its actual authorization and listener state.

## Upstream and license

Derived from SnapClick commit `b2e2dc97281d0baf1e53a7988c8ba10cbc265483`. Original code, icon assets, and Git history are retained. See [LICENSE](LICENSE) for the MIT license and original copyright notice. Older screenshots under `images/` depict the upstream application.
