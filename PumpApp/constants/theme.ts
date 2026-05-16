export const Colors = {
  light: {
    bg: '#fbf8f2',
    surf: '#f4f0e6',
    surf2: '#ece7d8',
    ink: '#1f1c19',
    ink2: '#3a342d',
    muted: 'rgba(31,28,25,0.5)',
    faint: 'rgba(31,28,25,0.13)',
    hair: 'rgba(31,28,25,0.08)',
    hair2: 'rgba(31,28,25,0.13)',
    accent: '#c8553d',
    accentSoft: 'rgba(200,85,61,0.08)',
    accentDark: '#a83e28',
    up: '#1f8f5a',
    upSoft: 'rgba(31,143,90,0.1)',
    down: '#c0392b',
    pr: '#b8860b',
    prSoft: 'rgba(184,134,11,0.1)',
    tickerBg: '#1a1816',
    tickerText: '#e8e4dc',
    divider: '#e8e4dc',
    white: '#ffffff',
  },
  dark: {
    bg: '#1a1816',
    surf: '#231f1c',
    surf2: '#2e2926',
    ink: '#f0ece4',
    ink2: '#c8c0b4',
    muted: 'rgba(240,236,228,0.5)',
    faint: 'rgba(240,236,228,0.13)',
    hair: 'rgba(240,236,228,0.08)',
    hair2: 'rgba(240,236,228,0.13)',
    accent: '#dc7d4a',
    accentSoft: 'rgba(220,125,74,0.12)',
    accentDark: '#c8553d',
    up: '#2ab870',
    upSoft: 'rgba(42,184,112,0.12)',
    down: '#e05050',
    pr: '#d4a520',
    prSoft: 'rgba(212,165,32,0.12)',
    tickerBg: '#1a1816',
    tickerText: '#e8e4dc',
    divider: '#0e0c0a',
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
