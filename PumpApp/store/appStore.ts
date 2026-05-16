import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';

export interface UserProfile {
  name: string;
  weight: string;
  weightUnit: 'kg' | 'lbs';
  height: string;
  heightUnit: 'cm' | 'ft/in';
  heightFt?: string;
  heightIn?: string;
  age: number;
  gender: 'male' | 'female' | 'other' | 'skip';
  experience: 'beginner' | 'intermediate' | 'experienced';
  split: string;
  tutorial: boolean;
  avatar?: string;
  handle?: string;
  program?: string;
}

export interface SetLog {
  id: string;
  type: 'STD' | 'WU' | 'DROP' | 'AMRAP' | 'SS' | 'RP' | 'FAIL' | 'UNI';
  weight: string;
  reps: string;
  rir: string;
  completed: boolean;
  prevWeight?: string;
  prevReps?: string;
}

export interface ExerciseLog {
  id: string;
  exerciseId: string;
  name: string;
  muscleGroups: string[];
  sets: SetLog[];
  notes?: string;
  collapsed?: boolean;
}

export interface Workout {
  id: string;
  name: string;
  startedAt: number;
  completedAt?: number;
  isDraft: boolean;
  exercises: ExerciseLog[];
  totalSets: number;
  totalVolume: number;
  calories?: number;
  notes?: string;
  musclesWorked?: string[];
  prs?: string[];
}

export interface Exercise {
  id: string;
  name: string;
  category: string;
  equipment: string;
  muscleGroups: string[];
  isCustom?: boolean;
}

export interface TemplateSet {
  type: 'STD' | 'WU' | 'DROP' | 'AMRAP' | 'SS' | 'RP' | 'FAIL' | 'UNI';
  targetReps?: number;
  rir?: number;
}

export interface TemplateExercise {
  exerciseId: string;
  name: string;
  sets: TemplateSet[];
  muscleGroups: string[];
}

export interface TemplateDay {
  id: string;
  label: string;
  exercises: TemplateExercise[];
}

export interface WorkoutTemplate {
  id: string;
  name: string;
  splitType: string;
  days: TemplateDay[];
  createdAt: number;
  isPreset?: boolean;
}

export interface FeedPost {
  id: string;
  userId: string;
  username: string;
  handle: string;
  workout: Workout;
  caption?: string;
  reactions: Record<string, number>;
  comments: Comment[];
  createdAt: number;
}

export interface Comment {
  id: string;
  userId: string;
  username: string;
  text: string;
  createdAt: number;
}

interface AppState {
  onboardingComplete: boolean;
  profile: UserProfile | null;
  workouts: Workout[];
  draftWorkout: Workout | null;
  templates: WorkoutTemplate[];
  exercises: Exercise[];
  feedPosts: FeedPost[];
  streak: number;
  lastFeedFetch: number | null;

  setOnboardingComplete: (v: boolean) => void;
  setProfile: (p: UserProfile) => void;
  setDraftWorkout: (w: Workout | null) => void;
  addWorkout: (w: Workout) => void;
  addTemplate: (t: WorkoutTemplate) => void;
  updateTemplate: (t: WorkoutTemplate) => void;
  deleteTemplate: (id: string) => void;
  addExercise: (e: Exercise) => void;
  setFeedPosts: (posts: FeedPost[]) => void;
  setLastFeedFetch: (t: number) => void;
  computeStreak: () => number;
}

const SEED_EXERCISES: Exercise[] = [
  { id: 'e1', name: 'Bench Press', category: 'Push', equipment: 'Barbell', muscleGroups: ['chest', 'triceps', 'shoulders'] },
  { id: 'e2', name: 'Squat', category: 'Legs', equipment: 'Barbell', muscleGroups: ['quads', 'glutes', 'hamstrings'] },
  { id: 'e3', name: 'Deadlift', category: 'Pull', equipment: 'Barbell', muscleGroups: ['back', 'glutes', 'hamstrings'] },
  { id: 'e4', name: 'Overhead Press', category: 'Push', equipment: 'Barbell', muscleGroups: ['shoulders', 'triceps'] },
  { id: 'e5', name: 'Pull-up', category: 'Pull', equipment: 'Bodyweight', muscleGroups: ['back', 'biceps'] },
  { id: 'e6', name: 'Barbell Row', category: 'Pull', equipment: 'Barbell', muscleGroups: ['back', 'biceps'] },
  { id: 'e7', name: 'Dumbbell Curl', category: 'Isolation', equipment: 'Dumbbell', muscleGroups: ['biceps'] },
  { id: 'e8', name: 'Tricep Pushdown', category: 'Isolation', equipment: 'Cable', muscleGroups: ['triceps'] },
  { id: 'e9', name: 'Leg Press', category: 'Legs', equipment: 'Machine', muscleGroups: ['quads', 'glutes'] },
  { id: 'e10', name: 'Romanian Deadlift', category: 'Hinge', equipment: 'Barbell', muscleGroups: ['hamstrings', 'glutes'] },
  { id: 'e11', name: 'Incline Dumbbell Press', category: 'Push', equipment: 'Dumbbell', muscleGroups: ['chest', 'triceps'] },
  { id: 'e12', name: 'Lat Pulldown', category: 'Pull', equipment: 'Cable', muscleGroups: ['back', 'biceps'] },
  { id: 'e13', name: 'Cable Fly', category: 'Isolation', equipment: 'Cable', muscleGroups: ['chest'] },
  { id: 'e14', name: 'Face Pull', category: 'Pull', equipment: 'Cable', muscleGroups: ['shoulders', 'traps'] },
  { id: 'e15', name: 'Hip Thrust', category: 'Hinge', equipment: 'Barbell', muscleGroups: ['glutes'] },
  { id: 'e16', name: 'Leg Curl', category: 'Isolation', equipment: 'Machine', muscleGroups: ['hamstrings'] },
  { id: 'e17', name: 'Calf Raise', category: 'Isolation', equipment: 'Machine', muscleGroups: ['calves'] },
  { id: 'e18', name: 'Dumbbell Shoulder Press', category: 'Push', equipment: 'Dumbbell', muscleGroups: ['shoulders'] },
  { id: 'e19', name: 'Dips', category: 'Push', equipment: 'Bodyweight', muscleGroups: ['chest', 'triceps'] },
  { id: 'e20', name: 'Plank', category: 'Core', equipment: 'Bodyweight', muscleGroups: ['core'] },
];

export const useAppStore = create<AppState>()(
  persist(
    (set, get) => ({
      onboardingComplete: false,
      profile: null,
      workouts: [],
      draftWorkout: null,
      templates: [],
      exercises: SEED_EXERCISES,
      feedPosts: [],
      streak: 0,
      lastFeedFetch: null,

      setOnboardingComplete: (v) => set({ onboardingComplete: v }),
      setProfile: (p) => set({ profile: p }),
      setDraftWorkout: (w) => set({ draftWorkout: w }),
      addWorkout: (w) => set((s) => ({ workouts: [w, ...s.workouts], draftWorkout: null })),
      addTemplate: (t) => set((s) => ({ templates: [...s.templates, t] })),
      updateTemplate: (t) => set((s) => ({ templates: s.templates.map((x) => (x.id === t.id ? t : x)) })),
      deleteTemplate: (id) => set((s) => ({ templates: s.templates.filter((x) => x.id !== id) })),
      addExercise: (e) => set((s) => ({ exercises: [...s.exercises, e] })),
      setFeedPosts: (posts) => set({ feedPosts: posts }),
      setLastFeedFetch: (t) => set({ lastFeedFetch: t }),
      computeStreak: () => {
        const workouts = get().workouts;
        if (workouts.length === 0) return 0;
        const days = [...new Set(workouts.map((w) => new Date(w.completedAt || w.startedAt).toDateString()))];
        const sorted = days.sort((a, b) => new Date(b).getTime() - new Date(a).getTime());
        let streak = 0;
        let cursor = new Date();
        cursor.setHours(0, 0, 0, 0);
        for (const day of sorted) {
          const d = new Date(day);
          d.setHours(0, 0, 0, 0);
          const diff = (cursor.getTime() - d.getTime()) / 86400000;
          if (diff <= 3) {
            streak++;
            cursor = d;
          } else {
            break;
          }
        }
        return streak;
      },
    }),
    {
      name: 'pump-app-storage',
      storage: createJSONStorage(() => AsyncStorage),
    }
  )
);
