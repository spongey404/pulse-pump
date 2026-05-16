import React, {
  useState,
  useEffect,
  useRef,
  useCallback,
  createContext,
  useContext,
} from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  Modal,
  Pressable,
  TextInput,
  Animated,
  StyleSheet,
  ScrollView,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import Svg, { Line, Polyline, Path, Circle, Polygon } from 'react-native-svg';

// ─── Shared theme type ────────────────────────────────────────────────────────
export interface ThemeColors {
  bg: string;
  surf: string;
  surf2: string;
  surf3?: string;
  ink: string;
  muted: string;
  faint: string;
  hair: string;
  hair2: string;
  accent: string;
  accentSoft: string;
  up: string;
  down: string;
  pr: string;
  [key: string]: string | undefined;
}

// ─── A: InlineConfirm ─────────────────────────────────────────────────────────

export interface InlineConfirmProps {
  C: ThemeColors;
  title: string;
  body: string;
  cancelLabel: string;
  confirmLabel: string;
  onCancel: () => void;
  onConfirm: () => void;
}

export function InlineConfirm({
  C,
  title,
  body,
  cancelLabel,
  confirmLabel,
  onCancel,
  onConfirm,
}: InlineConfirmProps) {
  return (
    <View
      style={[
        styles.inlineCard,
        {
          backgroundColor: C.surf,
          borderColor: C.hair2,
        },
      ]}
    >
      <View style={styles.inlineBody}>
        <Text style={[styles.inlineTitle, { color: C.ink, fontFamily: 'Archivo-SemiBold' }]}>
          {title}
        </Text>
        <Text style={[styles.inlineBodyText, { color: C.muted, fontFamily: 'Archivo-Regular' }]}>
          {body}
        </Text>
      </View>
      <View style={styles.inlineButtons}>
        <TouchableOpacity
          onPress={onCancel}
          style={[styles.inlineCancelBtn, { backgroundColor: C.surf2 }]}
          activeOpacity={0.75}
        >
          <Text style={[styles.inlineBtnLabel, { color: C.muted, fontFamily: 'Archivo-Black' }]}>
            {cancelLabel}
          </Text>
        </TouchableOpacity>
        <TouchableOpacity
          onPress={onConfirm}
          style={[
            styles.inlineConfirmBtn,
            {
              backgroundColor: C.down,
              shadowColor: C.down,
            },
          ]}
          activeOpacity={0.75}
        >
          <Text style={[styles.inlineBtnLabel, { color: '#fff', fontFamily: 'Archivo-Black' }]}>
            {confirmLabel}
          </Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

// ─── B: DestructiveModal ──────────────────────────────────────────────────────

export interface DestructiveModalProps {
  C: ThemeColors;
  kicker: string;
  title: string;
  body: string;
  consequences?: { value: string; label: string }[];
  cancelLabel: string;
  confirmLabel: string;
  accent?: string;
  onCancel: () => void;
  onConfirm: () => void;
  visible: boolean;
}

export function DestructiveModal({
  C,
  kicker,
  title,
  body,
  consequences,
  cancelLabel,
  confirmLabel,
  accent,
  onCancel,
  onConfirm,
  visible,
}: DestructiveModalProps) {
  const accentColor = accent ?? C.down;

  return (
    <Modal
      transparent
      animationType="fade"
      visible={visible}
      onRequestClose={onCancel}
      statusBarTranslucent
    >
      <Pressable style={styles.overlay} onPress={onCancel}>
        <Pressable onPress={() => {}} style={styles.overlayTouchGuard}>
          <View
            style={[
              styles.destructiveCard,
              { backgroundColor: C.bg, borderColor: C.hair2 },
            ]}
          >
            {/* Accent strip */}
            <View style={[styles.destructiveStrip, { backgroundColor: accentColor }]}>
              <Text style={[styles.destructiveKicker, { fontFamily: 'SpaceMono-Regular' }]}>
                ⚠ {kicker}
              </Text>
              <Text style={[styles.destructiveIrreversible, { fontFamily: 'SpaceMono-Regular' }]}>
                IRREVERSIBLE
              </Text>
            </View>

            {/* Body */}
            <View style={styles.destructiveBody}>
              <Text
                style={[styles.destructiveTitle, { color: C.ink, fontFamily: 'Archivo-Black' }]}
              >
                {title}
              </Text>
              <Text
                style={[styles.destructiveBodyText, { color: C.muted, fontFamily: 'Archivo-Regular' }]}
              >
                {body}
              </Text>

              {/* Consequences */}
              {consequences && consequences.length > 0 && (
                <View
                  style={[
                    styles.consequencesCard,
                    { backgroundColor: C.surf, borderColor: C.hair2 },
                  ]}
                >
                  <View style={[styles.consequencesHeader, { backgroundColor: C.surf2 }]}>
                    <Text
                      style={[
                        styles.consequencesHeaderText,
                        { color: C.muted, fontFamily: 'SpaceMono-Regular' },
                      ]}
                    >
                      WHAT YOU'LL LOSE
                    </Text>
                  </View>
                  {consequences.map((c, i) => (
                    <View
                      key={i}
                      style={[
                        styles.consequenceRow,
                        i < consequences.length - 1 && {
                          borderBottomWidth: StyleSheet.hairlineWidth,
                          borderBottomColor: C.hair,
                        },
                      ]}
                    >
                      <Text
                        style={[
                          styles.consequenceValue,
                          { color: accentColor, fontFamily: 'SpaceMono-Bold' },
                        ]}
                      >
                        {c.value}
                      </Text>
                      <Text
                        style={[
                          styles.consequenceLabel,
                          { color: C.ink, fontFamily: 'Archivo-Regular' },
                        ]}
                      >
                        {c.label}
                      </Text>
                    </View>
                  ))}
                </View>
              )}
            </View>

            {/* Footer */}
            <View style={[styles.modalFooter, { borderTopColor: C.hair, borderTopWidth: StyleSheet.hairlineWidth }]}>
              <TouchableOpacity
                onPress={onCancel}
                style={[
                  styles.modalFooterBtn,
                  { backgroundColor: C.surf2, borderColor: C.hair2, borderWidth: 1 },
                ]}
                activeOpacity={0.75}
              >
                <Text style={[styles.modalFooterBtnLabel, { color: C.muted, fontFamily: 'Archivo-Black' }]}>
                  {cancelLabel}
                </Text>
              </TouchableOpacity>
              <TouchableOpacity
                onPress={onConfirm}
                style={[
                  styles.modalFooterBtn,
                  {
                    backgroundColor: accentColor,
                    shadowColor: accentColor,
                    shadowOpacity: 0.4,
                    shadowRadius: 8,
                    shadowOffset: { width: 0, height: 3 },
                  },
                ]}
                activeOpacity={0.75}
              >
                <Text style={[styles.modalFooterBtnLabel, { color: '#fff', fontFamily: 'Archivo-Black' }]}>
                  {confirmLabel}
                </Text>
              </TouchableOpacity>
            </View>
          </View>
        </Pressable>
      </Pressable>
    </Modal>
  );
}

// ─── C: ActionSheet ───────────────────────────────────────────────────────────

export interface ActionSheetItem {
  icon?: React.ReactNode;
  label: string;
  sub?: string;
  danger?: boolean;
  shortcut?: string;
}

export interface ActionSheetProps {
  C: ThemeColors;
  title?: string;
  sub?: string;
  items: ActionSheetItem[];
  cancelLabel?: string;
  onCancel: () => void;
  onItemPress: (index: number) => void;
  visible: boolean;
}

export function ActionSheet({
  C,
  title,
  sub,
  items,
  cancelLabel = 'Cancel',
  onCancel,
  onItemPress,
  visible,
}: ActionSheetProps) {
  const slideAnim = useRef(new Animated.Value(300)).current;

  useEffect(() => {
    if (visible) {
      Animated.spring(slideAnim, {
        toValue: 0,
        tension: 65,
        friction: 11,
        useNativeDriver: true,
      }).start();
    } else {
      Animated.timing(slideAnim, {
        toValue: 300,
        duration: 220,
        useNativeDriver: true,
      }).start();
    }
  }, [visible]);

  return (
    <Modal
      transparent
      animationType="none"
      visible={visible}
      onRequestClose={onCancel}
      statusBarTranslucent
    >
      <Pressable style={[styles.overlay, { justifyContent: 'flex-end' }]} onPress={onCancel}>
        <Pressable onPress={() => {}} style={styles.overlayTouchGuard}>
          <Animated.View
            style={[
              styles.actionSheet,
              { backgroundColor: C.bg, transform: [{ translateY: slideAnim }] },
            ]}
          >
            {/* Pill handle */}
            <View style={styles.sheetHandleRow}>
              <View style={[styles.sheetHandle, { backgroundColor: C.faint }]} />
            </View>

            {/* Header */}
            {(title || sub) && (
              <View
                style={[
                  styles.sheetHeader,
                  { borderBottomColor: C.hair, borderBottomWidth: StyleSheet.hairlineWidth },
                ]}
              >
                {sub && (
                  <Text
                    style={[styles.sheetSub, { color: C.muted, fontFamily: 'SpaceMono-Regular' }]}
                  >
                    {sub}
                  </Text>
                )}
                {title && (
                  <Text
                    style={[styles.sheetTitle, { color: C.ink, fontFamily: 'Archivo-SemiBold' }]}
                  >
                    {title}
                  </Text>
                )}
              </View>
            )}

            {/* Items */}
            <View>
              {items.map((item, i) => (
                <TouchableOpacity
                  key={i}
                  onPress={() => onItemPress(i)}
                  activeOpacity={0.7}
                  style={[
                    styles.sheetItem,
                    i < items.length - 1 && {
                      borderBottomWidth: StyleSheet.hairlineWidth,
                      borderBottomColor: C.hair,
                    },
                  ]}
                >
                  {item.icon && (
                    <View
                      style={[
                        styles.sheetItemIcon,
                        {
                          backgroundColor: item.danger
                            ? 'rgba(192,57,43,0.15)'
                            : C.surf2,
                        },
                      ]}
                    >
                      {item.icon}
                    </View>
                  )}
                  <View style={styles.sheetItemText}>
                    <Text
                      style={[
                        styles.sheetItemLabel,
                        {
                          color: item.danger ? C.down : C.ink,
                          fontFamily: 'Archivo-SemiBold',
                        },
                      ]}
                    >
                      {item.label}
                    </Text>
                    {item.sub && (
                      <Text
                        style={[
                          styles.sheetItemSub,
                          { color: C.muted, fontFamily: 'Archivo-Regular' },
                        ]}
                      >
                        {item.sub}
                      </Text>
                    )}
                  </View>
                  {item.shortcut && (
                    <Text
                      style={[
                        styles.sheetItemShortcut,
                        { color: C.muted, fontFamily: 'SpaceMono-Regular' },
                      ]}
                    >
                      {item.shortcut}
                    </Text>
                  )}
                </TouchableOpacity>
              ))}
            </View>

            {/* Cancel */}
            <View style={[styles.sheetCancelSep, { backgroundColor: C.surf2 }]} />
            <TouchableOpacity
              onPress={onCancel}
              style={styles.sheetCancel}
              activeOpacity={0.7}
            >
              <Text style={[styles.sheetCancelLabel, { color: C.ink, fontFamily: 'Archivo-Black' }]}>
                {cancelLabel}
              </Text>
            </TouchableOpacity>
          </Animated.View>
        </Pressable>
      </Pressable>
    </Modal>
  );
}

// ─── D: PrimingScreen ─────────────────────────────────────────────────────────

export interface PrimingScreenProps {
  C: ThemeColors;
  kicker: string;
  title: string;
  body: string;
  icon: React.ReactNode;
  bullets: string[];
  primaryLabel: string;
  secondaryLabel: string;
  onPrimary: () => void;
  onSecondary: () => void;
}

export function PrimingScreen({
  C,
  kicker,
  title,
  body,
  icon,
  bullets,
  primaryLabel,
  secondaryLabel,
  onPrimary,
  onSecondary,
}: PrimingScreenProps) {
  return (
    <View style={[StyleSheet.absoluteFillObject, { backgroundColor: C.bg }]}>
      {/* Ticker strip */}
      <View style={[styles.primingTicker, { backgroundColor: '#1a1816' }]}>
        <Text style={[styles.primingTickerAccent, { color: C.accent, fontFamily: 'SpaceMono-Bold' }]}>
          ● PERMISSION
        </Text>
        <Text style={[styles.primingTickerStep, { color: C.muted, fontFamily: 'SpaceMono-Regular' }]}>
          STEP 1/1
        </Text>
      </View>

      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={styles.primingScroll}
        showsVerticalScrollIndicator={false}
      >
        {/* Kicker */}
        <Text
          style={[styles.primingKicker, { color: C.accent, fontFamily: 'SpaceMono-Regular' }]}
        >
          ⚡ {kicker}
        </Text>

        {/* Icon box */}
        <View
          style={[
            styles.primingIconBox,
            { backgroundColor: C.accentSoft, borderColor: C.accent },
          ]}
        >
          {icon}
        </View>

        {/* Title */}
        <Text style={[styles.primingTitle, { color: C.ink, fontFamily: 'Archivo-Black' }]}>
          {title}
        </Text>

        {/* Body */}
        <Text style={[styles.primingBody, { color: C.muted, fontFamily: 'Archivo-Regular' }]}>
          {body}
        </Text>

        {/* Bullets card */}
        {bullets.length > 0 && (
          <View
            style={[styles.primingBulletsCard, { backgroundColor: C.surf, borderColor: C.hair2 }]}
          >
            <View style={[styles.primingBulletsHeader, { backgroundColor: C.surf2 }]}>
              <Text
                style={[
                  styles.primingBulletsHeaderText,
                  { color: C.muted, fontFamily: 'SpaceMono-Regular' },
                ]}
              >
                WHAT WE'LL DO WITH IT
              </Text>
            </View>
            {bullets.map((bullet, i) => (
              <View
                key={i}
                style={[
                  styles.primingBulletRow,
                  i < bullets.length - 1 && {
                    borderBottomWidth: StyleSheet.hairlineWidth,
                    borderBottomColor: C.hair,
                  },
                ]}
              >
                <Text
                  style={[
                    styles.primingBulletNum,
                    { color: C.accent, fontFamily: 'SpaceMono-Regular' },
                  ]}
                >
                  {String(i + 1).padStart(2, '0')}
                </Text>
                <Text
                  style={[
                    styles.primingBulletText,
                    { color: C.ink, fontFamily: 'Archivo-Regular' },
                  ]}
                >
                  {bullet}
                </Text>
              </View>
            ))}
          </View>
        )}

        {/* CTAs */}
        <TouchableOpacity
          onPress={onPrimary}
          style={[styles.primingPrimaryBtn, { backgroundColor: C.accent }]}
          activeOpacity={0.8}
        >
          <Text
            style={[styles.primingPrimaryLabel, { color: '#fff', fontFamily: 'Archivo-Black' }]}
          >
            {primaryLabel}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          onPress={onSecondary}
          style={styles.primingSecondaryBtn}
          activeOpacity={0.7}
        >
          <Text
            style={[
              styles.primingSecondaryLabel,
              { color: C.muted, fontFamily: 'Archivo-Black' },
            ]}
          >
            {secondaryLabel}
          </Text>
        </TouchableOpacity>
      </ScrollView>
    </View>
  );
}

// ─── E: Toast + ToastContainer ────────────────────────────────────────────────

type ToastKind = 'success' | 'pr' | 'error' | 'info' | 'offline';

export interface ToastData {
  id: string;
  kind: ToastKind;
  kicker: string;
  title: string;
  value?: string;
}

export interface ToastProps {
  C: ThemeColors;
  kind: ToastKind;
  kicker: string;
  title: string;
  value?: string;
  onDismiss?: () => void;
}

function toastColors(C: ThemeColors, kind: ToastKind): { bg: string; fg: string } {
  switch (kind) {
    case 'success':
      return { bg: C.up, fg: '#fff' };
    case 'pr':
      return { bg: C.pr, fg: '#1f1c19' };
    case 'error':
      return { bg: C.down, fg: '#fff' };
    case 'info':
      return { bg: '#1a1816', fg: '#ece5d6' };
    case 'offline':
      return { bg: '#3a342d', fg: '#ece5d6' };
  }
}

export function Toast({ C, kind, kicker, title, value, onDismiss }: ToastProps) {
  const { bg, fg } = toastColors(C, kind);

  return (
    <TouchableOpacity
      onPress={onDismiss}
      activeOpacity={0.85}
      style={[styles.toast, { backgroundColor: bg }]}
    >
      <Text
        style={[styles.toastKicker, { color: fg, fontFamily: 'SpaceMono-Regular', opacity: 0.75 }]}
        numberOfLines={1}
      >
        {kicker}
      </Text>
      <Text
        style={[styles.toastTitle, { color: fg, fontFamily: 'Archivo-Bold' }]}
        numberOfLines={1}
      >
        {title}
      </Text>
      {value !== undefined && (
        <Text style={[styles.toastValue, { color: fg, fontFamily: 'SpaceMono-Bold' }]}>
          {value}
        </Text>
      )}
    </TouchableOpacity>
  );
}

// Toast context
interface ToastContextValue {
  addToast: (toast: Omit<ToastData, 'id'>) => void;
}

const ToastContext = createContext<ToastContextValue>({ addToast: () => {} });

export function useToast() {
  return useContext(ToastContext);
}

export interface ToastContainerProps {
  C: ThemeColors;
  children: React.ReactNode;
}

export function ToastProvider({ C, children }: ToastContainerProps) {
  const [toasts, setToasts] = useState<ToastData[]>([]);
  const timers = useRef<Record<string, ReturnType<typeof setTimeout>>>({});

  const removeToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
    if (timers.current[id]) {
      clearTimeout(timers.current[id]);
      delete timers.current[id];
    }
  }, []);

  const addToast = useCallback(
    (toast: Omit<ToastData, 'id'>) => {
      const id = `${Date.now()}-${Math.random()}`;
      const full: ToastData = { ...toast, id };
      setToasts((prev) => [...prev, full]);
      timers.current[id] = setTimeout(() => removeToast(id), 2500);
    },
    [removeToast]
  );

  useEffect(() => {
    return () => {
      Object.values(timers.current).forEach(clearTimeout);
    };
  }, []);

  return (
    <ToastContext.Provider value={{ addToast }}>
      {children}
      <View style={styles.toastContainer} pointerEvents="box-none">
        {toasts.map((t) => (
          <Toast
            key={t.id}
            C={C}
            kind={t.kind}
            kicker={t.kicker}
            title={t.title}
            value={t.value}
            onDismiss={() => removeToast(t.id)}
          />
        ))}
      </View>
    </ToastContext.Provider>
  );
}

// ─── F: PRCelebration ─────────────────────────────────────────────────────────

export interface PRCelebrationProps {
  C: ThemeColors;
  exercise: string;
  oldVal: number;
  newVal: number;
  unit?: string;
  onDismiss: () => void;
  onShare: () => void;
  visible: boolean;
}

export function PRCelebration({
  C,
  exercise,
  oldVal,
  newVal,
  unit = 'kg',
  onDismiss,
  onShare,
  visible,
}: PRCelebrationProps) {
  const delta = newVal - oldVal;
  const pct = oldVal > 0 ? ((delta / oldVal) * 100).toFixed(1) : '—';

  return (
    <Modal
      transparent
      animationType="fade"
      visible={visible}
      onRequestClose={onDismiss}
      statusBarTranslucent
    >
      <View style={styles.overlay}>
        <View
          style={[
            styles.prCard,
            { backgroundColor: C.bg, borderColor: C.pr },
          ]}
        >
          {/* Diagonal stripe overlay */}
          <View style={[StyleSheet.absoluteFillObject, styles.prStripes]} pointerEvents="none" />

          {/* Gold strip */}
          <View style={[styles.prStrip, { backgroundColor: C.pr }]}>
            <Text style={[styles.prStripLeft, { color: '#1f1c19', fontFamily: 'SpaceMono-Bold' }]}>
              ★ PERSONAL RECORD ★
            </Text>
            <View
              style={[
                styles.prNewBadge,
                { backgroundColor: 'rgba(255,255,255,0.2)' },
              ]}
            >
              <Text style={[styles.prNewBadgeText, { color: '#1f1c19', fontFamily: 'SpaceMono-Bold' }]}>
                NEW
              </Text>
            </View>
          </View>

          {/* Body */}
          <View style={styles.prBody}>
            <Text
              style={[styles.prExerciseLabel, { color: C.muted, fontFamily: 'SpaceMono-Regular' }]}
            >
              EXERCISE
            </Text>
            <Text
              style={[styles.prExerciseName, { color: C.ink, fontFamily: 'Archivo-Black' }]}
            >
              {exercise}
            </Text>

            {/* Numbers row */}
            <View style={styles.prNumbersRow}>
              <View style={styles.prOldBlock}>
                <Text
                  style={[
                    styles.prOldVal,
                    { color: C.muted, fontFamily: 'SpaceMono-Regular', textDecorationLine: 'line-through' },
                  ]}
                >
                  {oldVal}
                </Text>
                <Text style={[styles.prOldUnit, { color: C.muted, fontFamily: 'SpaceMono-Regular' }]}>
                  {unit}
                </Text>
              </View>

              {/* Arrow icon */}
              <Svg width={24} height={24} viewBox="0 0 24 24" fill="none">
                <Line x1="5" y1="12" x2="19" y2="12" stroke={C.pr} strokeWidth="2" strokeLinecap="round" />
                <Polyline points="13,6 19,12 13,18" stroke={C.pr} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
              </Svg>

              <View style={styles.prNewBlock}>
                <Text
                  style={[styles.prNewVal, { color: C.ink, fontFamily: 'SpaceMono-Bold' }]}
                >
                  {newVal}
                </Text>
                <Text style={[styles.prNewUnit, { color: C.pr, fontFamily: 'SpaceMono-Regular' }]}>
                  NEW · {unit}
                </Text>
              </View>
            </View>

            {/* Delta */}
            <Text style={[styles.prDelta, { color: C.up, fontFamily: 'SpaceMono-Regular' }]}>
              ▲ +{delta} {unit}  ({pct}% improvement)
            </Text>
          </View>

          {/* Footer */}
          <View
            style={[
              styles.prFooter,
              { borderTopColor: C.hair, borderTopWidth: StyleSheet.hairlineWidth },
            ]}
          >
            <TouchableOpacity
              onPress={onDismiss}
              style={styles.prDismissBtn}
              activeOpacity={0.7}
            >
              <Text
                style={[styles.prDismissLabel, { color: C.muted, fontFamily: 'Archivo-Black' }]}
              >
                DISMISS
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              onPress={onShare}
              style={[styles.prShareBtn, { backgroundColor: C.accent }]}
              activeOpacity={0.8}
            >
              <Svg width={14} height={14} viewBox="0 0 24 24" fill="none" style={{ marginRight: 6 }}>
                <Path
                  d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"
                  stroke="#fff"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <Polyline
                  points="16,6 12,2 8,6"
                  stroke="#fff"
                  strokeWidth="2"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <Line
                  x1="12"
                  y1="2"
                  x2="12"
                  y2="15"
                  stroke="#fff"
                  strokeWidth="2"
                  strokeLinecap="round"
                />
              </Svg>
              <Text
                style={[styles.prShareLabel, { color: '#fff', fontFamily: 'Archivo-Black' }]}
              >
                SHARE TO FEED
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}

// ─── G: RenameModal ───────────────────────────────────────────────────────────

const RENAME_MAX_CHARS = 40;

export interface RenameModalProps {
  C: ThemeColors;
  kicker: string;
  title: string;
  currentValue: string;
  label?: string;
  confirmLabel?: string;
  onCancel: () => void;
  onConfirm: (value: string) => void;
  visible: boolean;
}

export function RenameModal({
  C,
  kicker,
  title,
  currentValue,
  label = 'NAME',
  confirmLabel = 'Save',
  onCancel,
  onConfirm,
  visible,
}: RenameModalProps) {
  const [value, setValue] = useState(currentValue);

  useEffect(() => {
    if (visible) {
      setValue(currentValue);
    }
  }, [visible, currentValue]);

  const handleConfirm = () => {
    if (value.trim().length > 0) {
      onConfirm(value.trim());
    }
  };

  return (
    <Modal
      transparent
      animationType="fade"
      visible={visible}
      onRequestClose={onCancel}
      statusBarTranslucent
    >
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={{ flex: 1 }}
      >
        <Pressable style={styles.overlay} onPress={onCancel}>
          <Pressable onPress={() => {}} style={styles.overlayTouchGuard}>
            <View
              style={[
                styles.renameCard,
                { backgroundColor: C.bg, borderColor: C.hair2 },
              ]}
            >
              {/* Header */}
              <View style={styles.renameHeader}>
                <Text
                  style={[
                    styles.renameKicker,
                    { color: C.accent, fontFamily: 'SpaceMono-Regular' },
                  ]}
                >
                  ✎ {kicker}
                </Text>
                <Text
                  style={[styles.renameTitle, { color: C.ink, fontFamily: 'Archivo-Black' }]}
                >
                  {title}
                </Text>
              </View>

              {/* Input */}
              <View style={styles.renameBody}>
                <Text
                  style={[
                    styles.renameFieldLabel,
                    { color: C.muted, fontFamily: 'SpaceMono-Regular' },
                  ]}
                >
                  {label}
                </Text>
                <TextInput
                  value={value}
                  onChangeText={(t) => setValue(t.slice(0, RENAME_MAX_CHARS))}
                  style={[
                    styles.renameInput,
                    {
                      backgroundColor: C.surf,
                      borderColor: C.accent,
                      color: C.ink,
                      fontFamily: 'Archivo-Regular',
                    },
                  ]}
                  placeholderTextColor={C.muted}
                  autoFocus
                  returnKeyType="done"
                  onSubmitEditing={handleConfirm}
                  selectionColor={C.accent}
                />
                <Text
                  style={[
                    styles.renameCharCount,
                    { color: C.muted, fontFamily: 'SpaceMono-Regular' },
                  ]}
                >
                  {value.length}/{RENAME_MAX_CHARS}
                </Text>
              </View>

              {/* Footer */}
              <View
                style={[
                  styles.modalFooter,
                  { borderTopColor: C.hair, borderTopWidth: StyleSheet.hairlineWidth },
                ]}
              >
                <TouchableOpacity
                  onPress={onCancel}
                  style={[
                    styles.modalFooterBtn,
                    { backgroundColor: C.surf2, borderColor: C.hair2, borderWidth: 1 },
                  ]}
                  activeOpacity={0.75}
                >
                  <Text
                    style={[
                      styles.modalFooterBtnLabel,
                      { color: C.muted, fontFamily: 'Archivo-Black' },
                    ]}
                  >
                    Cancel
                  </Text>
                </TouchableOpacity>
                <TouchableOpacity
                  onPress={handleConfirm}
                  style={[
                    styles.modalFooterBtn,
                    {
                      backgroundColor: C.accent,
                      shadowColor: C.accent,
                      shadowOpacity: 0.35,
                      shadowRadius: 8,
                      shadowOffset: { width: 0, height: 3 },
                      opacity: value.trim().length === 0 ? 0.45 : 1,
                    },
                  ]}
                  activeOpacity={0.75}
                  disabled={value.trim().length === 0}
                >
                  <Text
                    style={[
                      styles.modalFooterBtnLabel,
                      { color: '#fff', fontFamily: 'Archivo-Black' },
                    ]}
                  >
                    {confirmLabel}
                  </Text>
                </TouchableOpacity>
              </View>
            </View>
          </Pressable>
        </Pressable>
      </KeyboardAvoidingView>
    </Modal>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const styles = StyleSheet.create({
  // ── Shared overlay
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.55)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  overlayTouchGuard: {
    width: '100%',
    alignItems: 'center',
  },

  // ── Shared modal footer
  modalFooter: {
    flexDirection: 'row',
    gap: 10,
    padding: 14,
  },
  modalFooterBtn: {
    flex: 1,
    height: 44,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  modalFooterBtnLabel: {
    fontSize: 12,
    letterSpacing: 1,
    textTransform: 'uppercase',
  },

  // ── A: InlineConfirm
  inlineCard: {
    borderRadius: 10,
    borderWidth: 1,
    overflow: 'hidden',
  },
  inlineBody: {
    padding: 14,
    gap: 4,
  },
  inlineTitle: {
    fontSize: 13,
  },
  inlineBodyText: {
    fontSize: 12,
    lineHeight: 17,
  },
  inlineButtons: {
    flexDirection: 'row',
    gap: 8,
    paddingHorizontal: 14,
    paddingBottom: 14,
  },
  inlineCancelBtn: {
    flex: 1,
    height: 40,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
  },
  inlineConfirmBtn: {
    flex: 1,
    height: 40,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
    shadowOpacity: 0.35,
    shadowRadius: 6,
    shadowOffset: { width: 0, height: 2 },
    elevation: 4,
  },
  inlineBtnLabel: {
    fontSize: 11,
    letterSpacing: 0.8,
    textTransform: 'uppercase',
  },

  // ── B: DestructiveModal
  destructiveCard: {
    width: '88%',
    maxWidth: 380,
    borderRadius: 14,
    borderWidth: 1,
    overflow: 'hidden',
  },
  destructiveStrip: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  destructiveKicker: {
    fontSize: 9,
    letterSpacing: 1.8,
    color: '#fff',
    textTransform: 'uppercase',
  },
  destructiveIrreversible: {
    fontSize: 9,
    letterSpacing: 1.8,
    color: 'rgba(255,255,255,0.65)',
    textTransform: 'uppercase',
  },
  destructiveBody: {
    padding: 18,
    gap: 8,
  },
  destructiveTitle: {
    fontSize: 22,
    lineHeight: 26,
  },
  destructiveBodyText: {
    fontSize: 13,
    lineHeight: 19,
  },
  consequencesCard: {
    borderRadius: 10,
    borderWidth: 1,
    overflow: 'hidden',
    marginTop: 6,
  },
  consequencesHeader: {
    paddingHorizontal: 12,
    paddingVertical: 7,
  },
  consequencesHeaderText: {
    fontSize: 8,
    letterSpacing: 1.5,
    textTransform: 'uppercase',
  },
  consequenceRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  consequenceValue: {
    fontSize: 11,
    minWidth: 56,
  },
  consequenceLabel: {
    fontSize: 12,
    flex: 1,
  },

  // ── C: ActionSheet
  actionSheet: {
    width: '100%',
    borderTopLeftRadius: 14,
    borderTopRightRadius: 14,
    overflow: 'hidden',
    paddingBottom: 32,
  },
  sheetHandleRow: {
    alignItems: 'center',
    paddingTop: 10,
    paddingBottom: 6,
  },
  sheetHandle: {
    width: 36,
    height: 4,
    borderRadius: 2,
  },
  sheetHeader: {
    paddingHorizontal: 16,
    paddingVertical: 12,
    gap: 3,
  },
  sheetSub: {
    fontSize: 8,
    letterSpacing: 1.5,
    textTransform: 'uppercase',
  },
  sheetTitle: {
    fontSize: 16,
  },
  sheetItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 13,
    gap: 12,
  },
  sheetItemIcon: {
    width: 36,
    height: 36,
    borderRadius: 7,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sheetItemText: {
    flex: 1,
    gap: 2,
  },
  sheetItemLabel: {
    fontSize: 14,
  },
  sheetItemSub: {
    fontSize: 11,
  },
  sheetItemShortcut: {
    fontSize: 10,
    letterSpacing: 0.5,
  },
  sheetCancelSep: {
    height: 8,
  },
  sheetCancel: {
    alignItems: 'center',
    paddingVertical: 15,
  },
  sheetCancelLabel: {
    fontSize: 14,
    letterSpacing: 0.5,
  },

  // ── D: PrimingScreen
  primingTicker: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingTop: 56,
    paddingBottom: 12,
  },
  primingTickerAccent: {
    fontSize: 9,
    letterSpacing: 1.8,
    textTransform: 'uppercase',
  },
  primingTickerStep: {
    fontSize: 9,
    letterSpacing: 1.8,
    textTransform: 'uppercase',
  },
  primingScroll: {
    padding: 24,
    gap: 20,
    paddingBottom: 48,
  },
  primingKicker: {
    fontSize: 9,
    letterSpacing: 2,
    textTransform: 'uppercase',
  },
  primingIconBox: {
    width: 88,
    height: 88,
    borderRadius: 20,
    borderWidth: 1.5,
    alignItems: 'center',
    justifyContent: 'center',
  },
  primingTitle: {
    fontSize: 30,
    lineHeight: 34,
  },
  primingBody: {
    fontSize: 14,
    lineHeight: 21,
  },
  primingBulletsCard: {
    borderRadius: 12,
    borderWidth: 1,
    overflow: 'hidden',
  },
  primingBulletsHeader: {
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  primingBulletsHeaderText: {
    fontSize: 8,
    letterSpacing: 1.5,
    textTransform: 'uppercase',
  },
  primingBulletRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 12,
    paddingHorizontal: 14,
    paddingVertical: 11,
  },
  primingBulletNum: {
    fontSize: 9,
    letterSpacing: 0.5,
    marginTop: 2,
    minWidth: 20,
  },
  primingBulletText: {
    fontSize: 13,
    lineHeight: 19,
    flex: 1,
  },
  primingPrimaryBtn: {
    height: 54,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
  },
  primingPrimaryLabel: {
    fontSize: 16,
    letterSpacing: 2,
    textTransform: 'uppercase',
  },
  primingSecondaryBtn: {
    height: 44,
    alignItems: 'center',
    justifyContent: 'center',
  },
  primingSecondaryLabel: {
    fontSize: 13,
    letterSpacing: 1.5,
    textTransform: 'uppercase',
  },

  // ── E: Toast
  toast: {
    marginHorizontal: 12,
    borderRadius: 10,
    paddingVertical: 10,
    paddingHorizontal: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  toastKicker: {
    fontSize: 9,
    letterSpacing: 1.8,
    textTransform: 'uppercase',
    minWidth: 48,
  },
  toastTitle: {
    fontSize: 13,
    flex: 1,
  },
  toastValue: {
    fontSize: 13,
  },
  toastContainer: {
    position: 'absolute',
    top: 80,
    left: 0,
    right: 0,
    gap: 8,
    zIndex: 9999,
  },

  // ── F: PRCelebration
  prCard: {
    width: '88%',
    maxWidth: 360,
    borderRadius: 14,
    borderWidth: 1.5,
    overflow: 'hidden',
  },
  prStripes: {
    // Simulated diagonal stripes via repeating pattern — RN doesn't support
    // CSS repeating-linear-gradient, but we achieve the effect with opacity
    opacity: 0.04,
    backgroundColor: 'transparent',
  },
  prStrip: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  prStripLeft: {
    fontSize: 10,
    letterSpacing: 2.5,
  },
  prNewBadge: {
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
  },
  prNewBadgeText: {
    fontSize: 8,
    letterSpacing: 1.5,
    fontWeight: '700',
  },
  prBody: {
    padding: 18,
    gap: 8,
  },
  prExerciseLabel: {
    fontSize: 9,
    letterSpacing: 1.5,
    textTransform: 'uppercase',
  },
  prExerciseName: {
    fontSize: 24,
    lineHeight: 28,
  },
  prNumbersRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginTop: 8,
  },
  prOldBlock: {
    alignItems: 'center',
  },
  prOldVal: {
    fontSize: 26,
    lineHeight: 30,
  },
  prOldUnit: {
    fontSize: 9,
    letterSpacing: 0.5,
    textTransform: 'uppercase',
  },
  prNewBlock: {
    alignItems: 'center',
  },
  prNewVal: {
    fontSize: 38,
    lineHeight: 42,
  },
  prNewUnit: {
    fontSize: 9,
    letterSpacing: 0.5,
    textTransform: 'uppercase',
  },
  prDelta: {
    fontSize: 10,
    letterSpacing: 0.5,
    textTransform: 'uppercase',
  },
  prFooter: {
    flexDirection: 'row',
  },
  prDismissBtn: {
    flex: 1,
    height: 50,
    alignItems: 'center',
    justifyContent: 'center',
  },
  prDismissLabel: {
    fontSize: 13,
    letterSpacing: 1,
  },
  prShareBtn: {
    flex: 1.4,
    height: 50,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 0,
  },
  prShareLabel: {
    fontSize: 13,
    letterSpacing: 1,
  },

  // ── G: RenameModal
  renameCard: {
    width: '88%',
    maxWidth: 380,
    borderRadius: 14,
    borderWidth: 1,
    overflow: 'hidden',
  },
  renameHeader: {
    padding: 18,
    gap: 6,
    paddingBottom: 12,
  },
  renameKicker: {
    fontSize: 9,
    letterSpacing: 1.5,
    textTransform: 'uppercase',
  },
  renameTitle: {
    fontSize: 18,
  },
  renameBody: {
    paddingHorizontal: 18,
    paddingBottom: 8,
    gap: 6,
  },
  renameFieldLabel: {
    fontSize: 8,
    letterSpacing: 1.5,
    textTransform: 'uppercase',
  },
  renameInput: {
    height: 46,
    borderRadius: 10,
    borderWidth: 1.5,
    paddingHorizontal: 14,
    fontSize: 15,
  },
  renameCharCount: {
    fontSize: 9,
    textAlign: 'right',
    letterSpacing: 0.5,
  },
});
