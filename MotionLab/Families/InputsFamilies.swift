import Foundation

/// Families (variation groups) of `EffectCategory.inputs`.
///
/// To add a variation: append the effect to `InputEffects.all`, then add one
/// `"<effect id>": "<family id>",` line to `membership` below. Each effect id may appear only once
/// (a duplicate dictionary key traps at launch). See docs/FAMILIES.md.
enum InputsFamilies {
    static let all: [EffectFamily] = [
        EffectFamily(
            id: "inputs.toggle",
            category: .inputs,
            name: L("Toggle", "开关"),
            summary: L("On/off switches with different ways of travelling between states.", "开与关之间以不同方式过渡的开关。"),
            symbol: "switch.2"
        ),
        EffectFamily(
            id: "inputs.slider",
            category: .inputs,
            name: L("Slider", "滑块"),
            summary: L("Dragging a value: liquid, magnetic, 3D drum, LED, rubber-band, velocity-aware and range sliders, and a media scrubber that grows under the finger.", "拖动取值：液面、磁吸、3D 滚筒、LED、橡皮筋、感知速度与区间滑块，以及按住变粗的媒体进度条。"),
            symbol: "slider.horizontal.3"
        ),
        EffectFamily(
            id: "inputs.dial",
            category: .inputs,
            name: L("Dials & Wheels", "旋钮与滚轮"),
            summary: L("Rotary knobs and wheel pickers that click into detents.", "带刻度吸附的旋钮与滚轮选择器。"),
            symbol: "dial.max"
        ),
        EffectFamily(
            id: "inputs.text-field",
            category: .inputs,
            name: L("Text Field", "输入框"),
            summary: L("Fields whose labels, underlines and meters animate as you type.", "标签、下划线与强度条随输入而动的输入框。"),
            symbol: "character.cursor.ibeam"
        ),
        EffectFamily(
            id: "inputs.code-entry",
            category: .inputs,
            name: L("Code & Passcode", "验证码与密码"),
            summary: L("Digit boxes and keypads that pop, shake on errors and celebrate success.", "数字格与键盘：输入弹出、错误抖动、成功庆祝。"),
            symbol: "circle.grid.3x3.fill"
        ),
        EffectFamily(
            id: "inputs.stepper",
            category: .inputs,
            name: L("Stepper", "步进器"),
            summary: L("Plus/minus steppers whose number rolls in the direction of the change.", "数字朝变化方向滚动的加减步进器。"),
            symbol: "plus.forwardslash.minus"
        ),
        EffectFamily(
            id: "inputs.rating",
            category: .inputs,
            name: L("Rating", "评分"),
            summary: L("Stars and scales that fill in a wave and pop as you rate.", "评分时以波浪填充并弹起的星级与刻度。"),
            symbol: "star.fill"
        ),
        EffectFamily(
            id: "inputs.selection",
            category: .inputs,
            name: L("Checkboxes & Chips", "勾选与标签"),
            summary: L("Checkboxes, tag chips and swatches that mark a choice with motion.", "以动效标记选择的勾选框、标签与色板。"),
            symbol: "checkmark.circle.fill"
        ),
    ]

    static let membership: [String: String] = [
        // Toggle
        "inputs.squash-toggle": "inputs.toggle",
        "inputs.day-night-toggle": "inputs.toggle",
        "inputs.inchworm-toggle": "inputs.toggle",
        "inputs.rolling-toggle": "inputs.toggle",
        "inputs.rocker-switch": "inputs.toggle",
        "inputs.pull-cord-toggle": "inputs.toggle",
        "inputs.flood-toggle": "inputs.toggle",
        "inputs.glass-toggle": "inputs.toggle",
        "inputs.lever-toggle": "inputs.toggle",
        "inputs.power-toggle": "inputs.toggle",
        // Slider
        "inputs.velocity-slider": "inputs.slider",
        "inputs.elastic-slider": "inputs.slider",
        "inputs.range-slider": "inputs.slider",
        "inputs.liquid-slider": "inputs.slider",
        "inputs.magnetic-tick-slider": "inputs.slider",
        "inputs.drum-slider": "inputs.slider",
        "inputs.segmented-slider": "inputs.slider",
        "inputs.grow-scrubber": "inputs.slider",
        "inputs.volume-pill": "inputs.slider",
        "inputs.hue-slider": "inputs.slider",
        "inputs.bend-slider": "inputs.slider",
        "inputs.center-slider": "inputs.slider",
        // Dials & wheels
        "inputs.dial-knob": "inputs.dial",
        "inputs.wheel-picker": "inputs.dial",
        "inputs.jog-wheel": "inputs.dial",
        "inputs.thermostat-dial": "inputs.dial",
        "inputs.wind-up-timer": "inputs.dial",
        "inputs.clock-picker": "inputs.dial",
        "inputs.safe-dial": "inputs.dial",
        "inputs.color-wheel": "inputs.dial",
        "inputs.crown-scroll": "inputs.dial",
        // Text field
        "inputs.floating-label": "inputs.text-field",
        "inputs.password-strength": "inputs.text-field",
        "inputs.expanding-search": "inputs.text-field",
        "inputs.char-drop-field": "inputs.text-field",
        "inputs.token-field": "inputs.text-field",
        "inputs.card-input": "inputs.text-field",
        "inputs.ai-composer": "inputs.text-field",
        "inputs.counter-ring": "inputs.text-field",
        "inputs.voice-field": "inputs.text-field",
        "inputs.magic-fill": "inputs.text-field",
        // Code & passcode
        "inputs.otp-code": "inputs.code-entry",
        "inputs.passcode-pad": "inputs.code-entry",
        "inputs.merge-pin": "inputs.code-entry",
        "inputs.slot-reel-code": "inputs.code-entry",
        "inputs.secure-flip-code": "inputs.code-entry",
        "inputs.pattern-lock": "inputs.code-entry",
        "inputs.paste-code": "inputs.code-entry",
        // Stepper
        "inputs.rolling-stepper": "inputs.stepper",
        "inputs.expanding-stepper": "inputs.stepper",
        "inputs.accelerating-stepper": "inputs.stepper",
        "inputs.drag-stepper": "inputs.stepper",
        "inputs.delta-stepper": "inputs.stepper",
        "inputs.gooey-stepper": "inputs.stepper",
        "inputs.cart-stepper": "inputs.stepper",
        // Rating
        "inputs.star-rating": "inputs.rating",
        "inputs.emoji-face-rating": "inputs.rating",
        "inputs.fill-rating": "inputs.rating",
        "inputs.thumbs-rating": "inputs.rating",
        "inputs.nps-scale": "inputs.rating",
        "inputs.reaction-slider": "inputs.rating",
        // Checkboxes & chips
        "inputs.checkbox-draw": "inputs.selection",
        "inputs.chip-select": "inputs.selection",
        "inputs.swatch-picker": "inputs.selection",
        "inputs.radio-travel": "inputs.selection",
        "inputs.todo-check": "inputs.selection",
        "inputs.dropdown-roll": "inputs.selection",
        "inputs.seat-picker": "inputs.selection",
        "inputs.bubble-picker": "inputs.selection",
        "inputs.radio-cards": "inputs.selection",
    ]
}
