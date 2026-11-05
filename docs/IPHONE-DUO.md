# iPhone Duo

How Motionary fits the foldable, and how to check it. Measured on the `iPhone Duo` simulator
(iOS 27.1 runtime, Xcode 27.1), 2026-11-04.

## The two screens

| | pixels | points | size class |
|---|---|---|---|
| outer (closed) | 1398 × 2034 | 466 × 678 | compact width, regular height |
| inner (open) | 2007 × 2853 | 669 × 951 | regular / regular, and it **ignores the iPhone portrait lock**, so expect 951 × 669 too |

On the outer screen the status bar is an 84pt strip down the **trailing** edge (island at the
top), and the system tab bar and toolbar buttons stand vertically in that strip. There is no top
status bar.

## What the app does about it

- **Built with Xcode 27.1.** An app built with an older SDK is kept clear of the strip instead of
  running to the screen edge, so `.github/workflows/testflight.yml` runs on the `xcode-27` image
  and pins `Xcode_27.1.app` (the image's `Xcode_27.2.app` is a release candidate).
- **Layout follows size classes, not the device.** The inner screen gets the same regular-width
  layout as iPad: adaptive grids, the top tab bar, wide detail pages. No code checks the idiom.
- **"Animate previews" follows the width class too** (`AnimatePreviews` in RootView.swift). Until the
  toggle is flipped, regular-width windows show still thumbnails and compact ones play them, so a Duo
  animates when closed and goes still when opened. It used to key off the iPad idiom, and the Duo is a
  phone: its inner screen played a whole wide grid live and scrolling stuttered.
- **The Featured row keeps its focus state to itself.** On the inner screen three or four Featured cards
  are on screen, and each snap used to rebuild the whole Browse page (the focus index lived on
  BrowseView) and swap the focused card's shadow plate, which re-laid the card out every frame of the
  lift. Measured on a Duo with an automated sweep of the row: 6% of frame time lost before, 0–1% with
  `FeaturedRow` owning the state and the two shadows cross-fading (`GlossCardBackground(liftable:)`).
  A finger swipe crosses several cards a second, so by hand it was far worse than the sweep.
- **Backgrounds run behind the strip.** The Browse hero glow ignores the horizontal safe area as well
  as the top, otherwise it stops short and leaves a black column under the clock.
- **Horizontal rows** (Featured, families, chips, variations) scroll under the strip like content
  under any bar; the first item at rest is never covered and the last one scrolls clear.
- **Thumbnails survive a fold.** Still-preview cache keys include the render scale, which follows
  the card size, so unfolding renders fresh stills instead of stretching the outer screen's.

## Checking it

On a real Duo, `-ML_perfLog YES` logs every stall over 50 ms to `Documents/perf-log.txt` (see
`PerfLog.swift`); Instruments cannot attach to it over Wi-Fi.

There is no `simctl` verb to open or close the Duo; only DeviceHub's GUI changes pose. The
simulator sits closed, so the app runs on the outer screen:

```bash
xcrun simctl io <duo-udid> screenshot --display=1 outer.png   # display 1 = outer (LCD)
```

For the inner screen's regular layout, iPad mini (744 × 1133, iOS 27.0 runtime; 27.1 has no iPad
simulators) is the closest stand-in with real size classes and insets. Rendering RootView into a
fixed 669 × 951 frame does not work as a check: the system tab bar reads the window's traits, not
SwiftUI's environment.
