import { useFonts } from 'expo-font';
import { Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { useEffect } from 'react';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { ToastProvider } from '../components/modals';
import { useTheme } from '../hooks/useTheme';

SplashScreen.preventAutoHideAsync();

function AppShell() {
  const { C } = useTheme();
  return (
    <ToastProvider C={C}>
      <Stack screenOptions={{ headerShown: false, animation: 'fade' }}>
        <Stack.Screen name="index" />
        <Stack.Screen name="onboarding/index" options={{ animation: 'fade' }} />
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="workout/active" options={{ animation: 'slide_from_bottom', presentation: 'fullScreenModal' }} />
        <Stack.Screen name="workout/complete" options={{ animation: 'slide_from_bottom', presentation: 'modal' }} />
      </Stack>
    </ToastProvider>
  );
}

export default function RootLayout() {
  const [loaded] = useFonts({
    'Archivo-Light': require('../assets/fonts/Archivo-Light.ttf'),
    'Archivo-Regular': require('../assets/fonts/Archivo-Regular.ttf'),
    'Archivo-Medium': require('../assets/fonts/Archivo-Medium.ttf'),
    'Archivo-SemiBold': require('../assets/fonts/Archivo-SemiBold.ttf'),
    'Archivo-Bold': require('../assets/fonts/Archivo-Bold.ttf'),
    'Archivo-ExtraBold': require('../assets/fonts/Archivo-ExtraBold.ttf'),
    'Archivo-Black': require('../assets/fonts/Archivo-Black.ttf'),
    'SpaceMono-Regular': require('../assets/fonts/SpaceMono-Regular.ttf'),
    'SpaceMono-Bold': require('../assets/fonts/SpaceMono-Bold.ttf'),
  });

  useEffect(() => {
    if (loaded) SplashScreen.hideAsync();
  }, [loaded]);

  if (!loaded) return null;

  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <AppShell />
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
