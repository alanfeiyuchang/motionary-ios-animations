enum FeedbackEffects {
    static let all: [Effect] = [
        .feedbackToast,
        .feedbackSuccessCheck,
        .feedbackErrorShake,
        .feedbackInlineValidation,
        .feedbackConfetti,
        .feedbackIsland,
        .feedbackConnectionBanner,
        .feedbackBadgeBounce,
        .feedbackUndoSnackbar,
        .feedbackAlertPop,
        .feedbackStackedBanners,
        .feedbackSpotlight,
        .feedbackCopy,
        .feedbackReactionPicker,
        .feedbackPullRefresh,
        // Toast variations
        .feedbackHingeToast,
        .feedbackMorphToast,
        // Success variations
        .feedbackSparkBurst,
        .feedbackLevelUp,
        // Error variations
        .feedbackGlitchError,
        .feedbackLimitBounce,
        .feedbackFaceIDFail,
        // Badge variations
        .feedbackStreakFlame,
        .feedbackPresencePing,
        .feedbackFloatingHearts,
        // Overlay variations
        .feedbackRecedingSheet,
        .feedbackTipPopover,
        .feedbackDropAlert,
        // Refresh variations
        .feedbackGooRefresh,
        .feedbackSunRefresh,
        .feedbackLetterRefresh,
        .feedbackDotsRefresh,
        // Round 2
        .feedbackProgressToast,
        .feedbackAchievementBanner,
        .feedbackPaymentDone,
        .feedbackFireworks,
        .feedbackCoinReward,
        .feedbackCardDeclined,
        .feedbackCounterBadge,
        .feedbackTypingBubble,
        .feedbackSilentHUD,
        .feedbackAutosavePulse,
        .feedbackThreadRefresh,
    ]
}
