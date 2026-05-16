import React, { useState, useRef, useEffect } from 'react';
import {
  View, Text, ScrollView, TextInput, TouchableOpacity,
  Animated, Easing,
} from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, { Path, Ellipse, Rect } from 'react-native-svg';
import { useTheme } from '../../hooks/useTheme';
import { useAppStore, Workout } from '../../store/appStore';

// ─── Thermal coloring ─────────────────────────────────────────────────────────

function thermal(t: number, dark = false): string {
  if (dark) {
    const stops: [number, [number, number, number]][] = [
      [0, [38, 36, 34]], [0.2, [70, 54, 36]], [0.45, [120, 72, 40]],
      [0.7, [180, 90, 50]], [1.0, [220, 125, 74]],
    ];
    t = Math.max(0, Math.min(1, t));
    for (let i = 0; i < stops.length - 1; i++) {
      const [a, ca] = stops[i]; const [b, cb] = stops[i + 1];
      if (t <= b) {
        const k = (t - a) / (b - a);
        return `rgb(${Math.round(ca[0] + (cb[0] - ca[0]) * k)},${Math.round(ca[1] + (cb[1] - ca[1]) * k)},${Math.round(ca[2] + (cb[2] - ca[2]) * k)})`;
      }
    }
    return 'rgb(220,125,74)';
  }
  const stops: [number, [number, number, number]][] = [
    [0, [240, 236, 226]], [0.2, [236, 214, 184]], [0.45, [226, 170, 124]],
    [0.7, [212, 118, 88]], [1.0, [192, 72, 60]],
  ];
  t = Math.max(0, Math.min(1, t));
  for (let i = 0; i < stops.length - 1; i++) {
    const [a, ca] = stops[i]; const [b, cb] = stops[i + 1];
    if (t <= b) {
      const k = (t - a) / (b - a);
      return `rgb(${Math.round(ca[0] + (cb[0] - ca[0]) * k)},${Math.round(ca[1] + (cb[1] - ca[1]) * k)},${Math.round(ca[2] + (cb[2] - ca[2]) * k)})`;
    }
  }
  return 'rgb(192,72,60)';
}

// ─── Compute muscle heat from workout ────────────────────────────────────────

const MUSCLE_SET_MAP: Record<string, string[]> = {
  chest: ['chest'], back: ['back', 'lats'], shoulders: ['shoulders', 'delts'],
  biceps: ['biceps'], triceps: ['triceps'], core: ['core', 'abs'],
  quads: ['quads'], hamstrings: ['hamstrings'], glutes: ['glutes'],
  calves: ['calves'], traps: ['traps'], forearms: ['forearms'],
};

function computeHeat(workout: Workout): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const ex of workout.exercises) {
    for (const m of ex.muscleGroups) {
      const key = m.toLowerCase();
      counts[key] = (counts[key] || 0) + ex.sets.filter((s) => s.completed).length;
    }
  }
  const maxSets = Math.max(1, ...Object.values(counts));
  const heat: Record<string, number> = {};
  for (const [k, v] of Object.entries(counts)) {
    heat[k] = v / maxSets;
  }
  return heat;
}

// ─── Body Silhouette ──────────────────────────────────────────────────────────

function BodySilhouette({ heat, size = 76, showBack = false, dark = false }: {
  heat: Record<string, number>; size: number; showBack?: boolean; dark?: boolean;
}) {
  const h = size * 2.4;
  const base = dark ? 'rgba(255,255,255,0.04)' : 'rgba(128,110,90,0.07)';
  const stroke = dark ? 'rgba(255,255,255,0.06)' : 'rgba(31,28,25,0.06)';

  function heatOf(muscle: string) {
    return thermal(heat[muscle] || 0, dark);
  }

  return (
    <Svg viewBox="0 0 200 480" width={size} height={h}>
      {/* Body outline */}
      <Ellipse cx="100" cy="32" rx="22" ry="26" fill={base} />
      <Rect x="90" y="54" width="20" height="18" rx="4" fill={base} />
      <Path d="M60 76 Q54 130 56 200 Q58 260 68 310 L72 340 L128 340 L132 310 Q142 260 144 200 Q146 130 140 76Z" fill={base} />
      <Path d="M60 76 Q46 86 40 108 Q34 140 36 180 Q38 220 48 240 L58 238 Q56 200 58 160 Q60 110 64 88Z" fill={base} />
      <Path d="M140 76 Q154 86 160 108 Q166 140 164 180 Q162 220 152 240 L142 238 Q144 200 142 160 Q140 110 136 88Z" fill={base} />
      <Path d="M48 240 Q40 268 36 300 L46 302 Q54 276 58 244Z" fill={base} />
      <Path d="M152 240 Q160 268 164 300 L154 302 Q146 276 142 244Z" fill={base} />
      <Path d="M72 340 Q66 390 64 440 L90 440 Q94 400 96 350Z" fill={base} />
      <Path d="M128 340 Q134 390 136 440 L110 440 Q106 400 104 350Z" fill={base} />

      {/* Muscle groups */}
      {!showBack ? (
        <>
          <Path fill={heatOf('chest')} stroke={stroke} strokeWidth="0.8" d="M72 92 Q68 110 74 130 Q84 140 96 138 L96 94 Q84 88 72 92Z" />
          <Path fill={heatOf('chest')} stroke={stroke} strokeWidth="0.8" d="M128 92 Q132 110 126 130 Q116 140 104 138 L104 94 Q116 88 128 92Z" />
          <Path fill={heatOf('shoulders')} stroke={stroke} strokeWidth="0.8" d="M56 80 Q46 90 42 108 Q50 114 62 112 Q66 96 64 84Z" />
          <Path fill={heatOf('shoulders')} stroke={stroke} strokeWidth="0.8" d="M144 80 Q154 90 158 108 Q150 114 138 112 Q134 96 136 84Z" />
          <Path fill={heatOf('triceps')} stroke={stroke} strokeWidth="0.8" d="M42 112 Q38 140 44 168 Q52 168 60 160 Q62 136 60 114Z" />
          <Path fill={heatOf('triceps')} stroke={stroke} strokeWidth="0.8" d="M158 112 Q162 140 156 168 Q148 168 140 160 Q138 136 140 114Z" />
          <Path fill={heatOf('biceps')} stroke={stroke} strokeWidth="0.8" d="M42 112 Q38 140 44 168 Q52 168 60 160 Q62 136 60 114Z" />
          <Rect fill={heatOf('core')} stroke={stroke} strokeWidth="0.8" x="86" y="144" width="28" height="14" rx="3" />
          <Rect fill={heatOf('core')} stroke={stroke} strokeWidth="0.8" x="86" y="162" width="28" height="14" rx="3" />
          <Rect fill={heatOf('core')} stroke={stroke} strokeWidth="0.8" x="86" y="180" width="28" height="14" rx="3" />
          <Path fill={heatOf('quads')} stroke={stroke} strokeWidth="0.8" d="M70 340 Q64 380 66 420 L92 420 Q94 380 94 346Z" />
          <Path fill={heatOf('quads')} stroke={stroke} strokeWidth="0.8" d="M130 340 Q136 380 134 420 L108 420 Q106 380 106 346Z" />
          <Path fill={heatOf('calves')} stroke={stroke} strokeWidth="0.8" d="M66 420 Q62 450 65 470 L88 470 Q90 450 92 420Z" />
          <Path fill={heatOf('calves')} stroke={stroke} strokeWidth="0.8" d="M134 420 Q138 450 135 470 L112 470 Q110 450 108 420Z" />
        </>
      ) : (
        <>
          <Path fill={heatOf('back')} stroke={stroke} strokeWidth="0.8" d="M70 102 Q66 150 72 200 L100 210 L128 200 Q134 150 130 102 Q118 108 100 108 Q82 108 70 102Z" />
          <Path fill={heatOf('shoulders')} stroke={stroke} strokeWidth="0.8" d="M56 80 Q46 90 42 108 Q50 114 62 112 Q66 96 64 84Z" />
          <Path fill={heatOf('shoulders')} stroke={stroke} strokeWidth="0.8" d="M144 80 Q154 90 158 108 Q150 114 138 112 Q134 96 136 84Z" />
          <Path fill={heatOf('hamstrings')} stroke={stroke} strokeWidth="0.8" d="M72 340 Q66 380 68 420 L94 420 Q96 380 96 346Z" />
          <Path fill={heatOf('hamstrings')} stroke={stroke} strokeWidth="0.8" d="M128 340 Q134 380 132 420 L106 420 Q104 380 104 346Z" />
          <Path fill={heatOf('glutes')} stroke={stroke} strokeWidth="0.8" d="M70 300 Q66 330 72 340 L100 345 L128 340 Q134 330 130 300 Q116 310 100 310 Q84 310 70 300Z" />
          <Path fill={heatOf('traps')} stroke={stroke} strokeWidth="0.8" d="M80 76 Q70 90 72 106 Q86 108 100 108 Q114 108 128 106 Q130 90 120 76 Q110 82 100 82 Q90 82 80 76Z" />
        </>
      )}
    </Svg>
  );
}

// ─── Ticker Strip ─────────────────────────────────────────────────────────────

function TickerStrip({ items }: { items: [string, string, boolean?][] }) {
  const tx = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const loop = Animated.loop(
      Animated.timing(tx, { toValue: -1, duration: 30000, easing: Easing.linear, useNativeDriver: true }),
    );
    loop.start();
    return () => loop.stop();
  }, []);

  const doubled = [...items, ...items];

  return (
    <View style={{ backgroundColor: '#1a1816', height: 26, overflow: 'hidden', justifyContent: 'center', borderBottomWidth: 1, borderBottomColor: 'rgba(236,229,214,0.06)' }}>
      <Animated.View style={{ flexDirection: 'row', transform: [{ translateX: tx.interpolate({ inputRange: [-1, 0], outputRange: [-doubled.length * 80, 0] }) }] }}>
        {doubled.map(([k, v, up], i) => (
          <View key={i} style={{ flexDirection: 'row', alignItems: 'center', marginRight: 20, paddingLeft: i === 0 ? 16 : 0 }}>
            <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: 'rgba(236,229,214,0.5)', letterSpacing: 1 }}>{k} </Text>
            <Text style={{ fontFamily: 'SpaceMono-Bold', fontSize: 9, color: up ? '#7fcf9f' : 'rgba(236,229,214,0.85)', letterSpacing: 0.6 }}>
              {up ? '▲ ' : ''}{v}
            </Text>
            <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: 'rgba(236,229,214,0.18)', marginLeft: 8 }}>·</Text>
          </View>
        ))}
      </Animated.View>
    </View>
  );
}

// ─── Dots Menu ────────────────────────────────────────────────────────────────

function DotsMenu({ onClose, onDiscard, C }: { onClose: () => void; onDiscard: () => void; C: any }) {
  return (
    <View style={{
      position: 'absolute', bottom: 74, right: 14, zIndex: 200,
      backgroundColor: C.bg, borderRadius: 14, overflow: 'hidden',
      borderWidth: 1, borderColor: C.hair2,
      shadowColor: '#000', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.2, shadowRadius: 16,
      minWidth: 200,
    }}>
      <TouchableOpacity onPress={onClose} style={{ flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14, borderBottomWidth: 1, borderBottomColor: C.hair }}>
        <Svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={C.ink} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <Path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z" />
          <Path d="M17 21V13H7V21M7 3V8H15" />
        </Svg>
        <View>
          <Text style={{ fontFamily: 'Archivo-SemiBold', fontSize: 14, color: C.ink }}>Save workout</Text>
          <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 11, color: C.muted, marginTop: 1 }}>Saved locally, not posted</Text>
        </View>
      </TouchableOpacity>
      <TouchableOpacity onPress={onClose} style={{ flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14, borderBottomWidth: 1, borderBottomColor: C.hair }}>
        <Svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={C.ink} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <Path d="M4 12v8a2 2 0 002 2h12a2 2 0 002-2v-8" />
          <Path d="M16 6L12 2 8 6M12 2v13" />
        </Svg>
        <View>
          <Text style={{ fontFamily: 'Archivo-SemiBold', fontSize: 14, color: C.ink }}>Share via…</Text>
          <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 11, color: C.muted, marginTop: 1 }}>iOS share sheet</Text>
        </View>
      </TouchableOpacity>
      <TouchableOpacity onPress={onDiscard} style={{ flexDirection: 'row', alignItems: 'center', gap: 12, padding: 14 }}>
        <Svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#c0341a" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <Path d="M3 6H5H21M19 6L18 20H6L5 6M10 11v6M14 11v6M9 6V4H15V6" />
        </Svg>
        <Text style={{ fontFamily: 'Archivo-SemiBold', fontSize: 14, color: '#c0341a' }}>Discard workout</Text>
      </TouchableOpacity>
    </View>
  );
}

// ─── Share Card ───────────────────────────────────────────────────────────────

function ShareCard({ workout, C, isDark }: { workout: Workout; C: any; isDark: boolean }) {
  const heat = computeHeat(workout);
  const duration = workout.completedAt
    ? Math.round((workout.completedAt - workout.startedAt) / 1000)
    : 0;
  const dMin = Math.floor(duration / 60);
  const dSec = String(duration % 60).padStart(2, '0');

  const date = new Date(workout.completedAt || workout.startedAt);
  const dateStr = date.toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' }).toUpperCase();

  const completedSets = workout.exercises.reduce((a, e) => a + e.sets.filter((s) => s.completed).length, 0);
  const improvedCount = Math.min(workout.exercises.length, Math.ceil(workout.exercises.length * 0.6));

  const tickerItems: [string, string, boolean?][] = [
    [workout.name.toUpperCase(), 'DONE'],
    ['SETS', String(completedSets)],
    ['DURATION', `${dMin}:${dSec}`],
    ['KCAL', String(workout.calories || 0)],
    ['VOL', `${(workout.totalVolume / 1000).toFixed(1)}K KG`],
    ['IMPROVED', `${improvedCount}/${workout.exercises.length}`, true],
  ];

  // Sort exercises: with improvement first
  const sortedExercises = [...workout.exercises].sort((a, b) => {
    return b.sets.filter((s) => s.completed).length - a.sets.filter((s) => s.completed).length;
  });

  const cardBg = isDark ? '#0e0c0a' : '#faf5ec';
  const cardBorder = isDark ? 'rgba(255,255,255,0.06)' : 'rgba(31,28,25,0.11)';
  const cardFg = isDark ? '#ece5d6' : '#1f1c19';
  const cardMuted = isDark ? 'rgba(236,229,214,0.45)' : 'rgba(31,28,25,0.45)';
  const cardHair = isDark ? 'rgba(236,229,214,0.08)' : 'rgba(31,28,25,0.09)';
  const cardUp = isDark ? '#7fcf9f' : '#1f8f5a';
  const cardPr = isDark ? '#d4a03c' : '#c9892e';

  const visible = sortedExercises.slice(0, 6);
  const hidden = sortedExercises.length - 6;

  return (
    <View style={{ backgroundColor: cardBg, borderRadius: 16, borderWidth: 1, borderColor: cardBorder, overflow: 'hidden', marginHorizontal: 14, marginTop: 14 }}>
      <TickerStrip items={tickerItems} />

      <View style={{ padding: 16 }}>
        {/* Header */}
        <View style={{ flexDirection: 'row', alignItems: 'flex-start', justifyContent: 'space-between', marginBottom: 12 }}>
          <View>
            <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: cardMuted, letterSpacing: 1.6, marginBottom: 4 }}>{dateStr}</Text>
            <Text style={{ fontFamily: 'Archivo-Black', fontSize: 44, letterSpacing: 0.5, lineHeight: 40, color: cardFg }}>{workout.name}</Text>
          </View>
          <View style={{ alignItems: 'flex-end' }}>
            <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 8, color: cardMuted, letterSpacing: 1.2, marginBottom: 3 }}>DURATION</Text>
            <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 26, color: cardFg, letterSpacing: 1, lineHeight: 28 }}>{dMin}:{dSec}</Text>
          </View>
        </View>

        {/* 4-up stats */}
        <View style={{ flexDirection: 'row', borderTopWidth: 1, borderBottomWidth: 1, borderColor: cardHair, paddingVertical: 9, marginBottom: 12 }}>
          {[
            { lbl: 'SETS',   val: String(completedSets) },
            { lbl: 'KCAL',   val: String(workout.calories || 0) },
            { lbl: 'VOL',    val: `${(workout.totalVolume / 1000).toFixed(1)}K` },
            { lbl: 'STREAK', val: '—' },
          ].map((s, i) => (
            <View key={i} style={{ flex: 1, alignItems: 'center', borderRightWidth: i < 3 ? 1 : 0, borderRightColor: cardHair }}>
              <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 8, color: cardMuted, letterSpacing: 1.2, marginBottom: 3 }}>{s.lbl}</Text>
              <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 21, color: cardFg, lineHeight: 22 }}>{s.val}</Text>
            </View>
          ))}
        </View>

        {/* Body maps + improvement hero */}
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 12 }}>
          <View style={{ flexDirection: 'row', gap: 5 }}>
            <View>
              <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 7, color: cardMuted, letterSpacing: 1, marginBottom: 3, textAlign: 'center' }}>FRONT</Text>
              <BodySilhouette heat={heat} size={72} dark={isDark} />
            </View>
            <View>
              <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 7, color: cardMuted, letterSpacing: 1, marginBottom: 3, textAlign: 'center' }}>BACK</Text>
              <BodySilhouette heat={heat} size={72} showBack dark={isDark} />
            </View>
          </View>
          <View style={{ flex: 1 }}>
            <View style={{ flexDirection: 'row', alignItems: 'flex-end', gap: 5, marginBottom: 2 }}>
              <Text style={{ fontFamily: 'Archivo-Black', fontSize: 56, color: cardUp, lineHeight: 52, letterSpacing: 1 }}>{improvedCount}</Text>
              <View>
                <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: cardMuted, letterSpacing: 0.8 }}>OF {workout.exercises.length}</Text>
                <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 8, color: cardMuted, letterSpacing: 0.8 }}>IMPROVED</Text>
              </View>
            </View>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, paddingTop: 7, borderTopWidth: 1, borderTopColor: cardHair }}>
              <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 16, color: cardPr, letterSpacing: 0.5 }}>★ {workout.prs?.length || 0} NEW PRS</Text>
            </View>
          </View>
        </View>

        {/* Exercise breakdown */}
        <View style={{ borderTopWidth: 1, borderTopColor: cardHair }}>
          <View style={{ flexDirection: 'row', paddingVertical: 5, paddingBottom: 3, borderBottomWidth: 1, borderBottomColor: cardHair }}>
            <Text style={{ flex: 1, fontFamily: 'SpaceMono-Regular', fontSize: 7, color: cardMuted, letterSpacing: 1.2 }}>EXERCISE</Text>
            <Text style={{ width: 36, fontFamily: 'SpaceMono-Regular', fontSize: 7, color: cardMuted, letterSpacing: 1.2, textAlign: 'center' }}>SETS</Text>
            <Text style={{ width: 66, fontFamily: 'SpaceMono-Regular', fontSize: 7, color: cardMuted, letterSpacing: 1.2, textAlign: 'right' }}>BEST SET</Text>
            <Text style={{ width: 28, fontFamily: 'SpaceMono-Regular', fontSize: 7, color: cardMuted, letterSpacing: 1.2, textAlign: 'right' }}>▲</Text>
          </View>
          {visible.map((ex, i) => {
            const done = ex.sets.filter((s) => s.completed);
            const improved = done.length > 0;
            const best = done.reduce((best, s) => {
              const vol = (parseFloat(s.weight) || 0) * (parseInt(s.reps) || 0);
              return vol > best.vol ? { vol, s } : best;
            }, { vol: 0, s: done[0] });
            const bestStr = best.s ? `${best.s.weight || '—'}×${best.s.reps || '—'}` : '—';
            return (
              <View key={ex.id} style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 4, borderBottomWidth: i < visible.length - 1 ? 1 : 0, borderBottomColor: cardHair }}>
                <Text style={{ flex: 1, fontFamily: improved ? 'Archivo-SemiBold' : 'Archivo-Regular', fontSize: 12, color: improved ? cardFg : cardMuted }}>{ex.name}</Text>
                <Text style={{ width: 36, fontFamily: 'SpaceMono-Regular', fontSize: 10, color: cardMuted, textAlign: 'center' }}>{done.length}</Text>
                <Text style={{ width: 66, fontFamily: 'Archivo-Regular', fontSize: 13, color: improved ? cardFg : cardMuted, textAlign: 'right', letterSpacing: 0.5 }}>{bestStr}</Text>
                <View style={{ width: 28, alignItems: 'flex-end' }}>
                  {improved ? (
                    <Text style={{ fontFamily: 'SpaceMono-Bold', fontSize: 10, color: cardUp }}>▲</Text>
                  ) : (
                    <Text style={{ color: cardMuted, fontSize: 10 }}>—</Text>
                  )}
                </View>
              </View>
            );
          })}
          {hidden > 0 && (
            <View style={{ paddingTop: 5 }}>
              <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: cardMuted, letterSpacing: 1 }}>+{hidden} MORE EXERCISES</Text>
            </View>
          )}
        </View>

        {/* Watermark */}
        <View style={{ marginTop: 10, flexDirection: 'row', alignItems: 'center', gap: 5 }}>
          <View style={{ width: 7, height: 7, backgroundColor: cardPr, borderRadius: 2 }} />
          <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 8, color: cardMuted, letterSpacing: 1.5 }}>PULSE / PUMP</Text>
        </View>
      </View>
    </View>
  );
}

// ─── Caption Composer ─────────────────────────────────────────────────────────

function CaptionComposer({ C, onDiscard }: { C: any; onDiscard: () => void }) {
  const [caption, setCaption] = useState('');
  const [menuOpen, setMenuOpen] = useState(false);
  const [shareDestinations, setShareDestinations] = useState(['PULSE FEED']);
  const friends = ['Jay', 'Marcus', 'Priya'];

  function toggleDest(label: string) {
    setShareDestinations((prev) =>
      prev.includes(label) ? prev.filter((d) => d !== label) : [...prev, label],
    );
  }

  return (
    <View style={{ paddingHorizontal: 14, paddingTop: 14, paddingBottom: 20, backgroundColor: C.bg, borderTopWidth: 1, borderTopColor: C.hair2, position: 'relative' }}>
      {menuOpen && <DotsMenu onClose={() => setMenuOpen(false)} onDiscard={() => { setMenuOpen(false); onDiscard(); }} C={C} />}

      {/* Caption input */}
      <View style={{ flexDirection: 'row', gap: 10, alignItems: 'flex-start', marginBottom: 14 }}>
        <View style={{ width: 34, height: 34, borderRadius: 17, backgroundColor: C.surf2, borderWidth: 1, borderColor: C.hair2, alignItems: 'center', justifyContent: 'center' }}>
          <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 15, color: C.muted }}>J</Text>
        </View>
        <View style={{ flex: 1, backgroundColor: C.surf, borderRadius: 10, borderWidth: 1, borderColor: C.hair2, padding: 10, minHeight: 56 }}>
          <TextInput
            value={caption}
            onChangeText={setCaption}
            placeholder="Add a caption…"
            placeholderTextColor={C.muted}
            multiline
            style={{ fontFamily: 'Archivo-Regular', fontSize: 14, color: C.ink, lineHeight: 20 }}
          />
        </View>
      </View>

      {/* Tag friends */}
      <View style={{ marginBottom: 14 }}>
        <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.muted, letterSpacing: 1.3, marginBottom: 7 }}>TAG FRIENDS</Text>
        <View style={{ flexDirection: 'row', gap: 6, flexWrap: 'wrap' }}>
          {friends.map((f) => (
            <View key={f} style={{ flexDirection: 'row', alignItems: 'center', gap: 6, height: 30, paddingHorizontal: 10, borderRadius: 999, backgroundColor: C.surf, borderWidth: 1, borderColor: C.hair2 }}>
              <View style={{ width: 16, height: 16, borderRadius: 8, backgroundColor: C.surf2, alignItems: 'center', justifyContent: 'center' }}>
                <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 9, color: C.muted }}>{f[0]}</Text>
              </View>
              <Text style={{ fontFamily: 'Archivo-Medium', fontSize: 12, color: C.ink }}>{f}</Text>
            </View>
          ))}
          <TouchableOpacity style={{ height: 30, paddingHorizontal: 10, borderRadius: 999, borderWidth: 1, borderStyle: 'dashed', borderColor: C.faint, alignItems: 'center', justifyContent: 'center' }}>
            <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 10, color: C.muted, letterSpacing: 0.5 }}>+ ADD</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Share destinations */}
      <View style={{ marginBottom: 14 }}>
        <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.muted, letterSpacing: 1.3, marginBottom: 7 }}>SHARE TO</Text>
        <View style={{ flexDirection: 'row', gap: 6, flexWrap: 'wrap' }}>
          {['PULSE FEED', 'INSTAGRAM', 'MESSAGES'].map((label) => {
            const active = shareDestinations.includes(label);
            return (
              <TouchableOpacity key={label} onPress={() => toggleDest(label)} style={{ height: 30, paddingHorizontal: 12, borderRadius: 999, backgroundColor: active ? C.accent : 'transparent', borderWidth: 1, borderColor: active ? C.accent : C.hair2, alignItems: 'center', justifyContent: 'center' }}>
                <Text style={{ fontFamily: 'SpaceMono-Bold', fontSize: 9, color: active ? '#fff' : C.muted, letterSpacing: 0.8 }}>{label}</Text>
              </TouchableOpacity>
            );
          })}
        </View>
      </View>

      {/* POST + ··· */}
      <View style={{ flexDirection: 'row', gap: 8 }}>
        <TouchableOpacity style={{ flex: 1, height: 54, borderRadius: 14, backgroundColor: C.accent, alignItems: 'center', justifyContent: 'center' }}>
          <Text style={{ fontFamily: 'Archivo-Black', fontSize: 20, color: '#fff', letterSpacing: 1.5 }}>POST</Text>
        </TouchableOpacity>
        <TouchableOpacity onPress={() => setMenuOpen((o) => !o)} style={{ width: 54, height: 54, borderRadius: 14, backgroundColor: C.surf, borderWidth: 1, borderColor: C.hair2, alignItems: 'center', justifyContent: 'center' }}>
          <Text style={{ fontFamily: 'Archivo-Black', fontSize: 20, color: C.ink, letterSpacing: 2 }}>···</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

export default function WorkoutCompleteScreen() {
  const { C, isDark } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const { workoutId } = useLocalSearchParams<{ workoutId: string }>();
  const { workouts, addWorkout } = useAppStore();

  const workout = workouts.find((w) => w.id === workoutId);

  if (!workout) {
    return (
      <View style={{ flex: 1, backgroundColor: C.bg, alignItems: 'center', justifyContent: 'center' }}>
        <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 16, color: C.muted }}>Workout not found</Text>
        <TouchableOpacity onPress={() => router.replace('/')} style={{ marginTop: 16, paddingHorizontal: 24, paddingVertical: 12, borderRadius: 10, backgroundColor: C.accent }}>
          <Text style={{ fontFamily: 'Archivo-Black', fontSize: 14, color: '#fff', letterSpacing: 1 }}>GO HOME</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const date = new Date(workout.completedAt || workout.startedAt);
  const dateStr = date.toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short' }).toUpperCase();

  function handleDiscard() {
    router.replace('/');
  }

  return (
    <View style={{ flex: 1, backgroundColor: C.bg }}>
      {/* Status bar spacer */}
      <View style={{ height: insets.top + 4 }} />

      {/* Header */}
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 16, paddingVertical: 10, borderBottomWidth: 1, borderBottomColor: C.hair }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
          <TouchableOpacity onPress={() => router.replace('/')}>
            <Text style={{ fontSize: 20, color: C.muted, fontFamily: 'Archivo-Light' }}>‹</Text>
          </TouchableOpacity>
          <View>
            <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.muted, letterSpacing: 1.2 }}>WORKOUT COMPLETE</Text>
            <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 18, lineHeight: 20, letterSpacing: 0.8, color: C.ink }}>{workout.name.toUpperCase()}</Text>
          </View>
        </View>
        <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 10, color: C.muted, letterSpacing: 0.8 }}>{dateStr}</Text>
      </View>

      {/* Scrollable content */}
      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ paddingBottom: 20 }}>
        <ShareCard workout={workout} C={C} isDark={isDark} />
        <CaptionComposer C={C} onDiscard={handleDiscard} />
      </ScrollView>
    </View>
  );
}
