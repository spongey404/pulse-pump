/* @ds-bundle: {"format":4,"namespace":"PumpDesignSystem_e68c28","components":[{"name":"DashedAdd","sourcePath":"components/controls/DashedAdd.jsx"},{"name":"DayScrubber","sourcePath":"components/controls/DayScrubber.jsx"},{"name":"DockedCTA","sourcePath":"components/controls/DockedCTA.jsx"},{"name":"FilterChip","sourcePath":"components/controls/FilterChip.jsx"},{"name":"SectionLabel","sourcePath":"components/controls/SectionLabel.jsx"},{"name":"ConfidenceDots","sourcePath":"components/data/ConfidenceDots.jsx"},{"name":"KPIBlock","sourcePath":"components/data/KPIBlock.jsx"},{"name":"TickerStrip","sourcePath":"components/data/TickerStrip.jsx"},{"name":"TrendValue","sourcePath":"components/data/TrendValue.jsx"},{"name":"WeekBars","sourcePath":"components/data/WeekBars.jsx"},{"name":"EmptyState","sourcePath":"components/feedback/EmptyState.jsx"},{"name":"PRMark","sourcePath":"components/feedback/PRMark.jsx"},{"name":"ExerciseCard","sourcePath":"components/logging/ExerciseCard.jsx"},{"name":"PLATE_COLORS","sourcePath":"components/logging/PlateBar.jsx"},{"name":"PlateBar","sourcePath":"components/logging/PlateBar.jsx"},{"name":"SetRow","sourcePath":"components/logging/SetRow.jsx"},{"name":"SET_TYPES","sourcePath":"components/logging/SetTypeChip.jsx"},{"name":"SetTypeChip","sourcePath":"components/logging/SetTypeChip.jsx"},{"name":"Masthead","sourcePath":"components/navigation/Masthead.jsx"},{"name":"RestTimerPill","sourcePath":"components/navigation/RestTimerPill.jsx"},{"name":"TabBar","sourcePath":"components/navigation/TabBar.jsx"}],"sourceHashes":{"components/controls/DashedAdd.jsx":"a49fe448af44","components/controls/DayScrubber.jsx":"cba8f1d0ef6f","components/controls/DockedCTA.jsx":"72cd0b39b253","components/controls/FilterChip.jsx":"fa8e39bb94a3","components/controls/SectionLabel.jsx":"57b21340dd7f","components/data/ConfidenceDots.jsx":"9c7c98f3b517","components/data/KPIBlock.jsx":"5bfb0a727556","components/data/TickerStrip.jsx":"47adad90fc12","components/data/TrendValue.jsx":"ce7cd23d3a61","components/data/WeekBars.jsx":"4b18deb42121","components/feedback/EmptyState.jsx":"a8348e9418b9","components/feedback/PRMark.jsx":"dba65ec16eb2","components/logging/ExerciseCard.jsx":"cf34d43606cb","components/logging/PlateBar.jsx":"122b243014c9","components/logging/SetRow.jsx":"4fe6249768d7","components/logging/SetTypeChip.jsx":"035dea313f69","components/navigation/Masthead.jsx":"e2947d824163","components/navigation/RestTimerPill.jsx":"faf8b565b175","components/navigation/TabBar.jsx":"2712a9947270","ui_kits/pump/kit-shared.jsx":"2ef61d30336e","ui_kits/pump/screen-home.jsx":"8853f704ba4e","ui_kits/pump/screen-logger.jsx":"93b94229df15","ui_kits/pump/screen-programs.jsx":"2d20bf609518","ui_kits/pump/screen-summary.jsx":"b9ace94d517b"},"inlinedExternals":[],"unexposedExports":[{"name":"computePlates","sourcePath":"components/logging/PlateBar.jsx"}]} */

(() => {

const __ds_ns = (window.PumpDesignSystem_e68c28 = window.PumpDesignSystem_e68c28 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/controls/DashedAdd.jsx
try { (() => {
/** Dashed "add a thing" affordance. The only place Pump uses a dashed border. */
function DashedAdd({
  label = "ADD",
  onClick,
  height = 36,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      height,
      borderRadius: "var(--radius-control)",
      border: "1px dashed var(--text-ghost)",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      gap: 6,
      fontFamily: "var(--font-mono)",
      fontSize: 10,
      letterSpacing: "1px",
      color: "var(--text-muted)",
      textTransform: "uppercase",
      background: "transparent",
      cursor: "pointer",
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 14,
      lineHeight: 1
    }
  }, "+"), label);
}
Object.assign(__ds_scope, { DashedAdd });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/controls/DashedAdd.jsx", error: String((e && e.message) || e) }); }

// components/controls/DayScrubber.jsx
try { (() => {
/** Rounded-rectangle day tiles. Never circles. Accent dot marks days with logged data. */
function DayScrubber({
  days = [],
  selected = -1,
  onSelect,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 6,
      ...style
    }
  }, days.map((d, i) => {
    const on = i === selected;
    return /*#__PURE__*/React.createElement("div", {
      key: i,
      onClick: () => onSelect && onSelect(i),
      style: {
        flex: 1,
        minWidth: 40,
        height: 52,
        borderRadius: "var(--radius-control)",
        background: on ? "var(--surface-inverse)" : "transparent",
        border: on ? "none" : "1px solid var(--rule-hair)",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: 3,
        cursor: "pointer",
        transition: "background var(--dur-micro) var(--ease-out)"
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: "var(--font-mono)",
        fontSize: 8,
        letterSpacing: "1.2px",
        color: on ? "var(--text-inverse)" : "var(--text-muted)"
      }
    }, d.letter), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: "var(--font-mono)",
        fontSize: 13,
        fontWeight: 700,
        color: on ? "var(--text-inverse)" : "var(--text-primary)"
      }
    }, d.date), /*#__PURE__*/React.createElement("div", {
      style: {
        width: 4,
        height: 4,
        borderRadius: 1,
        background: d.logged ? on ? "var(--pump-blue-lift)" : "var(--accent)" : "transparent"
      }
    }));
  }));
}
Object.assign(__ds_scope, { DayScrubber });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/controls/DayScrubber.jsx", error: String((e && e.message) || e) }); }

// components/controls/DockedCTA.jsx
try { (() => {
/**
 * Docked CTA — Pump's primary action. 54px, 12px radius, flat accent fill, no divider
 * line inside, optional progress fill. Bottom-anchored for one-handed reach.
 */
function DockedCTA({
  label,
  overline,
  meta,
  metaOverline,
  variant = "primary",
  progress,
  onClick,
  style
}) {
  const draft = variant === "draft";
  const bg = draft ? "var(--surface-elevated)" : variant === "destructive" ? "var(--signal-down)" : "var(--accent)";
  const fg = draft ? "var(--accent-text)" : "var(--text-on-accent)";
  const sub = draft ? "var(--text-muted)" : "rgba(255,255,255,0.6)";
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      position: "relative",
      height: "var(--cta-height)",
      borderRadius: "var(--radius-cta)",
      background: bg,
      border: draft ? "1px solid var(--accent-border)" : "none",
      overflow: "hidden",
      cursor: "pointer",
      ...style
    }
  }, progress != null && /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 0,
      top: 0,
      bottom: 0,
      width: Math.max(0, Math.min(1, progress)) * 100 + "%",
      background: draft ? "var(--accent)" : "rgba(0,0,0,0.18)",
      opacity: draft ? 0.18 : 1,
      transition: "width var(--dur-default) var(--ease-default)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      gap: 10,
      padding: "0 18px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      minWidth: 0
    }
  }, overline && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 8,
      letterSpacing: "1.5px",
      color: sub,
      marginBottom: 2
    }
  }, overline), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-display)",
      fontWeight: 900,
      fontSize: 20,
      letterSpacing: "1.5px",
      color: fg,
      whiteSpace: "nowrap"
    }
  }, label)), (meta || metaOverline) && /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "right",
      flexShrink: 0
    }
  }, metaOverline && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 8,
      letterSpacing: "0.8px",
      color: sub,
      marginBottom: 2
    }
  }, metaOverline), meta && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 9,
      fontWeight: 700,
      letterSpacing: "0.8px",
      color: draft ? "var(--text-muted)" : "rgba(255,255,255,0.85)"
    }
  }, meta))));
}
Object.assign(__ds_scope, { DockedCTA });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/controls/DockedCTA.jsx", error: String((e && e.message) || e) }); }

// components/controls/FilterChip.jsx
try { (() => {
/** Pill filter chip — one of only two places Pump allows a 999px radius. */
function FilterChip({
  label,
  selected = false,
  onClick,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      height: 28,
      padding: "0 14px",
      borderRadius: "var(--radius-round)",
      display: "inline-flex",
      alignItems: "center",
      background: selected ? "var(--accent)" : "var(--surface-sunken)",
      border: selected ? "1px solid var(--accent)" : "1px solid var(--rule-hair)",
      color: selected ? "var(--text-on-accent)" : "var(--text-primary)",
      fontFamily: "var(--font-mono)",
      fontSize: 10,
      fontWeight: 700,
      letterSpacing: "1px",
      textTransform: "uppercase",
      whiteSpace: "nowrap",
      cursor: "pointer",
      transition: "background var(--dur-micro) var(--ease-out)",
      ...style
    }
  }, label);
}
Object.assign(__ds_scope, { FilterChip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/controls/FilterChip.jsx", error: String((e && e.message) || e) }); }

// components/controls/SectionLabel.jsx
try { (() => {
/** Space Mono all-caps tracked section label, optionally with a right-hand value. */
function SectionLabel({
  children,
  meta,
  accent = false,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "baseline",
      justifyContent: "space-between",
      gap: 12,
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 9,
      letterSpacing: "1.5px",
      textTransform: "uppercase",
      color: accent ? "var(--accent-text)" : "var(--text-muted)"
    }
  }, children), meta && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 9,
      letterSpacing: "0.8px",
      color: "var(--text-muted)"
    }
  }, meta));
}
Object.assign(__ds_scope, { SectionLabel });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/controls/SectionLabel.jsx", error: String((e && e.message) || e) }); }

// components/data/ConfidenceDots.jsx
try { (() => {
/** Five 5px squares showing prediction confidence, plus the percentage in Space Mono. */
function ConfidenceDots({
  confidence = 0,
  showLabel = true,
  style
}) {
  const filled = Math.round(confidence * 5);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 3,
      alignItems: "center",
      ...style
    }
  }, [0, 1, 2, 3, 4].map(i => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      width: 5,
      height: 5,
      borderRadius: 1,
      background: i < filled ? "var(--accent)" : "var(--text-faint)"
    }
  })), showLabel && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 8,
      letterSpacing: "0.5px",
      color: "var(--text-muted)",
      marginLeft: 4
    }
  }, Math.round(confidence * 100), "% CONF"));
}
Object.assign(__ds_scope, { ConfidenceDots });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/ConfidenceDots.jsx", error: String((e && e.message) || e) }); }

// components/data/KPIBlock.jsx
try { (() => {
/**
 * KPI Block — label + tabular number + optional delta. The dominant data display.
 * inline: label above, big number, delta below, hairline underline.
 * hero:   page-dominant Space Mono number with a ghost denominator.
 * compact: single line, used inside 4-up KPI rows.
 */
function KPIBlock({
  label,
  value,
  denominator,
  delta,
  direction,
  variant = "inline",
  align = "left",
  style
}) {
  const deltaColor = direction === "up" ? "var(--signal-up)" : direction === "down" ? "var(--signal-down)" : "var(--text-muted)";
  const kpiLabel = {
    fontFamily: "var(--font-mono)",
    fontSize: variant === "compact" ? 7 : 9,
    letterSpacing: variant === "compact" ? "1.2px" : "1.5px",
    textTransform: "uppercase",
    color: "var(--text-muted)",
    marginBottom: 3
  };
  if (variant === "hero") {
    return /*#__PURE__*/React.createElement("div", {
      style: {
        textAlign: align,
        ...style
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: kpiLabel
    }, label), /*#__PURE__*/React.createElement("div", {
      style: {
        display: "flex",
        alignItems: "baseline",
        gap: 6,
        justifyContent: align === "right" ? "flex-end" : align === "center" ? "center" : "flex-start"
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: "var(--font-mono)",
        fontWeight: 700,
        fontSize: 64,
        lineHeight: 0.86,
        color: "var(--text-primary)",
        letterSpacing: "-1px"
      }
    }, value), denominator != null && /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: "var(--font-mono)",
        fontSize: 14,
        color: "var(--text-faint)"
      }
    }, "/ ", denominator)), delta && /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: "var(--font-mono)",
        fontSize: 11,
        fontWeight: 700,
        color: deltaColor,
        marginTop: 4
      }
    }, direction === "up" ? "▲ " : direction === "down" ? "▼ " : "", delta));
  }
  if (variant === "compact") {
    return /*#__PURE__*/React.createElement("div", {
      style: {
        textAlign: align,
        ...style
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: kpiLabel
    }, label), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: "var(--font-display)",
        fontWeight: 900,
        fontSize: 22,
        lineHeight: 0.9,
        color: "var(--text-primary)"
      }
    }, value), delta && /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: "var(--font-mono)",
        fontSize: 8,
        fontWeight: 700,
        color: deltaColor,
        marginTop: 2
      }
    }, direction === "up" ? "▲ " : direction === "down" ? "▼ " : "", delta));
  }
  return /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: align,
      borderBottom: "1px solid var(--rule-hair)",
      paddingBottom: 6,
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: kpiLabel
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontWeight: 700,
      fontSize: 20,
      lineHeight: 1,
      color: "var(--text-primary)"
    }
  }, value, denominator != null && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: "var(--text-faint)",
      marginLeft: 4
    }
  }, "/ ", denominator)), delta && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 9,
      fontWeight: 700,
      color: deltaColor,
      marginTop: 3
    }
  }, direction === "up" ? "▲ " : direction === "down" ? "▼ " : "", delta));
}
Object.assign(__ds_scope, { KPIBlock });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/KPIBlock.jsx", error: String((e && e.message) || e) }); }

// components/data/TickerStrip.jsx
try { (() => {
/**
 * Stock Ticker Strip — the single most recognisable Pulse element.
 * A 26px bar of Space Mono stats, each LABEL + VALUE + optional ▲/▼, separated by
 * a middle dot. In Pump the strip follows the theme: light cream in light mode,
 * near-black in dark mode. Never wraps — it marquees.
 */
function TickerStrip({
  items = [],
  speed = 45,
  paused = false,
  style
}) {
  const doubled = [...items, ...items];
  const anim = "pump-ticker " + speed + "s linear infinite";
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--ticker-bg)",
      height: "var(--ticker-height)",
      overflow: "hidden",
      display: "flex",
      alignItems: "center",
      ...style
    }
  }, /*#__PURE__*/React.createElement("style", null, "@keyframes pump-ticker{from{transform:translateX(0)}to{transform:translateX(-50%)}}"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "inline-flex",
      gap: 28,
      whiteSpace: "nowrap",
      paddingLeft: 28,
      animation: paused ? "none" : anim,
      fontFamily: "var(--font-mono)",
      fontSize: 10,
      letterSpacing: "1px"
    }
  }, doubled.map((it, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 6
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--ticker-fg)",
      opacity: 0.55
    }
  }, it.label), /*#__PURE__*/React.createElement("span", {
    style: {
      fontWeight: 700,
      color: it.direction === "up" ? "var(--ticker-up)" : it.direction === "down" ? "var(--ticker-down)" : "var(--ticker-fg)",
      opacity: it.direction ? 1 : 0.6
    }
  }, it.direction === "up" ? "▲ " : it.direction === "down" ? "▼ " : "", it.value), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--ticker-sep)",
      marginLeft: 4
    }
  }, "\xB7")))));
}
Object.assign(__ds_scope, { TickerStrip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/TickerStrip.jsx", error: String((e && e.message) || e) }); }

// components/data/TrendValue.jsx
try { (() => {
/** Inline ▲/▼ + value in a signal colour. The atomic delta used across tables and headers. */
function TrendValue({
  value,
  direction,
  size = 11,
  bold = true,
  showArrow = true,
  style
}) {
  const color = direction === "up" ? "var(--signal-up)" : direction === "down" ? "var(--signal-down)" : "var(--text-muted)";
  return /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: size,
      fontWeight: bold ? 700 : 400,
      color,
      letterSpacing: "0.5px",
      whiteSpace: "nowrap",
      ...style
    }
  }, showArrow && direction === "up" ? "▲" : showArrow && direction === "down" ? "▼" : "", showArrow && direction ? " " : "", value);
}
Object.assign(__ds_scope, { TrendValue });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/TrendValue.jsx", error: String((e && e.message) || e) }); }

// components/data/WeekBars.jsx
try { (() => {
/** Weekly volume sparkbar — 7 bars, Mon→Sun. Today is accent, completed days green-muted. */
function WeekBars({
  data = [],
  labels = ["M", "T", "W", "T", "F", "S", "S"],
  done = [],
  today = -1,
  height = 40,
  style
}) {
  const max = Math.max(...data, 1);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 4,
      alignItems: "flex-end",
      height: height + 18,
      ...style
    }
  }, data.map((v, i) => {
    const isToday = i === today;
    const barH = Math.max(v > 0 ? v / max * height : 3, 3);
    const col = isToday ? "var(--accent)" : done[i] ? "var(--signal-up)" : v > 0 ? "var(--text-primary)" : "var(--text-faint)";
    const op = isToday ? 1 : done[i] ? 0.7 : v > 0 ? 0.35 : 0.4;
    return /*#__PURE__*/React.createElement("div", {
      key: i,
      style: {
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 3,
        flex: 1
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        width: "100%",
        height: barH,
        background: col,
        opacity: op,
        borderRadius: 2,
        transition: "height var(--dur-default) var(--ease-default)"
      }
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: "var(--font-mono)",
        fontSize: 7,
        letterSpacing: "0.5px",
        fontWeight: isToday ? 700 : 400,
        color: isToday ? "var(--accent-text)" : "var(--text-muted)"
      }
    }, labels[i]));
  }));
}
Object.assign(__ds_scope, { WeekBars });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/data/WeekBars.jsx", error: String((e && e.message) || e) }); }

// components/feedback/EmptyState.jsx
try { (() => {
/** Quiet empty state: one muted glyph, one line of title, one line of description, one CTA. */
function EmptyState({
  title,
  description,
  action,
  glyph,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "40px 24px",
      textAlign: "center",
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      gap: 8,
      ...style
    }
  }, glyph && /*#__PURE__*/React.createElement("div", {
    style: {
      opacity: 0.18,
      marginBottom: 4
    }
  }, glyph), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-display)",
      fontWeight: 700,
      fontSize: 16,
      letterSpacing: "0.2px",
      color: "var(--text-primary)"
    }
  }, title), description && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-body)",
      fontSize: 13,
      lineHeight: 1.5,
      color: "var(--text-muted)",
      maxWidth: 260
    }
  }, description), action && /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 12,
      width: "100%",
      maxWidth: 260
    }
  }, action));
}
Object.assign(__ds_scope, { EmptyState });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/EmptyState.jsx", error: String((e && e.message) || e) }); }

// components/feedback/PRMark.jsx
try { (() => {
/**
 * PR treatment. A personal record is ink-primary text with a 1.5px underline —
 * never a colour, never a badge, never a trophy. Amber belongs to Fuel, not Pump.
 */
function PRMark({
  children,
  label,
  style
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "baseline",
      gap: 6,
      ...style
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontWeight: 700,
      color: "var(--text-primary)",
      borderBottom: "1.5px solid var(--text-primary)",
      paddingBottom: 1
    }
  }, children), label && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 8,
      letterSpacing: "1.5px",
      color: "var(--text-muted)",
      textTransform: "uppercase"
    }
  }, label));
}
Object.assign(__ds_scope, { PRMark });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/PRMark.jsx", error: String((e && e.message) || e) }); }

// components/logging/ExerciseCard.jsx
try { (() => {
/**
 * Exercise Card — the container for a set table in the logger. Drag handle, name,
 * equipment + PR + 1RM metadata, set progress, overflow, collapse chevron.
 * Cards group at the top level only; inside, hairline rules divide.
 */
function ExerciseCard({
  index = 0,
  name,
  equipment,
  pr,
  oneRm,
  delta,
  deltaDirection,
  setsDone = 0,
  totalSets = 0,
  lastNote,
  collapsed = false,
  onToggleCollapse,
  onOverflow,
  hasRIR = false,
  children,
  style
}) {
  const meta = {
    fontFamily: "var(--font-mono)",
    fontSize: 9,
    color: "var(--text-muted)",
    letterSpacing: "0.4px"
  };
  const strong = {
    color: "var(--text-primary)",
    fontWeight: 700
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--surface-elevated)",
      borderRadius: "var(--radius-card)",
      border: "1px solid var(--rule-hair)",
      marginBottom: 10,
      overflow: "hidden",
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "10px 12px 8px",
      display: "flex",
      alignItems: "center",
      gap: 8,
      borderBottom: collapsed ? "none" : "1px solid var(--rule-hair)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 2,
      opacity: 0.4,
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 12,
      height: 1.5,
      background: "var(--text-primary)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 12,
      height: 1.5,
      background: "var(--text-primary)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 12,
      height: 1.5,
      background: "var(--text-primary)"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "baseline",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      ...meta,
      letterSpacing: "1px"
    }
  }, String(index + 1).padStart(2, "0")), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-display)",
      fontWeight: 700,
      fontSize: 17,
      letterSpacing: "0.3px",
      lineHeight: 1,
      color: "var(--text-primary)",
      whiteSpace: "nowrap",
      overflow: "hidden",
      textOverflow: "ellipsis"
    }
  }, name)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8,
      marginTop: 3,
      ...meta
    }
  }, equipment && /*#__PURE__*/React.createElement("span", null, equipment), pr && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("span", null, "\xB7"), /*#__PURE__*/React.createElement("span", null, "PR ", /*#__PURE__*/React.createElement("span", {
    style: strong
  }, pr))), oneRm && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("span", null, "\xB7"), /*#__PURE__*/React.createElement("span", null, "1RM ", /*#__PURE__*/React.createElement("span", {
    style: strong
  }, oneRm))), delta && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("span", null, "\xB7"), /*#__PURE__*/React.createElement("span", {
    style: {
      color: deltaDirection === "down" ? "var(--signal-down)" : "var(--signal-up)",
      fontWeight: 700
    }
  }, deltaDirection === "down" ? "▼" : "▲", " ", delta)))), /*#__PURE__*/React.createElement("div", {
    style: {
      ...meta,
      fontWeight: 700,
      flexShrink: 0
    }
  }, setsDone, "/", totalSets), /*#__PURE__*/React.createElement("div", {
    onClick: onOverflow,
    style: {
      width: 24,
      height: 24,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      cursor: "pointer",
      color: "var(--text-muted)",
      fontSize: 14,
      flexShrink: 0
    }
  }, "\xB7\xB7\xB7"), /*#__PURE__*/React.createElement("div", {
    onClick: onToggleCollapse,
    style: {
      width: 20,
      height: 20,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      cursor: "pointer",
      color: "var(--text-muted)",
      fontSize: 11,
      flexShrink: 0,
      transform: collapsed ? "rotate(-90deg)" : "none",
      transition: "transform var(--dur-micro) var(--ease-out)"
    }
  }, "\u25BE")), !collapsed && lastNote && /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "8px 12px",
      background: "var(--surface-sunken)",
      borderBottom: "1px solid var(--rule-hair)",
      display: "flex",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      ...meta,
      letterSpacing: "1px",
      flexShrink: 0
    }
  }, "LAST"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-body)",
      fontSize: 11,
      fontStyle: "italic",
      color: "var(--text-secondary)"
    }
  }, "\"", lastNote, "\"")), !collapsed && /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: hasRIR ? "36px 22px 1fr 1fr 38px 30px" : "36px 22px 1fr 1fr 30px",
      padding: "5px 12px",
      background: "var(--surface-sunken)",
      fontFamily: "var(--font-mono)",
      fontSize: 8,
      letterSpacing: "1.2px",
      color: "var(--text-muted)",
      borderBottom: "1px solid var(--rule-hair)"
    }
  }, /*#__PURE__*/React.createElement("span", null, "TYPE"), /*#__PURE__*/React.createElement("span", null, "#"), /*#__PURE__*/React.createElement("span", {
    style: {
      textAlign: "center"
    }
  }, "KG"), /*#__PURE__*/React.createElement("span", {
    style: {
      textAlign: "center"
    }
  }, "REPS"), hasRIR && /*#__PURE__*/React.createElement("span", {
    style: {
      textAlign: "center"
    }
  }, "RIR"), /*#__PURE__*/React.createElement("span", {
    style: {
      textAlign: "right"
    }
  }, "\u2713")), children));
}
Object.assign(__ds_scope, { ExerciseCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/logging/ExerciseCard.jsx", error: String((e && e.message) || e) }); }

// components/logging/PlateBar.jsx
try { (() => {
const PLATE_COLORS = {
  25: {
    bg: "var(--pump-plate-25)",
    fg: "#fff"
  },
  20: {
    bg: "var(--pump-plate-20)",
    fg: "#fff"
  },
  15: {
    bg: "var(--pump-plate-15)",
    fg: "#fff"
  },
  10: {
    bg: "var(--pump-plate-10)",
    fg: "#fff"
  },
  5: {
    bg: "var(--pump-plate-5)",
    fg: "#F4F0E6"
  },
  2.5: {
    bg: "var(--pump-plate-2-5)",
    fg: "#1F1C19"
  },
  1.25: {
    bg: "var(--pump-plate-1-25)",
    fg: "#1F1C19"
  }
};
function computePlates(targetKg, barKg) {
  const sizes = [25, 20, 15, 10, 5, 2.5, 1.25];
  let remaining = (targetKg - barKg) / 2;
  if (remaining <= 0) return {
    perSide: 0,
    stack: [],
    remainder: 0
  };
  const stack = [];
  for (const p of sizes) {
    while (remaining >= p - 0.001) {
      stack.push(p);
      remaining = +(remaining - p).toFixed(3);
    }
  }
  return {
    perSide: (targetKg - barKg) / 2,
    stack,
    remainder: remaining
  };
}

/** Barbell loading diagram — the one place Pump uses saturated colour purely as coding. */
function PlateBar({
  targetKg = 100,
  barKg = 20,
  showChips = true,
  style
}) {
  const {
    stack,
    remainder
  } = computePlates(targetKg, barKg);
  const plate = (p, i) => {
    const c = PLATE_COLORS[p];
    return /*#__PURE__*/React.createElement("div", {
      key: i,
      style: {
        width: p >= 20 ? 9 : p >= 10 ? 7 : p >= 5 ? 6 : 5,
        height: 32 + Math.min(p, 25) * 0.9,
        background: c.bg,
        border: "1px solid rgba(0,0,0,0.25)",
        borderRadius: 1.5
      }
    });
  };
  return /*#__PURE__*/React.createElement("div", {
    style: style
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      height: 64
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "flex-end",
      width: 80,
      gap: 1
    }
  }, [...stack].reverse().map(plate)), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 60,
      height: 4,
      background: "#8A857C",
      borderTop: "1px solid #5A554D",
      borderBottom: "1px solid #5A554D"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "flex-start",
      width: 80,
      gap: 1
    }
  }, stack.map(plate))), showChips && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "center",
      gap: 6,
      flexWrap: "wrap",
      marginTop: 6
    }
  }, stack.length === 0 ? /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 10,
      color: "var(--text-muted)"
    }
  }, "BAR ONLY") : stack.map((p, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      background: PLATE_COLORS[p].bg,
      color: PLATE_COLORS[p].fg,
      fontFamily: "var(--font-mono)",
      fontSize: 9,
      fontWeight: 700,
      padding: "2px 6px",
      borderRadius: 3
    }
  }, p)), remainder > 0.01 && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 9,
      color: "var(--signal-down)"
    }
  }, "+", remainder.toFixed(2), "KG OFF")));
}
Object.assign(__ds_scope, { PLATE_COLORS, computePlates, PlateBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/logging/PlateBar.jsx", error: String((e && e.message) || e) }); }

// components/logging/SetTypeChip.jsx
try { (() => {
const SET_TYPES = {
  standard: {
    label: "STD",
    bg: "transparent",
    fg: "var(--text-muted)"
  },
  warmup: {
    label: "WU",
    bg: "rgba(161,116,24,0.12)",
    fg: "var(--pump-type-warmup)"
  },
  superset: {
    label: "SS",
    bg: "rgba(125,74,140,0.13)",
    fg: "var(--pump-type-superset)"
  },
  dropset: {
    label: "DROP",
    bg: "rgba(168,68,47,0.13)",
    fg: "var(--pump-type-drop)"
  },
  restpause: {
    label: "RP",
    bg: "rgba(58,52,45,0.10)",
    fg: "var(--pump-type-restpause)"
  },
  amrap: {
    label: "AMRAP",
    bg: "rgba(44,109,163,0.10)",
    fg: "var(--pump-type-amrap)"
  },
  failure: {
    label: "FAIL",
    bg: "rgba(192,52,26,0.10)",
    fg: "var(--pump-type-fail)"
  },
  unilateral: {
    label: "L/R",
    bg: "rgba(44,109,163,0.12)",
    fg: "var(--pump-type-amrap)"
  }
};

/**
 * Set-type pill. A standard set has no pill — it shows a dashed 24×18 "+" affordance
 * so tapping it is how you assign a type.
 */
function SetTypeChip({
  type = "standard",
  onClick,
  style
}) {
  const cfg = SET_TYPES[type] || SET_TYPES.standard;
  if (type === "standard") {
    return /*#__PURE__*/React.createElement("div", {
      onClick: onClick,
      style: {
        width: 24,
        height: 18,
        borderRadius: "var(--radius-chip)",
        border: "1px dashed var(--text-ghost)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        fontSize: 9,
        color: "var(--text-ghost)",
        cursor: onClick ? "pointer" : "default",
        ...style
      }
    }, "+");
  }
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      height: 18,
      padding: "0 5px",
      borderRadius: "var(--radius-chip)",
      background: cfg.bg,
      color: cfg.fg,
      fontFamily: "var(--font-mono)",
      fontSize: 8,
      fontWeight: 700,
      letterSpacing: "0.6px",
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      whiteSpace: "nowrap",
      cursor: onClick ? "pointer" : "default",
      ...style
    }
  }, cfg.label);
}
Object.assign(__ds_scope, { SET_TYPES, SetTypeChip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/logging/SetTypeChip.jsx", error: String((e && e.message) || e) }); }

// components/logging/SetRow.jsx
try { (() => {
/**
 * Set / Log Row — tabular row of TYPE · # · KG · REPS · RIR · ✓.
 * Only the active row is ever tinted, and completion is carried by the check control,
 * never by a background colour.
 */
function SetRow({
  index = 0,
  type = "standard",
  kg,
  reps,
  rir,
  prevKg,
  prevReps,
  prevRir,
  state = "pending",
  isPR = false,
  hasRIR = false,
  onTypeClick,
  onClick,
  style
}) {
  const active = state === "active";
  const done = state === "done";
  const cols = hasRIR ? "36px 22px 1fr 1fr 38px 30px" : "36px 22px 1fr 1fr 30px";
  const num = (val, ghost) => /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontWeight: 700,
      fontSize: 20,
      letterSpacing: "0.5px",
      color: ghost ? "var(--text-ghost)" : "var(--text-primary)",
      borderBottom: !ghost && isPR ? "1.5px solid var(--text-primary)" : "1.5px solid transparent",
      paddingBottom: 1
    }
  }, val);
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      display: "grid",
      gridTemplateColumns: cols,
      alignItems: "center",
      minHeight: 44,
      padding: "7px 12px",
      borderBottom: "1px solid var(--rule-hair)",
      background: active ? "var(--accent-row)" : "transparent",
      borderLeft: active ? "2px solid var(--accent)" : "2px solid transparent",
      opacity: type === "warmup" ? 0.65 : 1,
      cursor: onClick ? "pointer" : "default",
      ...style
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.SetTypeChip, {
    type: type,
    onClick: onTypeClick
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 10,
      fontWeight: 700,
      color: active ? "var(--accent-text)" : "var(--text-muted)"
    }
  }, String(index + 1).padStart(2, "0")), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "center"
    }
  }, kg != null ? num(kg, false) : num(prevKg, true)), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "center"
    }
  }, reps != null ? num(reps, false) : num(prevReps, true)), hasRIR && /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 11,
      fontWeight: rir != null ? 700 : 400,
      color: rir != null ? "var(--text-secondary)" : "var(--text-ghost)"
    }
  }, rir != null ? rir : prevRir != null ? prevRir : "—")), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "right",
      lineHeight: 1
    }
  }, done ? /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--signal-up)",
      fontSize: 13,
      fontWeight: 700
    }
  }, "\u2713") : /*#__PURE__*/React.createElement("span", {
    style: {
      width: 12,
      height: 12,
      display: "inline-block",
      borderRadius: "50%",
      border: active ? "2px solid var(--accent)" : "1.5px solid var(--text-faint)"
    }
  })));
}
Object.assign(__ds_scope, { SetRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/logging/SetRow.jsx", error: String((e && e.message) || e) }); }

// components/navigation/Masthead.jsx
try { (() => {
/** Screen masthead: PULSE/PUMP wordmark (or a session breadcrumb) plus trailing actions. */
function Masthead({
  title = "PULSE/PUMP",
  overline,
  showMark = true,
  onBack,
  right,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "8px 16px 6px",
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      gap: 12,
      borderBottom: "1px solid var(--rule-hair)",
      background: "var(--surface-canvas)",
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 8,
      minWidth: 0
    }
  }, onBack && /*#__PURE__*/React.createElement("span", {
    onClick: onBack,
    style: {
      fontSize: 18,
      fontWeight: 300,
      color: "var(--text-muted)",
      cursor: "pointer",
      lineHeight: 1
    }
  }, "\u2039"), showMark && !overline && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 16,
      height: 16,
      background: "var(--accent)",
      borderRadius: 3,
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      minWidth: 0
    }
  }, overline && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 9,
      letterSpacing: "1.2px",
      color: "var(--text-muted)",
      textTransform: "uppercase"
    }
  }, overline), /*#__PURE__*/React.createElement("div", {
    style: overline ? {
      fontFamily: "var(--font-display)",
      fontWeight: 900,
      fontSize: 18,
      letterSpacing: "0.8px",
      lineHeight: 1,
      color: "var(--text-primary)"
    } : {
      fontFamily: "var(--font-mono)",
      fontSize: 10,
      fontWeight: 700,
      letterSpacing: "2px",
      color: "var(--text-primary)"
    }
  }, title))), right && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 10,
      flexShrink: 0
    }
  }, right));
}
Object.assign(__ds_scope, { Masthead });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/Masthead.jsx", error: String((e && e.message) || e) }); }

// components/navigation/RestTimerPill.jsx
try { (() => {
/** Rest-timer pill in the logger masthead. Fills inverse while running; ring shows progress. */
function RestTimerPill({
  seconds = 0,
  total = 150,
  onClick,
  style
}) {
  const running = seconds > 0;
  const m = Math.floor(seconds / 60);
  const s = String(seconds % 60).padStart(2, "0");
  const r = 9;
  const circ = 2 * Math.PI * r;
  return /*#__PURE__*/React.createElement("div", {
    onClick: onClick,
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 8,
      padding: "5px 6px 5px 12px",
      borderRadius: "var(--radius-round)",
      background: running ? "var(--surface-inverse)" : "var(--surface-elevated)",
      border: running ? "none" : "1px solid var(--rule-strong)",
      color: running ? "var(--text-inverse)" : "var(--text-muted)",
      cursor: "pointer",
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "flex-end",
      lineHeight: 1
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 8,
      letterSpacing: "1px",
      opacity: 0.7
    }
  }, "REST"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 16,
      fontWeight: 700,
      letterSpacing: "0.5px",
      marginTop: 2
    }
  }, running ? m + ":" + s : "—:—")), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 24,
      height: 24,
      position: "relative",
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: "24",
    height: "24",
    viewBox: "0 0 24 24",
    style: {
      transform: "rotate(-90deg)"
    }
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: r,
    fill: "none",
    stroke: running ? "rgba(236,229,214,0.18)" : "var(--rule-strong)",
    strokeWidth: "2"
  }), running && /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: r,
    fill: "none",
    stroke: "var(--pump-blue-lift)",
    strokeWidth: "2.5",
    strokeDasharray: circ,
    strokeDashoffset: circ * (1 - seconds / total),
    strokeLinecap: "round"
  })), !running && /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontSize: 11,
      color: "var(--text-muted)"
    }
  }, "\u203A")));
}
Object.assign(__ds_scope, { RestTimerPill });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/RestTimerPill.jsx", error: String((e && e.message) || e) }); }

// components/navigation/TabBar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const stroke = c => ({
  width: 22,
  height: 22,
  fill: "none",
  stroke: c,
  strokeWidth: 1.6,
  strokeLinecap: "round",
  strokeLinejoin: "round"
});

/** Five-tab bar with the raised accent Home key in the centre for thumb reach. */
function TabBar({
  active = "Home",
  onSelect,
  style
}) {
  const tabs = ["Programs", "Social", "Home", "Body", "More"];
  const icon = (k, c) => {
    const s = stroke(c);
    if (k === "Programs") return /*#__PURE__*/React.createElement("svg", _extends({}, s, {
      viewBox: "0 0 24 24"
    }), /*#__PURE__*/React.createElement("rect", {
      x: "4",
      y: "5",
      width: "16",
      height: "14",
      rx: "2"
    }), /*#__PURE__*/React.createElement("path", {
      d: "M8 9h8M8 13h8M8 17h5"
    }));
    if (k === "Social") return /*#__PURE__*/React.createElement("svg", _extends({}, s, {
      viewBox: "0 0 24 24"
    }), /*#__PURE__*/React.createElement("circle", {
      cx: "9",
      cy: "9",
      r: "3"
    }), /*#__PURE__*/React.createElement("circle", {
      cx: "17",
      cy: "11",
      r: "2.5"
    }), /*#__PURE__*/React.createElement("path", {
      d: "M3 19c.5-3 3-5 6-5s5.5 2 6 5"
    }));
    if (k === "Body") return /*#__PURE__*/React.createElement("svg", _extends({}, s, {
      viewBox: "0 0 24 24"
    }), /*#__PURE__*/React.createElement("circle", {
      cx: "12",
      cy: "5",
      r: "2.2"
    }), /*#__PURE__*/React.createElement("path", {
      d: "M8 11l4-3 4 3M12 8v6M9 14l-2 6M15 14l2 6"
    }));
    return /*#__PURE__*/React.createElement("svg", _extends({}, s, {
      viewBox: "0 0 24 24"
    }), /*#__PURE__*/React.createElement("circle", {
      cx: "6",
      cy: "12",
      r: "1.4"
    }), /*#__PURE__*/React.createElement("circle", {
      cx: "12",
      cy: "12",
      r: "1.4"
    }), /*#__PURE__*/React.createElement("circle", {
      cx: "18",
      cy: "12",
      r: "1.4"
    }));
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      padding: "8px 0 24px",
      background: "var(--surface-canvas)",
      borderTop: "1px solid var(--rule-hair)",
      ...style
    }
  }, tabs.map(k => {
    const on = k === active;
    const col = on ? "var(--text-primary)" : "var(--text-muted)";
    return /*#__PURE__*/React.createElement("div", {
      key: k,
      onClick: () => onSelect && onSelect(k),
      style: {
        flex: 1,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 3,
        cursor: "pointer"
      }
    }, k === "Home" ? /*#__PURE__*/React.createElement("div", {
      style: {
        width: 46,
        height: 46,
        borderRadius: 15,
        background: "var(--accent)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        marginTop: -12
      }
    }, /*#__PURE__*/React.createElement("svg", {
      width: "22",
      height: "22",
      viewBox: "0 0 24 24",
      fill: "none"
    }, /*#__PURE__*/React.createElement("path", {
      d: "M3.5 12L12 4M12 4L20.5 12M6 13.5v7M18 13.5v7M6 20.5h12M10.5 20.5v-4.5h3v4.5",
      stroke: "#fff",
      strokeWidth: "1.8",
      strokeLinecap: "round",
      strokeLinejoin: "round"
    }))) : icon(k, col), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: "var(--font-mono)",
        fontSize: 7,
        letterSpacing: "1px",
        textTransform: "uppercase",
        fontWeight: on ? 700 : 400,
        color: k === "Home" ? "var(--accent-text)" : col
      }
    }, k));
  }));
}
Object.assign(__ds_scope, { TabBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/TabBar.jsx", error: String((e && e.message) || e) }); }

// ui_kits/pump/kit-shared.jsx
try { (() => {
// Shared scaffolding for the Pump UI kit: phone shell, status bar, fake session data.
const PHONE_W = 390,
  PHONE_H = 844;
function KitStatusBar() {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 50,
      flexShrink: 0,
      display: 'flex',
      alignItems: 'flex-end',
      justifyContent: 'space-between',
      padding: '0 26px 6px',
      position: 'relative'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 12,
      fontWeight: 700,
      color: 'var(--text-primary)'
    }
  }, "9:41"), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: '50%',
      top: 8,
      transform: 'translateX(-50%)',
      width: 120,
      height: 32,
      borderRadius: 18,
      background: '#000'
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: 'var(--font-mono)',
      fontSize: 10,
      color: 'var(--text-primary)',
      letterSpacing: '1px'
    }
  }, "\u25CF\u25CF\u25CF \u25AE"));
}
function KitPhone({
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: PHONE_W + 8,
      height: PHONE_H + 8,
      borderRadius: 48,
      padding: 4,
      background: 'linear-gradient(135deg,#cbcac4,#b9b8b2)',
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: '100%',
      height: '100%',
      borderRadius: 44,
      overflow: 'hidden',
      position: 'relative',
      background: 'var(--surface-canvas)',
      display: 'flex',
      flexDirection: 'column'
    }
  }, children));
}
function KitAvatar({
  initial = 'J',
  size = 28
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: size,
      height: size,
      borderRadius: 8,
      background: 'var(--surface-elevated)',
      border: '1px solid var(--rule-strong)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: 'var(--font-body)',
      fontSize: size * 0.46,
      color: 'var(--text-muted)',
      flexShrink: 0
    }
  }, initial);
}
function KitSearchGlyph() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "18",
    height: "18",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "var(--text-muted)",
    strokeWidth: "2",
    strokeLinecap: "round"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "11",
    cy: "11",
    r: "8"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M21 21l-4.35-4.35"
  }));
}
const TICKER = [{
  label: 'CHEST',
  value: '+12.5%',
  direction: 'up'
}, {
  label: 'BACK',
  value: '+11.1%',
  direction: 'up'
}, {
  label: 'QUADS',
  value: 'TGT'
}, {
  label: 'GLUTES',
  value: 'TGT'
}, {
  label: 'SHLDR',
  value: '-14.3%',
  direction: 'down'
}, {
  label: 'HAMS',
  value: '-33.3%',
  direction: 'down'
}, {
  label: 'BICEP',
  value: '+20.0%',
  direction: 'up'
}, {
  label: 'TRI',
  value: 'TGT'
}, {
  label: 'CORE',
  value: '-40.0%',
  direction: 'down'
}, {
  label: 'TRAP',
  value: '-25.0%',
  direction: 'down'
}];
const SESSION = {
  name: 'PUSH DAY',
  program: 'PPL',
  lastDone: '3 DAYS AGO',
  est: '~55 MIN',
  confidence: 0.94,
  reason: 'You do Push every Sat · 13-week pattern',
  chips: ['BENCH PRESS', 'OVERHEAD PRESS', 'INCLINE DB', 'CABLE FLY', 'TRICEP PD']
};
const EXERCISES = [{
  name: 'BENCH PRESS',
  equipment: 'BARBELL',
  pr: '105×4',
  oneRm: '~118',
  delta: '+5KG',
  deltaUp: true,
  hasRIR: true,
  lastNote: 'Pause at bottom. Felt strong.',
  sets: [{
    type: 'warmup',
    kg: 60,
    reps: 8,
    rir: 5,
    state: 'done'
  }, {
    type: 'standard',
    kg: 95,
    reps: 6,
    rir: 3,
    state: 'done'
  }, {
    type: 'standard',
    kg: 100,
    reps: 6,
    rir: 2,
    state: 'done',
    isPR: true
  }, {
    type: 'standard',
    prevKg: 95,
    prevReps: 6,
    prevRir: 3,
    state: 'active'
  }, {
    type: 'dropset',
    prevKg: 80,
    prevReps: 8,
    prevRir: 1
  }]
}, {
  name: 'OVERHEAD PRESS',
  equipment: 'BARBELL',
  pr: '70×5',
  oneRm: '~80',
  hasRIR: false,
  lastNote: 'Strict form, no leg drive.',
  sets: [{
    type: 'standard',
    prevKg: 65,
    prevReps: 8
  }, {
    type: 'standard',
    prevKg: 65,
    prevReps: 8
  }, {
    type: 'standard',
    prevKg: 65,
    prevReps: 7
  }]
}, {
  name: 'INCLINE DB PRESS',
  equipment: 'DUMBBELL',
  pr: '34×10',
  oneRm: '~38',
  hasRIR: true,
  lastNote: 'Bench at 30°. Right shoulder tight.',
  sets: [{
    type: 'standard',
    prevKg: 32,
    prevReps: 10,
    prevRir: 2
  }, {
    type: 'standard',
    prevKg: 32,
    prevReps: 10,
    prevRir: 2
  }, {
    type: 'failure',
    prevKg: 30,
    prevReps: 9,
    prevRir: 0
  }]
}, {
  name: 'CABLE FLY',
  equipment: 'CABLE',
  pr: '18×12',
  hasRIR: false,
  sets: [{
    type: 'standard',
    prevKg: 15,
    prevReps: 12
  }, {
    type: 'unilateral',
    prevKg: 13,
    prevReps: 12
  }, {
    type: 'amrap',
    prevKg: 12,
    prevReps: 15
  }]
}];
const PROGRAMS = [{
  name: 'Push Pull Legs',
  meta: '6 DAYS/WK · 18 EXERCISES',
  days: ['P', 'P', 'L', 'P', 'P', 'L']
}, {
  name: 'Upper / Lower',
  meta: '4 DAYS/WK · 14 EXERCISES',
  days: ['U', 'L', 'U', 'L']
}, {
  name: 'Full Body 3×',
  meta: '3 DAYS/WK · 9 EXERCISES',
  days: ['F', 'F', 'F']
}];
const RECENT = [{
  name: 'Pull Day',
  date: 'THU',
  sets: 26,
  improved: '5/6',
  vol: '+11%'
}, {
  name: 'Push Day',
  date: 'MON',
  sets: 24,
  improved: '4/6',
  vol: '+8%'
}, {
  name: 'Legs',
  date: 'LAST SAT',
  sets: 28,
  improved: '3/5',
  vol: '+3%'
}];
Object.assign(window, {
  KitPhone,
  KitStatusBar,
  KitAvatar,
  KitSearchGlyph,
  TICKER,
  SESSION,
  EXERCISES,
  PROGRAMS,
  RECENT,
  PHONE_W,
  PHONE_H
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/pump/kit-shared.jsx", error: String((e && e.message) || e) }); }

// ui_kits/pump/screen-home.jsx
try { (() => {
// Home — dense Bloomberg variant. Prediction block, 4-up KPI row, weekly volume,
(function () {
  // friends chip, recent table, docked start CTA.
  const {
    TickerStrip,
    KPIBlock,
    WeekBars,
    ConfidenceDots,
    TabBar,
    Masthead,
    DockedCTA,
    SectionLabel,
    TrendValue
  } = window.PumpDesignSystem_e68c28;
  function KitFriendsChip() {
    return /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: 8,
        padding: '8px 12px',
        background: 'var(--surface-elevated)',
        borderRadius: 8,
        border: '1px solid var(--rule-strong)'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex'
      }
    }, ['M', 'P', 'K'].map((n, i) => /*#__PURE__*/React.createElement("div", {
      key: i,
      style: {
        width: 22,
        height: 22,
        borderRadius: '50%',
        background: 'var(--surface-sunken)',
        border: '2px solid var(--surface-canvas)',
        marginLeft: i > 0 ? -8 : 0,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontSize: 9,
        color: 'var(--text-muted)'
      }
    }, n))), /*#__PURE__*/React.createElement("span", {
      style: {
        flex: 1,
        fontSize: 11,
        fontWeight: 500,
        color: 'var(--text-primary)'
      }
    }, "Marcus +2 others trained today"), /*#__PURE__*/React.createElement("svg", {
      width: "12",
      height: "12",
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: "var(--text-faint)",
      strokeWidth: "2",
      strokeLinecap: "round"
    }, /*#__PURE__*/React.createElement("polyline", {
      points: "9 18 15 12 9 6"
    })));
  }
  function KitHome({
    onStart,
    onTab,
    draft
  }) {
    return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(KitStatusBar, null), /*#__PURE__*/React.createElement(TickerStrip, {
      items: TICKER
    }), /*#__PURE__*/React.createElement(Masthead, {
      right: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(KitSearchGlyph, null), /*#__PURE__*/React.createElement(KitAvatar, null))
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '10px 16px',
        borderBottom: '1px solid var(--rule-hair)',
        background: 'var(--surface-elevated)'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        alignItems: 'flex-start',
        justifyContent: 'space-between',
        gap: 12
      }
    }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 8,
        letterSpacing: '1.5px',
        color: 'var(--text-muted)',
        marginBottom: 4
      }
    }, "PREDICTED TODAY \xB7 ", SESSION.program), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 900,
        fontSize: 36,
        letterSpacing: '0.5px',
        lineHeight: 0.9,
        color: 'var(--text-primary)'
      }
    }, SESSION.name), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 9,
        color: 'var(--text-muted)',
        marginTop: 4
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        marginRight: 10
      }
    }, SESSION.lastDone), /*#__PURE__*/React.createElement("span", null, SESSION.est))), /*#__PURE__*/React.createElement("div", {
      style: {
        textAlign: 'right'
      }
    }, /*#__PURE__*/React.createElement(ConfidenceDots, {
      confidence: SESSION.confidence
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 8,
        color: 'var(--text-muted)',
        marginTop: 6,
        maxWidth: 120,
        lineHeight: 1.4
      }
    }, SESSION.reason))), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        gap: 5,
        marginTop: 8,
        flexWrap: 'wrap'
      }
    }, SESSION.chips.map((c, i) => /*#__PURE__*/React.createElement("span", {
      key: i,
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 8,
        letterSpacing: '0.5px',
        color: 'var(--text-muted)',
        background: 'var(--surface-sunken)',
        padding: '2px 7px',
        borderRadius: 4
      }
    }, c)), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 8,
        color: 'var(--text-faint)',
        padding: '2px 4px'
      }
    }, "NOT TODAY? \u203A"))), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        overflowY: 'auto'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'grid',
        gridTemplateColumns: 'repeat(4,1fr)',
        borderBottom: '1px solid var(--rule-hair)'
      }
    }, [['Streak', '13D', '+1', 'up'], ['Improved', '14', 'this wk'], ['PRs', '3', 'this wk'], ['Sets', '480', 'this wk']].map((s, i) => /*#__PURE__*/React.createElement("div", {
      key: i,
      style: {
        padding: '9px 6px',
        borderRight: i < 3 ? '1px solid var(--rule-hair)' : 'none'
      }
    }, /*#__PURE__*/React.createElement(KPIBlock, {
      variant: "compact",
      align: "center",
      label: s[0],
      value: s[1],
      delta: s[2],
      direction: s[3]
    })))), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '10px 16px 8px',
        borderBottom: '1px solid var(--rule-hair)'
      }
    }, /*#__PURE__*/React.createElement(SectionLabel, {
      meta: "WK 14 \xB7 480 TOTAL",
      style: {
        marginBottom: 6
      }
    }, "Weekly volume \xB7 sets"), /*#__PURE__*/React.createElement(WeekBars, {
      data: [80, 94, 0, 112, 86, 0, 108],
      done: [true, true, false, true, true, false, false],
      today: 5
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '10px 16px',
        borderBottom: '1px solid var(--rule-hair)'
      }
    }, /*#__PURE__*/React.createElement(KitFriendsChip, null)), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'grid',
        gridTemplateColumns: '1fr 52px 52px 56px',
        padding: '5px 16px',
        background: 'var(--surface-sunken)',
        borderBottom: '1px solid var(--rule-hair)',
        fontFamily: 'var(--font-mono)',
        fontSize: 7,
        letterSpacing: '1.2px',
        color: 'var(--text-muted)'
      }
    }, /*#__PURE__*/React.createElement("span", null, "RECENT"), /*#__PURE__*/React.createElement("span", {
      style: {
        textAlign: 'center'
      }
    }, "SETS"), /*#__PURE__*/React.createElement("span", {
      style: {
        textAlign: 'center'
      }
    }, "IMPR"), /*#__PURE__*/React.createElement("span", {
      style: {
        textAlign: 'right'
      }
    }, "VOL")), RECENT.map((w, i) => /*#__PURE__*/React.createElement("div", {
      key: i,
      style: {
        display: 'grid',
        gridTemplateColumns: '1fr 52px 52px 56px',
        alignItems: 'center',
        padding: '8px 16px',
        borderBottom: '1px solid var(--rule-hair)'
      }
    }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 600,
        fontSize: 14,
        letterSpacing: '0.3px'
      }
    }, w.name), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 8,
        color: 'var(--text-muted)',
        marginTop: 1
      }
    }, w.date)), /*#__PURE__*/React.createElement("div", {
      style: {
        textAlign: 'center',
        fontFamily: 'var(--font-mono)',
        fontSize: 11,
        fontWeight: 700,
        color: 'var(--text-muted)'
      }
    }, w.sets), /*#__PURE__*/React.createElement("div", {
      style: {
        textAlign: 'center'
      }
    }, /*#__PURE__*/React.createElement(TrendValue, {
      value: w.improved,
      direction: "up",
      showArrow: false
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        textAlign: 'right'
      }
    }, /*#__PURE__*/React.createElement(TrendValue, {
      value: w.vol,
      direction: "up"
    })))), /*#__PURE__*/React.createElement("div", {
      style: {
        height: 96
      }
    }))), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '10px 16px 0',
        background: 'var(--surface-canvas)'
      }
    }, draft ? /*#__PURE__*/React.createElement(DockedCTA, {
      variant: "draft",
      label: "CONTINUE PUSH DAY",
      meta: "24:18 \xB7 9/28 SETS DONE",
      progress: 9 / 28,
      onClick: onStart
    }) : /*#__PURE__*/React.createElement(DockedCTA, {
      overline: 'TODAY · ' + SESSION.program,
      label: SESSION.name,
      metaOverline: SESSION.est,
      meta: "START WORKOUT \u203A",
      onClick: onStart
    })), /*#__PURE__*/React.createElement(TabBar, {
      active: "Home",
      onSelect: onTab
    }));
  }
  Object.assign(window, {
    KitHome,
    KitFriendsChip
  });
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/pump/screen-home.jsx", error: String((e && e.message) || e) }); }

// ui_kits/pump/screen-logger.jsx
try { (() => {
// Workout logger — card-stack layout. Tap a set's check to log it; tap PLATES to
(function () {
  // expand the calculator on the active set; tap the rest pill to open the sheet.
  const {
    ExerciseCard,
    SetRow,
    PlateBar,
    Masthead,
    RestTimerPill,
    DockedCTA,
    DashedAdd,
    SectionLabel,
    FilterChip
  } = window.PumpDesignSystem_e68c28;
  const BAR_TYPES = [['BARBELL', 20], ['OLY 15', 15], ['EZ', 7.5], ['TRAP', 25], ['SAFETY', 32]];
  function KitPlateDrawer({
    kg,
    barKg,
    onBar,
    open,
    onToggle
  }) {
    return /*#__PURE__*/React.createElement("div", {
      style: {
        borderBottom: '1px solid var(--rule-hair)'
      }
    }, /*#__PURE__*/React.createElement("div", {
      onClick: onToggle,
      style: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '5px 12px',
        background: 'var(--surface-sunken)',
        cursor: 'pointer'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 9,
        letterSpacing: '1.2px',
        color: 'var(--text-muted)'
      }
    }, "PLATES \xB7 ", kg, "KG"), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 9,
        color: 'var(--text-muted)'
      }
    }, open ? '▴ CLOSE' : '▾ SHOW')), open && /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '10px 12px',
        background: 'var(--surface-sunken)'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        background: 'var(--surface-elevated)',
        border: '1px solid var(--rule-strong)',
        borderRadius: 12,
        padding: '10px 12px'
      }
    }, /*#__PURE__*/React.createElement(SectionLabel, {
      meta: 'BAR ' + barKg + 'KG'
    }, "Plate calculator"), /*#__PURE__*/React.createElement(PlateBar, {
      targetKg: kg,
      barKg: barKg
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        gap: 4,
        marginTop: 10,
        paddingTop: 8,
        borderTop: '1px solid var(--rule-hair)'
      }
    }, BAR_TYPES.map(([n, w]) => /*#__PURE__*/React.createElement("div", {
      key: n,
      onClick: () => onBar(w),
      style: {
        flex: 1,
        textAlign: 'center',
        padding: '5px 2px',
        borderRadius: 6,
        cursor: 'pointer',
        background: w === barKg ? 'var(--surface-inverse)' : 'transparent',
        color: w === barKg ? 'var(--text-inverse)' : 'var(--text-muted)',
        border: w === barKg ? 'none' : '1px solid var(--rule-strong)',
        fontFamily: 'var(--font-mono)',
        fontSize: 9,
        fontWeight: 700,
        letterSpacing: '0.5px'
      }
    }, /*#__PURE__*/React.createElement("div", null, n), /*#__PURE__*/React.createElement("div", {
      style: {
        fontSize: 8,
        opacity: 0.7,
        marginTop: 1
      }
    }, w, "KG")))))));
  }
  function KitRestSheet({
    onClose
  }) {
    const [mins, setMins] = React.useState(1);
    const [secs, setSecs] = React.useState(30);
    const presets = [['OFF', 0], ['0:30', 30], ['1:00', 60], ['1:30', 90], ['2:00', 120], ['2:30', 150], ['3:00', 180], ['5:00', 300]];
    const total = mins * 60 + secs;
    return /*#__PURE__*/React.createElement("div", {
      style: {
        position: 'absolute',
        inset: 0,
        zIndex: 90,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'flex-end'
      }
    }, /*#__PURE__*/React.createElement("div", {
      onClick: onClose,
      style: {
        position: 'absolute',
        inset: 0,
        background: 'rgba(31,28,25,0.45)',
        backdropFilter: 'blur(6px)'
      }
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        position: 'relative',
        background: 'var(--surface-canvas)',
        borderRadius: '18px 18px 0 0',
        padding: '10px 20px 28px',
        borderTop: '1px solid var(--rule-strong)'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        width: 36,
        height: 4,
        background: 'var(--text-faint)',
        borderRadius: 2,
        margin: '0 auto 14px'
      }
    }), /*#__PURE__*/React.createElement(SectionLabel, null, "Rest timer"), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 900,
        fontSize: 22,
        marginTop: 2
      }
    }, "BENCH PRESS"), /*#__PURE__*/React.createElement("div", {
      style: {
        textAlign: 'center',
        fontFamily: 'var(--font-mono)',
        fontWeight: 700,
        fontSize: 56,
        letterSpacing: '-1px',
        margin: '12px 0 4px'
      }
    }, mins, ":", String(secs).padStart(2, '0')), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'grid',
        gridTemplateColumns: 'repeat(4,1fr)',
        gap: 8,
        marginTop: 12
      }
    }, presets.map(([l, v]) => /*#__PURE__*/React.createElement("div", {
      key: l,
      onClick: () => {
        setMins(Math.floor(v / 60));
        setSecs(v % 60);
      },
      style: {
        height: 44,
        borderRadius: 12,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        cursor: 'pointer',
        background: total === v ? 'var(--accent)' : 'var(--surface-elevated)',
        border: '1px solid ' + (total === v ? 'var(--accent)' : 'var(--rule-strong)'),
        color: total === v ? '#fff' : 'var(--text-primary)',
        fontFamily: 'var(--font-mono)',
        fontSize: 13,
        fontWeight: 700
      }
    }, l))), /*#__PURE__*/React.createElement("div", {
      onClick: onClose,
      style: {
        marginTop: 16
      }
    }, /*#__PURE__*/React.createElement(DockedCTA, {
      label: "SAVE",
      onClick: onClose
    }))));
  }
  function KitLogger({
    onFinish,
    onBack
  }) {
    const [sets, setSets] = React.useState(() => EXERCISES.map(e => e.sets.map(s => s.state || 'pending')));
    const [collapsed, setCollapsed] = React.useState({});
    const [plateOpen, setPlateOpen] = React.useState(false);
    const [barKg, setBarKg] = React.useState(20);
    const [rest, setRest] = React.useState(false);
    const [restSecs, setRestSecs] = React.useState(0);
    const toggle = (ei, si) => setSets(prev => prev.map((row, i) => i !== ei ? row : row.map((st, j) => {
      if (j !== si) return st === 'active' ? 'pending' : st;
      return st === 'done' ? 'pending' : 'done';
    })));
    const total = sets.reduce((a, r) => a + r.length, 0);
    const done = sets.reduce((a, r) => a + r.filter(s => s === 'done').length, 0);
    return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(KitStatusBar, null), /*#__PURE__*/React.createElement(Masthead, {
      overline: "SESSION",
      title: "PUSH \xB7 24:18",
      onBack: onBack,
      right: /*#__PURE__*/React.createElement(RestTimerPill, {
        seconds: restSecs,
        total: 150,
        onClick: () => setRest(true)
      })
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        overflowY: 'auto',
        padding: '10px 10px 0'
      }
    }, EXERCISES.map((ex, ei) => {
      const rowStates = sets[ei];
      const activeIdx = rowStates.indexOf('active');
      const isBarbell = ex.equipment === 'BARBELL';
      return /*#__PURE__*/React.createElement(ExerciseCard, {
        key: ei,
        index: ei,
        name: ex.name,
        equipment: ex.equipment,
        pr: ex.pr,
        oneRm: ex.oneRm,
        delta: ex.delta,
        deltaDirection: ex.deltaUp ? 'up' : 'down',
        setsDone: rowStates.filter(s => s === 'done').length,
        totalSets: ex.sets.length,
        hasRIR: ex.hasRIR,
        lastNote: ex.lastNote,
        collapsed: !!collapsed[ei],
        onToggleCollapse: () => setCollapsed(p => ({
          ...p,
          [ei]: !p[ei]
        }))
      }, ex.sets.map((s, si) => /*#__PURE__*/React.createElement(React.Fragment, {
        key: si
      }, /*#__PURE__*/React.createElement(SetRow, {
        index: si,
        type: s.type,
        kg: s.kg,
        reps: s.reps,
        rir: s.rir,
        prevKg: s.prevKg,
        prevReps: s.prevReps,
        prevRir: s.prevRir,
        state: rowStates[si],
        isPR: s.isPR,
        hasRIR: ex.hasRIR,
        onClick: () => {
          toggle(ei, si);
          if (rowStates[si] !== 'done') {
            setRestSecs(102);
          }
        }
      }), isBarbell && si === activeIdx && /*#__PURE__*/React.createElement(KitPlateDrawer, {
        kg: s.kg || s.prevKg,
        barKg: barKg,
        onBar: setBarKg,
        open: plateOpen,
        onToggle: () => setPlateOpen(o => !o)
      }))), /*#__PURE__*/React.createElement("div", {
        style: {
          padding: '8px 12px'
        }
      }, /*#__PURE__*/React.createElement(DashedAdd, {
        label: "Add set",
        height: 30
      })));
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        borderTop: '1px solid var(--rule-strong)',
        padding: '10px 2px 16px'
      }
    }, /*#__PURE__*/React.createElement(DashedAdd, {
      label: "Add exercise"
    }))), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '10px 12px 28px',
        background: 'var(--surface-canvas)',
        borderTop: '1px solid var(--rule-strong)'
      }
    }, /*#__PURE__*/React.createElement(DockedCTA, {
      label: "FINISH WORKOUT \u203A",
      meta: total - done + ' SETS LEFT',
      progress: done / total,
      onClick: onFinish
    })), rest && /*#__PURE__*/React.createElement(KitRestSheet, {
      onClose: () => setRest(false)
    }));
  }
  Object.assign(window, {
    KitLogger,
    KitPlateDrawer,
    KitRestSheet
  });
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/pump/screen-logger.jsx", error: String((e && e.message) || e) }); }

// ui_kits/pump/screen-programs.jsx
try { (() => {
// Programs tab — template list with split-day tiles, quick start rows, preset picker.
(function () {
  const {
    TabBar,
    Masthead,
    SectionLabel,
    DashedAdd,
    FilterChip,
    DockedCTA,
    EmptyState,
    TrendValue
  } = window.PumpDesignSystem_e68c28;
  function KitProgramRow({
    p,
    active,
    onClick
  }) {
    return /*#__PURE__*/React.createElement("div", {
      onClick: onClick,
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        padding: '12px 16px',
        borderBottom: '1px solid var(--rule-hair)',
        background: active ? 'var(--accent-row)' : 'transparent',
        borderLeft: active ? '2px solid var(--accent)' : '2px solid transparent',
        cursor: 'pointer'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        minWidth: 0
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 700,
        fontSize: 18,
        letterSpacing: '0.2px'
      }
    }, p.name), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 9,
        letterSpacing: '1.5px',
        color: 'var(--text-muted)',
        marginTop: 3
      }
    }, p.meta)), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        gap: 3,
        flexShrink: 0
      }
    }, p.days.map((d, i) => /*#__PURE__*/React.createElement("div", {
      key: i,
      style: {
        width: 18,
        height: 18,
        borderRadius: 4,
        background: 'var(--surface-sunken)',
        border: '1px solid var(--rule-hair)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        fontFamily: 'var(--font-mono)',
        fontSize: 8,
        fontWeight: 700,
        color: 'var(--text-muted)'
      }
    }, d))));
  }
  function KitPrograms({
    onTab,
    onStart
  }) {
    const [sel, setSel] = React.useState(0);
    const [filter, setFilter] = React.useState('MY PROGRAMS');
    return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(KitStatusBar, null), /*#__PURE__*/React.createElement(Masthead, {
      right: /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(KitSearchGlyph, null), /*#__PURE__*/React.createElement(KitAvatar, null))
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '12px 16px 8px'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 900,
        fontSize: 24,
        letterSpacing: '0.5px'
      }
    }, "PROGRAMS"), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        gap: 6,
        marginTop: 10
      }
    }, ['MY PROGRAMS', 'PRESETS', 'EXERCISES'].map(f => /*#__PURE__*/React.createElement(FilterChip, {
      key: f,
      label: f,
      selected: filter === f,
      onClick: () => setFilter(f)
    })))), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        overflowY: 'auto'
      }
    }, filter === 'MY PROGRAMS' && /*#__PURE__*/React.createElement(React.Fragment, null, PROGRAMS.map((p, i) => /*#__PURE__*/React.createElement(KitProgramRow, {
      key: i,
      p: p,
      active: i === sel,
      onClick: () => setSel(i)
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '12px 16px'
      }
    }, /*#__PURE__*/React.createElement(DashedAdd, {
      label: "New program",
      height: 44
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '4px 16px 6px'
      }
    }, /*#__PURE__*/React.createElement(SectionLabel, {
      meta: "LAST 7 DAYS"
    }, "Quick start")), [['Push Day', 'SAT · 28 SETS', '+8%'], ['Pull Day', 'THU · 26 SETS', '+11%'], ['Legs', 'LAST SAT · 28 SETS', '+3%']].map((q, i) => /*#__PURE__*/React.createElement("div", {
      key: i,
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        padding: '10px 16px',
        borderBottom: '1px solid var(--rule-hair)'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 600,
        fontSize: 14
      }
    }, q[0]), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 9,
        letterSpacing: '1.2px',
        color: 'var(--text-muted)',
        marginTop: 2
      }
    }, q[1])), /*#__PURE__*/React.createElement(TrendValue, {
      value: q[2],
      direction: "up"
    }), /*#__PURE__*/React.createElement("div", {
      onClick: onStart,
      style: {
        height: 28,
        padding: '0 14px',
        borderRadius: 999,
        background: 'var(--accent)',
        color: '#fff',
        display: 'flex',
        alignItems: 'center',
        fontFamily: 'var(--font-mono)',
        fontSize: 10,
        fontWeight: 700,
        letterSpacing: '1px',
        cursor: 'pointer'
      }
    }, "START")))), filter === 'PRESETS' && /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '4px 0'
      }
    }, [['Push Pull Legs', '6 DAYS/WK · CLASSIC HYPERTROPHY SPLIT'], ['Upper / Lower', '4 DAYS/WK · BALANCED FREQUENCY'], ['Full Body', '3 DAYS/WK · BEST FOR BEGINNERS'], ['Bro Split', '5 DAYS/WK · ONE MUSCLE PER DAY'], ['PHUL', '4 DAYS/WK · POWER + HYPERTROPHY'], ['Blank', 'START FROM AN EMPTY DAY']].map((p, i) => /*#__PURE__*/React.createElement("div", {
      key: i,
      style: {
        padding: '12px 16px',
        borderBottom: '1px solid var(--rule-hair)'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 700,
        fontSize: 16
      }
    }, p[0]), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 9,
        letterSpacing: '1.5px',
        color: 'var(--text-muted)',
        marginTop: 3
      }
    }, p[1])))), filter === 'EXERCISES' && /*#__PURE__*/React.createElement(EmptyState, {
      title: "No custom exercises yet.",
      description: "84 exercises ship with Pump. Anything you build shows up here.",
      action: /*#__PURE__*/React.createElement(DashedAdd, {
        label: "Create exercise",
        height: 44
      }),
      glyph: /*#__PURE__*/React.createElement("svg", {
        width: "30",
        height: "30",
        viewBox: "0 0 24 24",
        fill: "none",
        stroke: "currentColor",
        strokeWidth: "1.6",
        strokeLinecap: "round"
      }, /*#__PURE__*/React.createElement("path", {
        d: "M4 9v6M20 9v6M7 6v12M17 6v12M7 12h10"
      }))
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        height: 80
      }
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '10px 16px 0',
        background: 'var(--surface-canvas)'
      }
    }, /*#__PURE__*/React.createElement(DockedCTA, {
      overline: 'TODAY · ' + SESSION.program,
      label: SESSION.name,
      metaOverline: SESSION.est,
      meta: "START WORKOUT \u203A",
      onClick: onStart
    })), /*#__PURE__*/React.createElement(TabBar, {
      active: "Programs",
      onSelect: onTab
    }));
  }
  Object.assign(window, {
    KitPrograms,
    KitProgramRow
  });
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/pump/screen-programs.jsx", error: String((e && e.message) || e) }); }

// ui_kits/pump/screen-summary.jsx
try { (() => {
// Post-workout summary — dark share card inside the scroll, then the caption composer.
(function () {
  const {
    TickerStrip,
    KPIBlock,
    PRMark,
    DockedCTA,
    FilterChip,
    SectionLabel,
    TrendValue,
    Masthead
  } = window.PumpDesignSystem_e68c28;
  const BREAKDOWN = [{
    name: 'Bench Press',
    best: '100×6',
    delta: '+5KG',
    dir: 'up',
    pr: true
  }, {
    name: 'Overhead Press',
    best: '70×6',
    delta: '+2.5KG',
    dir: 'up'
  }, {
    name: 'Incline DB Press',
    best: '34×10',
    delta: '+2KG',
    dir: 'up',
    pr: true
  }, {
    name: 'Cable Fly',
    best: '16×12',
    delta: '+1KG',
    dir: 'up'
  }, {
    name: 'Tricep Pushdown',
    best: '30×12',
    delta: '0',
    dir: null
  }, {
    name: 'Lateral Raise',
    best: '12×15',
    delta: '-1KG',
    dir: 'down'
  }];
  function KitShareCard() {
    return /*#__PURE__*/React.createElement("div", {
      "data-theme": "dark",
      style: {
        background: '#1A1917',
        borderRadius: 14,
        overflow: 'hidden',
        border: '1px solid rgba(236,229,214,0.08)'
      }
    }, /*#__PURE__*/React.createElement(TickerStrip, {
      items: TICKER,
      paused: true
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '14px 14px 16px',
        color: '#ECE5D6'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'flex-end'
      }
    }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 8,
        letterSpacing: '1.5px',
        color: 'rgba(236,229,214,0.5)'
      }
    }, "SESSION \xB7 SAT 18 APR"), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 900,
        fontSize: 30,
        letterSpacing: '0.5px',
        lineHeight: 1
      }
    }, "PUSH DAY")), /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontWeight: 700,
        fontSize: 20
      }
    }, "1:04:22")), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'grid',
        gridTemplateColumns: 'repeat(4,1fr)',
        gap: 0,
        marginTop: 14,
        borderTop: '1px solid rgba(236,229,214,0.08)',
        borderBottom: '1px solid rgba(236,229,214,0.08)'
      }
    }, [['Sets', '28'], ['Kcal', '412'], ['Vol', '7,240'], ['Streak', '14D']].map((s, i) => /*#__PURE__*/React.createElement("div", {
      key: i,
      style: {
        padding: '10px 8px',
        borderRight: i < 3 ? '1px solid rgba(236,229,214,0.08)' : 'none'
      }
    }, /*#__PURE__*/React.createElement(KPIBlock, {
      variant: "compact",
      align: "center",
      label: s[0],
      value: s[1]
    })))), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: 18,
        marginTop: 14
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 8,
        letterSpacing: '1.5px',
        color: 'rgba(236,229,214,0.5)'
      }
    }, "IMPROVED ON"), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        alignItems: 'baseline',
        gap: 6
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontWeight: 700,
        fontSize: 48,
        color: '#00AA55',
        lineHeight: 1
      }
    }, "4"), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 14,
        color: 'rgba(236,229,214,0.4)'
      }
    }, "/ 6 EXERCISES"))), /*#__PURE__*/React.createElement("div", {
      style: {
        textAlign: 'right'
      }
    }, /*#__PURE__*/React.createElement("div", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontSize: 8,
        letterSpacing: '1.5px',
        color: 'rgba(236,229,214,0.5)',
        marginBottom: 4
      }
    }, "PERSONAL RECORDS"), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        flexDirection: 'column',
        gap: 4,
        alignItems: 'flex-end',
        fontSize: 14
      }
    }, /*#__PURE__*/React.createElement(PRMark, {
      label: "Bench"
    }, "100\xD76"), /*#__PURE__*/React.createElement(PRMark, {
      label: "Incline DB"
    }, "34\xD710")))), /*#__PURE__*/React.createElement("div", {
      style: {
        marginTop: 14,
        borderTop: '1px solid rgba(236,229,214,0.08)'
      }
    }, BREAKDOWN.map((b, i) => /*#__PURE__*/React.createElement("div", {
      key: i,
      style: {
        display: 'grid',
        gridTemplateColumns: '1fr 68px 60px',
        alignItems: 'center',
        padding: '6px 0',
        borderBottom: '1px solid rgba(236,229,214,0.08)'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: 'var(--font-display)',
        fontWeight: 600,
        fontSize: 13,
        color: b.pr ? '#ECE5D6' : 'rgba(236,229,214,0.8)',
        borderBottom: b.pr ? '1.5px solid #ECE5D6' : 'none',
        justifySelf: 'start',
        lineHeight: 1.3
      }
    }, b.name), /*#__PURE__*/React.createElement("span", {
      style: {
        fontFamily: 'var(--font-mono)',
        fontWeight: 700,
        fontSize: 12,
        textAlign: 'right',
        color: 'rgba(236,229,214,0.75)'
      }
    }, b.best), /*#__PURE__*/React.createElement("span", {
      style: {
        textAlign: 'right'
      }
    }, /*#__PURE__*/React.createElement(TrendValue, {
      value: b.delta,
      direction: b.dir,
      size: 11
    }))))), /*#__PURE__*/React.createElement("div", {
      style: {
        marginTop: 12,
        textAlign: 'right',
        fontFamily: 'var(--font-mono)',
        fontSize: 8,
        letterSpacing: '2px',
        color: 'rgba(236,229,214,0.3)'
      }
    }, "PULSE/PUMP")));
  }
  function KitSummary({
    onDone,
    onBack
  }) {
    const [dest, setDest] = React.useState('PULSE FEED');
    const [caption, setCaption] = React.useState('');
    return /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(KitStatusBar, null), /*#__PURE__*/React.createElement(Masthead, {
      overline: "WORKOUT COMPLETE",
      title: "PUSH DAY \xB7 SAT 18 APR",
      onBack: onBack
    }), /*#__PURE__*/React.createElement("div", {
      style: {
        flex: 1,
        overflowY: 'auto',
        padding: '12px 16px 0'
      }
    }, /*#__PURE__*/React.createElement(KitShareCard, null), /*#__PURE__*/React.createElement("div", {
      style: {
        marginTop: 16
      }
    }, /*#__PURE__*/React.createElement(SectionLabel, null, "Caption"), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        gap: 10,
        marginTop: 8
      }
    }, /*#__PURE__*/React.createElement(KitAvatar, {
      size: 32
    }), /*#__PURE__*/React.createElement("textarea", {
      value: caption,
      onChange: e => setCaption(e.target.value),
      placeholder: "Say something about this session\u2026",
      style: {
        flex: 1,
        minHeight: 56,
        resize: 'none',
        background: 'var(--surface-sunken)',
        border: '1px solid var(--rule-hair)',
        borderRadius: 8,
        padding: '8px 10px',
        fontFamily: 'var(--font-body)',
        fontSize: 13,
        color: 'var(--text-primary)',
        outline: 'none'
      }
    })), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        gap: 6,
        marginTop: 10,
        flexWrap: 'wrap'
      }
    }, /*#__PURE__*/React.createElement(FilterChip, {
      label: "Marcus"
    }), /*#__PURE__*/React.createElement(FilterChip, {
      label: "Priya"
    }), /*#__PURE__*/React.createElement(FilterChip, {
      label: "+ Add"
    })), /*#__PURE__*/React.createElement(SectionLabel, {
      style: {
        marginTop: 16
      }
    }, "Share to"), /*#__PURE__*/React.createElement("div", {
      style: {
        display: 'flex',
        gap: 6,
        marginTop: 8,
        flexWrap: 'wrap'
      }
    }, ['PULSE FEED', 'INSTAGRAM', 'MESSAGES'].map(d => /*#__PURE__*/React.createElement(FilterChip, {
      key: d,
      label: d,
      selected: dest === d,
      onClick: () => setDest(d)
    }))), /*#__PURE__*/React.createElement("div", {
      style: {
        height: 24
      }
    }))), /*#__PURE__*/React.createElement("div", {
      style: {
        padding: '10px 16px 28px',
        background: 'var(--surface-canvas)',
        borderTop: '1px solid var(--rule-strong)',
        display: 'flex',
        gap: 8
      }
    }, /*#__PURE__*/React.createElement(DockedCTA, {
      label: "POST TO FEED",
      meta: "28 SETS \xB7 1:04:22",
      onClick: onDone,
      style: {
        flex: 1
      }
    }), /*#__PURE__*/React.createElement("div", {
      onClick: onDone,
      style: {
        width: 54,
        height: 54,
        borderRadius: 12,
        border: '1px solid var(--rule-strong)',
        background: 'var(--surface-elevated)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        color: 'var(--text-muted)',
        fontSize: 18,
        cursor: 'pointer',
        flexShrink: 0
      }
    }, "\xB7\xB7\xB7")));
  }
  Object.assign(window, {
    KitSummary,
    KitShareCard
  });
})();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/pump/screen-summary.jsx", error: String((e && e.message) || e) }); }

__ds_ns.DashedAdd = __ds_scope.DashedAdd;

__ds_ns.DayScrubber = __ds_scope.DayScrubber;

__ds_ns.DockedCTA = __ds_scope.DockedCTA;

__ds_ns.FilterChip = __ds_scope.FilterChip;

__ds_ns.SectionLabel = __ds_scope.SectionLabel;

__ds_ns.ConfidenceDots = __ds_scope.ConfidenceDots;

__ds_ns.KPIBlock = __ds_scope.KPIBlock;

__ds_ns.TickerStrip = __ds_scope.TickerStrip;

__ds_ns.TrendValue = __ds_scope.TrendValue;

__ds_ns.WeekBars = __ds_scope.WeekBars;

__ds_ns.EmptyState = __ds_scope.EmptyState;

__ds_ns.PRMark = __ds_scope.PRMark;

__ds_ns.ExerciseCard = __ds_scope.ExerciseCard;

__ds_ns.PLATE_COLORS = __ds_scope.PLATE_COLORS;

__ds_ns.PlateBar = __ds_scope.PlateBar;

__ds_ns.SetRow = __ds_scope.SetRow;

__ds_ns.SET_TYPES = __ds_scope.SET_TYPES;

__ds_ns.SetTypeChip = __ds_scope.SetTypeChip;

__ds_ns.Masthead = __ds_scope.Masthead;

__ds_ns.RestTimerPill = __ds_scope.RestTimerPill;

__ds_ns.TabBar = __ds_scope.TabBar;

})();
