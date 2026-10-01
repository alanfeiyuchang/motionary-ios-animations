# Effect families · 动效系列

A **family** groups variations of the same UI element or pattern — every slider, every spinner, every tab indicator —
so the app can show *many motion styles for one control* side by side. Navigation is
**Browse → Category (families) → Family (variations: Grid / Compare) → Detail (Variations strip)**.

Current catalog: **783 effects** in **85 families** across **15 categories**.
Counts below are the number of variations per family today; singletons (1) are families that are
explicitly waiting for more variations.

## How it is wired

- Model: `EffectFamily` (`MotionLab/Core/EffectFamily.swift`) — `id`, `category`, `name`, `summary`, `symbol`.
- Declarations: `MotionLab/Families/<Category>Families.swift`, one `enum XxxFamilies` per category with
  `static let all: [EffectFamily]` (display order) and `static let membership: [String: String]` (effect id → family id).
- Registry: `EffectFamilies` concatenates all files and exposes `family(id:)`, `family(for:)`, `effects(in:)`,
  `families(in:)`, `variations(of:)` and `search(_:category:interaction:)`.
- A family's variations are ordered by the category list (`XxxEffects.all`), not by the membership table.
- Effects with a missing/invalid membership line fall into an automatic "More · 更多" family of their category.
- Search: family names/summaries are part of every member's search haystack, and matching families are shown as
  chips above the results.
- Launch argument: `-ML_route family:<family id>` (e.g. `-ML_route family:inputs.slider`). Category pages remember
  Families vs. All Effects in `app.categoryMode`; family pages remember Grid vs. Compare in `app.familyMode`.
- `-ML_route families` opens the All Families page; `-ML_freshState YES` starts with empty recents (used by screenshots).
- The tables below are generated: run `python3 scripts/gen_families_doc.py` after changing a Families file.

## How to add a variation · 如何添加变体

1. Write the effect as usual (see [`EFFECT_GUIDE.md`](EFFECT_GUIDE.md)) with a unique id such as `inputs.notch-slider`.
2. Append it to the category list (`XxxEffects.all`). Put it right after its siblings so the family reads well.
3. In `MotionLab/Families/<Category>Families.swift`, add **one line** to `membership`:
   ```swift
   "inputs.notch-slider": "inputs.slider",
   ```
   Each effect id must appear only once (a duplicate key in a Swift dictionary literal traps at launch).
4. Only if no family fits, add an `EffectFamily(...)` to that file's `all` (id `"<category rawValue>.<slug>"` —
   `shaders.` for the Shaders category — bilingual name + one-line summary + an SF Symbol) and update this document.
5. Make the variation differ in *motion style* (curve, physics, choreography, material, feedback), not only in color:
   the family page's Compare mode plays all variations side by side.

## Families per category · 各分类的系列

### Signature Interactions · 质感交互精选

File: `MotionLab/Families/ShowcaseFamilies.swift` · list: `ShowcaseSportEffects / ShowcaseTravelEffects / ShowcaseLifeEffects` · 6 families · 57 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `showcase.chart-widgets` | Chart Widgets · 图表小组件 | 10 | `showcase.speed-line`, `showcase.fresh-snow`, `showcase.heart-zone`, `showcase.finance-card`, `showcase.sleep-timeline`, `showcase.sun-arc`, `showcase.tide-pulse`, `showcase.steps-ring`, `showcase.water-intake`, `showcase.moon-phase` |
| `showcase.live-stats` | Stat Cards · 数据卡片 | 10 | `showcase.lift-status`, `showcase.run-summary`, `showcase.weather-widget`, `showcase.flip-clock`, `showcase.ev-charge`, `showcase.compass-heading`, `showcase.reaction-time`, `showcase.lap-timer`, `showcase.battery-widget`, `showcase.calendar-agenda` |
| `showcase.media-cards` | Photo & Media Cards · 照片与媒体卡片 | 11 | `showcase.board-card`, `showcase.photo-play`, `showcase.spots-grid`, `showcase.fog-wipe`, `showcase.destination-carousel`, `showcase.polaroid-fan`, `showcase.now-playing`, `showcase.vinyl-scrub`, `showcase.voice-memo`, `showcase.podcast-chapters`, `showcase.album-flip` |
| `showcase.controls` | Pickers, Sliders & Checklists · 选择、滑动与清单控件 | 10 | `showcase.slide-to-start`, `showcase.altitude-ruler`, `showcase.gear-checklist`, `showcase.trip-chips`, `showcase.date-range`, `showcase.focus-timer`, `showcase.dimmer-lamp`, `showcase.camera-shutter`, `showcase.zoom-dial`, `showcase.tip-selector` |
| `showcase.routes` | Routes & Timelines · 路线与时间轴 | 9 | `showcase.best-line`, `showcase.flight-path`, `showcase.pin-route`, `showcase.itinerary`, `showcase.transit-line`, `showcase.elevation-profile`, `showcase.parcel-tracker`, `showcase.ride-eta`, `showcase.turn-by-turn` |
| `showcase.moments` | Moments & CTAs · 行动与高光时刻 | 7 | `showcase.go-countdown`, `showcase.get-started`, `showcase.boarding-pass`, `showcase.save-burst`, `showcase.summit-badge`, `showcase.breath-flower`, `showcase.xp-level` |

### Buttons · 按钮

File: `MotionLab/Families/ButtonsFamilies.swift` · list: `ButtonEffects` · 7 families · 67 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `buttons.press` | Press Feedback · 按压反馈 | 13 | `buttons.press-scale`, `buttons.depth-press`, `buttons.ink-ripple`, `buttons.jelly-press`, `buttons.soft-press`, `buttons.echo-press`, `buttons.stack-press`, `buttons.label-roll`, `buttons.squircle-morph`, `buttons.keycap`, `buttons.string-border`, `buttons.icon-kick`, `buttons.lit-toggle` |
| `buttons.pointer` | Finger-Aware Buttons · 指尖感应按钮 | 9 | `buttons.magnetic`, `buttons.spotlight`, `buttons.repel-letters`, `buttons.parallax-tilt`, `buttons.elastic-blob`, `buttons.gravity-dots`, `buttons.specular-glass`, `buttons.fluid-gradient`, `buttons.sticky-label` |
| `buttons.glow` | Glow & Shimmer · 辉光与流光 | 8 | `buttons.shimmer`, `buttons.glow-border`, `buttons.neon-breath`, `buttons.ember-glow`, `buttons.plasma-glass`, `buttons.holo-foil`, `buttons.comet-border`, `buttons.mesh-breath` |
| `buttons.like` | Like Button · 点赞按钮 | 9 | `buttons.like-burst`, `buttons.like-thumb`, `buttons.like-liquid`, `buttons.like-float`, `buttons.like-draw`, `buttons.like-flip`, `buttons.like-double-tap`, `buttons.clap-accumulate`, `buttons.emoji-fountain` |
| `buttons.state-morph` | State-Change Buttons · 状态切换按钮 | 11 | `buttons.add-to-cart`, `buttons.follow-morph`, `buttons.liquid-glass`, `buttons.bookmark-ribbon`, `buttons.copy-flip`, `buttons.approve-stamp`, `buttons.split-confirm`, `buttons.particle-dissolve`, `buttons.get-open`, `buttons.send-fly`, `buttons.undo-countdown` |
| `buttons.hold` | Hold to Confirm · 长按确认 | 9 | `buttons.hold-to-confirm`, `buttons.hold-ring`, `buttons.hold-charge`, `buttons.hold-trace`, `buttons.hold-segments`, `buttons.hold-fuse`, `buttons.hold-liquid`, `buttons.hold-record`, `buttons.hold-bloom` |
| `buttons.expand` | Expanding Actions · 展开式操作 | 8 | `buttons.expand-actions`, `buttons.gooey-split`, `buttons.pill-toolbar`, `buttons.unfold-menu`, `buttons.orbit-actions`, `buttons.split-dropdown`, `buttons.button-to-input`, `buttons.quantity-expand` |

### Inputs & Controls · 输入与控件

File: `MotionLab/Families/InputsFamilies.swift` · list: `InputEffects` · 8 families · 70 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `inputs.toggle` | Toggle · 开关 | 10 | `inputs.squash-toggle`, `inputs.day-night-toggle`, `inputs.inchworm-toggle`, `inputs.rolling-toggle`, `inputs.rocker-switch`, `inputs.pull-cord-toggle`, `inputs.flood-toggle`, `inputs.glass-toggle`, `inputs.lever-toggle`, `inputs.power-toggle` |
| `inputs.slider` | Slider · 滑块 | 12 | `inputs.velocity-slider`, `inputs.elastic-slider`, `inputs.range-slider`, `inputs.liquid-slider`, `inputs.magnetic-tick-slider`, `inputs.drum-slider`, `inputs.segmented-slider`, `inputs.grow-scrubber`, `inputs.volume-pill`, `inputs.hue-slider`, `inputs.bend-slider`, `inputs.center-slider` |
| `inputs.dial` | Dials & Wheels · 旋钮与滚轮 | 9 | `inputs.dial-knob`, `inputs.wheel-picker`, `inputs.jog-wheel`, `inputs.thermostat-dial`, `inputs.wind-up-timer`, `inputs.clock-picker`, `inputs.safe-dial`, `inputs.color-wheel`, `inputs.crown-scroll` |
| `inputs.text-field` | Text Field · 输入框 | 10 | `inputs.floating-label`, `inputs.password-strength`, `inputs.expanding-search`, `inputs.char-drop-field`, `inputs.token-field`, `inputs.card-input`, `inputs.ai-composer`, `inputs.counter-ring`, `inputs.voice-field`, `inputs.magic-fill` |
| `inputs.code-entry` | Code & Passcode · 验证码与密码 | 7 | `inputs.otp-code`, `inputs.passcode-pad`, `inputs.merge-pin`, `inputs.slot-reel-code`, `inputs.secure-flip-code`, `inputs.pattern-lock`, `inputs.paste-code` |
| `inputs.stepper` | Stepper · 步进器 | 7 | `inputs.rolling-stepper`, `inputs.expanding-stepper`, `inputs.accelerating-stepper`, `inputs.drag-stepper`, `inputs.delta-stepper`, `inputs.gooey-stepper`, `inputs.cart-stepper` |
| `inputs.rating` | Rating · 评分 | 6 | `inputs.star-rating`, `inputs.emoji-face-rating`, `inputs.fill-rating`, `inputs.thumbs-rating`, `inputs.nps-scale`, `inputs.reaction-slider` |
| `inputs.selection` | Checkboxes & Chips · 勾选与标签 | 9 | `inputs.checkbox-draw`, `inputs.chip-select`, `inputs.swatch-picker`, `inputs.radio-travel`, `inputs.todo-check`, `inputs.dropdown-roll`, `inputs.seat-picker`, `inputs.bubble-picker`, `inputs.radio-cards` |

### Loading & Progress · 加载与进度

File: `MotionLab/Families/LoadingFamilies.swift` · list: `LoadingEffects` · 6 families · 61 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `loading.spinner` | Spinner · 旋转加载 | 15 | `loading.arc-spinner`, `loading.orbit-dots`, `loading.activity-petals`, `loading.gooey-orbit`, `loading.gyroscope`, `loading.flip-tile`, `loading.infinity-comet`, `loading.dna-helix`, `loading.shape-shifter`, `loading.folding-cube`, `loading.hourglass`, `loading.pendulum-wave`, `loading.atom-orbit`, `loading.squash-ball`, `loading.snake-pixels` |
| `loading.pulse` | Dots & Pulses · 跳动与脉冲 | 7 | `loading.dot-bounce`, `loading.audio-wave`, `loading.pulse-rings`, `loading.square-grid`, `loading.heartbeat`, `loading.voice-orb`, `loading.ripple-drop` |
| `loading.progress-bar` | Progress Bar · 进度条 | 12 | `loading.glow-bar`, `loading.story-bars`, `loading.indeterminate-bar`, `loading.segment-bar`, `loading.liquid-bar`, `loading.tooltip-bar`, `loading.candy-stripes`, `loading.stage-loader`, `loading.percent-pill`, `loading.milestones`, `loading.buffer-scrub`, `loading.file-queue` |
| `loading.progress-ring` | Progress Ring · 进度环 | 10 | `loading.progress-ring`, `loading.liquid-fill`, `loading.tick-ring`, `loading.install-pie`, `loading.elastic-ring`, `loading.ring-to-check`, `loading.dash-flow-ring`, `loading.countdown-ring`, `loading.orbit-ring`, `loading.half-gauge` |
| `loading.button` | Loading Button · 加载按钮 | 8 | `loading.load-button`, `loading.download-button`, `loading.fill-button`, `loading.dots-button`, `loading.trace-button`, `loading.launch-button`, `loading.pay-button`, `loading.sync-button` |
| `loading.placeholder` | Placeholders · 占位加载 | 9 | `loading.skeleton-shimmer`, `loading.blur-up`, `loading.ai-generating`, `loading.breathing-skeleton`, `loading.mosaic-resolve`, `loading.stream-in`, `loading.scan-reveal`, `loading.skeleton-resolve`, `loading.map-tiles` |

### Feedback & Alerts · 反馈与提示

File: `MotionLab/Families/FeedbackFamilies.swift` · list: `FeedbackEffects` · 6 families · 57 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `feedback.toast` | Toasts & Banners · 吐司与横幅 | 12 | `feedback.toast`, `feedback.island-pill`, `feedback.connection-banner`, `feedback.undo-snackbar`, `feedback.stacked-banners`, `feedback.hinge-toast`, `feedback.morph-toast`, `feedback.progress-toast`, `feedback.achievement-banner`, `feedback.swipe-toast`, `feedback.expand-toast`, `feedback.notch-drop` |
| `feedback.success` | Success · 成功反馈 | 11 | `feedback.success-check`, `feedback.confetti`, `feedback.copy-confirm`, `feedback.spark-burst`, `feedback.level-up`, `feedback.payment-done`, `feedback.fireworks`, `feedback.coin-reward`, `feedback.order-box`, `feedback.all-done-list`, `feedback.sticker-slap` |
| `feedback.error` | Errors & Validation · 错误与校验 | 8 | `feedback.error-shake`, `feedback.inline-validation`, `feedback.glitch-error`, `feedback.limit-bounce`, `feedback.faceid-fail`, `feedback.card-declined`, `feedback.retry-countdown`, `feedback.empty-state` |
| `feedback.badge` | Badges & Reactions · 角标与回应 | 9 | `feedback.badge-bounce`, `feedback.reaction-picker`, `feedback.streak-flame`, `feedback.presence-ping`, `feedback.floating-hearts`, `feedback.counter-badge`, `feedback.typing-bubble`, `feedback.new-messages-pill`, `feedback.live-badge` |
| `feedback.overlay` | Alerts & Overlays · 弹窗与引导 | 10 | `feedback.alert-pop`, `feedback.coach-spotlight`, `feedback.receding-sheet`, `feedback.tip-popover`, `feedback.drop-alert`, `feedback.silent-hud`, `feedback.autosave-pulse`, `feedback.screenshot-thumb`, `feedback.permission-dialog`, `feedback.action-sheet` |
| `feedback.refresh` | Pull to Refresh · 下拉刷新 | 7 | `feedback.pull-refresh`, `feedback.goo-refresh`, `feedback.sun-refresh`, `feedback.letter-refresh`, `feedback.dots-refresh`, `feedback.thread-refresh`, `feedback.rocket-refresh` |

### Transitions & Morphing · 转场与形变

File: `MotionLab/Families/MorphFamilies.swift` · list: `MorphEffects` · 5 families · 50 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `morph.container` | Button to Surface · 按钮变容器 | 11 | `morph.button-to-card`, `morph.fab-menu`, `morph.zoom-sheet`, `morph.search-expand`, `morph.island-expand`, `morph.notification-expand`, `morph.avatar-profile`, `morph.date-cell-expand`, `morph.chip-filter-panel`, `morph.fab-compose`, `morph.bubble-context` |
| `morph.hero` | Hero & Zoom Transitions · 英雄与缩放转场 | 10 | `morph.hero-card`, `morph.native-zoom`, `morph.mini-player`, `morph.folder-open`, `morph.gallery-zoom`, `morph.app-launch`, `morph.story-open`, `morph.pin-to-card`, `morph.fly-to-cart`, `morph.thumb-to-player` |
| `morph.shape` | Shape Morph · 形状形变 | 10 | `morph.shape-morph`, `morph.liquid-glass`, `morph.polygon-sides`, `morph.corner-cascade`, `morph.line-to-ring`, `morph.digit-morph`, `morph.blob-cycle`, `morph.icon-morph-set`, `morph.particles-assemble`, `morph.wave-circle` |
| `morph.reveal` | Reveal & Replace · 揭示与替换 | 10 | `morph.circular-reveal`, `morph.blur-replace`, `morph.blinds-reveal`, `morph.feather-wipe`, `morph.tile-mosaic`, `morph.page-curl`, `morph.shutter-iris`, `morph.portal-zoom`, `morph.split-doors`, `morph.drip-reveal` |
| `morph.layout` | Layout Transitions · 布局转场 | 9 | `morph.staggered-transition`, `morph.list-grid`, `morph.cube-transition`, `morph.grid-to-ring`, `morph.sort-hop`, `morph.calendar-week-month`, `morph.filter-reflow`, `morph.avatar-stack-expand`, `morph.masonry-shuffle` |

### Navigation & Menus · 导航与菜单

File: `MotionLab/Families/NavigationFamilies.swift` · list: `NavigationEffects` · 6 families · 57 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `navigation.tab-indicator` | Tab Indicator · 标签指示器 | 11 | `navigation.tab-indicator`, `navigation.segmented-thumb`, `navigation.elastic-underline`, `navigation.gooey-tab`, `navigation.spotlight-tab`, `navigation.hop-dot-tab`, `navigation.trace-tab`, `navigation.folder-tabs`, `navigation.bracket-focus`, `navigation.title-scale-tabs`, `navigation.glow-underline` |
| `navigation.tab-bar` | Tab Bars & Docks · 标签栏与程序坞 | 10 | `navigation.collapsing-tab-bar`, `navigation.dock-magnify`, `navigation.notch-tab-bar`, `navigation.search-tab-morph`, `navigation.ripple-tab-bar`, `navigation.glass-tab-bar`, `navigation.bubble-tab-bar`, `navigation.curve-fab-bar`, `navigation.island-bar-player`, `navigation.icon-pop-bar` |
| `navigation.page-indicator` | Page & Step Indicators · 页码与步骤指示 | 8 | `navigation.page-dots`, `navigation.step-progress`, `navigation.number-pager`, `navigation.timer-dots`, `navigation.scrolling-dots`, `navigation.page-control-scrub`, `navigation.onboarding-morph`, `navigation.filmstrip-scrubber` |
| `navigation.drawer` | Drawers & Sidebars · 抽屉与侧栏 | 8 | `navigation.side-drawer-3d`, `navigation.sidebar-rail`, `navigation.parallax-drawer`, `navigation.elastic-drawer`, `navigation.popout-drawer`, `navigation.space-switcher`, `navigation.card-stack-drawer`, `navigation.split-pane` |
| `navigation.sheet` | Pages & Sheets · 页面与面板 | 9 | `navigation.push-parallax`, `navigation.bottom-sheet`, `navigation.stacked-sheets`, `navigation.fade-through`, `navigation.floating-sheet`, `navigation.fluid-sheet`, `navigation.peek-pop`, `navigation.top-curtain`, `navigation.title-handoff` |
| `navigation.menu` | Menus · 菜单 | 11 | `navigation.radial-menu`, `navigation.context-popover`, `navigation.context-menu-lift`, `navigation.fold-menu`, `navigation.overlay-menu`, `navigation.command-palette`, `navigation.context-toolbar`, `navigation.breadcrumbs`, `navigation.submenu-slide`, `navigation.app-switcher`, `navigation.magnify-menu` |

### Cards · 卡片

File: `MotionLab/Families/CardsFamilies.swift` · list: `CardEffects` · 5 families · 52 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `cards.tilt` | Tilt & Foil · 倾斜与光泽 | 9 | `cards.tilt-3d`, `cards.holographic`, `cards.parallax-layers`, `cards.press-tilt`, `cards.rim-light`, `cards.sticker-peel`, `cards.spotlight-border`, `cards.bend-flex`, `cards.levitate` |
| `cards.flip` | Flip & Reveal · 翻转与揭示 | 11 | `cards.flip`, `cards.scratch-reveal`, `cards.hinge-reveal`, `cards.tile-flip`, `cards.scrub-flip`, `cards.book-open`, `cards.number-reveal`, `cards.prism-faces`, `cards.fold-half`, `cards.slide-door`, `cards.stamp-card` |
| `cards.swipe` | Card Swipe · 卡片滑动 | 10 | `cards.swipe-stack`, `cards.shuffle`, `cards.jelly-swipe`, `cards.turn-swipe`, `cards.toss-swipe`, `cards.tear-off`, `cards.rewind-swipe`, `cards.swap-places`, `cards.crumple-dismiss`, `cards.story-tap` |
| `cards.stack` | Stacks & Decks · 堆叠与牌组 | 11 | `cards.wallet-stack`, `cards.fan-deck`, `cards.notification-stack`, `cards.stacking-scroll`, `cards.cascade-spread`, `cards.rolodex`, `cards.time-machine`, `cards.deal-hand`, `cards.glass-stack`, `cards.isometric-explode`, `cards.scatter-gather` |
| `cards.expand` | Expand & Peek · 展开与预览 | 11 | `cards.peek`, `cards.accordion`, `cards.bento-expand`, `cards.detent-expand`, `cards.origami-unfold`, `cards.widget-resize`, `cards.plan-switch`, `cards.receipt-print`, `cards.split-reveal`, `cards.collapse-chip`, `cards.gift-unwrap` |

### Scroll & Lists · 滚动与列表

File: `MotionLab/Families/ScrollFamilies.swift` · list: `ScrollEffects` · 5 families · 52 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `scroll.carousel` | Carousel · 轮播 | 13 | `scroll.cover-flow`, `scroll.paging-carousel`, `scroll.infinite-carousel`, `scroll.stack-carousel`, `scroll.cube-carousel`, `scroll.parallax-pager`, `scroll.fan-carousel`, `scroll.ring-carousel`, `scroll.velocity-skew`, `scroll.zoom-focus`, `scroll.deck-paging`, `scroll.expanding-strips`, `scroll.page-turn` |
| `scroll.header` | Scroll Headers · 滚动头部 | 11 | `scroll.stretchy-header`, `scroll.collapsing-header`, `scroll.sticky-sections`, `scroll.hiding-header`, `scroll.pill-header`, `scroll.profile-header`, `scroll.pull-search`, `scroll.pinned-zoom`, `scroll.weather-collapse`, `scroll.sticky-tabs-sync`, `scroll.nav-blur-title` |
| `scroll.list-motion` | List Motion · 列表动效 | 12 | `scroll.transition-list`, `scroll.parallax-cards`, `scroll.staggered-entrance`, `scroll.insert-remove`, `scroll.elastic-list`, `scroll.fold-edge`, `scroll.fisheye-list`, `scroll.text-reveal`, `scroll.riding-avatar`, `scroll.timeline-fill`, `scroll.stack-under-header`, `scroll.mask-reveal` |
| `scroll.wheel` | Wheels & Dials · 滚轮与转盘 | 8 | `scroll.wheel-list`, `scroll.arc-dial`, `scroll.ruler-picker`, `scroll.rotary-wheel`, `scroll.slot-reels`, `scroll.date-strip`, `scroll.spiral-list`, `scroll.time-columns` |
| `scroll.indicator` | Progress & Index · 进度与索引 | 8 | `scroll.progress-indicator`, `scroll.index-scrubber`, `scroll.minimap`, `scroll.chapter-rail`, `scroll.liquid-scrollbar`, `scroll.top-fab-ring`, `scroll.windowed-dots`, `scroll.date-bubble` |

### Text & Numbers · 文字与数字

File: `MotionLab/Families/TextFamilies.swift` · list: `TextEffects` · 5 families · 41 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `text.number` | Number Counter · 数字滚动 | 9 | `text.numeric-counter`, `text.odometer`, `text.split-flap`, `text.slot-reel`, `text.gravity-digits`, `text.count-up`, `text.seven-segment`, `text.price-tick`, `text.countdown` |
| `text.reveal` | Text Reveal · 文字揭示 | 11 | `text.blur-reveal`, `text.typewriter`, `text.scramble`, `text.flip-in-3d`, `text.masked-lines`, `text.elastic-letters`, `text.light-sweep`, `text.tracking-in`, `text.ai-stream`, `text.handwriting`, `text.liquid-fill` |
| `text.kinetic` | Kinetic Type · 动态字形 | 7 | `text.wave`, `text.circular-badge`, `text.variable-weight`, `text.spring-chain`, `text.squash-hop`, `text.path-flow`, `text.magnet-letters` |
| `text.emphasis` | Light & Emphasis · 光效与强调 | 8 | `text.shimmer`, `text.highlighter`, `text.synced-lyrics`, `text.scribble-circle`, `text.neon-sign`, `text.gradient-flow`, `text.squiggle-underline`, `text.spotlight-mask` |
| `text.ticker` | Rotating & Ticker · 轮播与跑马灯 | 6 | `text.rotating-words`, `text.marquee`, `text.news-ticker`, `text.word-drum`, `text.type-cycle`, `text.letter-morph` |

### Icons & Symbols · 图标与符号

File: `MotionLab/Families/IconsFamilies.swift` · list: `IconEffects` · 5 families · 36 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `icons.symbol-effects` | SF Symbol Effects · SF 符号特效 | 5 | `icons.bounce`, `icons.replace`, `icons.ripple-grid`, `icons.draw-on`, `icons.appear-disappear` |
| `icons.ambient` | Ambient Icons · 常驻动态图标 | 6 | `icons.variable-color`, `icons.wiggle-rotate-breathe`, `icons.weather`, `icons.radar-ping`, `icons.ai-sparkle`, `icons.live-waveform` |
| `icons.glyph-morph` | Glyph Morph · 图标形变 | 8 | `icons.play-pause`, `icons.hamburger-morph`, `icons.plus-close`, `icons.chevron-flip`, `icons.search-close`, `icons.sun-moon`, `icons.eye-blink`, `icons.mute-slash` |
| `icons.status` | Status Icons · 状态图标 | 7 | `icons.checkmark-draw`, `icons.download`, `icons.padlock`, `icons.wifi-connect`, `icons.battery-charge`, `icons.cloud-sync`, `icons.faceid-scan` |
| `icons.action` | Action Icons · 动作图标 | 10 | `icons.heart-like`, `icons.bell-ring`, `icons.trash-delete`, `icons.paper-plane`, `icons.bookmark-save`, `icons.star-burst`, `icons.pin-drop`, `icons.mic-record`, `icons.archive-box`, `icons.refresh-spin` |

### Gestures & Physics · 手势与物理

File: `MotionLab/Families/GesturesFamilies.swift` · list: `GestureEffects` · 6 families · 43 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `gestures.drag-spring` | Drag & Spring · 拖拽与弹簧 | 9 | `gestures.rubber-band`, `gestures.jelly-stretch`, `gestures.spring-chain`, `gestures.gooey-blobs`, `gestures.magnetic-snap`, `gestures.elastic-tether`, `gestures.pendulum-swing`, `gestures.joystick`, `gestures.sticky-goo` |
| `gestures.throw` | Throw & Snap · 抛掷与吸附 | 7 | `gestures.fling-inertia`, `gestures.pip-snap`, `gestures.drag-dismiss`, `gestures.gravity-toss`, `gestures.detent-sheet`, `gestures.paper-toss`, `gestures.spin-wheel` |
| `gestures.physics` | Physics Toys · 物理模拟 | 8 | `gestures.charge-burst`, `gestures.verlet-rope`, `gestures.newtons-cradle`, `gestures.coil-spring`, `gestures.orbit-slingshot`, `gestures.ball-pit`, `gestures.soft-body`, `gestures.cloth-grid` |
| `gestures.list` | List Gestures · 列表手势 | 7 | `gestures.swipe-actions`, `gestures.drag-reorder`, `gestures.swipe-complete`, `gestures.staged-swipe`, `gestures.drag-select`, `gestures.pull-to-create`, `gestures.kanban-drag` |
| `gestures.pinch` | Pinch, Zoom & Loupe · 捏合缩放与放大镜 | 6 | `gestures.pinch-rotate`, `gestures.magnifier-loupe`, `gestures.photo-viewer`, `gestures.pinch-grid`, `gestures.pinch-open`, `gestures.zoom-timeline` |
| `gestures.slide-confirm` | Slide to Confirm · 滑动确认 | 6 | `gestures.slide-to-confirm`, `gestures.stretch-slide`, `gestures.notch-slide`, `gestures.arc-slide`, `gestures.pull-cord`, `gestures.swipe-up-unlock` |

### Data & Charts · 数据与图表

File: `MotionLab/Families/ChartsFamilies.swift` · list: `ChartEffects` · 5 families · 36 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `charts.bar` | Bar Charts · 柱状图 | 8 | `charts.bar-grow`, `charts.bar-race`, `charts.stacked-bars`, `charts.liquid-bars`, `charts.brick-bars`, `charts.waterfall`, `charts.lollipop`, `charts.range-brush` |
| `charts.line` | Line Charts · 折线图 | 8 | `charts.line-draw`, `charts.scrub-tooltip`, `charts.sparkline-stream`, `charts.range-morph`, `charts.candlestick-live`, `charts.stacked-area`, `charts.ecg-live`, `charts.line-compare` |
| `charts.ring` | Rings & Gauges · 圆环与仪表 | 7 | `charts.donut-explode`, `charts.gauge-needle`, `charts.activity-rings`, `charts.segmented-gauge`, `charts.rose-bloom`, `charts.radial-bars`, `charts.sunburst` |
| `charts.morph` | Chart Morph · 图表形变 | 6 | `charts.radar-morph`, `charts.donut-to-bars`, `charts.bars-to-line`, `charts.scatter-histogram`, `charts.grouped-stacked`, `charts.treemap` |
| `charts.kpi` | Stat Tiles & Unit Grids · 指标卡与格阵图 | 7 | `charts.heatmap-cascade`, `charts.kpi-count-up`, `charts.odometer-kpi`, `charts.bullet-kpi`, `charts.waffle-kpi`, `charts.funnel-flow`, `charts.trend-pill` |

### Backgrounds & Ambience · 背景与氛围

File: `MotionLab/Families/BackgroundsFamilies.swift` · list: `BackgroundEffects` · 5 families · 53 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `backgrounds.gradient` | Mesh & Ambient Gradients · 网格与氛围渐变 | 12 | `backgrounds.mesh-gradient`, `backgrounds.intelligence-glow`, `backgrounds.aurora`, `backgrounds.grain-gradient`, `backgrounds.conic-halo`, `backgrounds.light-leak`, `backgrounds.wave-band`, `backgrounds.godrays`, `backgrounds.holo-foil`, `backgrounds.silk-folds`, `backgrounds.sunset-horizon`, `backgrounds.pearl` |
| `backgrounds.particles` | Particle Fields · 粒子场 | 11 | `backgrounds.particle-repulsion`, `backgrounds.fireflies`, `backgrounds.bokeh`, `backgrounds.constellation`, `backgrounds.flow-field`, `backgrounds.galaxy`, `backgrounds.boids`, `backgrounds.matrix-rain`, `backgrounds.embers`, `backgrounds.magnetic-lines`, `backgrounds.shape-swarm` |
| `backgrounds.liquid` | Liquid & Blobs · 液态与融球 | 10 | `backgrounds.metaballs`, `backgrounds.glow-orb`, `backgrounds.lava-lamp`, `backgrounds.ink-bloom`, `backgrounds.slosh-tank`, `backgrounds.marbling`, `backgrounds.bubbles`, `backgrounds.ferrofluid`, `backgrounds.pond-ripples`, `backgrounds.paint-pour` |
| `backgrounds.weather` | Weather · 天气氛围 | 9 | `backgrounds.rain`, `backgrounds.snowfall`, `backgrounds.window-droplets`, `backgrounds.rolling-fog`, `backgrounds.autumn-wind`, `backgrounds.thunderstorm`, `backgrounds.shooting-stars`, `backgrounds.sakura`, `backgrounds.sun-clouds` |
| `backgrounds.waves-grids` | Waves, Grids & Warp · 波浪、网格与跃迁 | 11 | `backgrounds.starfield-warp`, `backgrounds.halftone-flow`, `backgrounds.sine-waves`, `backgrounds.synthwave-grid`, `backgrounds.shockwave-grid`, `backgrounds.dot-wave`, `backgrounds.topo-contours`, `backgrounds.hex-pulse`, `backgrounds.iso-cubes`, `backgrounds.ridge-lines`, `backgrounds.circuit-traces` |

### Shaders & Materials · 着色器与材质

File: `MotionLab/Families/ShadersFamilies.swift` · list: `ShaderEffects` · 5 families · 51 effects

| Family id | Name · 名称 | Count | Variations (effect ids) |
|---|---|---:|---|
| `shaders.distortion` | Ripple & Distortion · 涟漪与扭曲 | 12 | `shader.ripple`, `shader.wave`, `shader.swirl`, `shader.chromatic-drag`, `shader.jelly-press`, `shader.heat-haze`, `shader.shockwave`, `shader.black-hole`, `shader.underwater`, `shader.wind-smear`, `shader.crumple`, `shader.touch-trail` |
| `shaders.transition` | Shader Transitions · 着色器转场 | 11 | `shader.pixelate`, `shader.dissolve`, `shader.edge-scan`, `shader.liquid-wipe`, `shader.tile-scatter`, `shader.melt`, `shader.ink-bleed`, `shader.zoom-blur`, `shader.displace-fade`, `shader.glitch-cut`, `shader.curl-flip` |
| `shaders.glass` | Glass & Lens · 玻璃与透镜 | 9 | `shader.magnifier`, `shader.glassmorphism`, `shader.liquid-glass-lens`, `shader.progressive-blur`, `shader.reeded-glass`, `shader.frost-grow`, `shader.prism`, `shader.rain-glass`, `shader.glass-blocks` |
| `shaders.retro` | Retro & Print · 复古与印刷 | 10 | `shader.glitch`, `shader.crt`, `shader.halftone`, `shader.dither`, `shader.vhs`, `shader.ascii`, `shader.thermal`, `shader.super8`, `shader.night-vision`, `shader.sketch-edges` |
| `shaders.generative` | Generative Light · 生成光效 | 9 | `shader.plasma`, `shader.kaleidoscope`, `shader.caustics`, `shader.voronoi-cells`, `shader.tunnel`, `shader.liquid-chrome`, `shader.nebula`, `shader.fire`, `shader.lightning-arcs` |
