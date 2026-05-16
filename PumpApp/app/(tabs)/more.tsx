import React, { useState } from 'react';
import {
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, {
  Circle,
  Line,
  Path,
  Polygon,
  Polyline,
  Rect,
} from 'react-native-svg';
import { useTheme } from '../../hooks/useTheme';
import { useAppStore } from '../../store/appStore';

type Screen = 'hub' | 'history' | 'profile' | 'settings' | 'equipment' | 'pulse+';

// ── Shared primitives ──────────────────────────────────────────

function SectionHeader({ title, C }: { title: string; C: any }) {
  return (
    <Text style={[styles.sectionHeader, { color: C.muted }]}>{title}</Text>
  );
}

function NavRow({
  C,
  icon,
  label,
  sub,
  badge,
  accent,
  destructive,
  chevron = true,
  onPress,
}: {
  C: any;
  icon: React.ReactNode;
  label: string;
  sub?: string;
  badge?: string;
  accent?: boolean;
  destructive?: boolean;
  chevron?: boolean;
  onPress?: () => void;
}) {
  const { Fonts } = useTheme();
  const labelColor = destructive ? '#c0341a' : accent ? C.accent : C.ink;
  const iconBg = destructive ? 'rgba(192,52,26,0.12)' : accent ? C.accentSoft : C.surf2;
  return (
    <Pressable
      onPress={onPress}
      style={[styles.navRow, { borderBottomColor: C.hair }]}
    >
      <View style={[styles.navIcon, { backgroundColor: iconBg }]}>{icon}</View>
      <View style={{ flex: 1 }}>
        <Text style={[styles.navLabel, { color: labelColor, fontFamily: Fonts.medium }]}>{label}</Text>
        {sub ? (
          <Text style={[styles.navSub, { color: C.muted, fontFamily: Fonts.mono }]}>{sub}</Text>
        ) : null}
      </View>
      {badge ? (
        <View style={[styles.badge, { backgroundColor: C.accent }]}>
          <Text style={[styles.badgeText, { fontFamily: Fonts.monoBold }]}>{badge}</Text>
        </View>
      ) : null}
      {chevron ? (
        <Text style={[styles.chevron, { color: C.faint }]}>›</Text>
      ) : null}
    </Pressable>
  );
}

function ToggleRow({
  C,
  icon,
  label,
  sub,
  value,
  onChange,
}: {
  C: any;
  icon: React.ReactNode;
  label: string;
  sub?: string;
  value: boolean;
  onChange: (v: boolean) => void;
}) {
  const { Fonts } = useTheme();
  return (
    <View style={[styles.navRow, { borderBottomColor: C.hair }]}>
      <View style={[styles.navIcon, { backgroundColor: C.surf2 }]}>{icon}</View>
      <View style={{ flex: 1 }}>
        <Text style={[styles.navLabel, { color: C.ink, fontFamily: Fonts.medium }]}>{label}</Text>
        {sub ? (
          <Text style={[styles.navSub, { color: C.muted, fontFamily: Fonts.mono }]}>{sub}</Text>
        ) : null}
      </View>
      <Switch
        value={value}
        onValueChange={onChange}
        trackColor={{ false: C.hair2, true: C.accent }}
        thumbColor="#fff"
      />
    </View>
  );
}

function UnitRow({
  C,
  label,
  opts,
  active,
  onSelect,
}: {
  C: any;
  label: string;
  opts: string[];
  active: string;
  onSelect: (v: string) => void;
}) {
  const { Fonts } = useTheme();
  return (
    <View style={[styles.unitRow, { borderBottomColor: C.hair }]}>
      <Text style={[styles.unitLabel, { color: C.ink, fontFamily: Fonts.medium }]}>{label}</Text>
      <View style={styles.unitPills}>
        {opts.map((o) => (
          <Pressable
            key={o}
            onPress={() => onSelect(o)}
            style={[
              styles.unitPill,
              {
                backgroundColor: active === o ? C.accent : C.surf2,
                borderColor: active === o ? C.accent : C.hair,
              },
            ]}
          >
            <Text
              style={[
                styles.unitPillText,
                { color: active === o ? '#fff' : C.muted, fontFamily: Fonts.monoBold },
              ]}
            >
              {o}
            </Text>
          </Pressable>
        ))}
      </View>
    </View>
  );
}

// ── Destructive modal ──────────────────────────────────────────

function DestructiveModal({
  C,
  Fonts,
  visible,
  kicker,
  title,
  body,
  consequences,
  cancelLabel,
  confirmLabel,
  onCancel,
  onConfirm,
}: {
  C: any;
  Fonts: any;
  visible: boolean;
  kicker: string;
  title: string;
  body: string;
  consequences?: string[];
  cancelLabel: string;
  confirmLabel: string;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  return (
    <Modal visible={visible} transparent animationType="fade">
      <View style={styles.modalOverlay}>
        <View style={[styles.destroyCard, { backgroundColor: C.surf }]}>
          <View style={[styles.destroyStrip, { backgroundColor: '#c0341a' }]}>
            <Text style={[styles.destroyKicker, { fontFamily: Fonts.monoBold }]}>⚠ {kicker}</Text>
            <Text style={[styles.destroyTitle, { fontFamily: Fonts.black }]}>{title}</Text>
          </View>
          <View style={{ padding: 20 }}>
            <Text style={[styles.destroyBody, { color: C.ink, fontFamily: Fonts.regular }]}>{body}</Text>
            {consequences && consequences.length > 0 ? (
              <View style={[styles.consequencesBox, { backgroundColor: C.bg, borderColor: C.hair }]}>
                <Text style={[styles.consequencesHeader, { color: C.muted, fontFamily: Fonts.monoBold }]}>
                  WHAT YOU'LL LOSE
                </Text>
                {consequences.map((c, i) => (
                  <View key={i} style={[styles.consequenceRow, { borderTopColor: C.hair }]}>
                    <Text style={[styles.consequenceText, { color: C.ink, fontFamily: Fonts.regular }]}>
                      {c}
                    </Text>
                  </View>
                ))}
              </View>
            ) : null}
            <View style={styles.destroyBtns}>
              <Pressable
                onPress={onCancel}
                style={[styles.destroyBtn, { backgroundColor: C.surf2 }]}
              >
                <Text style={[styles.destroyBtnText, { color: C.ink, fontFamily: Fonts.medium }]}>
                  {cancelLabel}
                </Text>
              </Pressable>
              <Pressable
                onPress={onConfirm}
                style={[styles.destroyBtn, { backgroundColor: '#c0341a' }]}
              >
                <Text style={[styles.destroyBtnText, { color: '#fff', fontFamily: Fonts.medium }]}>
                  {confirmLabel}
                </Text>
              </Pressable>
            </View>
          </View>
        </View>
      </View>
    </Modal>
  );
}

// ── History screen ─────────────────────────────────────────────

function HistoryScreen({ C, Fonts, onBack }: { C: any; Fonts: any; onBack: () => void }) {
  const insets = useSafeAreaInsets();
  const workouts = useAppStore((s) => s.workouts);
  const [view, setView] = useState<'list' | 'calendar'>('list');
  const [calMonth] = useState(new Date());

  const calYear = calMonth.getFullYear();
  const calMonthIdx = calMonth.getMonth();
  const daysInMonth = new Date(calYear, calMonthIdx + 1, 0).getDate();
  const firstDow = (new Date(calYear, calMonthIdx, 1).getDay() + 6) % 7; // Mon=0
  const today = new Date().getDate();
  const todayMonth = new Date().getMonth();
  const workoutDaySet = new Set(
    workouts
      .filter((w) => {
        const d = new Date(w.completedAt || w.startedAt);
        return d.getFullYear() === calYear && d.getMonth() === calMonthIdx;
      })
      .map((w) => new Date(w.completedAt || w.startedAt).getDate())
  );

  const calCells: (number | null)[] = [
    ...Array(firstDow).fill(null),
    ...Array.from({ length: daysInMonth }, (_, i) => i + 1),
  ];
  while (calCells.length % 7 !== 0) calCells.push(null);

  const MONTH_LABELS = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];

  const sampleWorkouts = workouts.length > 0 ? workouts : [
    { id: 's1', name: 'Pull Day', startedAt: Date.now() - 86400000, totalSets: 26, prs: ['e1'], totalVolume: 4200 },
    { id: 's2', name: 'Push Day', startedAt: Date.now() - 86400000 * 4, totalSets: 24, prs: [], totalVolume: 3900 },
    { id: 's3', name: 'Legs', startedAt: Date.now() - 86400000 * 6, totalSets: 28, prs: ['e2'], totalVolume: 5100 },
    { id: 's4', name: 'Pull Day', startedAt: Date.now() - 86400000 * 8, totalSets: 25, prs: [], totalVolume: 4050 },
  ];

  return (
    <View style={[styles.screen, { backgroundColor: C.bg, paddingTop: insets.top }]}>
      <View style={[styles.subHeader, { borderBottomColor: C.hair }]}>
        <Pressable onPress={onBack} style={styles.backBtn}>
          <Text style={[styles.backArrow, { color: C.muted }]}>‹</Text>
        </Pressable>
        <Text style={[styles.subTitle, { color: C.ink, fontFamily: Fonts.black }]}>HISTORY</Text>
        <View style={[styles.viewToggle, { backgroundColor: C.surf2 }]}>
          {(['list', 'calendar'] as const).map((v) => (
            <Pressable
              key={v}
              onPress={() => setView(v)}
              style={[styles.viewToggleBtn, view === v && { backgroundColor: C.bg }]}
            >
              <Text style={[styles.viewToggleTxt, { color: view === v ? C.accent : C.muted }]}>
                {v === 'list' ? '≡' : '▦'}
              </Text>
            </Pressable>
          ))}
        </View>
      </View>

      <ScrollView style={{ flex: 1 }} showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 32 }}>
        {view === 'list' ? (
          <>
            <View style={[styles.triRow, { borderBottomColor: C.hair }]}>
              {[
                ['WORKOUTS', String(workouts.length || 148)],
                ['THIS MONTH', '12'],
                ['STREAK', '13D'],
              ].map(([l, v], i) => (
                <View
                  key={i}
                  style={[styles.triCell, i < 2 && { borderRightWidth: 1, borderRightColor: C.hair }]}
                >
                  <Text style={[styles.triLabel, { color: C.muted, fontFamily: Fonts.mono }]}>{l}</Text>
                  <Text style={[styles.triVal, { color: C.ink, fontFamily: Fonts.mono }]}>{v}</Text>
                </View>
              ))}
            </View>
            <SectionHeader title="RECENT" C={C} />
            {(sampleWorkouts as any[]).map((w: any, i: number) => {
              const date = new Date(w.startedAt || Date.now());
              const dayNames = ['SUN','MON','TUE','WED','THU','FRI','SAT'];
              return (
                <Pressable key={w.id || i} style={[styles.histRow, { borderBottomColor: C.hair }]}>
                  <View style={styles.histDateBox}>
                    <Text style={[styles.histDow, { color: C.muted, fontFamily: Fonts.mono }]}>
                      {dayNames[date.getDay()]}
                    </Text>
                    <Text style={[styles.histDayNum, { color: C.ink, fontFamily: Fonts.mono }]}>
                      {date.getDate()}
                    </Text>
                    <Text style={[styles.histMon, { color: C.muted, fontFamily: Fonts.mono }]}>
                      {MONTH_LABELS[date.getMonth()]}
                    </Text>
                  </View>
                  <View style={{ flex: 1 }}>
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
                      <Text style={[styles.histName, { color: C.ink, fontFamily: Fonts.black }]}>
                        {w.name}
                      </Text>
                      {(w.prs?.length || 0) > 0 && (
                        <Text style={[styles.histPRBadge, { color: C.pr, fontFamily: Fonts.monoBold }]}>
                          ★ {w.prs?.length}
                        </Text>
                      )}
                    </View>
                    <Text style={[styles.histMeta, { color: C.muted, fontFamily: Fonts.mono }]}>
                      {w.totalSets} SETS · {Math.round((w.totalVolume || 0) / 1000 * 10) / 10}T VOL
                    </Text>
                  </View>
                  <Text style={[styles.chevron, { color: C.faint }]}>›</Text>
                </Pressable>
              );
            })}
          </>
        ) : (
          <View style={{ padding: 16 }}>
            <View style={styles.calHeader}>
              <Pressable><Text style={[styles.calArrow, { color: C.muted }]}>‹</Text></Pressable>
              <Text style={[styles.calMonth, { color: C.ink, fontFamily: Fonts.black }]}>
                {MONTH_LABELS[calMonthIdx]} {calYear}
              </Text>
              <Pressable><Text style={[styles.calArrow, { color: C.muted }]}>›</Text></Pressable>
            </View>
            <View style={styles.calWeekRow}>
              {['M','T','W','T','F','S','S'].map((d, i) => (
                <Text key={i} style={[styles.calWeekDay, { color: C.muted, fontFamily: Fonts.mono }]}>{d}</Text>
              ))}
            </View>
            <View style={styles.calGrid}>
              {calCells.map((day, i) => {
                const isToday = day === today && calMonthIdx === todayMonth;
                const hasWorkout = day !== null && workoutDaySet.has(day);
                return (
                  <View
                    key={i}
                    style={[
                      styles.calCell,
                      {
                        backgroundColor: isToday
                          ? C.accent
                          : hasWorkout
                          ? C.accentSoft
                          : 'transparent',
                        borderWidth: day ? 1 : 0,
                        borderColor: isToday
                          ? 'transparent'
                          : hasWorkout
                          ? C.accent + '44'
                          : C.hair,
                      },
                    ]}
                  >
                    {day ? (
                      <Text
                        style={[
                          styles.calCellTxt,
                          {
                            color: isToday ? '#fff' : hasWorkout ? C.accent : C.ink2,
                            fontFamily: Fonts.mono,
                          },
                        ]}
                      >
                        {day}
                      </Text>
                    ) : null}
                  </View>
                );
              })}
            </View>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

// ── Profile screen ─────────────────────────────────────────────

function ProfileScreen({ C, Fonts, onBack }: { C: any; Fonts: any; onBack: () => void }) {
  const insets = useSafeAreaInsets();
  const profile = useAppStore((s) => s.profile);
  const workouts = useAppStore((s) => s.workouts);
  const computeStreak = useAppStore((s) => s.computeStreak);

  const name = profile?.name || 'Jay';
  const handle = profile?.handle || '@jaypump';
  const split = profile?.split || 'PPL';
  const experience = profile?.experience || 'intermediate';

  const PRs = [
    { name: 'Bench Press', val: '105KG × 3' },
    { name: 'Deadlift', val: '180KG × 3' },
    { name: 'Squat', val: '140KG × 5' },
    { name: 'OHP', val: '72.5KG × 4' },
  ];

  return (
    <View style={[styles.screen, { backgroundColor: C.bg, paddingTop: insets.top }]}>
      <View style={[styles.subHeader, { borderBottomColor: C.hair }]}>
        <Pressable onPress={onBack} style={styles.backBtn}>
          <Text style={[styles.backArrow, { color: C.muted }]}>‹</Text>
        </Pressable>
        <Text style={[styles.subTitle, { color: C.ink, fontFamily: Fonts.black }]}>PROFILE</Text>
        <Pressable>
          <Text style={[styles.editLink, { color: C.accent, fontFamily: Fonts.monoBold }]}>EDIT</Text>
        </Pressable>
      </View>

      <ScrollView style={{ flex: 1 }} showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 40 }}>
        <View style={[styles.profHero, { borderBottomColor: C.hair }]}>
          <View style={[styles.profAvatar, { backgroundColor: C.surf2, borderColor: C.hair2 }]}>
            <Text style={[styles.profAvatarLetter, { color: C.muted, fontFamily: Fonts.black }]}>
              {name[0].toUpperCase()}
            </Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={[styles.profName, { color: C.ink, fontFamily: Fonts.bold }]}>{name}</Text>
            <Text style={[styles.profHandle, { color: C.muted, fontFamily: Fonts.mono }]}>{handle}</Text>
            <Text style={[styles.profMeta, { color: C.muted, fontFamily: Fonts.mono }]}>
              {split.toUpperCase()} · {experience.toUpperCase()}
            </Text>
          </View>
        </View>

        <View style={[styles.triRow, { borderBottomColor: C.hair }]}>
          {[
            ['WORKOUTS', String(workouts.length || 148)],
            ['THIS YEAR', '64'],
            [`STREAK`, `${computeStreak()}D`],
          ].map(([l, v], i) => (
            <View
              key={i}
              style={[styles.triCell, i < 2 && { borderRightWidth: 1, borderRightColor: C.hair }]}
            >
              <Text style={[styles.triLabel, { color: C.muted, fontFamily: Fonts.mono }]}>{l}</Text>
              <Text style={[styles.triVal, { color: C.ink, fontFamily: Fonts.mono }]}>{v}</Text>
            </View>
          ))}
        </View>

        <View style={[styles.programSection, { borderBottomColor: C.hair }]}>
          <SectionHeader title="CURRENT PROGRAM" C={C} />
          <View style={styles.programRow}>
            <View style={{ flex: 1 }}>
              <Text style={[styles.programName, { color: C.ink, fontFamily: Fonts.black }]}>
                PUSH PULL LEGS
              </Text>
              <Text style={[styles.programMeta, { color: C.muted, fontFamily: Fonts.mono }]}>
                6 DAYS/WEEK · 18 EXERCISES
              </Text>
            </View>
            <Pressable style={[styles.switchBtn, { backgroundColor: C.accentSoft, borderColor: C.accent + '44' }]}>
              <Text style={[styles.switchBtnTxt, { color: C.accent, fontFamily: Fonts.mono }]}>SWITCH</Text>
            </Pressable>
          </View>
        </View>

        <View style={{ paddingHorizontal: 16, paddingTop: 4 }}>
          <SectionHeader title="ALL-TIME PRs" C={C} />
          {PRs.map((pr, i) => (
            <View
              key={i}
              style={[
                styles.prRow,
                { borderBottomColor: C.hair, borderTopWidth: i === 0 ? 0 : 0 },
              ]}
            >
              <Text style={[styles.prName, { color: C.ink, fontFamily: Fonts.medium }]}>{pr.name}</Text>
              <Text style={[styles.prVal, { color: C.pr, fontFamily: Fonts.mono }]}>{pr.val}</Text>
            </View>
          ))}
        </View>

        <View style={{ paddingHorizontal: 16 }}>
          <SectionHeader title="BODY STATS" C={C} />
          {[
            ['WEIGHT', profile?.weight ? `${profile.weight}${profile.weightUnit || 'KG'}` : '82KG'],
            ['HEIGHT', profile?.height ? `${profile.height}${profile.heightUnit || 'CM'}` : '180CM'],
            ['AGE', profile?.age ? String(profile.age) : '26'],
            ['UNITS', profile?.weightUnit === 'lbs' ? 'IMPERIAL' : 'METRIC'],
          ].map(([label, val], i) => (
            <View key={i} style={[styles.statBodyRow, { borderBottomColor: C.hair }]}>
              <Text style={[styles.statBodyLabel, { color: C.muted, fontFamily: Fonts.mono }]}>{label}</Text>
              <Text style={[styles.statBodyVal, { color: C.ink, fontFamily: Fonts.mono }]}>{val}</Text>
            </View>
          ))}
        </View>
      </ScrollView>
    </View>
  );
}

// ── Settings screen ────────────────────────────────────────────

function SettingsScreen({ C, Fonts, onBack }: { C: any; Fonts: any; onBack: () => void }) {
  const insets = useSafeAreaInsets();
  const profile = useAppStore((s) => s.profile);

  const [weightUnit, setWeightUnit] = useState<string>(profile?.weightUnit || 'kg');
  const [heightUnit, setHeightUnit] = useState<string>(profile?.heightUnit || 'cm');
  const [distUnit, setDistUnit] = useState<string>('km');
  const [autoStartTimer, setAutoStartTimer] = useState(true);
  const [workoutReminders, setWorkoutReminders] = useState(true);
  const [prAlerts, setPrAlerts] = useState(true);
  const [weeklySummary, setWeeklySummary] = useState(false);
  const [autoPost, setAutoPost] = useState(false);
  const [postSummary, setPostSummary] = useState(true);

  const sz = 16;
  const ic = C.muted;

  return (
    <View style={[styles.screen, { backgroundColor: C.bg, paddingTop: insets.top }]}>
      <View style={[styles.subHeader, { borderBottomColor: C.hair }]}>
        <Pressable onPress={onBack} style={styles.backBtn}>
          <Text style={[styles.backArrow, { color: C.muted }]}>‹</Text>
        </Pressable>
        <Text style={[styles.subTitle, { color: C.ink, fontFamily: Fonts.black }]}>SETTINGS</Text>
        <View style={{ width: 36 }} />
      </View>

      <ScrollView style={{ flex: 1 }} showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 40 }}>
        <SectionHeader title="ACCOUNT" C={C} />
        <NavRow C={C} label="Name & Email" sub={profile?.name ? `${profile.name} · ${profile?.handle || ''}` : 'JAY · @JAYPUMP'} chevron icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
            <Circle cx={12} cy={7} r={4} stroke={ic} strokeWidth={1.8} />
          </Svg>
        } />
        <NavRow C={C} label="Change Password" chevron icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Rect x={3} y={11} width={18} height={11} rx={2} stroke={ic} strokeWidth={1.8} />
            <Path d="M7 11V7a5 5 0 0110 0v4" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
          </Svg>
        } />
        <NavRow C={C} label="Linked Accounts" sub="APPLE · GOOGLE" chevron icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Path d="M10 13a5 5 0 007.54.54l3-3a5 5 0 00-7.07-7.07l-1.72 1.71" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
            <Path d="M14 11a5 5 0 00-7.54-.54l-3 3a5 5 0 007.07 7.07l1.71-1.71" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
          </Svg>
        } />

        <SectionHeader title="UNITS" C={C} />
        <View style={[styles.unitRowContainer, { borderBottomColor: C.hair }]}>
          <UnitRow C={C} label="Weight" opts={['kg', 'lbs']} active={weightUnit} onSelect={setWeightUnit} />
        </View>
        <View style={[styles.unitRowContainer, { borderBottomColor: C.hair }]}>
          <UnitRow C={C} label="Height" opts={['cm', 'ft/in']} active={heightUnit} onSelect={setHeightUnit} />
        </View>
        <View style={[styles.unitRowContainer, { borderBottomColor: C.hair }]}>
          <UnitRow C={C} label="Distance" opts={['km', 'mi']} active={distUnit} onSelect={setDistUnit} />
        </View>

        <SectionHeader title="REST TIMER" C={C} />
        <ToggleRow C={C} label="Auto-start after set" sub="STARTS AUTOMATICALLY WHEN YOU LOG A SET" value={autoStartTimer} onChange={setAutoStartTimer} icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Circle cx={12} cy={12} r={10} stroke={ic} strokeWidth={1.8} />
            <Path d="M12 6v6l4 2" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
          </Svg>
        } />
        <NavRow C={C} label="Compound lift default" sub="90 SEC" chevron icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Path d="M6.5 6.5h11M6.5 17.5h11M2 12h20M4 6.5v11M20 6.5v11" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
          </Svg>
        } />
        <NavRow C={C} label="Isolation lift default" sub="60 SEC" chevron icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Path d="M6.5 6.5h11M6.5 17.5h11M2 12h20M4 6.5v11M20 6.5v11" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
          </Svg>
        } />
        <NavRow C={C} label="Alert type" sub="HAPTIC + SOUND" chevron icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 01-3.46 0" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
          </Svg>
        } />

        <SectionHeader title="NOTIFICATIONS" C={C} />
        <ToggleRow C={C} label="Workout reminders" sub="DAILY AT YOUR SCHEDULED TIME" value={workoutReminders} onChange={setWorkoutReminders} icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 01-3.46 0" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
          </Svg>
        } />
        <ToggleRow C={C} label="PR alerts" sub="CELEBRATE NEW PERSONAL RECORDS" value={prAlerts} onChange={setPrAlerts} icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" stroke={ic} strokeWidth={1.8} strokeLinejoin="round" />
          </Svg>
        } />
        <ToggleRow C={C} label="Weekly summary" sub="EVERY MONDAY MORNING" value={weeklySummary} onChange={setWeeklySummary} icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Polyline points="22 12 18 12 15 21 9 3 6 12 2 12" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
          </Svg>
        } />

        <SectionHeader title="WORKOUT" C={C} />
        <ToggleRow C={C} label="Auto-post to feed" sub="SHARE WORKOUTS AUTOMATICALLY" value={autoPost} onChange={setAutoPost} icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Circle cx={18} cy={5} r={3} stroke={ic} strokeWidth={1.8} />
            <Circle cx={6} cy={12} r={3} stroke={ic} strokeWidth={1.8} />
            <Circle cx={18} cy={19} r={3} stroke={ic} strokeWidth={1.8} />
            <Line x1={8.59} y1={13.51} x2={15.42} y2={17.49} stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
            <Line x1={15.41} y1={6.51} x2={8.59} y2={10.49} stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
          </Svg>
        } />
        <ToggleRow C={C} label="Post-workout summary" sub="SHOW COMPLETION SCREEN AFTER FINISHING" value={postSummary} onChange={setPostSummary} icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Path d="M9 11l3 3L22 4" stroke={ic} strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" />
            <Path d="M21 12v7a2 2 0 01-2 2H5a2 2 0 01-2-2V5a2 2 0 012-2h11" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
          </Svg>
        } />

        <SectionHeader title="DATA" C={C} />
        <NavRow C={C} label="Import from Strong / Hevy" sub="CSV IMPORT" chevron icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
            <Polyline points="7 10 12 15 17 10" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
            <Line x1={12} y1={15} x2={12} y2={3} stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
          </Svg>
        } />
        <NavRow C={C} label="Export workout data" sub="JSON · CSV" chevron icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
            <Polyline points="17 8 12 3 7 8" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
            <Line x1={12} y1={3} x2={12} y2={15} stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
          </Svg>
        } />

        <SectionHeader title="DANGER ZONE" C={C} />
        <NavRow C={C} label="Delete Account" sub="PERMANENTLY REMOVES ALL DATA" destructive chevron={false} icon={
          <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
            <Polyline points="3 6 5 6 21 6" stroke="#c0341a" strokeWidth={1.8} strokeLinecap="round" />
            <Path d="M19 6l-1 14H6L5 6M10 11v6M14 11v6M9 6V4h6v2" stroke="#c0341a" strokeWidth={1.8} strokeLinecap="round" />
          </Svg>
        } />
      </ScrollView>
    </View>
  );
}

// ── Equipment screen ───────────────────────────────────────────

const PLATE_COLORS: Record<string, string> = {
  '25': '#e51b1b',
  '20': '#1f4ea3',
  '15': '#c98a17',
  '10': '#1f8f5a',
  '5': '#1f1c19',
  '2.5': '#a3a39a',
  '1.25': '#d6d2c4',
};

const EQUIPMENT_PROFILES = [
  {
    id: 'home',
    label: 'Home Gym',
    active: true,
    items: [
      { name: 'Barbell', qty: 1 },
      { name: 'Dumbbells', qty: 2 },
      { name: 'Power Rack', qty: 1 },
      { name: 'Bench', qty: 1 },
      { name: 'Pull-up Bar', qty: 1 },
    ],
    plates: ['25', '20', '10', '5', '2.5'],
  },
  {
    id: 'commercial',
    label: 'Commercial Gym',
    active: false,
    items: [
      { name: 'All Machines', qty: 1 },
      { name: 'Cable Stations', qty: 4 },
      { name: 'Free Weights', qty: 1 },
      { name: 'Smith Machine', qty: 1 },
    ],
    plates: ['25', '20', '15', '10', '5', '2.5', '1.25'],
  },
];

function EquipmentScreen({ C, Fonts, onBack }: { C: any; Fonts: any; onBack: () => void }) {
  const insets = useSafeAreaInsets();
  const [profileIdx, setProfileIdx] = useState(0);
  const profile = EQUIPMENT_PROFILES[profileIdx];

  return (
    <View style={[styles.screen, { backgroundColor: C.bg, paddingTop: insets.top }]}>
      <View style={[styles.subHeader, { borderBottomColor: C.hair }]}>
        <Pressable onPress={onBack} style={styles.backBtn}>
          <Text style={[styles.backArrow, { color: C.muted }]}>‹</Text>
        </Pressable>
        <Text style={[styles.subTitle, { color: C.ink, fontFamily: Fonts.black }]}>EQUIPMENT</Text>
        <View style={{ width: 36 }} />
      </View>

      {/* Profile tabs */}
      <View style={[styles.equipTabs, { borderBottomColor: C.hair, backgroundColor: C.surf }]}>
        {EQUIPMENT_PROFILES.map((p, i) => (
          <Pressable
            key={p.id}
            onPress={() => setProfileIdx(i)}
            style={[
              styles.equipTab,
              profileIdx === i && { borderBottomWidth: 2, borderBottomColor: C.accent },
            ]}
          >
            <Text
              style={[
                styles.equipTabTxt,
                {
                  color: profileIdx === i ? C.accent : C.muted,
                  fontFamily: profileIdx === i ? Fonts.monoBold : Fonts.mono,
                },
              ]}
            >
              {p.label.toUpperCase()}
            </Text>
          </Pressable>
        ))}
      </View>

      <ScrollView style={{ flex: 1 }} showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 40 }}>
        {/* Active badge */}
        <View style={[styles.activeBadgeRow, { borderBottomColor: C.hair }]}>
          <View style={[styles.activeBadge, { backgroundColor: C.up + '22', borderColor: C.up + '44' }]}>
            <Text style={[styles.activeBadgeTxt, { color: C.up, fontFamily: Fonts.monoBold }]}>
              {profile.active ? '● ACTIVE PROFILE' : '○ INACTIVE'}
            </Text>
          </View>
          <Pressable style={[styles.activateBtn, { borderColor: C.hair }]}>
            <Text style={[styles.activateBtnTxt, { color: C.muted, fontFamily: Fonts.mono }]}>
              {profile.active ? 'DEFAULT' : 'SET ACTIVE'}
            </Text>
          </Pressable>
        </View>

        <SectionHeader title="EQUIPMENT" C={C} />
        {profile.items.map((item, i) => (
          <View key={i} style={[styles.equipRow, { borderBottomColor: C.hair }]}>
            <View style={[styles.equipDot, { backgroundColor: C.up }]} />
            <Text style={[styles.equipName, { color: C.ink, fontFamily: Fonts.medium }]}>{item.name}</Text>
            <Text style={[styles.equipQty, { color: C.muted, fontFamily: Fonts.mono }]}>×{item.qty}</Text>
            <Pressable style={styles.equipEdit}>
              <Svg width={14} height={14} viewBox="0 0 24 24" fill="none">
                <Path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7" stroke={C.muted} strokeWidth={1.8} strokeLinecap="round" />
                <Path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z" stroke={C.muted} strokeWidth={1.8} strokeLinecap="round" />
              </Svg>
            </Pressable>
          </View>
        ))}
        <Pressable style={[styles.addEquipBtn, { borderColor: C.hair }]}>
          <Text style={[styles.addEquipTxt, { color: C.muted, fontFamily: Fonts.mono }]}>+ ADD EQUIPMENT</Text>
        </Pressable>

        <SectionHeader title="PLATES (KG)" C={C} />
        {/* Plate bar visualization */}
        <View style={{ paddingHorizontal: 16, marginBottom: 12 }}>
          <View style={[styles.plateBar, { borderColor: C.hair }]}>
            <View style={[styles.plateBarSleeve, { backgroundColor: C.ink2 }]} />
            {profile.plates.slice(0, 4).map((p, i) => (
              <View
                key={i}
                style={[
                  styles.plateBarPlate,
                  {
                    backgroundColor: PLATE_COLORS[p] || C.surf2,
                    width: p === '25' ? 16 : p === '20' ? 14 : p === '10' ? 12 : 10,
                  },
                ]}
              />
            ))}
            <View style={[styles.plateBarCenter, { backgroundColor: C.ink2 }]} />
            {profile.plates.slice(0, 4).reverse().map((p, i) => (
              <View
                key={i}
                style={[
                  styles.plateBarPlate,
                  {
                    backgroundColor: PLATE_COLORS[p] || C.surf2,
                    width: p === '25' ? 16 : p === '20' ? 14 : p === '10' ? 12 : 10,
                  },
                ]}
              />
            ))}
            <View style={[styles.plateBarSleeve, { backgroundColor: C.ink2 }]} />
          </View>
        </View>
        <View style={[styles.plateChips, { paddingHorizontal: 16 }]}>
          {profile.plates.map((p, i) => (
            <View
              key={i}
              style={[styles.plateChip, { backgroundColor: PLATE_COLORS[p] || C.surf2 }]}
            >
              <Text style={[styles.plateChipTxt, { fontFamily: Fonts.monoBold }]}>{p}</Text>
            </View>
          ))}
        </View>
      </ScrollView>
    </View>
  );
}

// ── Pulse+ screen ──────────────────────────────────────────────

const PULSE_FEATURES = [
  'Smart workout suggestions based on recovery',
  'Advanced analytics & volume tracking',
  'Cloud backup & cross-device sync',
  'AI form coaching (video analysis)',
  'Custom exercise creation (unlimited)',
  'Priority customer support',
  'Early access to new features',
  'Weekly AI-generated recap',
  'Nutrition tracking integration',
  'Heart rate zone coaching',
  'Unlimited program templates',
];

const TIERS = [
  { name: 'PUMP ONLY', monthly: 3.99, yearly: 45, apps: 1 },
  { name: '2 APPS', monthly: 6.49, yearly: 76, apps: 2 },
  { name: 'ALL 3 APPS', monthly: 7.49, yearly: 86, apps: 3, best: true },
];

function PulsePlusScreen({ C, Fonts, onBack }: { C: any; Fonts: any; onBack: () => void }) {
  const insets = useSafeAreaInsets();
  const [billing, setBilling] = useState<'monthly' | 'yearly'>('yearly');
  const [tierIdx, setTierIdx] = useState(2);

  return (
    <View style={[styles.screen, { backgroundColor: C.bg, paddingTop: insets.top }]}>
      <View style={[styles.subHeader, { borderBottomColor: C.hair }]}>
        <Pressable onPress={onBack} style={styles.backBtn}>
          <Text style={[styles.backArrow, { color: C.muted }]}>‹</Text>
        </Pressable>
        <Text style={[styles.subTitle, { color: C.ink, fontFamily: Fonts.black }]}>PULSE+</Text>
        <View style={{ width: 36 }} />
      </View>

      <ScrollView style={{ flex: 1 }} showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 48 }}>
        {/* Hero */}
        <View style={styles.plusHero}>
          <View style={[styles.plusHeroIcon, { backgroundColor: C.accentSoft, borderColor: C.accent + '44' }]}>
            <Svg width={40} height={40} viewBox="0 0 24 24" fill="none">
              <Polygon
                points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"
                stroke={C.accent}
                strokeWidth={1.8}
                fill="none"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </Svg>
          </View>
          <Text style={[styles.plusHeroTitle, { color: C.ink, fontFamily: Fonts.black }]}>
            UNLOCK PULSE+
          </Text>
          <View style={[styles.trialBadge, { backgroundColor: C.up + '22', borderColor: C.up + '44' }]}>
            <Text style={[styles.trialBadgeTxt, { color: C.up, fontFamily: Fonts.monoBold }]}>
              14-DAY FREE TRIAL
            </Text>
          </View>
        </View>

        {/* Billing toggle */}
        <View style={styles.billingToggleRow}>
          <View style={[styles.billingToggle, { backgroundColor: C.surf2 }]}>
            {(['monthly', 'yearly'] as const).map((b) => (
              <Pressable
                key={b}
                onPress={() => setBilling(b)}
                style={[styles.billingToggleBtn, billing === b && { backgroundColor: C.bg }]}
              >
                <Text
                  style={[
                    styles.billingToggleTxt,
                    {
                      color: billing === b ? C.ink : C.muted,
                      fontFamily: billing === b ? Fonts.monoBold : Fonts.mono,
                    },
                  ]}
                >
                  {b.toUpperCase()}
                  {b === 'yearly' ? ' · SAVE 25%' : ''}
                </Text>
              </Pressable>
            ))}
          </View>
        </View>

        {/* Tier cards */}
        <View style={[styles.tierCards, { paddingHorizontal: 16 }]}>
          {TIERS.map((tier, i) => (
            <Pressable
              key={i}
              onPress={() => setTierIdx(i)}
              style={[
                styles.tierCard,
                {
                  backgroundColor: tierIdx === i ? C.accentSoft : C.surf,
                  borderColor: tierIdx === i ? C.accent : C.hair,
                  borderWidth: tierIdx === i ? 1.5 : 1,
                },
              ]}
            >
              {tier.best && (
                <View style={[styles.tierBestBadge, { backgroundColor: C.accent }]}>
                  <Text style={[styles.tierBestTxt, { fontFamily: Fonts.monoBold }]}>BEST VALUE</Text>
                </View>
              )}
              <Text style={[styles.tierName, { color: C.ink, fontFamily: Fonts.black }]}>{tier.name}</Text>
              <Text style={[styles.tierPrice, { color: tierIdx === i ? C.accent : C.ink, fontFamily: Fonts.mono }]}>
                {billing === 'yearly' ? `$${tier.yearly}/yr` : `$${tier.monthly}/mo`}
              </Text>
            </Pressable>
          ))}
        </View>

        {/* Features */}
        <View style={{ paddingHorizontal: 16, paddingTop: 12 }}>
          <SectionHeader title="INCLUDED FEATURES" C={C} />
          {PULSE_FEATURES.map((f, i) => (
            <View key={i} style={[styles.featureRow, { borderBottomColor: C.hair }]}>
              <Text style={[styles.featureCheck, { color: C.up, fontFamily: Fonts.monoBold }]}>✓</Text>
              <Text style={[styles.featureTxt, { color: C.ink, fontFamily: Fonts.regular }]}>{f}</Text>
            </View>
          ))}
        </View>

        {/* CTA */}
        <View style={{ paddingHorizontal: 16, paddingTop: 20 }}>
          <Pressable style={[styles.trialCTA, { backgroundColor: C.accent }]}>
            <Text style={[styles.trialCTATxt, { fontFamily: Fonts.black }]}>START FREE TRIAL</Text>
          </Pressable>
          <Text style={[styles.trialDisclaimer, { color: C.muted, fontFamily: Fonts.mono }]}>
            14 DAYS FREE · CANCEL ANYTIME · NO CHARGE TODAY
          </Text>
        </View>
      </ScrollView>
    </View>
  );
}

// ── More hub ───────────────────────────────────────────────────

function MoreHub({
  C,
  Fonts,
  setScreen,
}: {
  C: any;
  Fonts: any;
  setScreen: (s: Screen) => void;
}) {
  const insets = useSafeAreaInsets();
  const profile = useAppStore((s) => s.profile);
  const workouts = useAppStore((s) => s.workouts);
  const computeStreak = useAppStore((s) => s.computeStreak);
  const setOnboardingComplete = useAppStore((s) => s.setOnboardingComplete);
  const [showSignOut, setShowSignOut] = useState(false);

  const name = profile?.name || 'Jay';
  const handle = profile?.handle || '@jaypump';
  const sz = 16;
  const ic = C.muted;

  return (
    <View style={[styles.screen, { backgroundColor: C.bg, paddingTop: insets.top }]}>
      <View style={[styles.header, { borderBottomColor: C.hair }]}>
        <Text style={[styles.headerTitle, { color: C.ink, fontFamily: Fonts.black }]}>MORE</Text>
      </View>

      <ScrollView style={{ flex: 1 }} showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingBottom: 32 }}>
        {/* Profile card */}
        <Pressable
          onPress={() => setScreen('profile')}
          style={[styles.profileCard, { backgroundColor: C.surf, borderColor: C.hair2 }]}
        >
          <View style={[styles.profileCardAvatar, { backgroundColor: C.surf2, borderColor: C.hair2 }]}>
            <Text style={[styles.profileCardLetter, { color: C.muted, fontFamily: Fonts.black }]}>
              {name[0].toUpperCase()}
            </Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={[styles.profileCardName, { color: C.ink, fontFamily: Fonts.bold }]}>{name}</Text>
            <Text style={[styles.profileCardHandle, { color: C.muted, fontFamily: Fonts.mono }]}>{handle}</Text>
            <View style={styles.profileCardStats}>
              <Text style={[styles.profileCardStatVal, { color: C.ink, fontFamily: Fonts.semiBold }]}>
                {workouts.length || 148}
              </Text>
              <Text style={[styles.profileCardStatLabel, { color: C.muted, fontFamily: Fonts.mono }]}>
                {' WORKOUTS'}
              </Text>
              <Text style={[styles.profileCardStatVal, { color: C.ink, fontFamily: Fonts.semiBold, marginLeft: 8 }]}>
                {computeStreak()}D
              </Text>
              <Text style={[styles.profileCardStatLabel, { color: C.muted, fontFamily: Fonts.mono }]}>
                {' STREAK'}
              </Text>
            </View>
          </View>
          <Text style={[styles.chevron, { color: C.faint }]}>›</Text>
        </Pressable>

        {/* Pulse+ banner */}
        <Pressable
          onPress={() => setScreen('pulse+')}
          style={[styles.plusBanner, { backgroundColor: C.accent }]}
        >
          <View style={[styles.plusBannerIcon, { backgroundColor: 'rgba(255,255,255,0.18)' }]}>
            <Svg width={18} height={18} viewBox="0 0 24 24" fill="none">
              <Polygon
                points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"
                stroke="#fff"
                strokeWidth={2}
                fill="none"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </Svg>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={[styles.plusBannerTitle, { fontFamily: Fonts.black }]}>UNLOCK PULSE+</Text>
            <Text style={[styles.plusBannerSub, { fontFamily: Fonts.mono }]}>
              SMART SUGGESTIONS · CLOUD SYNC · ANALYTICS
            </Text>
          </View>
          <Text style={[styles.chevron, { color: 'rgba(255,255,255,0.8)' }]}>›</Text>
        </Pressable>

        {/* Training section */}
        <SectionHeader title="TRAINING" C={C} />
        <NavRow
          C={C}
          label="History"
          sub="WORKOUTS · CALENDAR + LIST VIEW"
          onPress={() => setScreen('history')}
          icon={
            <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
              <Rect x={3} y={4} width={18} height={18} rx={2} stroke={ic} strokeWidth={1.8} />
              <Path d="M16 2v4M8 2v4M3 10h18M8 14h.01M12 14h.01M16 14h.01M8 18h.01M12 18h.01" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
            </Svg>
          }
        />
        <NavRow
          C={C}
          label="Equipment Profiles"
          sub="HOME GYM · COMMERCIAL GYM"
          onPress={() => setScreen('equipment')}
          icon={
            <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
              <Path d="M6.5 6.5h11M6.5 17.5h11M2 12h20M4 6.5v11M20 6.5v11" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
            </Svg>
          }
        />
        <NavRow
          C={C}
          label="Weekly Recap"
          sub="AVAILABLE EVERY MONDAY"
          icon={
            <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
              <Polyline points="22 12 18 12 15 21 9 3 6 12 2 12" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
            </Svg>
          }
        />

        {/* Account section */}
        <SectionHeader title="ACCOUNT" C={C} />
        <NavRow
          C={C}
          label="Profile"
          onPress={() => setScreen('profile')}
          icon={
            <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
              <Path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
              <Circle cx={12} cy={7} r={4} stroke={ic} strokeWidth={1.8} />
            </Svg>
          }
        />
        <NavRow
          C={C}
          label="Settings"
          onPress={() => setScreen('settings')}
          icon={
            <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
              <Circle cx={12} cy={12} r={3} stroke={ic} strokeWidth={1.8} />
              <Path d="M12 1v4M12 19v4M4.22 4.22l2.83 2.83M16.95 16.95l2.83 2.83M1 12h4M19 12h4M4.22 19.78l2.83-2.83M16.95 7.05l2.83-2.83" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
            </Svg>
          }
        />
        <NavRow
          C={C}
          label="Pulse+ Subscription"
          sub="FREE PLAN · UPGRADE"
          accent
          onPress={() => setScreen('pulse+')}
          icon={
            <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
              <Polygon
                points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"
                stroke={C.accent}
                strokeWidth={1.8}
                fill="none"
                strokeLinecap="round"
              />
            </Svg>
          }
        />

        {/* Help section */}
        <SectionHeader title="HELP" C={C} />
        <NavRow
          C={C}
          label="Tutorial"
          sub="REPLAY ONBOARDING WALKTHROUGH"
          icon={
            <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
              <Circle cx={12} cy={12} r={10} stroke={ic} strokeWidth={1.8} />
              <Path d="M9.09 9a3 3 0 015.83 1c0 2-3 3-3 3M12 17h.01" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
            </Svg>
          }
        />
        <NavRow
          C={C}
          label="Data Import"
          sub="IMPORT FROM STRONG · HEVY"
          icon={
            <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
              <Path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
              <Polyline points="7 10 12 15 17 10" stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
              <Line x1={12} y1={15} x2={12} y2={3} stroke={ic} strokeWidth={1.8} strokeLinecap="round" />
            </Svg>
          }
        />
        <NavRow
          C={C}
          label="Privacy Policy"
          icon={
            <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
              <Path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" stroke={ic} strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" />
            </Svg>
          }
        />
        <NavRow
          C={C}
          label="Sign Out"
          destructive
          chevron={false}
          onPress={() => setShowSignOut(true)}
          icon={
            <Svg width={sz} height={sz} viewBox="0 0 24 24" fill="none">
              <Path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9" stroke="#c0341a" strokeWidth={1.8} strokeLinecap="round" />
            </Svg>
          }
        />
      </ScrollView>

      <DestructiveModal
        C={C}
        Fonts={Fonts}
        visible={showSignOut}
        kicker="SIGN OUT"
        title="Sign out of Pump?"
        body="You'll need to sign back in to access your workouts and programs."
        consequences={['Your local data will be preserved', 'Sync will pause until you sign in']}
        cancelLabel="CANCEL"
        confirmLabel="SIGN OUT"
        onCancel={() => setShowSignOut(false)}
        onConfirm={() => {
          setShowSignOut(false);
          setOnboardingComplete(false);
        }}
      />
    </View>
  );
}

// ── Root export ────────────────────────────────────────────────

export default function MoreTab() {
  const { C, Fonts } = useTheme();
  const [screen, setScreen] = useState<Screen>('hub');

  if (screen === 'history') return <HistoryScreen C={C} Fonts={Fonts} onBack={() => setScreen('hub')} />;
  if (screen === 'profile') return <ProfileScreen C={C} Fonts={Fonts} onBack={() => setScreen('hub')} />;
  if (screen === 'settings') return <SettingsScreen C={C} Fonts={Fonts} onBack={() => setScreen('hub')} />;
  if (screen === 'equipment') return <EquipmentScreen C={C} Fonts={Fonts} onBack={() => setScreen('hub')} />;
  if (screen === 'pulse+') return <PulsePlusScreen C={C} Fonts={Fonts} onBack={() => setScreen('hub')} />;
  return <MoreHub C={C} Fonts={Fonts} setScreen={setScreen} />;
}

// ── Styles ─────────────────────────────────────────────────────

const styles = StyleSheet.create({
  screen: { flex: 1 },
  header: {
    paddingHorizontal: 16,
    paddingBottom: 10,
    paddingTop: 2,
    borderBottomWidth: 1,
  },
  headerTitle: { fontSize: 28, letterSpacing: 0.5 },
  subHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingBottom: 10,
    paddingTop: 2,
    borderBottomWidth: 1,
    gap: 10,
  },
  subTitle: { flex: 1, fontSize: 22, letterSpacing: 0.5 },
  backBtn: { width: 28, height: 28, alignItems: 'center', justifyContent: 'center' },
  backArrow: { fontSize: 26, lineHeight: 28 },
  editLink: { fontSize: 10, letterSpacing: 1 },
  sectionHeader: {
    fontSize: 9,
    letterSpacing: 1.5,
    paddingHorizontal: 16,
    paddingTop: 14,
    paddingBottom: 6,
  },
  navRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 16,
    paddingVertical: 13,
    borderBottomWidth: 1,
  },
  navIcon: {
    width: 32,
    height: 32,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  navLabel: { fontSize: 14 },
  navSub: { fontSize: 9, marginTop: 2, letterSpacing: 0.5 },
  badge: {
    height: 20,
    paddingHorizontal: 8,
    borderRadius: 4,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badgeText: { fontSize: 9, color: '#fff', letterSpacing: 0.5 },
  chevron: { fontSize: 18 },
  unitRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
  },
  unitRowContainer: {},
  unitLabel: { flex: 1, fontSize: 14 },
  unitPills: { flexDirection: 'row', gap: 6 },
  unitPill: {
    height: 30,
    paddingHorizontal: 12,
    borderRadius: 8,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  unitPillText: { fontSize: 10, letterSpacing: 0.8 },
  profileCard: {
    flexDirection: 'row',
    alignItems: 'center',
    margin: 12,
    padding: 14,
    borderRadius: 12,
    borderWidth: 1,
    gap: 12,
  },
  profileCardAvatar: {
    width: 52,
    height: 52,
    borderRadius: 14,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  profileCardLetter: { fontSize: 20 },
  profileCardName: { fontSize: 16 },
  profileCardHandle: { fontSize: 9, letterSpacing: 0.8, marginTop: 2 },
  profileCardStats: { flexDirection: 'row', alignItems: 'baseline', marginTop: 4 },
  profileCardStatVal: { fontSize: 14 },
  profileCardStatLabel: { fontSize: 8, letterSpacing: 0.5 },
  plusBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: 12,
    marginBottom: 12,
    padding: 14,
    paddingHorizontal: 16,
    borderRadius: 12,
    gap: 12,
  },
  plusBannerIcon: {
    width: 36,
    height: 36,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  plusBannerTitle: { fontSize: 18, color: '#fff', letterSpacing: 1.2 },
  plusBannerSub: { fontSize: 9, color: 'rgba(255,255,255,0.85)', marginTop: 2, letterSpacing: 0.5 },
  // History
  viewToggle: { flexDirection: 'row', borderRadius: 8, padding: 3, gap: 2 },
  viewToggleBtn: { height: 26, paddingHorizontal: 10, borderRadius: 6, alignItems: 'center', justifyContent: 'center' },
  viewToggleTxt: { fontSize: 14 },
  triRow: { flexDirection: 'row', borderBottomWidth: 1 },
  triCell: { flex: 1, paddingVertical: 10, alignItems: 'center' },
  triLabel: { fontSize: 8, letterSpacing: 1.2, marginBottom: 3 },
  triVal: { fontSize: 22 },
  histRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 16,
    paddingVertical: 11,
    borderBottomWidth: 1,
  },
  histDateBox: { width: 42, alignItems: 'center', flexShrink: 0 },
  histDow: { fontSize: 8, letterSpacing: 0.5 },
  histDayNum: { fontSize: 20, lineHeight: 22 },
  histMon: { fontSize: 7 },
  histName: { fontSize: 16, letterSpacing: 0.5 },
  histPRBadge: { fontSize: 8 },
  histMeta: { fontSize: 9, marginTop: 2 },
  calHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 },
  calArrow: { fontSize: 18 },
  calMonth: { fontSize: 18, letterSpacing: 0.5 },
  calWeekRow: { flexDirection: 'row', marginBottom: 6 },
  calWeekDay: { flex: 1, textAlign: 'center', fontSize: 9, letterSpacing: 0.8, paddingVertical: 4 },
  calGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 4 },
  calCell: {
    width: `${100 / 7 - 1}%` as any,
    aspectRatio: 1,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  calCellTxt: { fontSize: 11 },
  // Profile
  profHero: { flexDirection: 'row', alignItems: 'center', gap: 14, padding: 20, borderBottomWidth: 1 },
  profAvatar: { width: 66, height: 66, borderRadius: 18, borderWidth: 1, alignItems: 'center', justifyContent: 'center', flexShrink: 0 },
  profAvatarLetter: { fontSize: 26 },
  profName: { fontSize: 20 },
  profHandle: { fontSize: 10, letterSpacing: 0.8, marginTop: 2 },
  profMeta: { fontSize: 9, marginTop: 4 },
  programSection: { paddingHorizontal: 16, paddingBottom: 14, borderBottomWidth: 1 },
  programRow: { flexDirection: 'row', alignItems: 'center', gap: 10, marginTop: 8 },
  programName: { fontSize: 18, letterSpacing: 0.5 },
  programMeta: { fontSize: 9, marginTop: 2 },
  switchBtn: { height: 30, paddingHorizontal: 12, borderRadius: 8, borderWidth: 1, alignItems: 'center', justifyContent: 'center' },
  switchBtnTxt: { fontSize: 11, letterSpacing: 1 },
  prRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 10, borderBottomWidth: 1 },
  prName: { flex: 1, fontSize: 14 },
  prVal: { fontSize: 13 },
  statBodyRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 11, borderBottomWidth: 1 },
  statBodyLabel: { flex: 1, fontSize: 9, letterSpacing: 1 },
  statBodyVal: { fontSize: 14 },
  // Equipment
  equipTabs: { flexDirection: 'row', borderBottomWidth: 1 },
  equipTab: { flex: 1, paddingVertical: 12, alignItems: 'center' },
  equipTabTxt: { fontSize: 10, letterSpacing: 1 },
  activeBadgeRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    gap: 10,
  },
  activeBadge: {
    height: 26,
    paddingHorizontal: 10,
    borderRadius: 6,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  activeBadgeTxt: { fontSize: 9, letterSpacing: 0.8 },
  activateBtn: {
    height: 26,
    paddingHorizontal: 10,
    borderRadius: 6,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: 'auto',
  },
  activateBtnTxt: { fontSize: 9, letterSpacing: 0.8 },
  equipRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 13,
    gap: 10,
    borderBottomWidth: 1,
  },
  equipDot: { width: 7, height: 7, borderRadius: 4, flexShrink: 0 },
  equipName: { flex: 1, fontSize: 14 },
  equipQty: { fontSize: 11 },
  equipEdit: { width: 28, height: 28, alignItems: 'center', justifyContent: 'center' },
  addEquipBtn: {
    marginHorizontal: 16,
    marginTop: 10,
    height: 42,
    borderRadius: 10,
    borderWidth: 1,
    borderStyle: 'dashed',
    alignItems: 'center',
    justifyContent: 'center',
  },
  addEquipTxt: { fontSize: 10, letterSpacing: 1 },
  plateBar: {
    flexDirection: 'row',
    alignItems: 'center',
    height: 36,
    borderRadius: 10,
    borderWidth: 1,
    overflow: 'hidden',
    justifyContent: 'center',
  },
  plateBarSleeve: { width: 24, height: 14, borderRadius: 3 },
  plateBarPlate: { height: 32, borderRadius: 3, marginHorizontal: 1 },
  plateBarCenter: { flex: 1, height: 10, borderRadius: 3 },
  plateChips: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, paddingBottom: 16 },
  plateChip: {
    height: 28,
    paddingHorizontal: 12,
    borderRadius: 7,
    alignItems: 'center',
    justifyContent: 'center',
  },
  plateChipTxt: { fontSize: 10, color: '#fff', letterSpacing: 0.5 },
  // Pulse+
  plusHero: { alignItems: 'center', paddingVertical: 28, paddingHorizontal: 20, gap: 12 },
  plusHeroIcon: {
    width: 88,
    height: 88,
    borderRadius: 22,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  plusHeroTitle: { fontSize: 36, letterSpacing: 1.5 },
  trialBadge: {
    height: 28,
    paddingHorizontal: 14,
    borderRadius: 8,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  trialBadgeTxt: { fontSize: 10, letterSpacing: 1 },
  billingToggleRow: { paddingHorizontal: 16, marginBottom: 16 },
  billingToggle: { flexDirection: 'row', borderRadius: 10, padding: 4, gap: 2 },
  billingToggleBtn: { flex: 1, paddingVertical: 9, borderRadius: 8, alignItems: 'center' },
  billingToggleTxt: { fontSize: 10, letterSpacing: 0.8 },
  tierCards: { flexDirection: 'row', gap: 8, marginBottom: 8 },
  tierCard: {
    flex: 1,
    borderRadius: 12,
    padding: 12,
    alignItems: 'center',
    gap: 4,
    overflow: 'hidden',
  },
  tierBestBadge: {
    position: 'absolute',
    top: 0,
    right: 0,
    paddingHorizontal: 6,
    paddingVertical: 3,
    borderBottomLeftRadius: 8,
  },
  tierBestTxt: { fontSize: 7, color: '#fff', letterSpacing: 0.5 },
  tierName: { fontSize: 10, letterSpacing: 1, marginTop: 4 },
  tierPrice: { fontSize: 13 },
  featureRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    paddingVertical: 10,
    borderBottomWidth: 1,
    gap: 10,
  },
  featureCheck: { fontSize: 12, marginTop: 1 },
  featureTxt: { flex: 1, fontSize: 13, lineHeight: 18 },
  trialCTA: {
    height: 52,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  trialCTATxt: { color: '#fff', fontSize: 16, letterSpacing: 1.5 },
  trialDisclaimer: {
    textAlign: 'center',
    marginTop: 10,
    fontSize: 8,
    letterSpacing: 0.8,
  },
  // Destructive modal
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  destroyCard: {
    width: '100%',
    borderRadius: 16,
    overflow: 'hidden',
  },
  destroyStrip: {
    padding: 20,
    paddingBottom: 16,
  },
  destroyKicker: { fontSize: 9, color: 'rgba(255,255,255,0.85)', letterSpacing: 1.5, marginBottom: 6 },
  destroyTitle: { fontSize: 24, color: '#fff', letterSpacing: 0.5 },
  destroyBody: { fontSize: 14, lineHeight: 20, marginBottom: 14 },
  consequencesBox: {
    borderRadius: 10,
    borderWidth: 1,
    overflow: 'hidden',
    marginBottom: 16,
  },
  consequencesHeader: {
    fontSize: 8,
    letterSpacing: 1.5,
    padding: 10,
  },
  consequenceRow: { borderTopWidth: 1, padding: 10 },
  consequenceText: { fontSize: 13 },
  destroyBtns: { flexDirection: 'row', gap: 10 },
  destroyBtn: {
    flex: 1,
    height: 46,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  destroyBtnText: { fontSize: 13, letterSpacing: 0.8 },
});
