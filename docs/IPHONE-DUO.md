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
- **Layout follows size classes, not the device.** The only idiom check left is the iPad default for
  "Animate previews" (`MotionLabApp`), which is a performance choice, not layout. The inner screen
  gets the same regular-width layout as iPad: adaptive grids, the top tab bar, wide detail pages.
- **Backgrounds run behind the strip.** The Browse hero glow ignores the horizontal safe area as well
  as the top, otherwise it stops short and leaves a black column under the clock.
- **Horizontal rows** (Featured, families, chips, variations) scroll under the strip like content
  under any bar; the first item at rest is never covered and the last one scrolls clear.
- **Thumbnails survive a fold.** Still-preview cache keys include the render scale, which follows
  the card size, so unfolding renders fresh stills instead of stretching the outer screen's.

## Checking it

There is no `simctl` verb to open or close the Duo; only DeviceHub's GUI changes pose. The
simulator sits closed, so the app runs on the outer screen:

```bash
xcrun simctl io <duo-udid> screenshot --display=1 outer.png   # display 1 = outer (LCD)
```

For the inner screen's regular layout, iPad mini (744 × 1133, iOS 27.0 runtime; 27.1 has no iPad
simulators) is the closest stand-in with real size classes and insets. Rendering RootView into a
fixed 669 × 951 frame does not work as a check: the system tab bar reads the window's traits, not
SwiftUI's environment.
