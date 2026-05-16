import { useRouter } from 'expo-router';
import React, { useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, { Path, Rect, Circle, Polygon } from 'react-native-svg';
import { useAppStore, UserProfile } from '../../store/appStore';

// ── Design tokens (onboarding is always light) ─────────────────
const BG = '#fbf8f2';
const SURF = '#f4f0e6';
const SURF2 = '#ece7d8';
const INK = '#1f1c19';
const MUTED = 'rgba(31,28,25,0.5)';
const FAINT = 'rgba(31,28,25,0.13)';
const HAIR = 'rgba(31,28,25,0.08)';
const HAIR2 = 'rgba(31,28,25,0.13)';
const ACCENT = '#c8553d';
const ACCENT_SOFT = 'rgba(200,85,61,0.08)';

const F = {
  light: 'Archivo-Light',
  regular: 'Archivo-Regular',
  medium: 'Archivo-Medium',
  semiBold: 'Archivo-SemiBold',
  bold: 'Archivo-Bold',
  black: 'Archivo-Black',
  mono: 'SpaceMono-Regular',
  monoBold: 'SpaceMono-Bold',
};

const TOTAL_STEPS = 8;

type Screen = 'auth' | 'name' | 'weight' | 'height' | 'age' | 'gender' | 'experience' | 'split' | 'tutorial';

// ── Shared primitives ──────────────────────────────────────────

function ProgressBar({ step, total }: { step: number; total: number }) {
  const pct = `${Math.round((step / total) * 100)}%`;
  return (
    <View style={{ flex: 1, paddingBottom: 6 }}>
      <View style={styles.progressTrack}>
        <View style={[styles.progressFill, { width: `${(step / total) * 100}%` as any }]} />
      </View>
      <View style={styles.progressRow}>
        <Text style={styles.progressLabel}>STEP {step} OF {total}</Text>
        <Text style={styles.progressLabel}>{pct}</Text>
      </View>
    </View>
  );
}

function BackBtn({ onBack }: { onBack?: () => void }) {
  if (!onBack) return <View style={{ width: 36, height: 36 }} />;
  return (
    <Pressable onPress={onBack} style={styles.backBtn}>
      <Text style={styles.backArrow}>‹</Text>
    </Pressable>
  );
}

function PrimaryCTA({
  label = 'CONTINUE',
  onTap,
  disabled = false,
  sub,
}: {
  label?: string;
  onTap: () => void;
  disabled?: boolean;
  sub?: string;
}) {
  const insets = useSafeAreaInsets();
  return (
    <View style={[styles.ctaWrap, { paddingBottom: Math.max(insets.bottom, 20) }]}>
      {sub ? <Text style={styles.ctaSub}>{sub}</Text> : null}
      <Pressable
        onPress={disabled ? undefined : onTap}
        style={[styles.ctaBtn, disabled && styles.ctaBtnDisabled]}
      >
        <Text style={[styles.ctaLabel, disabled && styles.ctaLabelDisabled]}>{label}</Text>
      </Pressable>
    </View>
  );
}

function QHead({ label, title, sub }: { label?: string; title: string; sub?: string }) {
  return (
    <View style={styles.qheadWrap}>
      {label ? <Text style={styles.qheadLabel}>{label}</Text> : null}
      <Text style={styles.qheadTitle}>{title}</Text>
      {sub ? <Text style={styles.qheadSub}>{sub}</Text> : null}
    </View>
  );
}

function UnitToggle({ options, selected, onSelect }: { options: string[]; selected: string; onSelect: (v: string) => void }) {
  return (
    <View style={styles.unitToggle}>
      {options.map((u) => (
        <Pressable
          key={u}
          onPress={() => onSelect(u)}
          style={[styles.unitBtn, selected === u && styles.unitBtnActive]}
        >
          <Text style={[styles.unitBtnLabel, selected === u && styles.unitBtnLabelActive]}>
            {u.toUpperCase()}
          </Text>
        </Pressable>
      ))}
    </View>
  );
}

// ── Auth Screen ────────────────────────────────────────────────

function AuthScreen({ onNext }: { onNext: () => void }) {
  const insets = useSafeAreaInsets();
  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      <View style={styles.authContent}>
        {/* Logo */}
        <View style={styles.authLogo}>
          <View style={styles.logoBox}>
            <Svg width={22} height={22} viewBox="0 0 24 24" fill="none">
              <Path
                d="M3 9.5L12 3l9 6.5V21H3V9.5z"
                stroke="#fff"
                strokeWidth={2}
                strokeLinejoin="round"
                fill="none"
              />
              <Rect x={9} y={14} width={6} height={7} fill="#fff" rx={1} />
            </Svg>
          </View>
          <View>
            <Text style={styles.logoTitle}>PULSE/PUMP</Text>
            <Text style={styles.logoSub}>TRAIN SMARTER</Text>
          </View>
        </View>

        {/* Headline */}
        <Text style={styles.authHeadline}>Your training,{'\n'}quantified.</Text>
        <Text style={styles.authBody}>
          Log workouts, track progress, and let the app predict what you should do next.
        </Text>

        {/* Auth buttons */}
        <View style={styles.authBtns}>
          <Pressable onPress={onNext} style={styles.appleBtn}>
            <Svg width={18} height={18} viewBox="0 0 24 24" fill="none">
              <Path
                d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.7 9.05 7.4c1.35.07 2.29.74 3.08.8 1.18-.24 2.31-.93 3.57-.84 1.51.12 2.65.72 3.4 1.8-3.12 1.87-2.38 5.98.48 7.13-.57 1.39-1.32 2.76-2.54 3.99zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"
                fill="#fff"
              />
            </Svg>
            <Text style={styles.appleBtnLabel}>Continue with Apple</Text>
          </Pressable>
          <Pressable onPress={onNext} style={styles.googleBtn}>
            <Svg width={18} height={18} viewBox="0 0 24 24" fill="none">
              <Path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4" />
              <Path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853" />
              <Path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05" />
              <Path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335" />
            </Svg>
            <Text style={styles.googleBtnLabel}>Continue with Google</Text>
          </Pressable>
          <Pressable onPress={onNext} style={styles.emailBtn}>
            <Svg width={18} height={18} viewBox="0 0 24 24" fill="none">
              <Path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" stroke={MUTED} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
              <Path d="M22 6l-10 7L2 6" stroke={MUTED} strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
            </Svg>
            <Text style={styles.emailBtnLabel}>Use email instead</Text>
          </Pressable>
        </View>

        <Text style={styles.authDisclaimer}>
          By continuing you agree to our Terms of Service and Privacy Policy.
        </Text>
      </View>
    </View>
  );
}

// ── Name Screen ────────────────────────────────────────────────

function NameScreen({ onNext, onBack, step }: { onNext: (d: Partial<UserProfile>) => void; onBack: () => void; step: number }) {
  const [name, setName] = useState('');
  const insets = useSafeAreaInsets();
  return (
    <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
      <View style={[styles.stepHeader, { paddingTop: insets.top + 6 }]}>
        <BackBtn onBack={onBack} />
        <ProgressBar step={step} total={TOTAL_STEPS} />
      </View>
      <View style={styles.stepBody}>
        <QHead label="01 / NAME" title={"What should\nwe call you?"} sub="This is how you'll appear to friends and on your profile." />
        <View style={styles.inputWrap}>
          <TextInput
            value={name}
            onChangeText={setName}
            placeholder="Your name"
            placeholderTextColor={FAINT}
            autoFocus
            style={[styles.nameInput, name ? styles.nameInputActive : undefined]}
          />
          <Text style={styles.inputHint}>FIRST NAME IS FINE · CAN CHANGE LATER</Text>
        </View>
      </View>
      <PrimaryCTA onTap={() => name.trim() && onNext({ name })} disabled={!name.trim()} />
    </KeyboardAvoidingView>
  );
}

// ── Weight Screen ──────────────────────────────────────────────

function WeightScreen({ onNext, onBack, step, data }: { onNext: (d: Partial<UserProfile>) => void; onBack: () => void; step: number; data: Partial<UserProfile> }) {
  const [unit, setUnit] = useState<'kg' | 'lbs'>('kg');
  const [val, setVal] = useState('');
  const insets = useSafeAreaInsets();
  return (
    <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
      <View style={[styles.stepHeader, { paddingTop: insets.top + 6 }]}>
        <BackBtn onBack={onBack} />
        <ProgressBar step={step} total={TOTAL_STEPS} />
      </View>
      <View style={styles.stepBody}>
        <QHead label="02 / BODY" title={`How much do\nyou weigh, ${data.name || ''}?`} sub="Used to estimate calorie burn. Can be updated anytime." />
        <View style={styles.inputWrap}>
          <UnitToggle options={['kg', 'lbs']} selected={unit} onSelect={(u) => setUnit(u as 'kg' | 'lbs')} />
          <View style={styles.bigNumRow}>
            <TextInput
              value={val}
              onChangeText={(t) => setVal(t.replace(/[^0-9.]/g, ''))}
              placeholder="—"
              placeholderTextColor={FAINT}
              keyboardType="decimal-pad"
              style={[styles.bigNumInput, { color: val ? INK : FAINT }]}
            />
            <Text style={styles.bigNumUnit}>{unit.toUpperCase()}</Text>
          </View>
          <View style={styles.bigNumLine} />
          <Text style={styles.inputHint}>TYPICAL RANGE: 50–150KG</Text>
        </View>
      </View>
      <PrimaryCTA onTap={() => val && onNext({ weight: val, weightUnit: unit })} disabled={!val} />
    </KeyboardAvoidingView>
  );
}

// ── Height Screen ──────────────────────────────────────────────

function HeightScreen({ onNext, onBack, step }: { onNext: (d: Partial<UserProfile>) => void; onBack: () => void; step: number }) {
  const [unit, setUnit] = useState<'cm' | 'ft/in'>('cm');
  const [val, setVal] = useState('');
  const [ft, setFt] = useState('');
  const [inches, setInches] = useState('');
  const insets = useSafeAreaInsets();
  const isValid = unit === 'cm' ? !!val : !!ft;
  return (
    <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
      <View style={[styles.stepHeader, { paddingTop: insets.top + 6 }]}>
        <BackBtn onBack={onBack} />
        <ProgressBar step={step} total={TOTAL_STEPS} />
      </View>
      <View style={styles.stepBody}>
        <QHead label="03 / BODY" title="How tall are you?" sub="Used with weight to estimate your baseline metabolism." />
        <View style={styles.inputWrap}>
          <UnitToggle options={['cm', 'ft/in']} selected={unit} onSelect={(u) => setUnit(u as 'cm' | 'ft/in')} />
          {unit === 'cm' ? (
            <>
              <View style={styles.bigNumRow}>
                <TextInput
                  value={val}
                  onChangeText={(t) => setVal(t.replace(/[^0-9]/g, ''))}
                  placeholder="—"
                  placeholderTextColor={FAINT}
                  keyboardType="number-pad"
                  style={[styles.bigNumInput, { color: val ? INK : FAINT }]}
                />
                <Text style={styles.bigNumUnit}>CM</Text>
              </View>
              <View style={styles.bigNumLine} />
            </>
          ) : (
            <View style={{ flexDirection: 'row', gap: 16 }}>
              <View>
                <View style={styles.bigNumRow}>
                  <TextInput value={ft} onChangeText={(t) => setFt(t.replace(/[^0-9]/g, ''))} placeholder="—" placeholderTextColor={FAINT} keyboardType="number-pad" style={[styles.bigNumInputSm, { color: ft ? INK : FAINT }]} />
                  <Text style={styles.bigNumUnit}>FT</Text>
                </View>
                <View style={styles.bigNumLine} />
              </View>
              <View>
                <View style={styles.bigNumRow}>
                  <TextInput value={inches} onChangeText={(t) => setInches(t.replace(/[^0-9]/g, ''))} placeholder="—" placeholderTextColor={FAINT} keyboardType="number-pad" style={[styles.bigNumInputSm, { color: inches ? INK : FAINT }]} />
                  <Text style={styles.bigNumUnit}>IN</Text>
                </View>
                <View style={styles.bigNumLine} />
              </View>
            </View>
          )}
        </View>
      </View>
      <PrimaryCTA onTap={() => onNext({ height: val || ft, heightUnit: unit, heightFt: ft, heightIn: inches })} disabled={!isValid} />
    </KeyboardAvoidingView>
  );
}

// ── Age Screen ─────────────────────────────────────────────────

function AgeScreen({ onNext, onBack, step }: { onNext: (d: Partial<UserProfile>) => void; onBack: () => void; step: number }) {
  const [age, setAge] = useState('');
  const insets = useSafeAreaInsets();
  return (
    <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : 'height'}>
      <View style={[styles.stepHeader, { paddingTop: insets.top + 6 }]}>
        <BackBtn onBack={onBack} />
        <ProgressBar step={step} total={TOTAL_STEPS} />
      </View>
      <View style={styles.stepBody}>
        <QHead label="04 / BODY" title="How old are you?" sub="Used to calibrate calorie estimates. Not shown publicly." />
        <View style={styles.inputWrap}>
          <View style={styles.bigNumRow}>
            <TextInput
              value={age}
              onChangeText={(t) => setAge(t.replace(/[^0-9]/g, ''))}
              placeholder="—"
              placeholderTextColor={FAINT}
              keyboardType="number-pad"
              style={[styles.bigNumInput, { color: age ? INK : FAINT }]}
            />
            <Text style={styles.bigNumUnit}>YRS</Text>
          </View>
          <View style={styles.bigNumLine} />
        </View>
      </View>
      <PrimaryCTA onTap={() => age && onNext({ age: parseInt(age) })} disabled={!age} />
    </KeyboardAvoidingView>
  );
}

// ── Gender Screen ──────────────────────────────────────────────

const GENDER_OPTS = [
  { id: 'male', label: 'Male' },
  { id: 'female', label: 'Female' },
  { id: 'other', label: 'Non-binary / Other' },
  { id: 'skip', label: 'Prefer not to say' },
] as const;

function GenderScreen({ onNext, onBack, step }: { onNext: (d: Partial<UserProfile>) => void; onBack: () => void; step: number }) {
  const [sel, setSel] = useState<string | null>(null);
  const insets = useSafeAreaInsets();
  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      <View style={[styles.stepHeader, { paddingTop: 6 }]}>
        <BackBtn onBack={onBack} />
        <ProgressBar step={step} total={TOTAL_STEPS} />
      </View>
      <View style={styles.stepBody}>
        <QHead label="05 / BODY" title="Which best describes you?" sub="Used only for calorie burn calculations." />
        <View style={styles.radioList}>
          {GENDER_OPTS.map((o) => (
            <Pressable
              key={o.id}
              onPress={() => setSel(o.id)}
              style={[styles.radioRow, sel === o.id && styles.radioRowActive]}
            >
              <View style={[styles.radioCircle, sel === o.id && styles.radioCircleActive]}>
                {sel === o.id && <View style={styles.radioInner} />}
              </View>
              <Text style={[styles.radioLabel, sel === o.id && styles.radioLabelActive]}>{o.label}</Text>
            </Pressable>
          ))}
        </View>
      </View>
      <PrimaryCTA onTap={() => sel && onNext({ gender: sel as UserProfile['gender'] })} disabled={!sel} />
    </View>
  );
}

// ── Experience Screen ──────────────────────────────────────────

const EXP_OPTS = [
  { id: 'beginner', label: 'New to lifting', sub: 'Less than 1 year of consistent training', detail: "We'll guide you through the basics and build your first program." },
  { id: 'intermediate', label: 'Some experience', sub: '1–3 years of consistent training', detail: "You know the lifts. We'll help you track and progress." },
  { id: 'experienced', label: 'Advanced lifter', sub: '3+ years, training with intention', detail: "Minimal setup. Full control. We'll get out of your way." },
] as const;

function ExperienceScreen({ onNext, onBack, step }: { onNext: (d: Partial<UserProfile>) => void; onBack: () => void; step: number }) {
  const [sel, setSel] = useState<string | null>(null);
  const insets = useSafeAreaInsets();
  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      <View style={[styles.stepHeader, { paddingTop: 6 }]}>
        <BackBtn onBack={onBack} />
        <ProgressBar step={step} total={TOTAL_STEPS} />
      </View>
      <View style={styles.stepBody}>
        <QHead label="06 / EXPERIENCE" title="How long have you been lifting?" sub="This shapes how we set up your first program." />
        <View style={styles.radioList}>
          {EXP_OPTS.map((o) => (
            <Pressable
              key={o.id}
              onPress={() => setSel(o.id)}
              style={[styles.expCard, sel === o.id && styles.radioRowActive]}
            >
              <View style={styles.expCardTop}>
                <View style={[styles.radioCircle, sel === o.id && styles.radioCircleActive]}>
                  {sel === o.id && <View style={styles.radioInner} />}
                </View>
                <View style={{ flex: 1, marginLeft: 10 }}>
                  <Text style={[styles.radioLabel, sel === o.id && styles.radioLabelActive]}>{o.label}</Text>
                  <Text style={styles.expCardSub}>{o.sub}</Text>
                </View>
              </View>
              {sel === o.id && <Text style={styles.expCardDetail}>{o.detail}</Text>}
            </Pressable>
          ))}
        </View>
      </View>
      <PrimaryCTA onTap={() => sel && onNext({ experience: sel as UserProfile['experience'] })} disabled={!sel} />
    </View>
  );
}

// ── Split Screen ───────────────────────────────────────────────

const SPLIT_OPTS = [
  { id: 'ppl', label: 'Push / Pull / Legs', sub: '6 DAYS/WK · HIGH FREQUENCY · POPULAR' },
  { id: 'ul', label: 'Upper / Lower', sub: '4 DAYS/WK · BALANCED · GREAT FOR MOST' },
  { id: 'full', label: 'Full Body', sub: '3 DAYS/WK · EFFICIENT · GOOD FOR BEGINNERS' },
  { id: 'bro', label: 'Bro Split', sub: '5 DAYS/WK · ONE MUSCLE/DAY · CLASSIC' },
  { id: 'custom', label: 'Custom', sub: 'DEFINE YOUR OWN DAYS AND FOCUS' },
  { id: 'none', label: 'No fixed split', sub: 'TRAIN WHENEVER · LOG FREELY' },
];

function SplitScreen({ onNext, onBack, step }: { onNext: (d: Partial<UserProfile>) => void; onBack: () => void; step: number }) {
  const [sel, setSel] = useState<string | null>(null);
  const insets = useSafeAreaInsets();
  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      <View style={[styles.stepHeader, { paddingTop: 6 }]}>
        <BackBtn onBack={onBack} />
        <ProgressBar step={step} total={TOTAL_STEPS} />
      </View>
      <View style={[styles.stepBody, { overflow: 'hidden' }]}>
        <QHead label="07 / PROGRAM" title="How do you structure your training?" sub="This sets up your first program template. Change it anytime." />
        <ScrollView style={{ flex: 1 }} contentContainerStyle={[styles.radioList, { paddingBottom: 10 }]} showsVerticalScrollIndicator={false}>
          {SPLIT_OPTS.map((s) => (
            <Pressable
              key={s.id}
              onPress={() => setSel(s.id)}
              style={[styles.splitRow, sel === s.id && styles.radioRowActive]}
            >
              <View style={[styles.radioCircle, sel === s.id && styles.radioCircleActive]}>
                {sel === s.id && <View style={styles.radioInner} />}
              </View>
              <View style={{ flex: 1, marginLeft: 12 }}>
                <Text style={[styles.splitLabel, sel === s.id && styles.radioLabelActive]}>{s.label}</Text>
                <Text style={styles.splitSub}>{s.sub}</Text>
              </View>
            </Pressable>
          ))}
        </ScrollView>
      </View>
      <PrimaryCTA onTap={() => sel && onNext({ split: sel })} disabled={!sel} />
    </View>
  );
}

// ── Tutorial Screen ────────────────────────────────────────────

function TutorialScreen({ onNext, onBack, step, data }: { onNext: (d: Partial<UserProfile>) => void; onBack: () => void; step: number; data: Partial<UserProfile> }) {
  const insets = useSafeAreaInsets();
  const isExperienced = data.experience === 'experienced';
  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      <View style={[styles.stepHeader, { paddingTop: 6 }]}>
        <BackBtn onBack={onBack} />
        <ProgressBar step={step} total={TOTAL_STEPS} />
      </View>
      <View style={styles.tutorialBody}>
        <View style={styles.tutorialIcon}>
          <Svg width={28} height={28} viewBox="0 0 24 24" fill="none">
            <Path d="M20 6L9 17l-5-5" stroke={ACCENT} strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" />
          </Svg>
        </View>
        <View>
          <Text style={styles.tutorialStepLabel}>08 / ALMOST DONE</Text>
          <Text style={styles.tutorialTitle}>
            {isExperienced ? "You're all set." : `Welcome, ${data.name || 'there'}.`}
          </Text>
          <Text style={styles.tutorialBodyText}>
            {isExperienced
              ? "We've set up a basic template based on your split. You know the drill — start logging and the app learns your patterns."
              : 'Your program is ready. Want a quick tour of the key features before you start?'}
          </Text>
        </View>
        {isExperienced ? (
          <Pressable onPress={() => onNext({ tutorial: false })} style={styles.ctaBtn}>
            <Text style={styles.ctaLabel}>START TRAINING</Text>
          </Pressable>
        ) : (
          <View style={{ gap: 10 }}>
            <Pressable onPress={() => onNext({ tutorial: true })} style={styles.ctaBtn}>
              <Text style={styles.ctaLabel}>YES, SHOW ME AROUND</Text>
            </Pressable>
            <Pressable onPress={() => onNext({ tutorial: false })} style={styles.skipBtn}>
              <Text style={styles.skipBtnLabel}>SKIP, I'LL EXPLORE MYSELF</Text>
            </Pressable>
          </View>
        )}
        <Text style={styles.tutorialFootnote}>TUTORIAL ALWAYS AVAILABLE IN MORE → HELP</Text>
      </View>
    </View>
  );
}

// ── Flow ───────────────────────────────────────────────────────

export default function OnboardingScreen() {
  const router = useRouter();
  const setOnboardingComplete = useAppStore((s) => s.setOnboardingComplete);
  const setProfile = useAppStore((s) => s.setProfile);

  const [screen, setScreen] = useState<Screen>('auth');
  const [data, setData] = useState<Partial<UserProfile>>({});
  const [history, setHistory] = useState<Screen[]>([]);

  const go = (next: Screen, newData: Partial<UserProfile> = {}) => {
    setHistory((h) => [...h, screen]);
    setData((d) => ({ ...d, ...newData }));
    setScreen(next);
  };

  const back = () => {
    const prev = history[history.length - 1];
    if (prev) { setHistory((h) => h.slice(0, -1)); setScreen(prev); }
  };

  const finish = (newData: Partial<UserProfile> = {}) => {
    const finalData = { ...data, ...newData } as UserProfile;
    setProfile(finalData);
    setOnboardingComplete(true);
    router.replace('/(tabs)');
  };

  if (screen === 'auth') return <AuthScreen onNext={() => go('name')} />;
  if (screen === 'name') return <NameScreen onNext={(d) => go('weight', d)} onBack={back} step={1} />;
  if (screen === 'weight') return <WeightScreen onNext={(d) => go('height', d)} onBack={back} step={2} data={data} />;
  if (screen === 'height') return <HeightScreen onNext={(d) => go('age', d)} onBack={back} step={3} />;
  if (screen === 'age') return <AgeScreen onNext={(d) => go('gender', d)} onBack={back} step={4} />;
  if (screen === 'gender') return <GenderScreen onNext={(d) => go('experience', d)} onBack={back} step={5} />;
  if (screen === 'experience') return <ExperienceScreen onNext={(d) => go('split', d)} onBack={back} step={6} />;
  if (screen === 'split') return <SplitScreen onNext={(d) => go('tutorial', d)} onBack={back} step={7} />;
  if (screen === 'tutorial') return <TutorialScreen onNext={finish} onBack={back} step={8} data={data} />;
  return null;
}

// ── Styles ─────────────────────────────────────────────────────

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: BG },
  stepHeader: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 10,
    paddingHorizontal: 20,
    paddingBottom: 8,
  },
  stepBody: { flex: 1, paddingTop: 12 },
  progressTrack: { height: 2, backgroundColor: HAIR, borderRadius: 999, overflow: 'hidden' },
  progressFill: { height: '100%', backgroundColor: ACCENT, borderRadius: 999 },
  progressRow: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 5 },
  progressLabel: { fontFamily: F.mono, fontSize: 8, color: MUTED, letterSpacing: 1 },
  backBtn: {
    width: 36,
    height: 36,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 8,
    backgroundColor: SURF2,
  },
  backArrow: { fontFamily: F.regular, fontSize: 22, color: MUTED, lineHeight: 24 },
  ctaWrap: { paddingHorizontal: 20, paddingTop: 10, backgroundColor: BG },
  ctaSub: { fontFamily: F.regular, fontSize: 11, color: MUTED, textAlign: 'center', marginBottom: 10, lineHeight: 16 },
  ctaBtn: {
    height: 52,
    borderRadius: 12,
    backgroundColor: ACCENT,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ctaBtnDisabled: { backgroundColor: SURF2 },
  ctaLabel: { fontFamily: F.black, fontSize: 22, letterSpacing: 2, color: '#fff' },
  ctaLabelDisabled: { color: MUTED },
  qheadWrap: { paddingHorizontal: 20, paddingBottom: 20, paddingTop: 6 },
  qheadLabel: { fontFamily: F.mono, fontSize: 9, color: MUTED, letterSpacing: 1.5, marginBottom: 8 },
  qheadTitle: { fontFamily: F.light, fontSize: 30, color: INK, letterSpacing: -0.5, lineHeight: 34 },
  qheadSub: { fontFamily: F.regular, fontSize: 13, color: MUTED, marginTop: 8, lineHeight: 19 },
  unitToggle: {
    flexDirection: 'row',
    backgroundColor: SURF2,
    borderRadius: 8,
    padding: 3,
    gap: 2,
    width: 140,
    marginBottom: 16,
  },
  unitBtn: { flex: 1, height: 30, borderRadius: 6, alignItems: 'center', justifyContent: 'center' },
  unitBtnActive: { backgroundColor: BG },
  unitBtnLabel: { fontFamily: F.monoBold, fontSize: 10, color: MUTED, letterSpacing: 0.8 },
  unitBtnLabelActive: { color: ACCENT },
  inputWrap: { paddingHorizontal: 20, flex: 1 },
  nameInput: {
    width: '100%',
    height: 54,
    backgroundColor: SURF2,
    borderWidth: 1,
    borderColor: HAIR2,
    borderRadius: 12,
    paddingHorizontal: 16,
    fontFamily: F.black,
    fontSize: 24,
    letterSpacing: 0.5,
    color: INK,
  },
  nameInputActive: { borderColor: ACCENT },
  inputHint: { fontFamily: F.mono, fontSize: 9, color: MUTED, letterSpacing: 0.8, marginTop: 8 },
  bigNumRow: { flexDirection: 'row', alignItems: 'flex-end', gap: 6 },
  bigNumInput: {
    width: 160,
    fontFamily: F.black,
    fontSize: 72,
    letterSpacing: -1,
    padding: 0,
    lineHeight: 80,
  },
  bigNumInputSm: {
    width: 80,
    fontFamily: F.black,
    fontSize: 64,
    letterSpacing: -1,
    padding: 0,
    lineHeight: 72,
  },
  bigNumUnit: { fontFamily: F.black, fontSize: 28, color: MUTED, letterSpacing: 0.5, paddingBottom: 8 },
  bigNumLine: { height: 1, backgroundColor: HAIR, marginTop: 4, marginBottom: 12 },
  radioList: { paddingHorizontal: 20, gap: 8 },
  radioRow: {
    height: 52,
    borderRadius: 12,
    backgroundColor: SURF2,
    borderWidth: 1,
    borderColor: HAIR2,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    gap: 12,
  },
  radioRowActive: { backgroundColor: ACCENT_SOFT, borderColor: ACCENT },
  radioCircle: {
    width: 18,
    height: 18,
    borderRadius: 9,
    borderWidth: 2,
    borderColor: FAINT,
    alignItems: 'center',
    justifyContent: 'center',
    flexShrink: 0,
  },
  radioCircleActive: { borderColor: ACCENT, backgroundColor: ACCENT },
  radioInner: { width: 6, height: 6, borderRadius: 3, backgroundColor: '#fff' },
  radioLabel: { fontFamily: F.regular, fontSize: 15, color: INK },
  radioLabelActive: { fontFamily: F.semiBold, color: ACCENT },
  expCard: {
    borderRadius: 12,
    backgroundColor: SURF2,
    borderWidth: 1,
    borderColor: HAIR2,
    padding: 14,
    paddingHorizontal: 16,
  },
  expCardTop: { flexDirection: 'row', alignItems: 'center' },
  expCardSub: { fontFamily: F.mono, fontSize: 9, color: MUTED, letterSpacing: 0.5, marginTop: 2 },
  expCardDetail: { fontFamily: F.regular, fontSize: 12, color: MUTED, marginTop: 10, paddingLeft: 28, lineHeight: 18 },
  splitRow: {
    height: 56,
    borderRadius: 12,
    backgroundColor: SURF2,
    borderWidth: 1,
    borderColor: HAIR2,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
  },
  splitLabel: { fontFamily: F.medium, fontSize: 14, color: INK },
  splitSub: { fontFamily: F.mono, fontSize: 8, color: MUTED, letterSpacing: 0.5, marginTop: 1 },
  tutorialBody: { flex: 1, justifyContent: 'center', paddingHorizontal: 24, gap: 24 },
  tutorialIcon: {
    width: 56,
    height: 56,
    borderRadius: 16,
    backgroundColor: ACCENT_SOFT,
    borderWidth: 1,
    borderColor: ACCENT + '44',
    alignItems: 'center',
    justifyContent: 'center',
  },
  tutorialStepLabel: { fontFamily: F.mono, fontSize: 9, color: MUTED, letterSpacing: 1.5, marginBottom: 8 },
  tutorialTitle: { fontFamily: F.light, fontSize: 32, color: INK, letterSpacing: -0.5, lineHeight: 36, marginBottom: 10 },
  tutorialBodyText: { fontFamily: F.regular, fontSize: 13, color: MUTED, lineHeight: 21 },
  skipBtn: {
    height: 52,
    borderRadius: 12,
    backgroundColor: SURF,
    borderWidth: 1,
    borderColor: HAIR2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  skipBtnLabel: { fontFamily: F.black, fontSize: 13, letterSpacing: 1.5, color: MUTED },
  tutorialFootnote: { fontFamily: F.mono, fontSize: 9, color: FAINT, letterSpacing: 0.8, textAlign: 'center' },
  // Auth
  authContent: { flex: 1, justifyContent: 'center', paddingHorizontal: 24, paddingBottom: 40 },
  authLogo: { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 48 },
  logoBox: {
    width: 44,
    height: 44,
    borderRadius: 12,
    backgroundColor: ACCENT,
    alignItems: 'center',
    justifyContent: 'center',
  },
  logoTitle: { fontFamily: F.black, fontSize: 20, color: INK, letterSpacing: 1, lineHeight: 22 },
  logoSub: { fontFamily: F.mono, fontSize: 9, color: MUTED, letterSpacing: 1.5 },
  authHeadline: { fontFamily: F.light, fontSize: 36, color: INK, letterSpacing: -1, lineHeight: 40, marginBottom: 8 },
  authBody: { fontFamily: F.regular, fontSize: 14, color: MUTED, marginBottom: 44, lineHeight: 21 },
  authBtns: { gap: 10 },
  appleBtn: {
    height: 52,
    borderRadius: 12,
    backgroundColor: INK,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
  },
  appleBtnLabel: { fontFamily: F.semiBold, fontSize: 15, color: BG },
  googleBtn: {
    height: 52,
    borderRadius: 12,
    backgroundColor: SURF,
    borderWidth: 1,
    borderColor: HAIR2,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
  },
  googleBtnLabel: { fontFamily: F.medium, fontSize: 15, color: INK },
  emailBtn: {
    height: 52,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: HAIR2,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
  },
  emailBtnLabel: { fontFamily: F.medium, fontSize: 15, color: MUTED },
  authDisclaimer: { marginTop: 20, fontFamily: F.regular, fontSize: 11, color: FAINT, textAlign: 'center', lineHeight: 16 },
});
