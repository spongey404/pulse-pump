import { Tabs } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '../../hooks/useTheme';
import Svg, { Path, Circle, Rect } from 'react-native-svg';

function TabIcon({ name, focused, color }: { name: string; focused: boolean; color: string }) {
  const s = { width: 22, height: 22, stroke: color, strokeWidth: 1.6, fill: 'none' };
  if (name === 'Programs') return (
    <Svg {...s} viewBox="0 0 24 24">
      <Rect x="4" y="5" width="16" height="14" rx="2" stroke={color} strokeWidth={1.6} fill="none" />
      <Path d="M8 9h8M8 13h8M8 17h5" stroke={color} strokeWidth={1.6} strokeLinecap="round" fill="none" />
    </Svg>
  );
  if (name === 'Social') return (
    <Svg {...s} viewBox="0 0 24 24">
      <Circle cx="9" cy="9" r="3" stroke={color} strokeWidth={1.6} fill="none" />
      <Circle cx="17" cy="11" r="2.5" stroke={color} strokeWidth={1.6} fill="none" />
      <Path d="M3 19c.5-3 3-5 6-5s5.5 2 6 5" stroke={color} strokeWidth={1.6} strokeLinecap="round" fill="none" />
    </Svg>
  );
  if (name === 'Body') return (
    <Svg {...s} viewBox="0 0 24 24">
      <Circle cx="12" cy="5" r="2.2" stroke={color} strokeWidth={1.6} fill="none" />
      <Path d="M8 11l4-3 4 3M12 8v6M9 14l-2 6M15 14l2 6" stroke={color} strokeWidth={1.6} strokeLinecap="round" fill="none" />
    </Svg>
  );
  if (name === 'More') return (
    <Svg {...s} viewBox="0 0 24 24">
      <Circle cx="6" cy="12" r="1.4" fill={color} />
      <Circle cx="12" cy="12" r="1.4" fill={color} />
      <Circle cx="18" cy="12" r="1.4" fill={color} />
    </Svg>
  );
  return null;
}

function HomeTabIcon({ focused, color }: { focused: boolean; color: string }) {
  const { C } = useTheme();
  return (
    <View style={[styles.homeTabIcon, { backgroundColor: C.accent }]}>
      <Svg width={22} height={22} viewBox="0 0 24 24" fill="none">
        <Path
          d="M3.5 12L12 4M12 4L20.5 12M6 13.5v7M18 13.5v7M6 20.5h12M10.5 20.5v-4.5h3v4.5"
          stroke="#fff"
          strokeWidth={1.8}
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </Svg>
    </View>
  );
}

export default function TabLayout() {
  const { C, Fonts } = useTheme();
  const insets = useSafeAreaInsets();

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: {
          backgroundColor: C.bg,
          borderTopColor: C.hair,
          borderTopWidth: 0.5,
          height: 56 + insets.bottom,
          paddingBottom: insets.bottom,
          paddingTop: 8,
        },
        tabBarActiveTintColor: C.ink,
        tabBarInactiveTintColor: C.muted,
        tabBarLabelStyle: {
          fontFamily: Fonts.semiBold,
          fontSize: 10,
          marginTop: 2,
        },
      }}
    >
      <Tabs.Screen
        name="programs"
        options={{
          title: 'Programs',
          tabBarIcon: ({ focused, color }) => <TabIcon name="Programs" focused={focused} color={color} />,
        }}
      />
      <Tabs.Screen
        name="social"
        options={{
          title: 'Social',
          tabBarIcon: ({ focused, color }) => <TabIcon name="Social" focused={focused} color={color} />,
        }}
      />
      <Tabs.Screen
        name="index"
        options={{
          title: 'Home',
          tabBarIcon: ({ focused, color }) => <HomeTabIcon focused={focused} color={color} />,
          tabBarActiveTintColor: C.accent,
          tabBarLabelStyle: {
            fontFamily: Fonts.semiBold,
            fontSize: 10,
            color: C.accent,
          },
        }}
      />
      <Tabs.Screen
        name="body"
        options={{
          title: 'Body',
          tabBarIcon: ({ focused, color }) => <TabIcon name="Body" focused={focused} color={color} />,
        }}
      />
      <Tabs.Screen
        name="more"
        options={{
          title: 'More',
          tabBarIcon: ({ focused, color }) => <TabIcon name="More" focused={focused} color={color} />,
        }}
      />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  homeTabIcon: {
    width: 46,
    height: 46,
    borderRadius: 15,
    alignItems: 'center',
    justifyContent: 'center',
    marginTop: -12,
  },
});
