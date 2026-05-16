import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View, Text, ScrollView, TextInput, TouchableOpacity, Modal,
  StyleSheet, Pressable, KeyboardAvoidingView, Platform,
  FlatList,
} from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, { Circle as SvgCircle } from 'react-native-svg';
import { DestructiveModal } from '../../components/modals';
import { useTheme } from '../../hooks/useTheme';
import { useAppStore, Exercise } from '../../store/appStore';

// ─── Types ────────────────────────────────────────────────────────────────────

type SetType = 'STD' | 'WU' | 'DROP' | 'AMRAP' | 'SS' | 'RP' | 'FAIL' | 'UNI';

interface ActiveSet {
  id: string;
  type: SetType;
  weight: string;
  reps: string;
  rir: string;
  completed: boolean;
  prevWeight: string;
  prevReps: string;
}

interface ActiveExercise {
  id: string;
  exerciseId: string;
  name: string;
  equipment: string;
  muscleGroups: string[];
  sets: ActiveSet[];
  collapsed: boolean;
  hasRir: boolean;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

const SET_TYPE_META: Record<SetType, { bg: string; fg: string; label: string }> = {
  STD:  { bg: 'transparent',            fg: 'rgba(31,28,25,0.55)', label: 'STD' },
  WU:   { bg: 'rgba(180,140,60,0.12)',  fg: '#a17418',             label: 'WU' },
  SS:   { bg: 'rgba(125,74,140,0.13)',  fg: '#7d4a8c',             label: 'SS' },
  DROP: { bg: 'rgba(200,85,61,0.13)',   fg: '#a8442f',             label: 'DROP' },
  RP:   { bg: 'rgba(31,28,25,0.08)',    fg: '#3a342d',             label: 'RP' },
  AMRAP:{ bg: 'rgba(44,109,163,0.10)', fg: '#2c6da3',             label: 'AMRAP' },
  FAIL: { bg: 'rgba(229,27,27,0.10)',  fg: '#c0341a',             label: 'FAIL' },
  UNI:  { bg: 'rgba(44,109,163,0.12)', fg: '#2c6da3',             label: 'L/R' },
};

const BAR_TYPES = [
  { id: 'barbell', name: 'BARBELL', kg: 20 },
  { id: 'olympic', name: 'OLY 15',  kg: 15 },
  { id: 'ez',      name: 'EZ',      kg: 7.5 },
  { id: 'trap',    name: 'TRAP',    kg: 25 },
  { id: 'safety',  name: 'SAFETY',  kg: 32 },
];

const PLATE_COLORS: Record<number, { bg: string; fg: string }> = {
  25:   { bg: '#e51b1b', fg: '#fff' },
  20:   { bg: '#1f4ea3', fg: '#fff' },
  15:   { bg: '#c98a17', fg: '#fff' },
  10:   { bg: '#1f8f5a', fg: '#fff' },
  5:    { bg: '#1f1c19', fg: '#f4f0e6' },
  2.5:  { bg: '#a3a39a', fg: '#1f1c19' },
  1.25: { bg: '#d6d2c4', fg: '#1f1c19' },
};

function computePlates(targetKg: number, barKg: number) {
  const plates = [25, 20, 15, 10, 5, 2.5, 1.25];
  const perSide = (targetKg - barKg) / 2;
  if (perSide <= 0) return { stack: [] as number[], remainder: 0 };
  let remaining = perSide;
  const stack: number[] = [];
  for (const p of plates) {
    while (remaining >= p - 0.001) { stack.push(p); remaining = +((remaining - p).toFixed(3)); }
  }
  return { stack, remainder: remaining };
}

function isBarbell(equipment: string) {
  const e = equipment.toLowerCase();
  return e === 'barbell' || e === 'ez';
}

function makeId() {
  return Math.random().toString(36).slice(2);
}

function fmtTime(secs: number) {
  const m = Math.floor(secs / 60);
  const s = String(secs % 60).padStart(2, '0');
  return `${m}:${s}`;
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function SetTypeChip({ type, onTap, C }: { type: SetType; onTap: () => void; C: any }) {
  if (type === 'STD') {
    return (
      <TouchableOpacity onPress={onTap} style={{ width: 24, height: 18, borderRadius: 4, borderWidth: 1, borderStyle: 'dashed', borderColor: C.faint, alignItems: 'center', justifyContent: 'center' }}>
        <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.faint }}>+</Text>
      </TouchableOpacity>
    );
  }
  const m = SET_TYPE_META[type];
  return (
    <TouchableOpacity onPress={onTap} style={{ height: 18, paddingHorizontal: 5, borderRadius: 4, backgroundColor: m.bg, alignItems: 'center', justifyContent: 'center' }}>
      <Text style={{ fontFamily: 'SpaceMono-Bold', fontSize: 8, color: m.fg, letterSpacing: 0.6 }}>{m.label}</Text>
    </TouchableOpacity>
  );
}

function PlateCalcView({ targetKg, barKg, onBarChange, C }: {
  targetKg: number; barKg: number; onBarChange: (kg: number) => void; C: any;
}) {
  const { stack, remainder } = computePlates(targetKg, barKg);
  return (
    <View style={{ backgroundColor: C.surf, borderRadius: 12, padding: 10, borderWidth: 1, borderColor: C.hair2 }}>
      <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: 8 }}>
        <View>
          <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.muted, letterSpacing: 1.2 }}>PLATE CALCULATOR</Text>
          <View style={{ flexDirection: 'row', alignItems: 'flex-end', gap: 6, marginTop: 2 }}>
            <Text style={{ fontFamily: 'Archivo-Black', fontSize: 28, color: C.ink, lineHeight: 30 }}>{targetKg}</Text>
            <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 10, color: C.muted, marginBottom: 4 }}>KG · BAR {barKg}</Text>
          </View>
        </View>
      </View>
      {/* Plate bar visual */}
      <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', height: 56, marginBottom: 8 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'flex-end', width: 80, gap: 1 }}>
          {[...stack].reverse().map((p, i) => {
            const pc = PLATE_COLORS[p] || PLATE_COLORS[5];
            const h = 32 + Math.min(p, 25) * 0.9;
            const w = p >= 20 ? 9 : p >= 10 ? 7 : p >= 5 ? 6 : 5;
            return <View key={i} style={{ width: w, height: h, backgroundColor: pc.bg, borderRadius: 1.5, borderWidth: 1, borderColor: 'rgba(0,0,0,0.25)' }} />;
          })}
        </View>
        <View style={{ width: 60, height: 4, backgroundColor: '#8a857c', borderTopWidth: 1, borderBottomWidth: 1, borderColor: '#5a554d' }} />
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'flex-start', width: 80, gap: 1 }}>
          {stack.map((p, i) => {
            const pc = PLATE_COLORS[p] || PLATE_COLORS[5];
            const h = 32 + Math.min(p, 25) * 0.9;
            const w = p >= 20 ? 9 : p >= 10 ? 7 : p >= 5 ? 6 : 5;
            return <View key={i} style={{ width: w, height: h, backgroundColor: pc.bg, borderRadius: 1.5, borderWidth: 1, borderColor: 'rgba(0,0,0,0.25)' }} />;
          })}
        </View>
      </View>
      {/* Plate chips */}
      <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 4, justifyContent: 'center', marginBottom: 10 }}>
        {stack.length === 0 ? (
          <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 10, color: C.muted }}>BAR ONLY</Text>
        ) : (
          stack.map((p, i) => {
            const pc = PLATE_COLORS[p] || PLATE_COLORS[5];
            return <View key={i} style={{ backgroundColor: pc.bg, borderRadius: 3, paddingHorizontal: 6, paddingVertical: 2 }}><Text style={{ fontFamily: 'SpaceMono-Bold', fontSize: 9, color: pc.fg }}>{p}</Text></View>;
          })
        )}
        {remainder > 0.01 && <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: '#e51b1b' }}>+{remainder.toFixed(2)}KG OFF</Text>}
      </View>
      {/* Bar selector */}
      <View style={{ flexDirection: 'row', gap: 4, paddingTop: 8, borderTopWidth: 1, borderTopColor: C.hair }}>
        {BAR_TYPES.map((b) => (
          <TouchableOpacity key={b.id} onPress={() => onBarChange(b.kg)} style={{ flex: 1, alignItems: 'center', paddingVertical: 5, borderRadius: 6, backgroundColor: b.kg === barKg ? C.ink : 'transparent', borderWidth: b.kg === barKg ? 0 : 1, borderColor: C.hair2 }}>
            <Text style={{ fontFamily: 'SpaceMono-Bold', fontSize: 9, color: b.kg === barKg ? '#ece5d6' : C.muted, letterSpacing: 0.5 }}>{b.name}</Text>
            <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 8, color: b.kg === barKg ? 'rgba(236,229,214,0.7)' : C.muted, marginTop: 1 }}>{b.kg}KG</Text>
          </TouchableOpacity>
        ))}
      </View>
    </View>
  );
}

function SetRow({
  set, setIdx, hasRir, onSetTypeTap, isBarbell: isBb, showPlate, onPlateToggle, plateBarKg, onPlateBarChange,
  onFieldChange, onToggleComplete, C,
}: {
  set: ActiveSet; setIdx: number; hasRir: boolean;
  onSetTypeTap: () => void;
  isBarbell: boolean; showPlate: boolean; onPlateToggle: () => void;
  plateBarKg: number; onPlateBarChange: (kg: number) => void;
  onFieldChange: (field: 'weight' | 'reps' | 'rir', val: string) => void;
  onToggleComplete: () => void;
  C: any;
}) {
  const cols = hasRir ? [36, 22, 0, 0, 38, 30] : [36, 22, 0, 0, 30];
  const isActive = !set.completed && set.weight === '' && set.reps === '';
  const displayKg = set.weight !== '' ? set.weight : null;
  const displayReps = set.reps !== '' ? set.reps : null;

  return (
    <>
      <View style={{
        flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, paddingVertical: 7,
        borderBottomWidth: 1, borderBottomColor: C.hair,
        backgroundColor: set.completed ? 'transparent' : isActive ? C.accentSoft : 'transparent',
        borderLeftWidth: 2, borderLeftColor: set.completed ? C.up : isActive ? C.accent : 'transparent',
        opacity: set.type === 'WU' ? 0.65 : 1,
      }}>
        {/* TYPE */}
        <View style={{ width: cols[0] }}>
          <SetTypeChip type={set.type} onTap={onSetTypeTap} C={C} />
        </View>
        {/* # */}
        <View style={{ width: cols[1] }}>
          <Text style={{ fontFamily: 'SpaceMono-Bold', fontSize: 10, color: set.completed ? C.up : isActive ? C.accent : C.muted }}>
            {String(setIdx + 1).padStart(2, '0')}
          </Text>
        </View>
        {/* KG */}
        <View style={{ flex: 1, alignItems: 'center' }}>
          {set.completed ? (
            <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 19, color: C.ink, letterSpacing: 0.5 }}>{set.weight || '—'}</Text>
          ) : (
            <TextInput
              value={set.weight}
              onChangeText={(v) => onFieldChange('weight', v)}
              placeholder={set.prevWeight || '0'}
              placeholderTextColor={C.faint}
              keyboardType="decimal-pad"
              style={{ fontFamily: 'Archivo-Regular', fontSize: 19, color: C.ink, letterSpacing: 0.5, textAlign: 'center', minWidth: 40 }}
            />
          )}
        </View>
        {/* REPS */}
        <View style={{ flex: 1, alignItems: 'center' }}>
          {set.completed ? (
            <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 19, color: C.ink, letterSpacing: 0.5 }}>{set.reps || '—'}</Text>
          ) : (
            <TextInput
              value={set.reps}
              onChangeText={(v) => onFieldChange('reps', v)}
              placeholder={set.prevReps || '0'}
              placeholderTextColor={C.faint}
              keyboardType="number-pad"
              style={{ fontFamily: 'Archivo-Regular', fontSize: 19, color: C.ink, letterSpacing: 0.5, textAlign: 'center', minWidth: 40 }}
            />
          )}
        </View>
        {/* RIR */}
        {hasRir && (
          <View style={{ width: cols[4], alignItems: 'center' }}>
            {set.completed ? (
              <Text style={{ fontFamily: 'SpaceMono-Bold', fontSize: 11, color: C.ink2 || C.ink }}>{set.rir || '—'}</Text>
            ) : (
              <TextInput
                value={set.rir}
                onChangeText={(v) => onFieldChange('rir', v)}
                placeholder={set.prevReps ? '2' : '—'}
                placeholderTextColor={C.faint}
                keyboardType="number-pad"
                style={{ fontFamily: 'SpaceMono-Bold', fontSize: 11, color: C.ink, textAlign: 'center', width: 32 }}
              />
            )}
          </View>
        )}
        {/* ✓ */}
        <TouchableOpacity onPress={onToggleComplete} style={{ width: hasRir ? cols[5] : cols[4], alignItems: 'flex-end' }}>
          {set.completed ? (
            <Text style={{ color: C.up, fontSize: 14, fontFamily: 'Archivo-Bold' }}>✓</Text>
          ) : isActive ? (
            <View style={{ width: 12, height: 12, borderRadius: 6, borderWidth: 2, borderColor: C.accent }} />
          ) : (
            <View style={{ width: 12, height: 12, borderRadius: 6, borderWidth: 1.5, borderColor: C.faint }} />
          )}
        </TouchableOpacity>
      </View>

      {/* Plate toggle row for barbell active sets */}
      {isBb && !set.completed && (
        <>
          <TouchableOpacity onPress={onPlateToggle} style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', paddingHorizontal: 12, paddingVertical: 5, backgroundColor: C.surf2, borderBottomWidth: 1, borderBottomColor: C.hair }}>
            <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.muted, letterSpacing: 1.2 }}>
              PLATES · {set.weight || set.prevWeight || '0'}KG
            </Text>
            <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.muted }}>{showPlate ? '▴ CLOSE' : '▾ SHOW'}</Text>
          </TouchableOpacity>
          {showPlate && (
            <View style={{ padding: 8, backgroundColor: C.surf2, borderBottomWidth: 1, borderBottomColor: C.hair }}>
              <PlateCalcView
                targetKg={parseFloat(set.weight || set.prevWeight || '0') || 0}
                barKg={plateBarKg}
                onBarChange={onPlateBarChange}
                C={C}
              />
            </View>
          )}
        </>
      )}
    </>
  );
}

function ExerciseCard({
  ex, exIdx, openPlateFor, plateBarKg,
  onSetTypeTap, onPlateToggle, onPlateBarChange,
  onFieldChange, onToggleComplete, onAddSet,
  onCollapse, C,
}: {
  ex: ActiveExercise; exIdx: number;
  openPlateFor: { ei: number; si: number } | null;
  plateBarKg: number;
  onSetTypeTap: (si: number) => void;
  onPlateToggle: (si: number) => void;
  onPlateBarChange: (kg: number) => void;
  onFieldChange: (si: number, field: 'weight' | 'reps' | 'rir', val: string) => void;
  onToggleComplete: (si: number) => void;
  onAddSet: () => void;
  onCollapse: () => void;
  C: any;
}) {
  const isBb = isBarbell(ex.equipment);
  const doneSets = ex.sets.filter((s) => s.completed).length;

  return (
    <View style={{ backgroundColor: C.surf, borderRadius: 14, borderWidth: 1, borderColor: C.hair, marginBottom: 10, overflow: 'hidden' }}>
      {/* Card header */}
      <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8, paddingHorizontal: 12, paddingTop: 10, paddingBottom: 8, borderBottomWidth: ex.collapsed ? 0 : 1, borderBottomColor: C.hair }}>
        <View style={{ gap: 2.5, opacity: 0.4 }}>
          <View style={{ width: 12, height: 1.5, backgroundColor: C.ink }} />
          <View style={{ width: 12, height: 1.5, backgroundColor: C.ink }} />
          <View style={{ width: 12, height: 1.5, backgroundColor: C.ink }} />
        </View>
        <View style={{ flex: 1, minWidth: 0 }}>
          <View style={{ flexDirection: 'row', alignItems: 'baseline', gap: 8 }}>
            <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.muted, letterSpacing: 1 }}>{String(exIdx + 1).padStart(2, '0')}</Text>
            <Text style={{ fontFamily: 'Archivo-Bold', fontSize: 16, letterSpacing: 0.3, color: C.ink }} numberOfLines={1}>{ex.name}</Text>
          </View>
          <View style={{ flexDirection: 'row', gap: 6, marginTop: 2, flexWrap: 'wrap' }}>
            <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.muted, letterSpacing: 0.4 }}>{ex.equipment.toUpperCase()}</Text>
            {ex.muscleGroups.slice(0, 2).map((m) => (
              <Text key={m} style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.muted }}>· {m.toUpperCase()}</Text>
            ))}
          </View>
        </View>
        <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.muted }}>{doneSets}/{ex.sets.length}</Text>
        <TouchableOpacity onPress={onCollapse} style={{ width: 20, height: 20, alignItems: 'center', justifyContent: 'center' }}>
          <Text style={{ color: C.muted, fontSize: 11, transform: [{ rotate: ex.collapsed ? '-90deg' : '0deg' }] }}>▾</Text>
        </TouchableOpacity>
      </View>

      {!ex.collapsed && (
        <>
          {/* Column headers */}
          <View style={{
            flexDirection: 'row', paddingHorizontal: 12, paddingVertical: 5,
            backgroundColor: C.surf2, borderBottomWidth: 1, borderBottomColor: C.hair,
          }}>
            <Text style={{ width: 36, fontFamily: 'SpaceMono-Regular', fontSize: 8, color: C.muted, letterSpacing: 1.2 }}>TYPE</Text>
            <Text style={{ width: 22, fontFamily: 'SpaceMono-Regular', fontSize: 8, color: C.muted, letterSpacing: 1.2 }}>#</Text>
            <Text style={{ flex: 1, fontFamily: 'SpaceMono-Regular', fontSize: 8, color: C.muted, letterSpacing: 1.2, textAlign: 'center' }}>KG</Text>
            <Text style={{ flex: 1, fontFamily: 'SpaceMono-Regular', fontSize: 8, color: C.muted, letterSpacing: 1.2, textAlign: 'center' }}>REPS</Text>
            {ex.hasRir && <Text style={{ width: 38, fontFamily: 'SpaceMono-Regular', fontSize: 8, color: C.muted, letterSpacing: 1.2, textAlign: 'center' }}>RIR</Text>}
            <Text style={{ width: 30, fontFamily: 'SpaceMono-Regular', fontSize: 8, color: C.muted, letterSpacing: 1.2, textAlign: 'right' }}>✓</Text>
          </View>

          {/* Set rows */}
          {ex.sets.map((s, si) => (
            <SetRow
              key={s.id}
              set={s}
              setIdx={si}
              hasRir={ex.hasRir}
              onSetTypeTap={() => onSetTypeTap(si)}
              isBarbell={isBb}
              showPlate={openPlateFor?.ei === exIdx && openPlateFor?.si === si}
              onPlateToggle={() => onPlateToggle(si)}
              plateBarKg={plateBarKg}
              onPlateBarChange={onPlateBarChange}
              onFieldChange={(field, val) => onFieldChange(si, field, val)}
              onToggleComplete={() => onToggleComplete(si)}
              C={C}
            />
          ))}

          {/* Add set button */}
          <View style={{ padding: 8 }}>
            <TouchableOpacity onPress={onAddSet} style={{ height: 30, borderRadius: 6, borderWidth: 1, borderStyle: 'dashed', borderColor: C.faint, alignItems: 'center', justifyContent: 'center' }}>
              <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 10, color: C.muted, letterSpacing: 0.8 }}>+ ADD SET</Text>
            </TouchableOpacity>
          </View>
        </>
      )}
    </View>
  );
}

function SetTypeSheet({ current, onPick, onClose, C }: {
  current: SetType; onPick: (t: SetType) => void; onClose: () => void; C: any;
}) {
  const types: { id: SetType; name: string; desc: string }[] = [
    { id: 'STD',  name: 'Standard',   desc: 'Normal working set' },
    { id: 'WU',   name: 'Warmup',     desc: 'Excluded from volume' },
    { id: 'SS',   name: 'Superset',   desc: 'Paired with next exercise, no rest' },
    { id: 'DROP', name: 'Dropset',    desc: 'Multiple weight drops in one set' },
    { id: 'RP',   name: 'Rest-Pause', desc: 'Short rest, continue same set' },
    { id: 'AMRAP',name: 'AMRAP',      desc: 'As many reps as possible' },
    { id: 'FAIL', name: 'To Failure', desc: 'Last possible rep' },
    { id: 'UNI',  name: 'Unilateral', desc: 'Track left and right side separately' },
  ];

  return (
    <Modal transparent animationType="slide" onRequestClose={onClose}>
      <View style={{ flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(31,28,25,0.45)' }}>
        <Pressable style={{ flex: 1 }} onPress={onClose} />
        <View style={{ backgroundColor: C.bg, borderTopLeftRadius: 18, borderTopRightRadius: 18, paddingHorizontal: 14, paddingBottom: 32, borderTopWidth: 1, borderTopColor: C.hair2 }}>
          <View style={{ width: 36, height: 4, backgroundColor: C.faint, borderRadius: 2, alignSelf: 'center', marginVertical: 12 }} />
          <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.muted, letterSpacing: 1.5, marginBottom: 8 }}>SET TYPE</Text>
          {types.map((t) => {
            const m = SET_TYPE_META[t.id];
            const active = t.id === current;
            return (
              <TouchableOpacity key={t.id} onPress={() => onPick(t.id)} style={{ flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 10, borderBottomWidth: 1, borderBottomColor: C.hair }}>
                <View style={{ width: 42, height: 22, borderRadius: 4, backgroundColor: m.bg, borderWidth: t.id === 'STD' ? 1 : 0, borderStyle: 'dashed', borderColor: C.faint, alignItems: 'center', justifyContent: 'center' }}>
                  <Text style={{ fontFamily: 'SpaceMono-Bold', fontSize: 9, color: m.fg }}>{m.label}</Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={{ fontFamily: 'Archivo-SemiBold', fontSize: 14, color: C.ink }}>{t.name}</Text>
                  <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 11, color: C.muted, marginTop: 1 }}>{t.desc}</Text>
                </View>
                {active && <Text style={{ color: C.accent, fontSize: 18 }}>•</Text>}
              </TouchableOpacity>
            );
          })}
        </View>
      </View>
    </Modal>
  );
}

function RestTimerModal({ secs, total, onClose, onAdjust, C }: {
  secs: number; total: number; onClose: () => void; onAdjust: (delta: number) => void; C: any;
}) {
  const m = Math.floor(secs / 60);
  const s = String(secs % 60).padStart(2, '0');
  const pct = Math.max(0, Math.min(1, secs / total));
  const r = 96;
  const circ = 2 * Math.PI * r;
  const size = r * 2 + 20;

  return (
    <Modal transparent animationType="fade" onRequestClose={onClose}>
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: 'rgba(31,28,25,0.6)' }}>
        <Pressable style={StyleSheet.absoluteFill} onPress={onClose} />
        <View style={{ backgroundColor: C.bg, borderRadius: 24, padding: 24, width: 300, borderWidth: 1, borderColor: C.hair2, zIndex: 1 }}>
          <View style={{ width: 36, height: 4, backgroundColor: C.faint, borderRadius: 2, alignSelf: 'center', marginBottom: 20 }} />
          {/* Ring */}
          <View style={{ alignItems: 'center', justifyContent: 'center', width: size, height: size, alignSelf: 'center', marginBottom: 20 }}>
            <Svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ position: 'absolute' }}>
              <SvgCircle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={C.hair2} strokeWidth="7" />
              <SvgCircle
                cx={size / 2} cy={size / 2} r={r} fill="none"
                stroke={C.accent} strokeWidth="7"
                strokeDasharray={circ} strokeDashoffset={circ * (1 - pct)}
                strokeLinecap="round"
                transform={`rotate(-90 ${size / 2} ${size / 2})`}
              />
            </Svg>
            <View style={{ alignItems: 'center' }}>
              <Text style={{ fontFamily: 'Archivo-Light', fontSize: 68, color: C.ink, letterSpacing: 2, lineHeight: 70 }}>{m}:{s}</Text>
              <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.muted, letterSpacing: 1.5, marginTop: 6 }}>REST · TGT {fmtTime(total)}</Text>
            </View>
          </View>
          {/* Time adjust */}
          <View style={{ flexDirection: 'row', gap: 6, justifyContent: 'center', marginBottom: 12 }}>
            {[['−15s', -15], ['+15s', 15], ['+30s', 30], ['+1m', 60]].map(([label, delta]) => (
              <TouchableOpacity key={String(label)} onPress={() => onAdjust(Number(delta))} style={{ height: 34, borderRadius: 8, paddingHorizontal: 10, backgroundColor: C.surf, borderWidth: 1, borderColor: C.hair2, alignItems: 'center', justifyContent: 'center', flex: 1 }}>
                <Text style={{ fontFamily: 'SpaceMono-Bold', fontSize: 11, color: C.ink, letterSpacing: 0.5 }}>{String(label)}</Text>
              </TouchableOpacity>
            ))}
          </View>
          {/* Default rest */}
          <View style={{ backgroundColor: C.surf, borderRadius: 10, padding: 10, borderWidth: 1, borderColor: C.hair, flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <View>
              <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 8, color: C.muted, letterSpacing: 1.2 }}>DEFAULT REST</Text>
              <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 20, color: C.ink, lineHeight: 24, marginTop: 2 }}>2:30 PER SET</Text>
            </View>
            <Text style={{ fontFamily: 'SpaceMono-Bold', fontSize: 10, color: C.accent }}>EDIT</Text>
          </View>
          <TouchableOpacity onPress={onClose} style={{ height: 54, borderRadius: 12, backgroundColor: C.accent, alignItems: 'center', justifyContent: 'center' }}>
            <Text style={{ fontFamily: 'Archivo-Black', fontSize: 20, color: '#fff', letterSpacing: 1.5 }}>SKIP REST ›</Text>
          </TouchableOpacity>
        </View>
      </View>
    </Modal>
  );
}

function ExercisePicker({ exercises, onPick, onClose, C }: {
  exercises: Exercise[]; onPick: (e: Exercise) => void; onClose: () => void; C: any;
}) {
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState('All');
  const cats = ['All', 'Push', 'Pull', 'Legs', 'Hinge', 'Core', 'Isolation'];
  const filtered = exercises.filter((e) => {
    const matchQ = e.name.toLowerCase().includes(query.toLowerCase());
    const matchC = filter === 'All' || e.category === filter;
    return matchQ && matchC;
  });

  const CAT_COLORS: Record<string, string> = {
    Push: '#c8553d', Pull: '#2c6da3', Legs: '#1f8f5a', Hinge: '#c98a17',
    Core: '#7d4a8c', Isolation: '#3a342d', Other: '#a3a39a',
  };

  return (
    <Modal animationType="slide" onRequestClose={onClose}>
      <View style={{ flex: 1, backgroundColor: C.bg }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingTop: 60, paddingBottom: 12, borderBottomWidth: 1, borderBottomColor: C.hair, gap: 12 }}>
          <TouchableOpacity onPress={onClose}>
            <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 16, color: C.muted }}>‹</Text>
          </TouchableOpacity>
          <Text style={{ fontFamily: 'SpaceMono-Bold', fontSize: 12, color: C.ink, letterSpacing: 1 }}>ADD EXERCISE</Text>
        </View>
        <View style={{ paddingHorizontal: 16, paddingVertical: 10, borderBottomWidth: 1, borderBottomColor: C.hair }}>
          <TextInput
            value={query}
            onChangeText={setQuery}
            placeholder="Search exercises…"
            placeholderTextColor={C.muted}
            style={{ height: 40, backgroundColor: C.surf, borderRadius: 8, paddingHorizontal: 12, fontFamily: 'Archivo-Regular', fontSize: 14, color: C.ink, borderWidth: 1, borderColor: C.hair2 }}
          />
        </View>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ flexGrow: 0, borderBottomWidth: 1, borderBottomColor: C.hair }} contentContainerStyle={{ paddingHorizontal: 16, paddingVertical: 10, gap: 6, flexDirection: 'row' }}>
          {cats.map((c) => (
            <TouchableOpacity key={c} onPress={() => setFilter(c)} style={{ paddingHorizontal: 12, paddingVertical: 6, borderRadius: 999, backgroundColor: filter === c ? C.ink : C.surf, borderWidth: 1, borderColor: C.hair2 }}>
              <Text style={{ fontFamily: 'SpaceMono-Bold', fontSize: 10, color: filter === c ? '#ece5d6' : C.muted, letterSpacing: 0.5 }}>{c.toUpperCase()}</Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
        <FlatList
          data={filtered}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => (
            <TouchableOpacity onPress={() => onPick(item)} style={{ flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 16, paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: C.hair }}>
              <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: CAT_COLORS[item.category] || CAT_COLORS.Other }} />
              <View style={{ flex: 1 }}>
                <Text style={{ fontFamily: 'Archivo-SemiBold', fontSize: 15, color: C.ink }}>{item.name}</Text>
                <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.muted, letterSpacing: 0.5, marginTop: 1 }}>{item.equipment.toUpperCase()} · {item.category.toUpperCase()}</Text>
              </View>
            </TouchableOpacity>
          )}
        />
      </View>
    </Modal>
  );
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

export default function ActiveWorkoutScreen() {
  const { C, Fonts } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const params = useLocalSearchParams<{ templateId?: string; dayIdx?: string; workoutName?: string }>();

  const { templates, exercises: allExercises, draftWorkout, setDraftWorkout, addWorkout, profile } = useAppStore();

  // ── Build initial exercises ──────────────────────────────────────────────
  const buildInitialExercises = useCallback((): ActiveExercise[] => {
    if (params.templateId) {
      const tpl = templates.find((t) => t.id === params.templateId);
      const dayIdx = parseInt(params.dayIdx || '0', 10);
      const day = tpl?.days[dayIdx];
      if (day?.exercises.length) {
        return day.exercises.map((te) => {
          const ex = allExercises.find((e) => e.id === te.exerciseId);
          return {
            id: makeId(),
            exerciseId: te.exerciseId,
            name: te.name,
            equipment: ex?.equipment || 'Barbell',
            muscleGroups: te.muscleGroups,
            collapsed: false,
            hasRir: false,
            sets: te.sets.map((ts) => ({
              id: makeId(),
              type: ts.type,
              weight: '',
              reps: '',
              rir: '',
              completed: false,
              prevWeight: '',
              prevReps: ts.targetReps ? String(ts.targetReps) : '',
            })),
          };
        });
      }
    }
    // Default: single empty exercise
    return [{
      id: makeId(),
      exerciseId: '',
      name: 'Bench Press',
      equipment: 'Barbell',
      muscleGroups: ['chest', 'triceps'],
      collapsed: false,
      hasRir: false,
      sets: [
        { id: makeId(), type: 'WU',  weight: '', reps: '', rir: '', completed: false, prevWeight: '60', prevReps: '8' },
        { id: makeId(), type: 'STD', weight: '', reps: '', rir: '', completed: false, prevWeight: '80', prevReps: '8' },
        { id: makeId(), type: 'STD', weight: '', reps: '', rir: '', completed: false, prevWeight: '80', prevReps: '6' },
        { id: makeId(), type: 'STD', weight: '', reps: '', rir: '', completed: false, prevWeight: '80', prevReps: '6' },
      ],
    }];
  }, [params.templateId, params.dayIdx, templates, allExercises]);

  const [exercises, setExercises] = useState<ActiveExercise[]>(() => {
    if (draftWorkout) {
      return draftWorkout.exercises.map((el) => ({
        id: el.id,
        exerciseId: el.exerciseId,
        name: el.name,
        equipment: allExercises.find((e) => e.id === el.exerciseId)?.equipment || 'Barbell',
        muscleGroups: el.muscleGroups,
        collapsed: el.collapsed || false,
        hasRir: false,
        sets: el.sets.map((s) => ({
          id: s.id,
          type: s.type as SetType,
          weight: s.weight,
          reps: s.reps,
          rir: s.rir,
          completed: s.completed,
          prevWeight: s.prevWeight || '',
          prevReps: s.prevReps || '',
        })),
      }));
    }
    return buildInitialExercises();
  });

  const workoutName = params.workoutName || 'Workout';
  const startedAt = useRef(Date.now());
  const [elapsedSecs, setElapsedSecs] = useState(0);
  const [restSecs, setRestSecs] = useState(0);
  const [restTotal] = useState(150);
  const [showRestModal, setShowRestModal] = useState(false);
  const [setTypeSheet, setSetTypeSheet] = useState<{ ei: number; si: number } | null>(null);
  const [showExercisePicker, setShowExercisePicker] = useState(false);
  const [openPlateFor, setOpenPlateFor] = useState<{ ei: number; si: number } | null>(null);
  const [plateBarKg, setPlateBarKg] = useState(20);
  const [showIncompleteModal, setShowIncompleteModal] = useState(false);
  const [pendingFinish, setPendingFinish] = useState<(() => void) | null>(null);

  // ── Timers ───────────────────────────────────────────────────────────────
  useEffect(() => {
    const t = setInterval(() => setElapsedSecs((s) => s + 1), 1000);
    return () => clearInterval(t);
  }, []);

  useEffect(() => {
    if (restSecs <= 0) return;
    const t = setInterval(() => setRestSecs((s) => Math.max(0, s - 1)), 1000);
    return () => clearInterval(t);
  }, [restSecs > 0]);

  // ── Persist draft ────────────────────────────────────────────────────────
  useEffect(() => {
    const draft = buildDraft(exercises);
    setDraftWorkout(draft);
  }, [exercises]);

  function buildDraft(exs: ActiveExercise[]) {
    return {
      id: draftWorkout?.id || makeId(),
      name: workoutName,
      startedAt: startedAt.current,
      isDraft: true,
      exercises: exs.map((ex) => ({
        id: ex.id,
        exerciseId: ex.exerciseId,
        name: ex.name,
        muscleGroups: ex.muscleGroups,
        collapsed: ex.collapsed,
        sets: ex.sets.map((s) => ({
          id: s.id,
          type: s.type,
          weight: s.weight,
          reps: s.reps,
          rir: s.rir,
          completed: s.completed,
          prevWeight: s.prevWeight,
          prevReps: s.prevReps,
        })),
      })),
      totalSets: exs.reduce((a, e) => a + e.sets.length, 0),
      totalVolume: exs.reduce((a, e) => a + e.sets.filter((s) => s.completed).reduce((sa, s) => sa + (parseFloat(s.weight) || 0) * (parseInt(s.reps) || 0), 0), 0),
    };
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  function updateSet(ei: number, si: number, update: Partial<ActiveSet>) {
    setExercises((prev) => prev.map((ex, i) => i !== ei ? ex : {
      ...ex,
      sets: ex.sets.map((s, j) => j !== si ? s : { ...s, ...update }),
    }));
  }

  function toggleComplete(ei: number, si: number) {
    const set = exercises[ei].sets[si];
    if (!set.completed) {
      // Mark done + start rest timer
      updateSet(ei, si, { completed: true });
      setRestSecs(restTotal);
      setShowRestModal(true);
    } else {
      updateSet(ei, si, { completed: false });
    }
  }

  function addSet(ei: number) {
    const lastSet = exercises[ei].sets.slice(-1)[0];
    const newSet: ActiveSet = {
      id: makeId(),
      type: lastSet?.type === 'WU' ? 'STD' : (lastSet?.type || 'STD'),
      weight: '',
      reps: '',
      rir: '',
      completed: false,
      prevWeight: lastSet?.weight || lastSet?.prevWeight || '',
      prevReps: lastSet?.reps || lastSet?.prevReps || '',
    };
    setExercises((prev) => prev.map((ex, i) => i !== ei ? ex : { ...ex, sets: [...ex.sets, newSet] }));
  }

  function pickExercise(ex: Exercise) {
    const newEx: ActiveExercise = {
      id: makeId(),
      exerciseId: ex.id,
      name: ex.name,
      equipment: ex.equipment,
      muscleGroups: ex.muscleGroups,
      collapsed: false,
      hasRir: false,
      sets: [
        { id: makeId(), type: 'STD', weight: '', reps: '', rir: '', completed: false, prevWeight: '', prevReps: '' },
        { id: makeId(), type: 'STD', weight: '', reps: '', rir: '', completed: false, prevWeight: '', prevReps: '' },
        { id: makeId(), type: 'STD', weight: '', reps: '', rir: '', completed: false, prevWeight: '', prevReps: '' },
      ],
    };
    setExercises((prev) => [...prev, newEx]);
    setShowExercisePicker(false);
  }

  function handleFinishWorkout() {
    const totalSets = exercises.reduce((a, e) => a + e.sets.length, 0);
    const doneSets = exercises.reduce((a, e) => a + e.sets.filter((s) => s.completed).length, 0);
    const incompleteSets = totalSets - doneSets;

    const doFinish = () => {
      const now = Date.now();
      const allMuscles = [...new Set(exercises.flatMap((e) => e.muscleGroups))];
      const workout = {
        id: makeId(),
        name: workoutName,
        startedAt: startedAt.current,
        completedAt: now,
        isDraft: false,
        exercises: exercises.map((ex) => ({
          id: ex.id,
          exerciseId: ex.exerciseId,
          name: ex.name,
          muscleGroups: ex.muscleGroups,
          sets: ex.sets.map((s) => ({
            id: s.id,
            type: s.type,
            weight: s.weight,
            reps: s.reps,
            rir: s.rir,
            completed: s.completed,
            prevWeight: s.prevWeight,
            prevReps: s.prevReps,
          })),
        })),
        totalSets,
        totalVolume: exercises.reduce((a, e) => a + e.sets.filter((s) => s.completed).reduce((sa, s) => sa + (parseFloat(s.weight) || 0) * (parseInt(s.reps) || 0), 0), 0),
        calories: Math.round(doneSets * 8 + elapsedSecs / 60 * 2),
        musclesWorked: allMuscles,
      };
      addWorkout(workout);
      router.replace({ pathname: '/workout/complete', params: { workoutId: workout.id } });
    };

    if (incompleteSets > 0) {
      setPendingFinish(() => doFinish);
      setShowIncompleteModal(true);
    } else {
      doFinish();
    }
  }

  const totalSets = exercises.reduce((a, e) => a + e.sets.length, 0);
  const doneSets = exercises.reduce((a, e) => a + e.sets.filter((s) => s.completed).length, 0);
  const progress = totalSets > 0 ? doneSets / totalSets : 0;
  const restRunning = restSecs > 0;

  return (
    <View style={{ flex: 1, backgroundColor: C.bg }}>
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined} style={{ flex: 1 }}>

        {/* Status bar spacer */}
        <View style={{ height: insets.top + 4 }} />

        {/* Masthead */}
        <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 14, height: 50, borderBottomWidth: 1, borderBottomColor: C.hair, backgroundColor: C.bg }}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
            <TouchableOpacity onPress={() => router.back()}>
              <Text style={{ fontSize: 20, color: C.muted, fontFamily: 'Archivo-Light' }}>‹</Text>
            </TouchableOpacity>
            <View>
              <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: C.muted, letterSpacing: 1.2 }}>SESSION</Text>
              <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 18, lineHeight: 20, letterSpacing: 0.8, color: C.ink }}>{workoutName.toUpperCase()} · {fmtTime(elapsedSecs)}</Text>
            </View>
          </View>
          {/* Rest timer pill */}
          <TouchableOpacity onPress={() => setShowRestModal(true)} style={{
            flexDirection: 'row', alignItems: 'center', gap: 8,
            backgroundColor: restRunning ? C.ink : C.surf,
            borderRadius: 99, paddingLeft: 12, paddingRight: 6, paddingVertical: 5,
            borderWidth: restRunning ? 0 : 1, borderColor: C.hair2,
          }}>
            <View style={{ alignItems: 'flex-end' }}>
              <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 8, color: restRunning ? 'rgba(236,229,214,0.7)' : C.muted, letterSpacing: 1 }}>REST</Text>
              <Text style={{ fontFamily: 'Archivo-Regular', fontSize: 18, color: restRunning ? '#ece5d6' : C.muted, letterSpacing: 1, lineHeight: 20 }}>
                {restRunning ? fmtTime(restSecs) : '—:—'}
              </Text>
            </View>
            <View style={{ width: 24, height: 24 }}>
              <Svg width="24" height="24" viewBox="0 0 24 24">
                <SvgCircle cx="12" cy="12" r="9" fill="none" stroke={restRunning ? 'rgba(236,229,214,0.18)' : C.hair2} strokeWidth="2" />
                {restRunning && (
                  <SvgCircle
                    cx="12" cy="12" r="9" fill="none" stroke={C.accent} strokeWidth="2.5"
                    strokeDasharray={2 * Math.PI * 9}
                    strokeDashoffset={2 * Math.PI * 9 * (1 - restSecs / restTotal)}
                    strokeLinecap="round"
                    transform="rotate(-90 12 12)"
                  />
                )}
              </Svg>
            </View>
          </TouchableOpacity>
        </View>

        {/* Exercise cards */}
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 10, paddingBottom: 120 }} keyboardShouldPersistTaps="handled">
          {exercises.map((ex, ei) => (
            <ExerciseCard
              key={ex.id}
              ex={ex}
              exIdx={ei}
              openPlateFor={openPlateFor}
              plateBarKg={plateBarKg}
              onSetTypeTap={(si) => setSetTypeSheet({ ei, si })}
              onPlateToggle={(si) => setOpenPlateFor((prev) => (prev?.ei === ei && prev?.si === si ? null : { ei, si }))}
              onPlateBarChange={setPlateBarKg}
              onFieldChange={(si, field, val) => updateSet(ei, si, { [field]: val })}
              onToggleComplete={(si) => toggleComplete(ei, si)}
              onAddSet={() => addSet(ei)}
              onCollapse={() => setExercises((prev) => prev.map((e, i) => i !== ei ? e : { ...e, collapsed: !e.collapsed }))}
              C={C}
            />
          ))}

          {/* Add exercise */}
          <View style={{ borderTopWidth: 1, borderTopColor: C.hair2, paddingTop: 10 }}>
            <TouchableOpacity onPress={() => setShowExercisePicker(true)} style={{ height: 36, borderRadius: 8, borderWidth: 1, borderStyle: 'dashed', borderColor: C.faint, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 6 }}>
              <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 14, color: C.muted }}>+</Text>
              <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 10, color: C.muted, letterSpacing: 1 }}>ADD EXERCISE</Text>
            </TouchableOpacity>
          </View>
        </ScrollView>

        {/* Finish bar */}
        <View style={{ paddingHorizontal: 12, paddingBottom: insets.bottom + 12, paddingTop: 10, borderTopWidth: 1, borderTopColor: C.hair2, backgroundColor: C.bg }}>
          <TouchableOpacity onPress={handleFinishWorkout} style={{ position: 'relative', height: 48, borderRadius: 11, overflow: 'hidden', backgroundColor: C.accent }}>
            <View style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: `${progress * 100}%`, backgroundColor: 'rgba(0,0,0,0.18)' }} />
            <View style={{ position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 14 }}>
              <Text style={{ fontFamily: 'Archivo-Black', fontSize: 16, color: '#fff', letterSpacing: 1 }}>FINISH WORKOUT ›</Text>
              <Text style={{ fontFamily: 'SpaceMono-Regular', fontSize: 9, color: 'rgba(255,255,255,0.85)', letterSpacing: 0.8 }}>{totalSets - doneSets} SETS LEFT</Text>
            </View>
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>

      {/* Set type sheet */}
      {setTypeSheet && (
        <SetTypeSheet
          current={exercises[setTypeSheet.ei]?.sets[setTypeSheet.si]?.type || 'STD'}
          onPick={(t) => {
            updateSet(setTypeSheet.ei, setTypeSheet.si, { type: t });
            setSetTypeSheet(null);
          }}
          onClose={() => setSetTypeSheet(null)}
          C={C}
        />
      )}

      {/* Rest timer modal */}
      {showRestModal && (
        <RestTimerModal
          secs={restSecs}
          total={restTotal}
          onClose={() => setShowRestModal(false)}
          onAdjust={(delta) => setRestSecs((s) => Math.max(0, s + delta))}
          C={C}
        />
      )}

      {/* Exercise picker */}
      {showExercisePicker && (
        <ExercisePicker
          exercises={allExercises}
          onPick={pickExercise}
          onClose={() => setShowExercisePicker(false)}
          C={C}
        />
      )}

      <DestructiveModal
        C={C}
        visible={showIncompleteModal}
        kicker="INCOMPLETE WORKOUT"
        title="Finish anyway?"
        body="Some sets are still unchecked. You can finish now and your completed sets will be saved."
        consequences={[{ value: String(exercises.reduce((a, e) => a + e.sets.length, 0) - exercises.reduce((a, e) => a + e.sets.filter((s) => s.completed).length, 0)), label: 'sets unchecked' }]}
        cancelLabel="KEEP GOING"
        confirmLabel="FINISH WORKOUT"
        onCancel={() => { setShowIncompleteModal(false); setPendingFinish(null); }}
        onConfirm={() => { setShowIncompleteModal(false); pendingFinish?.(); setPendingFinish(null); }}
      />
    </View>
  );
}
