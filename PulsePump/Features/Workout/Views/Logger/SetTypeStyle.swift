import SwiftUI
import SwiftData

struct SetTypeStyle {
    let bg: Color
    let fg: Color
    let label: String
}

let setTypeStyles: [SetType: SetTypeStyle] = [
    .standard:   SetTypeStyle(bg: .clear,                              fg: Color.inkMuted,            label: "STD"),
    .warmup:     SetTypeStyle(bg: Color(hex: "#b48c3c").opacity(0.12), fg: Color(hex: "#a17418"),      label: "WU"),
    .superset:   SetTypeStyle(bg: Color(hex: "#7d4a8c").opacity(0.13), fg: Color(hex: "#7d4a8c"),      label: "SS"),
    .dropset:    SetTypeStyle(bg: Color.pumpAccent.opacity(0.13),      fg: Color(hex: "#a8442f"),      label: "DROP"),
    .restPause:  SetTypeStyle(bg: Color.inkPrimary.opacity(0.08),      fg: Color(hex: "#3a342d"),      label: "RP"),
    .amrap:      SetTypeStyle(bg: Color(hex: "#2c6da3").opacity(0.10), fg: Color(hex: "#2c6da3"),      label: "AMRAP"),
    .failureSet: SetTypeStyle(bg: Color.signalDown.opacity(0.10),      fg: Color(hex: "#c0341a"),      label: "FAIL"),
    .leftRight:  SetTypeStyle(bg: Color(hex: "#1f8f5a").opacity(0.10), fg: Color(hex: "#1f8f5a"),      label: "L/R"),
]

// MARK: - Active Workout View
