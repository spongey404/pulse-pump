import { Redirect } from 'expo-router';
import { useAppStore } from '../store/appStore';

export default function Index() {
  const onboardingComplete = useAppStore((s) => s.onboardingComplete);
  return <Redirect href={onboardingComplete ? '/(tabs)' : '/onboarding'} />;
}
