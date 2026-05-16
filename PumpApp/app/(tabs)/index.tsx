import { useRouter } from 'expo-router';
import React, { useEffect, useRef } from 'react';
import {
  Animated,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { InlineConfirm } from '../../components/modals';
import { useTheme } from '../../hooks/useTheme';
import { useAppStore } from '../../store/appStore';

// ── Ticker strip (always dark bg) ─────────────────────────────

const TICKER_ITEMS = [
  { key: 'CHEST', val: '▲ +12.5%', up: true },
  { key: 'BACK', val: '▲ +11.1%', up: true },
  { key: 'QUADS', val: 'TGT', up: null },
  { key: 'GLUTES', val: 'TGT', up: null },
  { key: 'SHLDR', val: '▼ -14.3%', up: false },
  { key: 'HAMS', val: '▼ -33.3%', up: false },
  { key: 'BICEP', val: '▲ +20.0%', up: true },
  { key: 'TRI', val: 'TGT', up: null },
  { key: 'CORE', val: '▼ -40.0%', up: false },
];

function TickerStrip() {
  const translateX = useRef(new Animated.Value(0)).current;
  const itemWidth = 100;
  const totalWidth = TICKER_ITEMS.length * itemWidth;

  useEffect(() => {
    const anim = Animated.loop(
      Animated.timing(translateX, {
        toValue: -totalWidth,
        duration: 40000,
        useNativeDriver: true,
      })
    );
    anim.start();
    return () => anim.stop();
  }, []);

  const items = [...TICKER_ITEMS, ...TICKER_ITEMS];
  return (
    <View style={styles.tickerContainer}>
      <Animated.View style={[styles.tickerRow, { transform: [{ translateX }] }]}>
        {items.map((item, i) => (
          <View key={i} style={styles.tickerItem}>
            <Text style={styles.tickerKey}>{item.key}</Text>
            <Text
              style={[
                styles.tickerVal,
                item.up === true
                  ? styles.tickerUp
                  : item.up === false
                  ? styles.tickerDown
                  : styles.tickerNeutral,
              ]}
            >
              {item.val}
            </Text>
            <Text style={styles.tickerDot}> · </Text>
          </View>
        ))}
      </Animated.View>
    </View>
  );
}

// ── Confidence dots ────────────────────────────────────────────

function ConfidenceDots({ conf }: { conf: number }) {
  const { C } = useTheme();
  const filled = Math.round(conf * 5);
  return (
    <View style={styles.confRow}>
      {[0, 1, 2, 3, 4].map((i) => (
        <View
          key={i}
          style={[
            styles.confDot,
            { backgroundColor: i < filled ? C.accent : C.faint },
          ]}
        />
      ))}
      <Text style={[styles.confLabel, { color: C.muted }]}>{Math.round(conf * 100)}% CONF</Text>
    </View>
  );
}

// ── Week bars ──────────────────────────────────────────────────

function WeekBars({
  data,
  labels,
  done,
  todayIdx,
}: {
  data: number[];
  labels: string[];
  done: boolean[];
  todayIdx: number;
}) {
  const { C } = useTheme();
  const max = Math.max(...data, 1);
  const barH = 40;

  return (
    <View style={styles.weekBarsRow}>
      {data.map((v, i) => {
        const isToday = i === todayIdx;
        const pct = v / max;
        const height = Math.max(v > 0 ? pct * barH : 3, 3);
        const color = isToday ? C.accent : done[i] ? C.up : v > 0 ? C.ink : C.faint;
        const opacity = isToday ? 1 : done[i] ? 0.7 : v > 0 ? 0.35 : 0.15;
        return (
          <View key={i} style={styles.weekBarCol}>
            <View style={[styles.weekBar, { height, backgroundColor: color, opacity }]} />
            <Text style={[styles.weekBarLabel, { color: isToday ? C.accent : C.muted }]}>
              {labels[i]}
            </Text>
          </View>
        );
      })}
    </View>
  );
}

// ── Prediction + prediction algorithm ─────────────────────────

function buildPrediction(workouts: any[]) {
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const todayDow = new Date().getDay();
  if (workouts.length === 0) {
    return {
      name: 'PUSH DAY',
      program: 'PPL',
      lastDone: 'never',
      estDuration: '~55 MIN',
      exercises: ['Bench Press', 'OHP', 'Incline DB', 'Cable Fly', 'Tricep PD'],
      confidence: 0.6,
      reason: 'Default recommendation',
    };
  }
  const recent = workouts.slice(0, 60);
  const dayScores: Record<number, number> = {};
  recent.forEach((w) => {
    const dow = new Date(w.startedAt).getDay();
    dayScores[dow] = (dayScores[dow] || 0) + 1;
  });
  const todayScore = dayScores[todayDow] || 0;
  const totalWorkouts = recent.length;
  const confidence = Math.min(todayScore / Math.max(totalWorkouts / 7, 1), 1);
  const lastWorkout = recent[0];
  return {
    name: lastWorkout?.name?.toUpperCase() || 'WORKOUT',
    program: 'PPL',
    lastDone: 'recently',
    estDuration: '~55 MIN',
    exercises: lastWorkout?.exercises?.map((e: any) => e.name).slice(0, 5) || [],
    confidence,
    reason: `${days[todayDow]} pattern · ${totalWorkouts} workouts`,
  };
}

// ── Docked CTA ─────────────────────────────────────────────────

function DockedCTA({ prediction }: { prediction: ReturnType<typeof buildPrediction> }) {
  const { C, Fonts } = useTheme();
  const router = useRouter();
  const draft = useAppStore((s) => s.draftWorkout);
  const setDraftWorkout = useAppStore((s) => s.setDraftWorkout);
  const [confirmDiscard, setConfirmDiscard] = React.useState(false);

  if (draft) {
    const pct = draft.totalSets > 0 ? draft.exercises.reduce((acc, e) => acc + e.sets.filter((s) => s.completed).length, 0) / draft.totalSets : 0;
    return (
      <View style={[styles.dockedWrap, { borderTopWidth: 1, borderTopColor: C.hair2 }]}>
        {confirmDiscard ? (
          <InlineConfirm
            C={C}
            title="Discard current workout?"
            body={`Your progress on ${draft.name} will be lost.`}
            cancelLabel="CANCEL"
            confirmLabel="DISCARD + START NEW"
            onCancel={() => setConfirmDiscard(false)}
            onConfirm={() => { setDraftWorkout(null); setConfirmDiscard(false); }}
          />
        ) : (
          <Pressable
            onPress={() => setConfirmDiscard(true)}
            style={styles.startNewLink}
          >
            <Text style={[styles.startNewText, { color: C.muted, borderBottomColor: C.faint }]}>
              START NEW WORKOUT
            </Text>
          </Pressable>
        )}
        <Pressable
          onPress={() => router.push('/workout/active')}
          style={[styles.draftBtn, { backgroundColor: C.surf, borderColor: C.accent + '55' }]}
        >
          <View style={[styles.draftProgress, { width: `${pct * 100}%` as any, backgroundColor: C.accent }]} />
          <View style={styles.draftBtnContent}>
            <View style={{ flex: 1 }}>
              <Text style={[styles.draftName, { color: C.accent }]}>CONTINUE {draft.name.toUpperCase()}</Text>
              <Text style={[styles.draftMeta, { color: C.muted }]}>
                {draft.exercises.reduce((acc, e) => acc + e.sets.filter((s) => s.completed).length, 0)}/{draft.totalSets} SETS DONE
              </Text>
            </View>
            <Text style={[styles.draftArrow, { color: C.accent }]}>›</Text>
          </View>
        </Pressable>
      </View>
    );
  }

  return (
    <View style={styles.dockedWrap}>
      <Pressable
        onPress={() => router.push('/workout/active')}
        style={[styles.startBtn, { backgroundColor: C.accent }]}
      >
        <View style={{ flex: 1 }}>
          <Text style={styles.startBtnLabel}>TODAY · {prediction.program}</Text>
          <Text style={styles.startBtnName}>{prediction.name}</Text>
        </View>
        <View style={{ alignItems: 'flex-end' }}>
          <Text style={styles.startBtnDur}>{prediction.estDuration}</Text>
          <Text style={styles.startBtnCta}>START WORKOUT ›</Text>
        </View>
      </Pressable>
    </View>
  );
}

// ── Main screen ────────────────────────────────────────────────

export default function HomeScreen() {
  const { C, Fonts } = useTheme();
  const insets = useSafeAreaInsets();
  const router = useRouter();
  const profile = useAppStore((s) => s.profile);
  const workouts = useAppStore((s) => s.workouts);
  const computeStreak = useAppStore((s) => s.computeStreak);
  const streak = computeStreak();

  const prediction = buildPrediction(workouts);

  const weekVol = [80, 94, 0, 112, 86, 0, 0];
  const weekLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  const today = new Date().getDay();
  const todayIdx = today === 0 ? 6 : today - 1;
  const weekDone = weekLabels.map((_, i) => i < todayIdx && weekVol[i] > 0);

  const weekSets = weekVol.reduce((a, b) => a + b, 0);
  const recentWorkouts = workouts.slice(0, 5);

  return (
    <View style={[styles.screen, { backgroundColor: C.bg }]}>
      <View style={{ paddingTop: insets.top }}>
        <TickerStrip />
        {/* Masthead */}
        <View style={[styles.masthead, { borderBottomColor: C.hair }]}>
          <View style={styles.mastheadLeft}>
            <View style={[styles.mastheadDot, { backgroundColor: C.accent }]} />
            <Text style={[styles.mastheadTitle, { color: C.ink }]}>PULSE/PUMP</Text>
          </View>
          <View style={styles.mastheadRight}>
            <Pressable onPress={() => {}}>
              <Text style={[styles.mastheadSearch, { color: C.muted }]}>⌕</Text>
            </Pressable>
            <Pressable
              onPress={() => router.push('/more/profile')}
              style={[styles.mastheadAvatar, { backgroundColor: C.surf, borderColor: C.hair2 }]}
            >
              <Text style={[styles.mastheadAvatarText, { color: C.muted }]}>
                {profile?.name?.[0] ?? 'J'}
              </Text>
            </Pressable>
          </View>
        </View>
      </View>

      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{ paddingBottom: 180 }}
        showsVerticalScrollIndicator={false}
      >
        {/* Prediction block */}
        <View style={[styles.predBlock, { backgroundColor: C.surf, borderBottomColor: C.hair }]}>
          <View style={styles.predRow}>
            <View style={{ flex: 1 }}>
              <Text style={[styles.predLabel, { color: C.muted }]}>
                PREDICTED TODAY · {prediction.program}
              </Text>
              <Text style={[styles.predName, { color: C.ink }]}>{prediction.name}</Text>
              <Text style={[styles.predMeta, { color: C.muted }]}>
                {prediction.lastDone.toUpperCase()}{'  '}{prediction.estDuration}
              </Text>
            </View>
            <View style={{ alignItems: 'flex-end' }}>
              <ConfidenceDots conf={prediction.confidence} />
              <Text style={[styles.predReason, { color: C.muted }]}>{prediction.reason}</Text>
            </View>
          </View>
          <View style={styles.predChips}>
            {prediction.exercises.map((e: string, i: number) => (
              <View key={i} style={[styles.predChip, { backgroundColor: C.surf2 }]}>
                <Text style={[styles.predChipText, { color: C.muted }]}>{e.toUpperCase()}</Text>
              </View>
            ))}
            <Pressable>
              <Text style={[styles.predNotToday, { color: C.faint }]}>NOT TODAY? ›</Text>
            </Pressable>
          </View>
        </View>

        {/* KPI 4-up */}
        <View style={[styles.kpiRow, { borderBottomColor: C.hair }]}>
          {[
            { l: 'STREAK', v: `${streak}D`, d: '▲ +1', up: true },
            { l: 'IMPROVED', v: String(workouts.length > 0 ? 14 : 0), d: 'this wk', up: null },
            { l: 'PRs', v: String(3), d: 'this wk', up: null },
            { l: 'SETS', v: String(weekSets), d: 'this wk', up: null },
          ].map((s, i) => (
            <View
              key={i}
              style={[
                styles.kpiCell,
                i < 3 && { borderRightWidth: 1, borderRightColor: C.hair },
              ]}
            >
              <Text style={[styles.kpiLabel, { color: C.muted }]}>{s.l}</Text>
              <Text style={[styles.kpiVal, { color: s.up === true ? C.up : C.ink }]}>{s.v}</Text>
              <Text style={[styles.kpiSub, { color: s.up === true ? C.up : C.muted }]}>{s.d}</Text>
            </View>
          ))}
        </View>

        {/* Week volume bars */}
        <View style={[styles.weekSection, { borderBottomColor: C.hair }]}>
          <View style={styles.weekHeader}>
            <Text style={[styles.weekLabel, { color: C.muted }]}>WEEKLY VOLUME · SETS</Text>
            <Text style={[styles.weekLabel, { color: C.muted }]}>WK {new Date().getWeek()} · {weekSets} TOTAL</Text>
          </View>
          <WeekBars data={weekVol} labels={weekLabels} done={weekDone} todayIdx={todayIdx} />
        </View>

        {/* Friends chip */}
        <View style={[styles.friendsSection, { borderBottomColor: C.hair }]}>
          <View style={[styles.friendsChip, { backgroundColor: C.surf, borderColor: C.hair2 }]}>
            <View style={styles.friendsAvatars}>
              {['M', 'P'].map((initial, i) => (
                <View
                  key={i}
                  style={[
                    styles.friendAvatar,
                    { backgroundColor: C.surf2, borderColor: C.bg, marginLeft: i > 0 ? -8 : 0 },
                  ]}
                >
                  <Text style={[styles.friendAvatarText, { color: C.muted }]}>{initial}</Text>
                </View>
              ))}
            </View>
            <Text style={[styles.friendsText, { color: C.ink }]}>Marcus +1 others trained today</Text>
            <Text style={[styles.friendsChevron, { color: C.faint }]}>›</Text>
          </View>
        </View>

        {/* Recent workouts table */}
        <View>
          <View
            style={[
              styles.tableHeader,
              { backgroundColor: C.surf2, borderBottomColor: C.hair },
            ]}
          >
            <Text style={[styles.tableHeaderCell, { color: C.muted, flex: 1 }]}>RECENT</Text>
            <Text style={[styles.tableHeaderCell, { color: C.muted, width: 56, textAlign: 'center' }]}>SETS</Text>
            <Text style={[styles.tableHeaderCell, { color: C.muted, width: 56, textAlign: 'center' }]}>IMPR</Text>
            <Text style={[styles.tableHeaderCell, { color: C.muted, width: 56, textAlign: 'right' }]}>VOL▲</Text>
          </View>
          {recentWorkouts.length === 0
            ? [
                { name: 'Pull Day', date: 'Thu', sets: 26, improved: '5/6', vol: '+11%' },
                { name: 'Push Day', date: 'Mon', sets: 24, improved: '4/6', vol: '+8%' },
                { name: 'Legs', date: 'Last Sat', sets: 28, improved: '3/5', vol: '+3%' },
              ].map((w, i) => (
                <View key={i} style={[styles.tableRow, { borderBottomColor: C.hair }]}>
                  <View style={{ flex: 1 }}>
                    <Text style={[styles.tableRowName, { color: C.ink }]}>{w.name}</Text>
                    <Text style={[styles.tableRowDate, { color: C.muted }]}>{w.date}</Text>
                  </View>
                  <Text style={[styles.tableRowNum, { color: C.muted, width: 56, textAlign: 'center' }]}>{w.sets}</Text>
                  <Text style={[styles.tableRowNum, { color: C.up, width: 56, textAlign: 'center' }]}>{w.improved}</Text>
                  <Text style={[styles.tableRowNum, { color: C.up, width: 56, textAlign: 'right' }]}>▲{w.vol}</Text>
                </View>
              ))
            : recentWorkouts.map((w, i) => (
                <Pressable
                  key={i}
                  onPress={() => router.push(`/more/workout/${w.id}`)}
                  style={[styles.tableRow, { borderBottomColor: C.hair }]}
                >
                  <View style={{ flex: 1 }}>
                    <Text style={[styles.tableRowName, { color: C.ink }]}>{w.name}</Text>
                    <Text style={[styles.tableRowDate, { color: C.muted }]}>
                      {new Date(w.startedAt).toLocaleDateString('en', { weekday: 'short', day: 'numeric', month: 'short' })}
                    </Text>
                  </View>
                  <Text style={[styles.tableRowNum, { color: C.muted, width: 56, textAlign: 'center' }]}>{w.totalSets}</Text>
                  <Text style={[styles.tableRowNum, { color: C.up, width: 56, textAlign: 'center' }]}>—</Text>
                  <Text style={[styles.tableRowNum, { color: C.up, width: 56, textAlign: 'right' }]}>—</Text>
                </Pressable>
              ))}
        </View>
      </ScrollView>

      <DockedCTA prediction={prediction} />
    </View>
  );
}

// Extend Date prototype for week number
declare global {
  interface Date {
    getWeek(): number;
  }
}
Date.prototype.getWeek = function () {
  const d = new Date(Date.UTC(this.getFullYear(), this.getMonth(), this.getDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  return Math.ceil((((d.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
};

const styles = StyleSheet.create({
  screen: { flex: 1 },
  tickerContainer: {
    height: 26,
    overflow: 'hidden',
    backgroundColor: '#1a1816',
  },
  tickerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    height: 26,
  },
  tickerItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginRight: 8,
  },
  tickerKey: {
    fontFamily: 'SpaceMono-Regular',
    fontSize: 9,
    color: 'rgba(236,229,214,0.55)',
    letterSpacing: 1,
  },
  tickerVal: {
    fontFamily: 'SpaceMono-Bold',
    fontSize: 9,
    fontWeight: '700',
  },
  tickerUp: { color: '#7fcf9f' },
  tickerDown: { color: '#ff8b75' },
  tickerNeutral: { color: 'rgba(236,229,214,0.6)' },
  tickerDot: {
    fontFamily: 'SpaceMono-Regular',
    fontSize: 9,
    color: 'rgba(236,229,214,0.18)',
  },
  masthead: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderBottomWidth: 1,
  },
  mastheadLeft: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  mastheadDot: { width: 16, height: 16, borderRadius: 3 },
  mastheadTitle: {
    fontFamily: 'SpaceMono-Bold',
    fontSize: 10,
    letterSpacing: 2,
  },
  mastheadRight: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  mastheadSearch: { fontSize: 20 },
  mastheadAvatar: {
    width: 28,
    height: 28,
    borderRadius: 8,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  mastheadAvatarText: { fontFamily: 'Archivo-Medium', fontSize: 13 },
  predBlock: { padding: 10, paddingHorizontal: 16, borderBottomWidth: 1 },
  predRow: { flexDirection: 'row', alignItems: 'flex-start', justifyContent: 'space-between' },
  predLabel: { fontFamily: 'SpaceMono-Regular', fontSize: 8, letterSpacing: 1.5, marginBottom: 4 },
  predName: { fontFamily: 'Archivo-Black', fontSize: 36, letterSpacing: 0.5, lineHeight: 36 },
  predMeta: { fontFamily: 'SpaceMono-Regular', fontSize: 9, marginTop: 4 },
  predReason: { fontFamily: 'SpaceMono-Regular', fontSize: 8, marginTop: 6, maxWidth: 120, textAlign: 'right', lineHeight: 14 },
  predChips: { flexDirection: 'row', flexWrap: 'wrap', gap: 5, marginTop: 8 },
  predChip: { paddingHorizontal: 7, paddingVertical: 2, borderRadius: 4 },
  predChipText: { fontFamily: 'SpaceMono-Regular', fontSize: 8, letterSpacing: 0.5 },
  predNotToday: { fontFamily: 'SpaceMono-Regular', fontSize: 8, paddingHorizontal: 4, paddingVertical: 2 },
  confRow: { flexDirection: 'row', alignItems: 'center', gap: 3 },
  confDot: { width: 5, height: 5, borderRadius: 1 },
  confLabel: { fontFamily: 'SpaceMono-Regular', fontSize: 8, marginLeft: 4, letterSpacing: 0.5 },
  kpiRow: {
    flexDirection: 'row',
    borderBottomWidth: 1,
  },
  kpiCell: {
    flex: 1,
    paddingVertical: 9,
    paddingHorizontal: 10,
    alignItems: 'center',
  },
  kpiLabel: { fontFamily: 'SpaceMono-Regular', fontSize: 7, letterSpacing: 1.2, marginBottom: 3 },
  kpiVal: { fontFamily: 'Archivo-Black', fontSize: 22, lineHeight: 24 },
  kpiSub: { fontFamily: 'SpaceMono-Bold', fontSize: 8, marginTop: 2 },
  weekSection: { padding: 10, paddingHorizontal: 16, borderBottomWidth: 1 },
  weekHeader: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 6 },
  weekLabel: { fontFamily: 'SpaceMono-Regular', fontSize: 8, letterSpacing: 1.5 },
  weekBarsRow: {
    flexDirection: 'row',
    gap: 4,
    alignItems: 'flex-end',
    height: 60,
  },
  weekBarCol: { flex: 1, alignItems: 'center', gap: 3, justifyContent: 'flex-end' },
  weekBar: { width: '100%', borderRadius: 2 },
  weekBarLabel: { fontFamily: 'SpaceMono-Regular', fontSize: 7, letterSpacing: 0.5 },
  friendsSection: { padding: 10, paddingHorizontal: 16, borderBottomWidth: 1 },
  friendsChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    padding: 8,
    paddingHorizontal: 12,
    borderRadius: 8,
    borderWidth: 1,
  },
  friendsAvatars: { flexDirection: 'row' },
  friendAvatar: {
    width: 22,
    height: 22,
    borderRadius: 11,
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  friendAvatarText: { fontFamily: 'Archivo-Regular', fontSize: 9 },
  friendsText: { flex: 1, fontFamily: 'Archivo-Medium', fontSize: 11 },
  friendsChevron: { fontFamily: 'Archivo-Regular', fontSize: 14 },
  tableHeader: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingVertical: 5,
    borderBottomWidth: 1,
  },
  tableHeaderCell: { fontFamily: 'SpaceMono-Regular', fontSize: 7, letterSpacing: 1.2 },
  tableRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderBottomWidth: 1,
  },
  tableRowName: { fontFamily: 'Archivo-SemiBold', fontSize: 14, letterSpacing: 0.3 },
  tableRowDate: { fontFamily: 'SpaceMono-Regular', fontSize: 8, marginTop: 1 },
  tableRowNum: { fontFamily: 'SpaceMono-Bold', fontSize: 11 },
  dockedWrap: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    paddingHorizontal: 16,
    paddingTop: 10,
    paddingBottom: 96,
  },
  startBtn: {
    height: 54,
    borderRadius: 12,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    gap: 10,
  },
  startBtnLabel: {
    fontFamily: 'SpaceMono-Regular',
    fontSize: 8,
    color: 'rgba(255,255,255,0.6)',
    letterSpacing: 1.5,
    marginBottom: 2,
  },
  startBtnName: { fontFamily: 'Archivo-Black', fontSize: 22, letterSpacing: 1.5, color: '#fff' },
  startBtnDur: {
    fontFamily: 'SpaceMono-Regular',
    fontSize: 8,
    color: 'rgba(255,255,255,0.6)',
    letterSpacing: 0.8,
    marginBottom: 2,
  },
  startBtnCta: { fontFamily: 'Archivo-Black', fontSize: 18, letterSpacing: 1, color: '#fff' },
  draftBtn: {
    height: 54,
    borderRadius: 12,
    borderWidth: 1,
    overflow: 'hidden',
  },
  draftProgress: {
    position: 'absolute',
    left: 0,
    top: 0,
    bottom: 0,
    opacity: 0.18,
    borderRadius: 12,
  },
  draftBtnContent: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 18,
    gap: 14,
  },
  draftName: { fontFamily: 'Archivo-Black', fontSize: 20, letterSpacing: 1.5 },
  draftMeta: { fontFamily: 'SpaceMono-Regular', fontSize: 9, marginTop: 1 },
  draftArrow: { fontFamily: 'Archivo-Black', fontSize: 22 },
  startNewLink: { alignItems: 'center', marginBottom: 7 },
  startNewText: {
    fontFamily: 'SpaceMono-Regular',
    fontSize: 10,
    letterSpacing: 1,
    borderBottomWidth: 1,
    paddingBottom: 1,
  },
  confirmCard: {
    borderRadius: 10,
    borderWidth: 1,
    padding: 10,
    paddingHorizontal: 14,
    marginBottom: 8,
  },
  confirmTitle: { fontFamily: 'Archivo-SemiBold', fontSize: 13, marginBottom: 3 },
  confirmBody: { fontFamily: 'Archivo-Regular', fontSize: 12, marginBottom: 10 },
  confirmBtns: { flexDirection: 'row', gap: 8 },
  confirmCancel: {
    flex: 1,
    height: 34,
    borderRadius: 8,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  confirmCancelLabel: { fontFamily: 'Archivo-SemiBold', fontSize: 13, letterSpacing: 1 },
  confirmDestruct: {
    flex: 1,
    height: 34,
    borderRadius: 8,
    backgroundColor: '#c0341a',
    alignItems: 'center',
    justifyContent: 'center',
  },
  confirmDestructLabel: { fontFamily: 'Archivo-SemiBold', fontSize: 12, letterSpacing: 0.8, color: '#fff' },
});
