import { useColorScheme } from 'react-native';
import { Colors, Fonts, Radii, Spacing, type ThemeColors } from '../constants/theme';

export function useTheme() {
  const scheme = useColorScheme();
  const isDark = scheme === 'dark';
  const C: ThemeColors = isDark ? Colors.dark : Colors.light;
  return { C, isDark, Fonts, Radii, Spacing };
}
