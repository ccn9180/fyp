import { useState, useEffect } from 'react';
import { collection, getDocs, onSnapshot, query, orderBy, limit, where, collectionGroup } from 'firebase/firestore';
import { db } from '../firebase';

/**
 * Generic hook: subscribe to a Firestore collection in real-time.
 * @param {string} col - Collection name
 * @param {Array}  constraints - Optional Firestore query constraints
 */
export function useCollection(col, constraints = []) {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const q = query(collection(db, col), ...constraints);
    const unsub = onSnapshot(
      q,
      (snap) => {
        setData(snap.docs.map(d => ({ id: d.id, ...d.data() })));
        setLoading(false);
      },
      (err) => { setError(err.message); setLoading(false); }
    );
    return () => unsub();
  }, [col]);

  return { data, loading, error };
}

/**
 * Generic hook: subscribe to a Firestore collection group in real-time.
 */
export function useCollectionGroup(col, constraints = []) {
  const [data, setData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const q = query(collectionGroup(db, col), ...constraints);
    const unsub = onSnapshot(
      q,
      (snap) => {
        setData(snap.docs.map(d => ({ id: d.id, parentId: d.ref.parent.parent?.id, ...d.data() })));
        setLoading(false);
      },
      (err) => { setError(err.message); setLoading(false); }
    );
    return () => unsub();
  }, [col]);

  return { data, loading, error };
}

/**
 * Hook: fetch all users (collection: 'users')
 */
export function useUsers() {
  return useCollection('users');
}

/**
 * Hook: fetch counsellor applications (collection: 'counsellor_applications')
 */
export function useCounsellorApplications() {
  return useCollection('counsellor_applications');
}

/**
 * Hook: fetch deactivation requests (collection: 'deactivation_requests')
 */
export function useDeactivationRequests() {
  return useCollection('deactivation_requests');
}

/**
 * Hook: fetch counsellor bookings (collection: 'counsellor_bookings')
 */
export function useCounsellorBookings() {
  return useCollection('counsellor_bookings');
}

/**
 * Hook: fetch articles (collection: 'articles')
 */
export function useArticles() {
  return useCollection('articles');
}

/**
 * Hook: fetch meditation guides (collection: 'meditation_guides')
 */
export function useMeditationGuides() {
  return useCollection('meditation_guides');
}

/**
 * Hook: fetch categories (collection: 'categories')
 */
export function useCategories() {
  return useCollection('categories');
}

/**
 * Hook: fetch vouchers (collection: 'vouchers')
 */
export function useVouchers() {
  return useCollection('vouchers');
}

/**
 * Hook: fetch XP acquisition rules (collection: 'xp_rules')
 */
export function useXPRules() {
  return useCollection('xp_rules', [orderBy('xp', 'desc')]);
}

/**
 * Hook: fetch badge milestones (collection: 'badges')
 */
export function useBadges() {
  return useCollection('badges', [orderBy('xp', 'asc')]);
}

export function useChatSessions() {
  return useCollection('chat_sessions');
}

export function useAllDiaries() {
  const { data, loading, error } = useCollectionGroup('diary_entries');
  const MOCK_DIARIES = [
    {
      id: 'mock_diary_1',
      parentId: 'u1',
      userName: 'Alex Wong',
      timestamp: { toDate: () => new Date(Date.now() - 1000 * 60 * 60 * 5) },
      isCrisis: true,
      mood: 'Despair',
      content: 'I have lost all hope. There is no point in continuing anymore.',
    },
    {
      id: 'mock_diary_2',
      parentId: 'u2',
      userName: 'Sarah Jenkins',
      timestamp: { toDate: () => new Date(Date.now() - 1000 * 60 * 60 * 48) },
      isCrisis: true,
      mood: 'Severe Anxiety',
      content: 'Everything is overwhelming. I cannot sleep, I cannot eat. The pressure is too much to handle.',
    }
  ];
  return { data: [...data, ...MOCK_DIARIES], loading, error };
}
/**
 * Hook: fetch all community posts (collection: 'posts')
 */
export function usePosts() {
  return useCollection('posts', [orderBy('timestamp', 'desc')]);
}

/**
 * Hook: fetch all XP logs entries (cross-user) using collection group
 */
export function useAllXPEntries() {
  return useCollectionGroup('entries');
}

/**
 * Hook: fetch all rewards (collection: 'rewards')
 */
export function useRewards() {
  return useCollection('rewards');
}

