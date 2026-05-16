import React, { useRef, useState } from 'react';
import {
  Animated,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { ActionSheet } from '../../components/modals';
import { useTheme } from '../../hooks/useTheme';
import Svg, { Path, Circle } from 'react-native-svg';

const SAMPLE_POSTS: Array<{
  id: string; username: string; handle: string; workout: string; duration: string;
  time: string; sets: number; volume: string; improved: string; likes: number;
  comments: number; exercises: string[]; prs: string[]; heat: Record<string, number>;
}> = [
  {
    id: '1',
    username: 'Marcus',
    handle: '@marcuspump',
    workout: 'Pull Day',
    duration: '52:10',
    time: '2h ago',
    sets: 26,
    volume: '4,820 kg',
    improved: '5/6',
    likes: 12,
    comments: 4,
    exercises: ['Barbell Row', 'Pull-up', 'Lat Pulldown', 'Dumbbell Curl', 'Face Pull'],
    prs: ['Barbell Row: 100kg×5'],
    heat: { back: 1.0, biceps: 0.7, traps: 0.5, shoulders: 0.3 },
  },
  {
    id: '2',
    username: 'Priya',
    handle: '@priyalifts',
    workout: 'Legs',
    duration: '61:30',
    time: '5h ago',
    sets: 28,
    volume: '5,200 kg',
    improved: '4/5',
    likes: 8,
    comments: 2,
    exercises: ['Squat', 'Romanian Deadlift', 'Leg Press', 'Hip Thrust', 'Calf Raise'],
    prs: [],
    heat: { quads: 1.0, glutes: 0.9, hamstrings: 0.7, calves: 0.5 },
  },
];

const REACTS = ['❤️', '💪', '🔥', '👊', '🏆', '😤'];

// ── Thermal color function ─────────────────────────────────────

function thermal(t: number): string {
  const stops: Array<[number, [number, number, number]]> = [
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
  return 'rgb(192,72,60)';
}

// ── Body silhouette SVG ────────────────────────────────────────

function BodySilhouette({ heat, size = 72 }: { heat: Record<string, number>; size?: number }) {
  const h = size * 1.6;
  const c = (id: string) =>
    heat[id] !== undefined ? thermal(heat[id]) : 'rgba(80,60,40,0.06)';

  return (
    <Svg width={size} height={h} viewBox="0 0 200 320">
      <Circle cx={100} cy={22} r={14} fill="rgba(80,60,40,0.06)" />
      <Path d="M75 46 L100 42 L125 46 L120 56 L100 52 L80 56 Z" fill={c('traps')} />
      <Path d="M70 56 Q100 48 130 56 L132 96 Q100 102 68 96 Z" fill={c('chest')} />
      <Path d="M55 60 Q48 70 50 90 L66 92 Q70 76 70 56 Z" fill={c('shoulders')} />
      <Path d="M145 60 Q152 70 150 90 L134 92 Q130 76 130 56 Z" fill={c('shoulders')} />
      <Path d="M40 90 Q34 110 36 130 L52 130 Q54 110 50 90 Z" fill={c('biceps')} />
      <Path d="M160 90 Q166 110 164 130 L148 130 Q146 110 150 90 Z" fill={c('biceps')} />
      <Path d="M75 96 Q100 100 125 96 L122 138 Q100 142 78 138 Z" fill={c('core')} />
      <Path d="M76 158 Q72 200 76 230 L98 230 Q100 200 98 158 Z" fill={c('quads')} />
      <Path d="M124 158 Q128 200 124 230 L102 230 Q100 200 102 158 Z" fill={c('quads')} />
      <Path d="M80 234 Q76 260 80 286 L96 286 Q98 260 96 234 Z" fill={c('calves')} />
      <Path d="M120 234 Q124 260 120 286 L104 286 Q102 260 104 234 Z" fill={c('calves')} />
    </Svg>
  );
}

// ── React picker ───────────────────────────────────────────────

function ReactPicker({
  onPick,
  onClose,
}: {
  onPick: (r: string) => void;
  onClose: () => void;
}) {
  const { C } = useTheme();
  return (
    <View style={[styles.reactPickerWrap, { backgroundColor: C.bg, borderColor: C.hair2 }]}>
      {REACTS.map((r, i) => (
        <Pressable
          key={i}
          onPress={() => { onPick(r); onClose(); }}
          style={styles.reactPickerItem}
        >
          <Text style={styles.reactPickerEmoji}>{r}</Text>
        </Pressable>
      ))}
    </View>
  );
}

// ── Feed post card ─────────────────────────────────────────────

function FeedPostCard({ post, onOpenComments }: { post: typeof SAMPLE_POSTS[0]; onOpenComments: () => void }) {
  const { C, Fonts } = useTheme();
  const [reaction, setReaction] = useState<string | null>(null);
  const [showPicker, setShowPicker] = useState(false);
  const [showMenu, setShowMenu] = useState(false);
  const holdRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [likes, setLikes] = useState(post.likes);

  const startHold = () => {
    holdRef.current = setTimeout(() => setShowPicker(true), 400);
  };
  const endHold = () => {
    if (holdRef.current) clearTimeout(holdRef.current);
  };
  const tapLike = () => {
    if (showPicker) return;
    if (reaction) {
      setReaction(null);
      setLikes((l) => l - 1);
    } else {
      setReaction('❤️');
      setLikes((l) => l + 1);
    }
  };

  return (
    <View style={[styles.postCard, { backgroundColor: C.bg, borderBottomColor: C.divider }]}>
      {/* Header */}
      <View style={styles.postHeader}>
        <View style={[styles.postAvatar, { backgroundColor: C.surf2, borderColor: C.hair2 }]}>
          <Text style={[styles.postAvatarText, { color: C.muted }]}>{post.username[0]}</Text>
        </View>
        <View style={{ flex: 1 }}>
          <Text style={[styles.postUsername, { color: C.ink }]}>{post.username}</Text>
          <Text style={[styles.postHandle, { color: C.muted }]}>
            {post.handle} · {post.time}
          </Text>
        </View>
        <Pressable onPress={() => setShowMenu(true)}>
          <Text style={[styles.postMenu, { color: C.muted }]}>···</Text>
        </Pressable>
      </View>

      <ActionSheet
        C={C}
        visible={showMenu}
        title={post.username}
        items={[
          { label: 'View Full Post' },
          { label: 'Save Post' },
          { label: 'Copy Link' },
          { label: 'Report', danger: true },
        ]}
        cancelLabel="CANCEL"
        onCancel={() => setShowMenu(false)}
        onItemPress={() => setShowMenu(false)}
      />

      {/* Session info */}
      <View style={styles.postSession}>
        <Text style={[styles.postWorkoutName, { color: C.ink }]}>{post.workout.toUpperCase()}</Text>
        <Text style={[styles.postDuration, { color: C.muted }]}>{post.duration}</Text>
      </View>

      {/* Body map + stats */}
      <View style={[styles.postBody, { backgroundColor: C.surf, borderColor: C.hair2 }]}>
        <BodySilhouette heat={post.heat} size={56} />
        <View style={styles.postStats}>
          {[
            { l: 'SETS', v: String(post.sets) },
            { l: 'VOL', v: post.volume },
            { l: 'IMPR', v: post.improved },
          ].map((s, i) => (
            <View key={i} style={styles.postStatCell}>
              <Text style={[styles.postStatLabel, { color: C.muted }]}>{s.l}</Text>
              <Text style={[styles.postStatVal, { color: C.ink, fontFamily: Fonts.mono }]}>{s.v}</Text>
            </View>
          ))}
        </View>
        {post.prs.length > 0 && (
          <View style={[styles.prBadge, { backgroundColor: C.prSoft }]}>
            <Text style={[styles.prBadgeText, { color: C.pr }]}>★ PR</Text>
          </View>
        )}
      </View>

      {/* Exercises */}
      <View style={styles.postExercises}>
        {post.exercises.slice(0, 3).map((e, i) => (
          <View key={i} style={[styles.exChip, { backgroundColor: C.surf2 }]}>
            <Text style={[styles.exChipText, { color: C.muted }]}>{e.toUpperCase()}</Text>
          </View>
        ))}
        {post.exercises.length > 3 && (
          <Text style={[styles.exMore, { color: C.faint }]}>
            +{post.exercises.length - 3} MORE
          </Text>
        )}
      </View>

      {/* React row */}
      <View style={styles.postReactRow}>
        {showPicker && (
          <ReactPicker
            onPick={(r) => { setReaction(r); setLikes((l) => l + 1); }}
            onClose={() => setShowPicker(false)}
          />
        )}
        <Pressable
          onPress={tapLike}
          onLongPress={() => setShowPicker(true)}
          delayLongPress={400}
          style={[
            styles.reactBtn,
            {
              borderColor: reaction ? C.accent + '88' : C.hair2,
              backgroundColor: reaction ? C.accentSoft : 'transparent',
            },
          ]}
        >
          <Text style={styles.reactEmoji}>{reaction ?? '♡'}</Text>
          <Text style={[styles.reactCount, { color: reaction ? C.accent : C.muted, fontFamily: Fonts.mono }]}>
            {likes}
          </Text>
          <Text style={[styles.holdHint, { color: C.faint }]}>HOLD</Text>
        </Pressable>
        <Pressable
          onPress={onOpenComments}
          style={[styles.reactBtn, { borderColor: C.hair2, backgroundColor: 'transparent' }]}
        >
          <Svg width={14} height={14} viewBox="0 0 24 24" fill="none">
            <Path
              d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"
              stroke={C.muted}
              strokeWidth={2}
              strokeLinecap="round"
            />
          </Svg>
          <Text style={[styles.reactCount, { color: C.muted, fontFamily: Fonts.mono }]}>
            {post.comments}
          </Text>
        </Pressable>
      </View>
    </View>
  );
}

// ── Comments modal ─────────────────────────────────────────────

const SAMPLE_COMMENTS = [
  { user: 'Marcus', text: 'That bench! Been watching this number creep up for weeks.', time: '2h' },
  { user: 'Priya', text: 'Form check vid next time?', time: '3h' },
  { user: 'Alex', text: '105 is insane. What program are you running?', time: '5h' },
];

function CommentsModal({ visible, onClose }: { visible: boolean; onClose: () => void }) {
  const { C, Fonts } = useTheme();
  const insets = useSafeAreaInsets();
  const [text, setText] = useState('');

  return (
    <Modal visible={visible} transparent animationType="slide">
      <View style={styles.commentsOverlay}>
        <Pressable style={styles.commentsBg} onPress={onClose} />
        <View style={[styles.commentsSheet, { backgroundColor: C.bg, borderColor: C.hair2, paddingBottom: insets.bottom + 8 }]}>
          <View style={styles.commentsHandle}>
            <View style={[styles.handleBar, { backgroundColor: C.faint }]} />
          </View>
          <View style={[styles.commentsHeader, { borderBottomColor: C.hair }]}>
            <Text style={[styles.commentsTitle, { color: C.muted }]}>COMMENTS</Text>
            <Pressable onPress={onClose}>
              <Text style={[styles.commentsClose, { color: C.muted }]}>✕</Text>
            </Pressable>
          </View>
          <ScrollView style={{ flex: 1 }} contentContainerStyle={{ padding: 16 }}>
            {SAMPLE_COMMENTS.map((c, i) => (
              <View key={i} style={styles.commentRow}>
                <View style={[styles.commentAvatar, { backgroundColor: C.surf2, borderColor: C.hair2 }]}>
                  <Text style={[styles.commentAvatarText, { color: C.muted }]}>{c.user[0]}</Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={[styles.commentText, { color: C.ink }]}>
                    <Text style={{ fontFamily: Fonts.bold }}>{c.user} </Text>
                    {c.text}
                  </Text>
                  <Text style={[styles.commentTime, { color: C.muted }]}>{c.time}</Text>
                </View>
              </View>
            ))}
          </ScrollView>
          <View style={[styles.commentInput, { borderTopColor: C.hair, backgroundColor: C.bg }]}>
            <TextInput
              value={text}
              onChangeText={setText}
              placeholder="Add a comment…"
              placeholderTextColor={C.muted}
              style={[styles.commentInputField, { color: C.ink, backgroundColor: C.surf, fontFamily: Fonts.regular }]}
            />
            <Pressable
              style={[styles.commentPostBtn, { backgroundColor: text ? C.accent : C.surf2 }]}
            >
              <Text style={[styles.commentPostBtnText, { color: text ? '#fff' : C.muted }]}>POST</Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
  );
}

// ── Main Social screen ─────────────────────────────────────────

export default function SocialScreen() {
  const { C, Fonts } = useTheme();
  const insets = useSafeAreaInsets();
  const [activeTab, setActiveTab] = useState<'friends' | 'challenges'>('friends');
  const [commentsPost, setCommentsPost] = useState<string | null>(null);

  return (
    <View style={[styles.screen, { backgroundColor: C.bg, paddingTop: insets.top }]}>
      <View style={[styles.header, { borderBottomColor: C.hair }]}>
        <Text style={[styles.headerTitle, { color: C.ink }]}>SOCIAL</Text>
      </View>

      {/* Tab pills */}
      <View style={[styles.tabRow, { borderBottomColor: C.hair }]}>
        {(['friends', 'challenges'] as const).map((t) => (
          <Pressable
            key={t}
            onPress={() => setActiveTab(t)}
            style={[
              styles.tabPill,
              {
                backgroundColor: activeTab === t ? C.ink : C.surf,
                borderColor: activeTab === t ? C.ink : C.hair2,
              },
            ]}
          >
            <Text
              style={[
                styles.tabPillText,
                { color: activeTab === t ? C.bg : C.muted },
              ]}
            >
              {t.toUpperCase()}
            </Text>
          </Pressable>
        ))}
      </View>

      {activeTab === 'friends' ? (
        <ScrollView
          style={{ flex: 1 }}
          contentContainerStyle={{ paddingBottom: 20 }}
          showsVerticalScrollIndicator={false}
        >
          {SAMPLE_POSTS.map((post) => (
            <FeedPostCard
              key={post.id}
              post={post}
              onOpenComments={() => setCommentsPost(post.id)}
            />
          ))}
          {/* Empty state if no real posts */}
          <View style={styles.findFriendsSection}>
            <Text style={[styles.findFriendsTitle, { color: C.muted }]}>FIND MORE FRIENDS</Text>
            <Pressable style={[styles.findFriendsBtn, { backgroundColor: C.accent }]}>
              <Text style={styles.findFriendsBtnText}>FIND FRIENDS</Text>
            </Pressable>
          </View>
        </ScrollView>
      ) : (
        <View style={styles.emptyState}>
          <Text style={[styles.emptyTitle, { color: C.muted }]}>CHALLENGES COMING SOON</Text>
          <Text style={[styles.emptySub, { color: C.faint }]}>
            Challenge friends to weekly volume, streak, or PR goals.
          </Text>
        </View>
      )}

      <CommentsModal
        visible={commentsPost !== null}
        onClose={() => setCommentsPost(null)}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingBottom: 10,
    paddingTop: 2,
    borderBottomWidth: 1,
  },
  headerTitle: { fontFamily: 'Archivo-Black', fontSize: 28, letterSpacing: 0.5 },
  tabRow: {
    flexDirection: 'row',
    gap: 8,
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderBottomWidth: 1,
  },
  tabPill: {
    height: 30,
    paddingHorizontal: 14,
    borderRadius: 999,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  tabPillText: { fontFamily: 'SpaceMono-Bold', fontSize: 9, letterSpacing: 0.8 },
  postCard: { borderBottomWidth: 8, padding: 16, paddingBottom: 12 },
  postHeader: { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 10 },
  postAvatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  postAvatarText: { fontFamily: 'Archivo-SemiBold', fontSize: 14 },
  postUsername: { fontFamily: 'Archivo-SemiBold', fontSize: 14 },
  postHandle: { fontFamily: 'SpaceMono-Regular', fontSize: 9, marginTop: 1 },
  postMenu: { fontFamily: 'Archivo-Regular', fontSize: 18 },
  postSession: { flexDirection: 'row', alignItems: 'baseline', gap: 8, marginBottom: 10 },
  postWorkoutName: { fontFamily: 'Archivo-Black', fontSize: 22, letterSpacing: 0.5 },
  postDuration: { fontFamily: 'SpaceMono-Regular', fontSize: 10 },
  postBody: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    borderRadius: 10,
    borderWidth: 1,
    padding: 10,
    marginBottom: 8,
  },
  postStats: { flex: 1, gap: 6 },
  postStatCell: { flexDirection: 'row', alignItems: 'baseline', gap: 6 },
  postStatLabel: { fontFamily: 'SpaceMono-Regular', fontSize: 8, letterSpacing: 1, width: 32 },
  postStatVal: { fontSize: 13 },
  prBadge: { paddingHorizontal: 8, paddingVertical: 4, borderRadius: 6 },
  prBadgeText: { fontFamily: 'SpaceMono-Bold', fontSize: 9 },
  postExercises: { flexDirection: 'row', flexWrap: 'wrap', gap: 4, marginBottom: 10 },
  exChip: { paddingHorizontal: 7, paddingVertical: 3, borderRadius: 4 },
  exChipText: { fontFamily: 'SpaceMono-Regular', fontSize: 8, letterSpacing: 0.5 },
  exMore: { fontFamily: 'SpaceMono-Regular', fontSize: 8, paddingHorizontal: 4, paddingVertical: 3 },
  postReactRow: { flexDirection: 'row', gap: 8, position: 'relative' },
  reactPickerWrap: {
    position: 'absolute',
    bottom: 48,
    left: 0,
    flexDirection: 'row',
    borderRadius: 999,
    borderWidth: 1,
    padding: 6,
    paddingHorizontal: 10,
    gap: 4,
    zIndex: 200,
  },
  reactPickerItem: { width: 36, height: 36, alignItems: 'center', justifyContent: 'center' },
  reactPickerEmoji: { fontSize: 22 },
  reactBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 14,
    paddingVertical: 7,
    borderRadius: 8,
    borderWidth: 1,
  },
  reactEmoji: { fontSize: 16, lineHeight: 20 },
  reactCount: { fontSize: 12 },
  holdHint: { fontFamily: 'SpaceMono-Regular', fontSize: 8, letterSpacing: 0.5 },
  findFriendsSection: { padding: 24, alignItems: 'center', gap: 12 },
  findFriendsTitle: { fontFamily: 'SpaceMono-Bold', fontSize: 10, letterSpacing: 1.5 },
  findFriendsBtn: { height: 40, paddingHorizontal: 24, borderRadius: 10, alignItems: 'center', justifyContent: 'center' },
  findFriendsBtnText: { fontFamily: 'Archivo-Black', fontSize: 13, letterSpacing: 1.5, color: '#fff' },
  emptyState: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 32, gap: 8 },
  emptyTitle: { fontFamily: 'SpaceMono-Bold', fontSize: 11, letterSpacing: 1.5 },
  emptySub: { fontFamily: 'Archivo-Regular', fontSize: 13, textAlign: 'center', lineHeight: 20 },
  // Comments modal
  commentsOverlay: { flex: 1, flexDirection: 'column', justifyContent: 'flex-end' },
  commentsBg: { position: 'absolute', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.45)' },
  commentsSheet: {
    height: '72%',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    borderWidth: 1,
    borderBottomWidth: 0,
    overflow: 'hidden',
  },
  commentsHandle: { paddingVertical: 10, alignItems: 'center' },
  handleBar: { width: 36, height: 4, borderRadius: 2 },
  commentsHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingBottom: 10,
    borderBottomWidth: 1,
  },
  commentsTitle: { fontFamily: 'SpaceMono-Bold', fontSize: 10, letterSpacing: 1.2 },
  commentsClose: { fontFamily: 'Archivo-Regular', fontSize: 18 },
  commentRow: { flexDirection: 'row', gap: 10, marginBottom: 16 },
  commentAvatar: { width: 32, height: 32, borderRadius: 16, borderWidth: 1, alignItems: 'center', justifyContent: 'center', flexShrink: 0 },
  commentAvatarText: { fontFamily: 'Archivo-Medium', fontSize: 12 },
  commentText: { fontFamily: 'Archivo-Regular', fontSize: 13, lineHeight: 19 },
  commentTime: { fontFamily: 'SpaceMono-Regular', fontSize: 9, marginTop: 3 },
  commentInput: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    padding: 12,
    borderTopWidth: 1,
  },
  commentInputField: {
    flex: 1,
    height: 36,
    borderRadius: 8,
    paddingHorizontal: 12,
    fontSize: 13,
  },
  commentPostBtn: {
    height: 36,
    paddingHorizontal: 14,
    borderRadius: 8,
    alignItems: 'center',
    justifyContent: 'center',
  },
  commentPostBtnText: { fontFamily: 'Archivo-Black', fontSize: 12, letterSpacing: 1 },
});
