import Foundation

/// Families (variation groups) of `EffectCategory.navigation`.
///
/// To add a variation: append the effect to `NavigationEffects.all`, then add one
/// `"<effect id>": "<family id>",` line to `membership` below. Each effect id may appear only once
/// (a duplicate dictionary key traps at launch). See docs/FAMILIES.md.
enum NavigationFamilies {
    static let all: [EffectFamily] = [
        EffectFamily(
            id: "navigation.tab-indicator",
            category: .navigation,
            name: L("Tab Indicator", "标签指示器"),
            summary: L("Selection pills, thumbs and underlines travelling between tabs.", "在标签之间移动的选中胶囊、滑块与下划线。"),
            symbol: "rectangle.split.3x1"
        ),
        EffectFamily(
            id: "navigation.tab-bar",
            category: .navigation,
            name: L("Tab Bars & Docks", "标签栏与程序坞"),
            summary: L("Tab bars and docks that collapse, notch, morph into search, ripple or magnify.", "会收起、开凹口、变形为搜索、泛起涟漪或放大的标签栏与程序坞。"),
            symbol: "dock.rectangle"
        ),
        EffectFamily(
            id: "navigation.page-indicator",
            category: .navigation,
            name: L("Page & Step Indicators", "页码与步骤指示"),
            summary: L("Dots and steppers that show where you are in a flow.", "表示当前位置的页码圆点与步骤条。"),
            symbol: "ellipsis"
        ),
        EffectFamily(
            id: "navigation.drawer",
            category: .navigation,
            name: L("Drawers & Sidebars", "抽屉与侧栏"),
            summary: L("Side navigation that slides, widens or turns in 3D.", "滑出、展宽或 3D 翻转的侧边导航。"),
            symbol: "sidebar.left"
        ),
        EffectFamily(
            id: "navigation.sheet",
            category: .navigation,
            name: L("Pages & Sheets", "页面与面板"),
            summary: L("Page pushes, cross-page transitions and sheets with parallax and detents.", "页面推入、页面间转场，以及带视差与档位的面板。"),
            symbol: "rectangle.bottomthird.inset.filled"
        ),
        EffectFamily(
            id: "navigation.menu",
            category: .navigation,
            name: L("Menus", "菜单"),
            summary: L("Context, popover and radial menus that grow out of their source.", "从触发点长出的上下文、弹出与径向菜单。"),
            symbol: "list.bullet"
        ),
    ]

    static let membership: [String: String] = [
        // Tab indicator
        "navigation.tab-indicator": "navigation.tab-indicator",
        "navigation.segmented-thumb": "navigation.tab-indicator",
        "navigation.elastic-underline": "navigation.tab-indicator",
        "navigation.gooey-tab": "navigation.tab-indicator",
        "navigation.spotlight-tab": "navigation.tab-indicator",
        "navigation.hop-dot-tab": "navigation.tab-indicator",
        "navigation.trace-tab": "navigation.tab-indicator",
        "navigation.folder-tabs": "navigation.tab-indicator",
        // Tab bars & docks
        "navigation.collapsing-tab-bar": "navigation.tab-bar",
        "navigation.dock-magnify": "navigation.tab-bar",
        "navigation.notch-tab-bar": "navigation.tab-bar",
        "navigation.search-tab-morph": "navigation.tab-bar",
        "navigation.ripple-tab-bar": "navigation.tab-bar",
        "navigation.glass-tab-bar": "navigation.tab-bar",
        "navigation.bubble-tab-bar": "navigation.tab-bar",
        "navigation.curve-fab-bar": "navigation.tab-bar",
        // Page & step indicators
        "navigation.page-dots": "navigation.page-indicator",
        "navigation.step-progress": "navigation.page-indicator",
        "navigation.number-pager": "navigation.page-indicator",
        "navigation.timer-dots": "navigation.page-indicator",
        "navigation.scrolling-dots": "navigation.page-indicator",
        "navigation.page-control-scrub": "navigation.page-indicator",
        // Drawers & sidebars
        "navigation.side-drawer-3d": "navigation.drawer",
        "navigation.sidebar-rail": "navigation.drawer",
        "navigation.parallax-drawer": "navigation.drawer",
        "navigation.elastic-drawer": "navigation.drawer",
        "navigation.popout-drawer": "navigation.drawer",
        "navigation.space-switcher": "navigation.drawer",
        // Sheets & pushes
        "navigation.push-parallax": "navigation.sheet",
        "navigation.bottom-sheet": "navigation.sheet",
        "navigation.stacked-sheets": "navigation.sheet",
        "navigation.fade-through": "navigation.sheet",
        "navigation.floating-sheet": "navigation.sheet",
        "navigation.fluid-sheet": "navigation.sheet",
        "navigation.peek-pop": "navigation.sheet",
        // Menus
        "navigation.radial-menu": "navigation.menu",
        "navigation.context-popover": "navigation.menu",
        "navigation.context-menu-lift": "navigation.menu",
        "navigation.fold-menu": "navigation.menu",
        "navigation.overlay-menu": "navigation.menu",
        "navigation.command-palette": "navigation.menu",
        "navigation.context-toolbar": "navigation.menu",
        "navigation.breadcrumbs": "navigation.menu",
    ]
}
