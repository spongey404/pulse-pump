// Pulse colour system — see design_handoff_pulse_color_system/README.md and
// tokens.json in the "App color system redesign" Claude Design project.
// `accent` is for FILLED surfaces (CTA, tab-bar fill); `accentInk` is for accent
// text/glyphs/borders — it lifts to a brighter blue on the dark canvas so it doesn't
// read as a dim, desaturated ink. `pr` is gone: PR is inkPrimary text + underline, not
// a colour (see signalPR in tokens.json). Amber is reserved for Fuel's over-target signal.
export const Colors = {
  light: {
    bg: '#f9f8f4',
    surf: '#f1efe9',
    surf2: '#e7e4dc',
    ink: '#1c1b18',
    ink2: '#3a342d',
    muted: 'rgba(28,27,24,0.5)',
    faint: 'rgba(28,27,24,0.13)',
    hair: 'rgba(28,27,24,0.08)',
    hair2: 'rgba(28,27,24,0.13)',
    accent: '#0a6fc0',
    accentInk: '#0a6fc0',
    accentSoft: 'rgba(10,111,192,0.08)',
    onAccent: '#ffffff',
    up: '#00aa55',
    upSoft: 'rgba(0,170,85,0.1)',
    down: '#ff3b30',
    tickerBg: '#1a1816',
    tickerText: '#ece5d6',
    divider: 'rgba(28,27,24,0.08)',
    white: '#ffffff',
  },
  dark: {
    bg: '#1a1917',
    surf: '#24221f',
    surf2: '#2d2a26',
    ink: '#eae7df',
    ink2: '#c8c0b4',
    muted: 'rgba(234,231,223,0.5)',
    faint: 'rgba(234,231,223,0.13)',
    hair: 'rgba(234,231,223,0.08)',
    hair2: 'rgba(234,231,223,0.13)',
    accent: '#0a6fc0',
    accentInk: '#4db8ff',
    accentSoft: 'rgba(77,184,255,0.14)',
    onAccent: '#ffffff',
    up: '#00aa55',
    upSoft: 'rgba(0,170,85,0.12)',
    down: '#ff3b30',
    tickerBg: '#1a1816',
    tickerText: '#ece5d6',
    divider: 'rgba(234,231,223,0.08)',
    white: '#ffffff',
  },
};

export const Fonts = {
  light: 'Archivo-Light',
  regular: 'Archivo-Regular',
  medium: 'Archivo-Medium',
  semiBold: 'Archivo-SemiBold',
  bold: 'Archivo-Bold',
  extraBold: 'Archivo-ExtraBold',
  black: 'Archivo-Black',
  mono: 'SpaceMono-Regular',
  monoBold: 'SpaceMono-Bold',
};

export const Radii = {
  chip: 4,
  pill: 6,
  card: 12,
  cardLg: 14,
  input: 12,
  cta: 12,
  avatar: 999,
};

export const Spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 20,
  xxl: 24,
  xxxl: 32,
};

// Plate colors for plate calculator
export const PlateColors: Record<string, string> = {
  '25': '#e51b1b',
  '20': '#1f4ea3',
  '15': '#c98a17',
  '10': '#1f8f5a',
  '5': '#1f1c19',
  '2.5': '#8a8580',
  '1.25': '#e8e0cc',
};

// Set type colors
export const SetTypeColors: Record<string, { bg: string; text: string; border: string }> = {
  STD: { bg: 'transparent', text: '#8a8580', border: '#8a8580' },
  WU: { bg: 'rgba(201,138,23,0.12)', text: '#c98a17', border: '#c98a17' },
  DROP: { bg: 'rgba(229,27,27,0.1)', text: '#e51b1b', border: '#e51b1b' },
  AMRAP: { bg: 'rgba(31,78,163,0.1)', text: '#1f4ea3', border: '#1f4ea3' },
  SS: { bg: 'rgba(100,60,200,0.1)', text: '#6432c8', border: '#6432c8' },
  RP: { bg: 'rgba(31,28,25,0.08)', text: '#3a342d', border: '#3a342d' },
  FAIL: { bg: 'rgba(229,27,27,0.08)', text: '#e51b1b', border: '#e51b1b' },
  UNI: { bg: 'rgba(31,78,163,0.08)', text: '#1f4ea3', border: '#1f4ea3' },
};

export type ThemeColors = typeof Colors.light;
