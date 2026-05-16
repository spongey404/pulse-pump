import React, { useRef, useState } from 'react';
import {
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { DestructiveModal, RenameModal, useToast } from '../../components/modals';
import { useTheme } from '../../hooks/useTheme';
import { useAppStore, WorkoutTemplate, TemplateDay, TemplateExercise } from '../../store/appStore';
import Svg, { Path, Rect, Polyline } from 'react-native-svg';

// ── Movement color dots ────────────────────────────────────────

const MOVEMENT_COLORS: Record<string, string> = {
  Push: '#c8553d',
  Pull: '#2c6da3',
  Hinge: '#c9892e',
  Squat: '#1f8f5a',
  Isolation: '#888',
  Legs: '#1f8f5a',
  Core: '#6432c8',
};

const PRESET_SPLITS = [
  { id: 'blank', name: 'Blank Program', desc: 'Start from scratch', days: null },
  { id: 'ppl', name: 'Push Pull Legs', desc: '6-day split. High frequency.', days: 6 },
  { id: 'ul', name: 'Upper Lower', desc: '4-day split. Balanced frequency.', days: 4 },
  { id: 'fb', name: 'Full Body', desc: '3-day split. Great for beginners.', days: 3 },
  { id: 'bro', name: 'Bro Split', desc: '5-day split. One muscle group per day.', days: 5 },
  { id: 'phul', name: 'PHUL', desc: '4-day Power Hypertrophy Upper Lower.', days: 4 },
];

// ── Exercise picker data ───────────────────────────────────────

const EXERCISE_LIST = [
  { id: 'e1', name: 'Bench Press', category: 'Push', muscleGroups: ['chest', 'triceps', 'shoulders'] },
  { id: 'e2', name: 'Squat', category: 'Squat', muscleGroups: ['quads', 'glutes', 'hamstrings'] },
  { id: 'e3', name: 'Deadlift', category: 'Hinge', muscleGroups: ['back', 'glutes', 'hamstrings'] },
  { id: 'e4', name: 'Overhead Press', category: 'Push', muscleGroups: ['shoulders', 'triceps'] },
  { id: 'e5', name: 'Pull-up', category: 'Pull', muscleGroups: ['back', 'biceps'] },
  { id: 'e6', name: 'Barbell Row', category: 'Pull', muscleGroups: ['back', 'biceps'] },
  { id: 'e7', name: 'Dumbbell Curl', category: 'Isolation', muscleGroups: ['biceps'] },
  { id: 'e8', name: 'Tricep Pushdown', category: 'Isolation', muscleGroups: ['triceps'] },
  { id: 'e9', name: 'Leg Press', category: 'Squat', muscleGroups: ['quads', 'glutes'] },
  { id: 'e10', name: 'Romanian Deadlift', category: 'Hinge', muscleGroups: ['hamstrings', 'glutes'] },
  { id: 'e11', name: 'Incline Dumbbell Press', category: 'Push', muscleGroups: ['chest', 'triceps'] },
  { id: 'e12', name: 'Lat Pulldown', category: 'Pull', muscleGroups: ['back', 'biceps'] },
  { id: 'e13', name: 'Cable Fly', category: 'Isolation', muscleGroups: ['chest'] },
  { id: 'e14', name: 'Face Pull', category: 'Pull', muscleGroups: ['shoulders', 'traps'] },
  { id: 'e15', name: 'Hip Thrust', category: 'Hinge', muscleGroups: ['glutes'] },
  { id: 'e16', name: 'Lateral Raise', category: 'Isolation', muscleGroups: ['shoulders'] },
  { id: 'e17', name: 'Dips', category: 'Push', muscleGroups: ['chest', 'triceps'] },
  { id: 'e18', name: 'Plank', category: 'Core', muscleGroups: ['core'] },
];

const MOVEMENT_FILTERS = ['All', 'Push', 'Pull', 'Hinge', 'Squat', 'Isolation'];

// ── Set type chip ──────────────────────────────────────────────

const SET_TYPE_COLORS: Record<string, { bg: string; text: string }> = {
  WU: { bg: 'rgba(180,140,60,0.13)', text: '#a17418' },
  STD: { bg: 'transparent', text: 'rgba(31,28,25,0.5)' },
  DROP: { bg: 'rgba(200,85,61,0.10)', text: '#a8442f' },
  AMRAP: { bg: 'rgba(44,109,163,0.10)', text: '#2c6da3' },
  SS: { bg: 'rgba(100,60,200,0.10)', text: '#6432c8' },
  RP: { bg: 'rgba(31,28,25,0.08)', text: '#3a342d' },
};

function SetTypeChip({ type, C }: { type: string; C: any }) {
  const tc = SET_TYPE_COLORS[type] || SET_TYPE_COLORS.STD;
  return (
    <View style={[styles.setTypeChip, { backgroundColor: tc.bg, borderColor: tc.text + '88' }]}>
      <Text style={[styles.setTypeChipText, { color: tc.text }]}>{type}</Text>
    </View>
  );
}

// ── Swipeable program row ──────────────────────────────────────

function ProgramRow({
  template,
  onSelect,
  onDelete,
  onRename,
}: {
  template: WorkoutTemplate;
  onSelect: () => void;
  onDelete: () => void;
  onRename: () => void;
}) {
  const { C } = useTheme();
  const [offset, setOffset] = useState(0);
  const startX = useRef<number | null>(null);
  const REVEAL = 80;

  return (
    <View style={[styles.programRowWrap, { borderBottomColor: C.hair }]}>
      {/* Delete reveal */}
      <Pressable
        onPress={onDelete}
        style={[styles.deleteReveal, { width: REVEAL }]}
      >
        <Svg width={18} height={18} viewBox="0 0 24 24" fill="none">
          <Polyline points="3 6 5 6 21 6" stroke="#fff" strokeWidth={2} strokeLinecap="round" />
          <Path d="M19 6l-1 14H6L5 6M10 11v6M14 11v6" stroke="#fff" strokeWidth={2} strokeLinecap="round" />
        </Svg>
      </Pressable>
      <Pressable
        onPress={() => { if (offset === 0) onSelect(); }}
        onLongPress={() => { if (offset === 0) onRename(); }}
        style={[
          styles.programRow,
          {
            backgroundColor: C.surf,
            transform: [{ translateX: offset }],
          },
        ]}
      >
        <View style={{ flex: 1 }}>
          <Text style={[styles.programRowName, { color: C.ink }]}>{template.name}</Text>
          <View style={styles.programRowMeta}>
            <Text style={[styles.programRowMetaText, { color: C.muted }]}>
              {template.days.length} DAYS
            </Text>
            <Text style={[styles.programRowMetaText, { color: C.muted }]}> · </Text>
            <Text style={[styles.programRowMetaText, { color: C.muted }]}>
              {template.days.reduce((acc, d) => acc + d.exercises.length, 0)} EXERCISES
            </Text>
          </View>
        </View>
        {/* Split day tiles */}
        <View style={styles.splitTiles}>
          {template.days.slice(0, 6).map((day, i) => (
            <View
              key={i}
              style={[
                styles.splitTile,
                { backgroundColor: C.accentSoft, borderColor: C.accent + '33' },
              ]}
            >
              <Text style={[styles.splitTileText, { color: C.accent }]}>
                {day.label[0].toUpperCase()}
              </Text>
            </View>
          ))}
        </View>
        <Text style={[styles.chevron, { color: C.faint }]}>›</Text>
      </Pressable>
    </View>
  );
}

// ── Exercise picker modal ──────────────────────────────────────

function ExercisePickerModal({
  visible,
  onClose,
  onAdd,
}: {
  visible: boolean;
  onClose: () => void;
  onAdd: (exercise: TemplateExercise) => void;
}) {
  const { C, Fonts } = useTheme();
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('All');

  const filtered = EXERCISE_LIST.filter((e) => {
    const matchSearch = e.name.toLowerCase().includes(search.toLowerCase());
    const matchFilter = filter === 'All' || e.category === filter;
    return matchSearch && matchFilter;
  });

  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet">
      <View style={[styles.pickerScreen, { backgroundColor: C.bg }]}>
        <View style={[styles.pickerHeader, { borderBottomColor: C.hair }]}>
          <Text style={[styles.pickerTitle, { color: C.ink }]}>ADD EXERCISE</Text>
          <Pressable onPress={onClose}>
            <Text style={[styles.pickerClose, { color: C.muted }]}>✕</Text>
          </Pressable>
        </View>
        <View style={[styles.searchBar, { backgroundColor: C.surf, borderColor: C.hair2 }]}>
          <Text style={[styles.searchIcon, { color: C.muted }]}>⌕</Text>
          <TextInput
            value={search}
            onChangeText={setSearch}
            placeholder="Search exercises…"
            placeholderTextColor={C.muted}
            style={[styles.searchInput, { color: C.ink, fontFamily: Fonts.regular }]}
          />
        </View>
        <ScrollView
          horizontal
          style={styles.filterScroll}
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.filterContent}
        >
          {MOVEMENT_FILTERS.map((f) => (
            <Pressable
              key={f}
              onPress={() => setFilter(f)}
              style={[
                styles.filterChip,
                {
                  backgroundColor: filter === f ? C.accent : C.surf,
                  borderColor: filter === f ? C.accent : C.hair2,
                },
              ]}
            >
              <Text
                style={[
                  styles.filterChipText,
                  { color: filter === f ? '#fff' : C.muted },
                ]}
              >
                {f.toUpperCase()}
              </Text>
            </Pressable>
          ))}
        </ScrollView>
        <ScrollView style={{ flex: 1 }} showsVerticalScrollIndicator={false}>
          {filtered.map((ex) => (
            <Pressable
              key={ex.id}
              onPress={() =>
                onAdd({
                  exerciseId: ex.id,
                  name: ex.name,
                  muscleGroups: ex.muscleGroups,
                  sets: [{ type: 'STD', targetReps: 8, rir: 2 }],
                })
              }
              style={[styles.exerciseRow, { borderBottomColor: C.hair }]}
            >
              <View
                style={[
                  styles.movementDot,
                  { backgroundColor: MOVEMENT_COLORS[ex.category] || C.muted },
                ]}
              />
              <View style={{ flex: 1 }}>
                <Text style={[styles.exerciseRowName, { color: C.ink }]}>{ex.name}</Text>
                <Text style={[styles.exerciseRowMeta, { color: C.muted }]}>
                  {ex.category.toUpperCase()} · {ex.muscleGroups.join(', ')}
                </Text>
              </View>
              <Text style={[styles.chevron, { color: C.faint }]}>+</Text>
            </Pressable>
          ))}
        </ScrollView>
      </View>
    </Modal>
  );
}

// ── Template detail screen ─────────────────────────────────────

function TemplateDetailScreen({
  template,
  onBack,
  onSave,
}: {
  template: WorkoutTemplate;
  onBack: () => void;
  onSave: (t: WorkoutTemplate) => void;
}) {
  const { C, Fonts } = useTheme();
  const insets = useSafeAreaInsets();
  const [t, setT] = useState(template);
  const [selDay, setSelDay] = useState(0);
  const [collapsed, setCollapsed] = useState<Set<string>>(new Set());
  const [showPicker, setShowPicker] = useState(false);

  const currentDay = t.days[selDay];

  const toggleCollapse = (exId: string) => {
    setCollapsed((prev) => {
      const next = new Set(prev);
      if (next.has(exId)) next.delete(exId);
      else next.add(exId);
      return next;
    });
  };

  const addExercise = (ex: TemplateExercise) => {
    setT((prev) => {
      const days = prev.days.map((d, i) =>
        i === selDay ? { ...d, exercises: [...d.exercises, ex] } : d
      );
      return { ...prev, days };
    });
    setShowPicker(false);
  };

  const addSet = (exIdx: number) => {
    setT((prev) => {
      const days = prev.days.map((d, i) => {
        if (i !== selDay) return d;
        const exercises = d.exercises.map((ex, ei) => {
          if (ei !== exIdx) return ex;
          return { ...ex, sets: [...ex.sets, { type: 'STD' as const, targetReps: 8, rir: 2 }] };
        });
        return { ...d, exercises };
      });
      return { ...prev, days };
    });
  };

  const removeExercise = (exIdx: number) => {
    setT((prev) => {
      const days = prev.days.map((d, i) => {
        if (i !== selDay) return d;
        return { ...d, exercises: d.exercises.filter((_, ei) => ei !== exIdx) };
      });
      return { ...prev, days };
    });
  };

  return (
    <View style={[styles.screen, { backgroundColor: C.bg, paddingTop: insets.top }]}>
      <View style={[styles.templateHeader, { borderBottomColor: C.hair }]}>
        <Pressable onPress={onBack} style={styles.backBtn}>
          <Text style={[styles.backBtnText, { color: C.muted }]}>‹</Text>
        </Pressable>
        <Text style={[styles.templateHeaderTitle, { color: C.ink }]}>{t.name.toUpperCase()}</Text>
        <Pressable
          onPress={() => onSave(t)}
          style={[styles.saveBtn, { backgroundColor: C.accent }]}
        >
          <Text style={styles.saveBtnText}>SAVE</Text>
        </Pressable>
      </View>

      {/* Day selector */}
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.daySelector}
        style={[styles.daySelectorWrap, { borderBottomColor: C.hair }]}
      >
        {t.days.map((d, i) => (
          <Pressable
            key={d.id}
            onPress={() => setSelDay(i)}
            style={[
              styles.dayPill,
              {
                backgroundColor: selDay === i ? C.ink : C.surf,
                borderColor: selDay === i ? C.ink : C.hair2,
              },
            ]}
          >
            <Text
              style={[
                styles.dayPillText,
                { color: selDay === i ? C.bg : C.muted },
              ]}
            >
              {d.label.toUpperCase()}
            </Text>
          </Pressable>
        ))}
      </ScrollView>

      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{ paddingBottom: 40 }}
        showsVerticalScrollIndicator={false}
      >
        {currentDay?.exercises.map((ex, exIdx) => {
          const isCollapsed = collapsed.has(`${selDay}-${exIdx}`);
          return (
            <View key={exIdx} style={[styles.exCard, { backgroundColor: C.surf, borderColor: C.hair2 }]}>
              <Pressable
                onPress={() => toggleCollapse(`${selDay}-${exIdx}`)}
                style={[styles.exCardHeader, { borderBottomColor: C.hair }]}
              >
                <View
                  style={[
                    styles.movementDot,
                    { backgroundColor: MOVEMENT_COLORS[ex.muscleGroups[0]] || C.muted },
                  ]}
                />
                <View style={{ flex: 1 }}>
                  <Text style={[styles.exCardName, { color: C.ink }]}>{ex.name}</Text>
                  <Text style={[styles.exCardMeta, { color: C.muted }]}>
                    {ex.sets.length} SETS · {ex.muscleGroups.join(', ')}
                  </Text>
                </View>
                <Pressable onPress={() => removeExercise(exIdx)} style={styles.removeBtn}>
                  <Text style={[styles.removeBtnText, { color: C.muted }]}>✕</Text>
                </Pressable>
                <Text style={[styles.collapseArrow, { color: C.muted }]}>
                  {isCollapsed ? '›' : '›'}
                </Text>
              </Pressable>
              {!isCollapsed && (
                <>
                  {/* Set header */}
                  <View style={[styles.setRowHeader, { borderBottomColor: C.hair }]}>
                    {['TYPE', '#', 'REPS', 'RIR'].map((h, i) => (
                      <Text key={i} style={[styles.setHeaderCell, { color: C.muted }]}>
                        {h}
                      </Text>
                    ))}
                  </View>
                  {ex.sets.map((s, si) => (
                    <View key={si} style={[styles.setRow, { borderBottomColor: C.hair }]}>
                      <SetTypeChip type={s.type} C={C} />
                      <Text style={[styles.setNum, { color: C.muted }]}>{si + 1}</Text>
                      <Text style={[styles.setVal, { color: C.ink, fontFamily: Fonts.mono }]}>
                        {s.targetReps ?? '—'}
                      </Text>
                      <Text style={[styles.setVal, { color: C.muted, fontFamily: Fonts.mono }]}>
                        {s.rir ?? '—'}
                      </Text>
                    </View>
                  ))}
                  <Pressable
                    onPress={() => addSet(exIdx)}
                    style={[styles.addSetBtn, { borderColor: C.faint }]}
                  >
                    <Text style={[styles.addSetBtnText, { color: C.muted }]}>+ ADD SET</Text>
                  </Pressable>
                </>
              )}
            </View>
          );
        })}

        <Pressable
          onPress={() => setShowPicker(true)}
          style={[styles.addExBtn, { borderColor: C.faint }]}
        >
          <Text style={[styles.addExBtnText, { color: C.muted }]}>+ ADD EXERCISE</Text>
        </Pressable>
      </ScrollView>

      <ExercisePickerModal
        visible={showPicker}
        onClose={() => setShowPicker(false)}
        onAdd={addExercise}
      />
    </View>
  );
}

// ── New program sheet ──────────────────────────────────────────

function NewProgramModal({
  visible,
  onClose,
  onCreate,
}: {
  visible: boolean;
  onClose: () => void;
  onCreate: (t: WorkoutTemplate) => void;
}) {
  const { C, Fonts } = useTheme();
  const [name, setName] = useState('');
  const [days, setDays] = useState(4);
  const [preset, setPreset] = useState<string | null>(null);

  const create = () => {
    if (!name.trim()) return;
    const dayLabels =
      preset === 'ppl'
        ? ['Push', 'Pull', 'Legs', 'Push', 'Pull', 'Legs']
        : preset === 'ul'
        ? ['Upper', 'Lower', 'Upper', 'Lower']
        : preset === 'fb'
        ? ['Full Body A', 'Full Body B', 'Full Body C']
        : Array.from({ length: days }, (_, i) => `Day ${i + 1}`);

    const template: WorkoutTemplate = {
      id: Date.now().toString(),
      name: name.trim(),
      splitType: preset || 'custom',
      createdAt: Date.now(),
      days: dayLabels.map((label, i) => ({
        id: `d${i}`,
        label,
        exercises: [],
      })),
    };
    onCreate(template);
    setName('');
    setDays(4);
    setPreset(null);
  };

  return (
    <Modal visible={visible} animationType="slide" presentationStyle="pageSheet">
      <View style={[styles.pickerScreen, { backgroundColor: C.bg }]}>
        <View style={[styles.pickerHeader, { borderBottomColor: C.hair }]}>
          <Text style={[styles.pickerTitle, { color: C.ink }]}>NEW PROGRAM</Text>
          <Pressable onPress={onClose}>
            <Text style={[styles.pickerClose, { color: C.muted }]}>✕</Text>
          </Pressable>
        </View>
        <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 16, gap: 20 }}>
          <View>
            <Text style={[styles.fieldLabel, { color: C.muted }]}>PROGRAM NAME</Text>
            <TextInput
              value={name}
              onChangeText={setName}
              placeholder="e.g. Push Pull Legs"
              placeholderTextColor={C.faint}
              style={[
                styles.fieldInput,
                {
                  color: C.ink,
                  backgroundColor: C.surf,
                  borderColor: name ? C.accent : C.hair2,
                  fontFamily: Fonts.bold,
                },
              ]}
            />
          </View>

          <View>
            <Text style={[styles.fieldLabel, { color: C.muted }]}>DAYS PER WEEK</Text>
            <View style={styles.daysGrid}>
              {[1, 2, 3, 4, 5, 6, 7].map((d) => (
                <Pressable
                  key={d}
                  onPress={() => { setDays(d); setPreset(null); }}
                  style={[
                    styles.dayTile,
                    {
                      backgroundColor: days === d && !preset ? C.ink : C.surf,
                      borderColor: days === d && !preset ? C.ink : C.hair2,
                    },
                  ]}
                >
                  <Text
                    style={[
                      styles.dayTileText,
                      { color: days === d && !preset ? C.bg : C.muted, fontFamily: Fonts.mono },
                    ]}
                  >
                    {d}
                  </Text>
                </Pressable>
              ))}
            </View>
          </View>

          <View>
            <Text style={[styles.fieldLabel, { color: C.muted }]}>START FROM TEMPLATE</Text>
            {PRESET_SPLITS.map((p) => (
              <Pressable
                key={p.id}
                onPress={() => { setPreset(p.id); if (p.days) setDays(p.days); }}
                style={[
                  styles.presetRow,
                  {
                    backgroundColor: preset === p.id ? C.accentSoft : C.surf,
                    borderColor: preset === p.id ? C.accent : C.hair2,
                  },
                ]}
              >
                <View style={{ flex: 1 }}>
                  <Text style={[styles.presetName, { color: preset === p.id ? C.accent : C.ink }]}>
                    {p.name}
                  </Text>
                  <Text style={[styles.presetDesc, { color: C.muted }]}>{p.desc}</Text>
                </View>
                {p.days && (
                  <Text style={[styles.presetDays, { color: C.muted, fontFamily: Fonts.mono }]}>
                    {p.days}D
                  </Text>
                )}
              </Pressable>
            ))}
          </View>
        </ScrollView>
        <View style={{ padding: 16, paddingBottom: 32 }}>
          <Pressable
            onPress={create}
            style={[
              styles.createBtn,
              { backgroundColor: name.trim() ? C.accent : C.surf },
            ]}
            disabled={!name.trim()}
          >
            <Text style={[styles.createBtnText, { color: name.trim() ? '#fff' : C.muted }]}>
              CREATE PROGRAM
            </Text>
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

// ── Main Programs screen ───────────────────────────────────────

export default function ProgramsScreen() {
  const { C, Fonts } = useTheme();
  const insets = useSafeAreaInsets();
  const templates = useAppStore((s) => s.templates);
  const addTemplate = useAppStore((s) => s.addTemplate);
  const updateTemplate = useAppStore((s) => s.updateTemplate);
  const deleteTemplate = useAppStore((s) => s.deleteTemplate);
  const { addToast } = useToast();

  const [selectedTemplate, setSelectedTemplate] = useState<WorkoutTemplate | null>(null);
  const [showNewModal, setShowNewModal] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<WorkoutTemplate | null>(null);
  const [renameTarget, setRenameTarget] = useState<WorkoutTemplate | null>(null);

  if (selectedTemplate) {
    return (
      <TemplateDetailScreen
        template={selectedTemplate}
        onBack={() => setSelectedTemplate(null)}
        onSave={(t) => {
          updateTemplate(t);
          setSelectedTemplate(null);
        }}
      />
    );
  }

  return (
    <View style={[styles.screen, { backgroundColor: C.bg, paddingTop: insets.top }]}>
      <View style={[styles.header, { borderBottomColor: C.hair }]}>
        <Text style={[styles.headerTitle, { color: C.ink }]}>PROGRAMS</Text>
        <Pressable
          onPress={() => setShowNewModal(true)}
          style={[styles.addBtn, { backgroundColor: C.accent }]}
        >
          <Text style={styles.addBtnText}>+</Text>
        </Pressable>
      </View>

      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{ paddingBottom: 20 }}
        showsVerticalScrollIndicator={false}
      >
        {templates.length === 0 ? (
          <View style={styles.emptyState}>
            <Text style={[styles.emptyTitle, { color: C.muted }]}>NO PROGRAMS YET</Text>
            <Text style={[styles.emptySub, { color: C.faint }]}>
              Create your first program to get started
            </Text>
            <Pressable
              onPress={() => setShowNewModal(true)}
              style={[styles.emptyBtn, { backgroundColor: C.accent }]}
            >
              <Text style={styles.emptyBtnText}>CREATE PROGRAM</Text>
            </Pressable>
          </View>
        ) : (
          templates.map((t) => (
            <ProgramRow
              key={t.id}
              template={t}
              onSelect={() => setSelectedTemplate(t)}
              onDelete={() => setDeleteTarget(t)}
              onRename={() => setRenameTarget(t)}
            />
          ))
        )}

        <Pressable
          onPress={() => setShowNewModal(true)}
          style={[styles.newProgramBtn, { borderColor: C.faint }]}
        >
          <Text style={[styles.newProgramBtnText, { color: C.muted }]}>+ NEW PROGRAM</Text>
        </Pressable>

        <View style={{ paddingHorizontal: 16, paddingTop: 16 }}>
          <Text style={[styles.quickStartLabel, { color: C.muted }]}>QUICK START</Text>
          <Text style={[styles.quickStartSub, { color: C.muted }]}>
            Repeat a recent session in one tap
          </Text>
          {[
            { name: 'Push Day', tag: 'PPL', time: '2 days ago' },
            { name: 'Pull Day', tag: 'PPL', time: '4 days ago' },
          ].map((w, i) => (
            <View
              key={i}
              style={[styles.quickStartRow, { borderTopColor: C.hair }]}
            >
              <View style={{ flex: 1 }}>
                <Text style={[styles.quickStartName, { color: C.ink }]}>{w.name}</Text>
                <Text style={[styles.quickStartMeta, { color: C.muted }]}>
                  {w.tag} · {w.time}
                </Text>
              </View>
              <Pressable
                style={[styles.quickStartBtn, { backgroundColor: C.accentSoft, borderColor: C.accent + '44' }]}
              >
                <Text style={[styles.quickStartBtnText, { color: C.accent }]}>START</Text>
              </Pressable>
            </View>
          ))}
        </View>
      </ScrollView>

      <NewProgramModal
        visible={showNewModal}
        onClose={() => setShowNewModal(false)}
        onCreate={(t) => {
          addTemplate(t);
          setShowNewModal(false);
          setSelectedTemplate(t);
        }}
      />

      <DestructiveModal
        C={C}
        visible={!!deleteTarget}
        kicker="DESTRUCTIVE ACTION"
        title={`Delete "${deleteTarget?.name}"?`}
        body="This program and all its exercises will be permanently removed. This cannot be undone."
        consequences={[{ value: deleteTarget?.days?.reduce((a, d) => a + d.exercises.length, 0)?.toString() ?? '0', label: 'exercises removed' }]}
        cancelLabel="CANCEL"
        confirmLabel="DELETE PROGRAM"
        onCancel={() => setDeleteTarget(null)}
        onConfirm={() => {
          if (deleteTarget) deleteTemplate(deleteTarget.id);
          setDeleteTarget(null);
          addToast({ kind: 'info', kicker: 'DELETED', title: 'Program removed' });
        }}
      />

      <RenameModal
        C={C}
        visible={!!renameTarget}
        kicker="RENAME PROGRAM"
        title="What should we call it?"
        currentValue={renameTarget?.name ?? ''}
        label="PROGRAM NAME"
        confirmLabel="SAVE"
        onCancel={() => setRenameTarget(null)}
        onConfirm={(name) => {
          if (renameTarget) updateTemplate({ ...renameTarget, name });
          setRenameTarget(null);
          addToast({ kind: 'success', kicker: 'RENAMED', title: 'Program updated' });
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingBottom: 10,
    paddingTop: 2,
    borderBottomWidth: 1,
  },
  headerTitle: { fontFamily: 'Archivo-Black', fontSize: 28, letterSpacing: 0.5 },
  addBtn: { width: 34, height: 34, borderRadius: 10, alignItems: 'center', justifyContent: 'center' },
  addBtnText: { fontFamily: 'Archivo-Bold', fontSize: 20, color: '#fff', lineHeight: 22 },
  programRowWrap: { position: 'relative', overflow: 'hidden', borderBottomWidth: 1 },
  deleteReveal: {
    position: 'absolute',
    right: 0,
    top: 0,
    bottom: 0,
    backgroundColor: '#c0341a',
    alignItems: 'center',
    justifyContent: 'center',
  },
  programRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 14,
    paddingHorizontal: 16,
    gap: 12,
  },
  programRowName: { fontFamily: 'Archivo-SemiBold', fontSize: 18, letterSpacing: 0.2 },
  programRowMeta: { flexDirection: 'row', marginTop: 3 },
  programRowMetaText: { fontFamily: 'SpaceMono-Regular', fontSize: 9 },
  splitTiles: { flexDirection: 'row', gap: 3 },
  splitTile: {
    width: 22,
    height: 22,
    borderRadius: 4,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  splitTileText: { fontFamily: 'SpaceMono-Bold', fontSize: 7 },
  chevron: { fontFamily: 'Archivo-Regular', fontSize: 16 },
  emptyState: { padding: 40, alignItems: 'center', gap: 12 },
  emptyTitle: { fontFamily: 'SpaceMono-Bold', fontSize: 11, letterSpacing: 1.5 },
  emptySub: { fontFamily: 'Archivo-Regular', fontSize: 13, textAlign: 'center' },
  emptyBtn: { height: 44, paddingHorizontal: 24, borderRadius: 10, alignItems: 'center', justifyContent: 'center', marginTop: 8 },
  emptyBtnText: { fontFamily: 'Archivo-Black', fontSize: 13, letterSpacing: 1.5, color: '#fff' },
  newProgramBtn: {
    margin: 16,
    height: 52,
    borderRadius: 10,
    borderWidth: 1,
    borderStyle: 'dashed',
    alignItems: 'center',
    justifyContent: 'center',
  },
  newProgramBtnText: { fontFamily: 'SpaceMono-Regular', fontSize: 10, letterSpacing: 1 },
  quickStartLabel: { fontFamily: 'SpaceMono-Regular', fontSize: 9, letterSpacing: 1.3, marginBottom: 4 },
  quickStartSub: { fontFamily: 'Archivo-Regular', fontSize: 11, marginBottom: 10, lineHeight: 16 },
  quickStartRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingVertical: 10,
    borderTopWidth: 1,
  },
  quickStartName: { fontFamily: 'Archivo-SemiBold', fontSize: 14, letterSpacing: 0.2 },
  quickStartMeta: { fontFamily: 'SpaceMono-Regular', fontSize: 9, marginTop: 1 },
  quickStartBtn: {
    height: 32,
    paddingHorizontal: 14,
    borderRadius: 8,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  quickStartBtnText: { fontFamily: 'Archivo-Regular', fontSize: 14, letterSpacing: 1 },
  // Template detail
  templateHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingBottom: 10,
    paddingTop: 2,
    borderBottomWidth: 1,
    gap: 10,
  },
  templateHeaderTitle: { flex: 1, fontFamily: 'Archivo-Black', fontSize: 20, letterSpacing: 0.5 },
  backBtn: { width: 32, height: 32, alignItems: 'center', justifyContent: 'center' },
  backBtnText: { fontFamily: 'Archivo-Regular', fontSize: 24 },
  saveBtn: { height: 30, paddingHorizontal: 14, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
  saveBtnText: { fontFamily: 'Archivo-Black', fontSize: 12, letterSpacing: 1.5, color: '#fff' },
  daySelectorWrap: { borderBottomWidth: 1, maxHeight: 52 },
  daySelector: { paddingHorizontal: 12, paddingVertical: 10, gap: 8, alignItems: 'center' },
  dayPill: {
    height: 32,
    paddingHorizontal: 14,
    borderRadius: 999,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  dayPillText: { fontFamily: 'SpaceMono-Regular', fontSize: 9, letterSpacing: 0.8 },
  exCard: {
    margin: 12,
    marginBottom: 0,
    borderRadius: 14,
    borderWidth: 1,
    overflow: 'hidden',
  },
  exCardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    borderBottomWidth: 1,
    gap: 10,
  },
  exCardName: { fontFamily: 'Archivo-SemiBold', fontSize: 14 },
  exCardMeta: { fontFamily: 'SpaceMono-Regular', fontSize: 9, marginTop: 1 },
  movementDot: { width: 8, height: 8, borderRadius: 4, flexShrink: 0 },
  removeBtn: { padding: 4 },
  removeBtnText: { fontFamily: 'Archivo-Regular', fontSize: 16 },
  collapseArrow: { fontFamily: 'Archivo-Regular', fontSize: 16 },
  setRowHeader: {
    flexDirection: 'row',
    paddingHorizontal: 12,
    paddingVertical: 5,
    borderBottomWidth: 1,
    gap: 8,
  },
  setHeaderCell: { fontFamily: 'SpaceMono-Regular', fontSize: 8, letterSpacing: 1, flex: 1 },
  setRow: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 12, paddingVertical: 8, borderBottomWidth: 1, gap: 8 },
  setNum: { fontFamily: 'SpaceMono-Regular', fontSize: 11, width: 20, textAlign: 'center' },
  setVal: { fontSize: 12, flex: 1 },
  setTypeChip: {
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 4,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  setTypeChipText: { fontFamily: 'SpaceMono-Bold', fontSize: 8, letterSpacing: 0.5 },
  addSetBtn: {
    margin: 10,
    height: 36,
    borderRadius: 8,
    borderWidth: 1,
    borderStyle: 'dashed',
    alignItems: 'center',
    justifyContent: 'center',
  },
  addSetBtnText: { fontFamily: 'SpaceMono-Regular', fontSize: 9, letterSpacing: 1 },
  addExBtn: {
    margin: 16,
    marginTop: 12,
    height: 48,
    borderRadius: 10,
    borderWidth: 1,
    borderStyle: 'dashed',
    alignItems: 'center',
    justifyContent: 'center',
  },
  addExBtnText: { fontFamily: 'SpaceMono-Regular', fontSize: 10, letterSpacing: 1 },
  // Picker
  pickerScreen: { flex: 1 },
  pickerHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 16,
    borderBottomWidth: 1,
  },
  pickerTitle: { fontFamily: 'Archivo-Black', fontSize: 20, letterSpacing: 0.5 },
  pickerClose: { fontFamily: 'Archivo-Regular', fontSize: 20 },
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    marginHorizontal: 16,
    marginTop: 12,
    marginBottom: 8,
    height: 40,
    borderRadius: 10,
    borderWidth: 1,
    paddingHorizontal: 12,
    gap: 8,
  },
  searchIcon: { fontSize: 16 },
  searchInput: { flex: 1, fontSize: 14, height: 40 },
  filterScroll: { maxHeight: 44 },
  filterContent: { paddingHorizontal: 16, gap: 8, paddingVertical: 8, alignItems: 'center' },
  filterChip: {
    height: 28,
    paddingHorizontal: 10,
    borderRadius: 6,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  filterChipText: { fontFamily: 'SpaceMono-Bold', fontSize: 8, letterSpacing: 0.5 },
  exerciseRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderBottomWidth: 1,
    gap: 12,
  },
  exerciseRowName: { fontFamily: 'Archivo-Medium', fontSize: 14 },
  exerciseRowMeta: { fontFamily: 'SpaceMono-Regular', fontSize: 9, marginTop: 2 },
  // New program
  fieldLabel: { fontFamily: 'SpaceMono-Regular', fontSize: 9, letterSpacing: 1.5, marginBottom: 8 },
  fieldInput: {
    height: 52,
    borderRadius: 12,
    borderWidth: 1,
    paddingHorizontal: 16,
    fontSize: 18,
  },
  daysGrid: { flexDirection: 'row', gap: 8, flexWrap: 'wrap' },
  dayTile: {
    width: 44,
    height: 44,
    borderRadius: 8,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  dayTileText: { fontSize: 16 },
  presetRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    paddingHorizontal: 14,
    borderRadius: 10,
    borderWidth: 1,
    marginBottom: 8,
  },
  presetName: { fontFamily: 'Archivo-SemiBold', fontSize: 14 },
  presetDesc: { fontFamily: 'Archivo-Regular', fontSize: 11, marginTop: 2, lineHeight: 16 },
  presetDays: { fontSize: 12 },
  createBtn: {
    height: 52,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  createBtnText: { fontFamily: 'Archivo-Black', fontSize: 15, letterSpacing: 2 },
});
