import React, { useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, { Path, Circle, Ellipse, Line, Rect } from 'react-native-svg';
import { useTheme } from '../../hooks/useTheme';
import { useAppStore } from '../../store/appStore';

const WEEK_DATA = [
  { d: 'M', date: 13, kind: 'Push', total: 24, sets: { chest: 8, shoulders: 6, triceps: 6, traps: 2, core: 2 } },
  { d: 'T', date: 14, kind: 'Rest', total: 0, sets: {} },
  { d: 'W', date: 15, kind: 'Pull', total: 26, sets: { back: 10, biceps: 6, traps: 4, core: 2 } },
  { d: 'T', date: 16, kind: 'Rest', total: 0, sets: {} },
  { d: 'F', date: 17, kind: 'Legs', total: 32, sets: { quads: 10, glutes: 8, hamstrings: 4, calves: 4, core: 2 } },
  { d: 'S', date: 18, kind: 'Cond.', total: 12, sets: { core: 6, shoulders: 2, calves: 2, glutes: 2 } },
  { d: 'S', date: 19, kind: '—', total: 0, sets: {} },
];

const TARGETS: Record<string, number> = {
  chest: 16, shoulders: 14, triceps: 10, back: 18, traps: 8,
  biceps: 10, quads: 16, glutes: 14, hamstrings: 12, calves: 8, core: 10,
};

function thermal(t: number, dark = false): string {
  const stops: Array<[number, [number, number, number]]> = dark
    ? [
        [0, [40, 38, 34]],
        [0.2, [80, 60, 50]],
        [0.45, [148, 96, 64]],
        [0.7, [220, 130, 70]],
        [1, [248, 100, 80]],
      ]
    : [
        [0, [240, 236, 226]],
        [0.2, [236, 214, 184]],
        [0.45, [226, 170, 124]],
        [0.7, [212, 118, 88]],
        [1, [192, 72, 60]],
      ];
  t = Math.max(0, Math.min(1, t));
  for (let i = 0; i < stops.length - 1; i++) {
    const [a, ca] = stops[i];
    const [b, cb] = stops[i + 1];
    if (t <= b) {
      const k = (t - a) / (b - a);
      return `rgb(${Math.round(ca[0] + (cb[0] - ca[0]) * k)},${Math.round(ca[1] + (cb[1] - ca[1]) * k)},${Math.round(ca[2] + (cb[2] - ca[2]) * k)})`;
    }
  }
  return dark ? 'rgb(248,100,80)' : 'rgb(192,72,60)';
}

function BodyMapSVG({ heat, isDark }: { heat: Record<string, number>; isDark: boolean }) {
  const base = isDark ? 'rgba(255,255,255,0.04)' : 'rgba(80,60,40,0.05)';
  const sk = isDark ? 'rgba(255,255,255,0.07)' : 'rgba(80,60,40,0.08)';
  const c = (id: string) =>
    heat[id] !== undefined ? thermal(heat[id], isDark) : base;

  return (
    <Svg viewBox="0 0 200 320" width={170} height={272}>
      <Circle cx={100} cy={22} r={14} fill={base} stroke={sk} strokeWidth={0.7} />
      <Rect x={94} y={34} width={12} height={10} rx={2} fill={base} stroke={sk} strokeWidth={0.7} />
      <Path d="M75 46 L100 42 L125 46 L120 56 L100 52 L80 56 Z" fill={c('traps')} stroke={sk} strokeWidth={0.7} />
      <Path d="M70 56 Q100 48 130 56 L132 96 Q100 102 68 96 Z" fill={c('chest')} stroke={sk} strokeWidth={0.7} />
      <Path d="M55 60 Q48 70 50 90 L66 92 Q70 76 70 56 Z" fill={c('shoulders')} stroke={sk} strokeWidth={0.7} />
      <Path d="M145 60 Q152 70 150 90 L134 92 Q130 76 130 56 Z" fill={c('shoulders')} stroke={sk} strokeWidth={0.7} />
      <Path d="M40 90 Q34 110 36 130 L52 130 Q54 110 50 90 Z" fill={c('biceps')} stroke={sk} strokeWidth={0.7} />
      <Path d="M160 90 Q166 110 164 130 L148 130 Q146 110 150 90 Z" fill={c('biceps')} stroke={sk} strokeWidth={0.7} />
      <Path d="M30 130 Q26 154 30 172 L48 172 Q50 154 48 130 Z" fill={c('forearms')} stroke={sk} strokeWidth={0.7} />
      <Path d="M170 130 Q174 154 170 172 L152 172 Q150 154 152 130 Z" fill={c('forearms')} stroke={sk} strokeWidth={0.7} />
      <Path d="M75 96 Q100 100 125 96 L122 138 Q100 142 78 138 Z" fill={c('core')} stroke={sk} strokeWidth={0.7} />
      <Path d="M76 138 L124 138 L128 158 L72 158 Z" fill={base} stroke={sk} strokeWidth={0.7} />
      <Path d="M76 158 Q72 200 76 230 L98 230 Q100 200 98 158 Z" fill={c('quads')} stroke={sk} strokeWidth={0.7} />
      <Path d="M124 158 Q128 200 124 230 L102 230 Q100 200 102 158 Z" fill={c('quads')} stroke={sk} strokeWidth={0.7} />
      <Line x1={78} y1={232} x2={98} y2={232} stroke={sk} strokeWidth={0.7} />
      <Line x1={102} y1={232} x2={124} y2={232} stroke={sk} strokeWidth={0.7} />
      <Path d="M80 234 Q76 260 80 286 L96 286 Q98 260 96 234 Z" fill={c('calves')} stroke={sk} strokeWidth={0.7} />
      <Path d="M120 234 Q124 260 120 286 L104 286 Q102 260 104 234 Z" fill={c('calves')} stroke={sk} strokeWidth={0.7} />
      <Ellipse cx={88} cy={294} rx={11} ry={5} fill={base} stroke={sk} strokeWidth={0.7} />
      <Ellipse cx={112} cy={294} rx={11} ry={5} fill={base} stroke={sk} strokeWidth={0.7} />
    </Svg>
  );
}

function computeWeekHeat() {
  const tot: Record<string, number> = {};
  for (const d of WEEK_DATA) {
    for (const k in d.sets) tot[k] = (tot[k] || 0) + (d.sets as any)[k];
  }
  const map: Record<string, number> = {};
  for (const k in TARGETS) {
    map[k] = Math.min(1, (tot[k] || 0) / TARGETS[k]);
  }
  return map;
}

function computeDayHeat(idx: number) {
  const d = WEEK_DATA[idx];
  const map: Record<string, number> = {};
  const vals = Object.values(d.sets) as number[];
  const max = Math.max(...vals, 1);
  for (const k in d.sets) map[k] = Math.min(1, (d.sets as any)[k] / max);
  return map;
}

// ── Volume sparkline ───────────────────────────────────────────

function VolumeSparkline({ data }: { data: number[] }) {
  const { C } = useTheme();
  const max = Math.max(...data, 1);
  const w = 280;
  const h = 40;
  const step = w / (data.length - 1);
  const pts = data.map((v, i) => `${i * step},${h - (v / max) * h}`).join(' ');
  return (
    <Svg width={w} height={h}>
      <Path
        d={`M${pts.replace(/,/g, ' ').replace(/ /g, ',')}`.replace(/,(\d)/g, ' $1')}
        fill="none"
        stroke={C.accent}
        strokeWidth={1.5}
      />
    </Svg>
  );
}

// ── Main Body map screen ───────────────────────────────────────

export default function BodyScreen() {
  const { C, Fonts, isDark } = useTheme();
  const insets = useSafeAreaInsets();
  const [dayIdx, setDayIdx] = useState(-1);

  const heat = dayIdx === -1 ? computeWeekHeat() : computeDayHeat(dayIdx);
  const weekTot = (() => {
    const t: Record<string, number> = {};
    for (const d of WEEK_DATA) for (const k in d.sets) t[k] = (t[k] || 0) + (d.sets as any)[k];
    return t;
  })();
  const daySets = dayIdx === -1 ? weekTot : (WEEK_DATA[dayIdx]?.sets ?? {});
  const totalSets = Object.values(daySets).reduce((a: number, b: any) => a + b, 0);
  const target = dayIdx === -1 ? 132 : 22;

  const ratios = Object.keys(TARGETS).map((k) => ({
    k,
    sets: (daySets as any)[k] || 0,
    target: TARGETS[k],
    ratio: ((daySets as any)[k] || 0) / TARGETS[k],
  }));
  const gainers = [...ratios].sort((a, b) => b.ratio - a.ratio).slice(0, 3);
  const gaps = [...ratios].sort((a, b) => a.ratio - b.ratio).slice(0, 3);

  const sparklineData = [60, 72, 58, 84, 78, 94, 102, 88, 110, 96, 108, 120];

  return (
    <View style={[styles.screen, { backgroundColor: C.bg, paddingTop: insets.top }]}>
      {/* Ticker strip */}
      <View style={styles.tickerBar}>
        <Text style={styles.tickerText}>PULSE/PUMP</Text>
        <Text style={[styles.tickerLabel, { color: 'rgba(236,229,214,0.5)' }]}>BODY · LIVE</Text>
      </View>

      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{ paddingBottom: 20 }}
        showsVerticalScrollIndicator={false}
      >
        {/* Big stat block */}
        <View style={[styles.statBlock, { borderBottomColor: C.hair }]}>
          <View>
            <Text style={[styles.statTotal, { color: C.ink, fontFamily: Fonts.mono }]}>
              {totalSets}
            </Text>
            <Text style={[styles.statTarget, { color: C.muted }]}>
              / {target} TARGET
            </Text>
          </View>
          <View style={{ alignItems: 'flex-end' }}>
            <Text style={[styles.statPct, { color: C.up }]}>
              +4.2% vs last
            </Text>
          </View>
        </View>

        {/* Day scrubber */}
        <View style={[styles.dayScrubber, { borderBottomColor: C.hair }]}>
          <Pressable
            onPress={() => setDayIdx(-1)}
            style={[
              styles.weekPill,
              {
                backgroundColor: dayIdx === -1 ? C.ink : 'rgba(0,0,0,0.04)',
                borderColor: dayIdx === -1 ? C.ink : C.hair,
              },
            ]}
          >
            <Text style={[styles.weekPillLabel, { color: dayIdx === -1 ? C.bg : C.muted }]}>WEEK</Text>
            <Text style={[styles.weekPillNum, { color: dayIdx === -1 ? C.bg : C.ink, fontFamily: Fonts.mono }]}>14</Text>
          </Pressable>
          {WEEK_DATA.map((d, i) => (
            <Pressable
              key={i}
              onPress={() => setDayIdx(i)}
              style={[
                styles.dayBtn,
                {
                  backgroundColor: dayIdx === i ? C.ink : 'rgba(0,0,0,0.04)',
                  borderColor: dayIdx === i ? C.ink : C.hair,
                },
              ]}
            >
              <Text style={[styles.dayBtnLabel, { color: dayIdx === i ? C.bg : C.muted }]}>{d.d}</Text>
              <Text style={[styles.dayBtnNum, { color: dayIdx === i ? C.bg : C.ink, fontFamily: Fonts.mono }]}>{d.date}</Text>
              {d.total > 0 && dayIdx !== i && (
                <View style={[styles.workoutDot, { backgroundColor: C.accent }]} />
              )}
            </Pressable>
          ))}
        </View>

        {/* Body map + top/gap columns */}
        <View style={[styles.bodySection, { borderBottomColor: C.hair }]}>
          <View style={styles.muscleList}>
            <Text style={[styles.muscleListLabel, { color: C.muted }]}>TOP</Text>
            {gainers.map((g, i) => (
              <View key={i} style={styles.muscleRow}>
                <View style={[styles.muscleDot, { backgroundColor: thermal(g.ratio, isDark) }]} />
                <Text style={[styles.muscleName, { color: C.ink }]}>{g.k.toUpperCase()}</Text>
                <Text style={[styles.muscleSets, { color: C.muted, fontFamily: Fonts.mono }]}>
                  {g.sets}
                </Text>
              </View>
            ))}
          </View>

          <BodyMapSVG heat={heat} isDark={isDark} />

          <View style={styles.muscleList}>
            <Text style={[styles.muscleListLabel, { color: C.muted }]}>GAPS</Text>
            {gaps.map((g, i) => (
              <View key={i} style={styles.muscleRow}>
                <View style={[styles.muscleDot, { backgroundColor: thermal(g.ratio, isDark) }]} />
                <Text style={[styles.muscleName, { color: C.ink }]}>{g.k.toUpperCase()}</Text>
                <Text style={[styles.muscleSets, { color: C.muted, fontFamily: Fonts.mono }]}>
                  {g.sets}/{g.target}
                </Text>
              </View>
            ))}
          </View>
        </View>

        {/* 12-week volume sparkline */}
        <View style={styles.sparklineSection}>
          <Text style={[styles.sparklineLabel, { color: C.muted }]}>12-WEEK VOLUME TREND</Text>
          <VolumeSparkline data={sparklineData} />
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  tickerBar: {
    height: 28,
    backgroundColor: '#1a1816',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
  },
  tickerText: { fontFamily: 'SpaceMono-Bold', fontSize: 10, letterSpacing: 2, color: 'rgba(236,229,214,0.9)' },
  tickerLabel: { fontFamily: 'SpaceMono-Regular', fontSize: 10, letterSpacing: 1 },
  statBlock: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-between',
    padding: 16,
    borderBottomWidth: 1,
  },
  statTotal: { fontSize: 52, lineHeight: 56 },
  statTarget: { fontFamily: 'SpaceMono-Regular', fontSize: 9, letterSpacing: 1.2, marginTop: 2 },
  statPct: { fontFamily: 'SpaceMono-Bold', fontSize: 12 },
  dayScrubber: {
    flexDirection: 'row',
    gap: 4,
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderBottomWidth: 1,
  },
  weekPill: {
    flex: 1.2,
    height: 54,
    borderRadius: 10,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  weekPillLabel: { fontFamily: 'SpaceMono-Regular', fontSize: 9, letterSpacing: 1.5, opacity: 0.7 },
  weekPillNum: { fontSize: 14, marginTop: 2 },
  dayBtn: {
    flex: 1,
    height: 54,
    borderRadius: 10,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative',
  },
  dayBtnLabel: { fontFamily: 'SpaceMono-Regular', fontSize: 9, letterSpacing: 1, opacity: 0.65 },
  dayBtnNum: { fontSize: 14, marginTop: 2 },
  workoutDot: { position: 'absolute', bottom: 4, width: 14, height: 2, borderRadius: 1, opacity: 0.6 },
  bodySection: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 12,
    paddingVertical: 20,
    borderBottomWidth: 1,
  },
  muscleList: { width: 80, gap: 10 },
  muscleListLabel: { fontFamily: 'SpaceMono-Bold', fontSize: 8, letterSpacing: 1.5, marginBottom: 4 },
  muscleRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  muscleDot: { width: 6, height: 6, borderRadius: 3 },
  muscleName: { fontFamily: 'SpaceMono-Regular', fontSize: 8, flex: 1 },
  muscleSets: { fontSize: 9 },
  sparklineSection: { padding: 16 },
  sparklineLabel: { fontFamily: 'SpaceMono-Regular', fontSize: 8, letterSpacing: 1.5, marginBottom: 8 },
});
