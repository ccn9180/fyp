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
  const { data, loading, error } = useCollection('chat_sessions');
  const MOCK_CHATS = [
    {
      id: 'mock_chat_1',
      userId: 'u1',
      userName: 'John Doe',
      createdAt: { toDate: () => new Date(Date.now() - 1000 * 60 * 60 * 2) },
      crisisDetected: true,
      crisisKeyword: 'Panic Attack',
      messages: [{ text: 'I feel like I cannot breathe anymore and the walls are closing in.' }],
      status: 'Escalated',
      rating: 4,
    },
    {
      id: 'mock_chat_2',
      userId: 'u2',
      userName: 'Jane Smith',
      createdAt: { toDate: () => new Date(Date.now() - 1000 * 60 * 60 * 24) },
      crisisDetected: true,
      crisisKeyword: 'Self-Harm',
      messages: [{ text: 'I just want to end it all. It hurts too much.' }],
      status: 'Pending Review',
      rating: 5,
    },
    {
      id: 'mock_chat_3',
      userId: 'u3',
      userName: 'Emily Chen',
      createdAt: { toDate: () => new Date(Date.now() - 1000 * 60 * 30) },
      crisisDetected: true,
      crisisKeyword: 'Hopelessness',
      messages: [{ text: 'I don\'t see any way out of this darkness.' }],
      status: 'Escalated',
      rating: 5,
    },
    {
      id: 'mock_chat_4',
      userId: 'u4',
      userName: 'Michael Roberts',
      createdAt: { toDate: () => new Date(Date.now() - 1000 * 60 * 60 * 48) },
      crisisDetected: true,
      crisisKeyword: 'Overdose',
      messages: [{ text: 'I took too many pills, I don\'t know what to do.' }],
      status: 'Escalated',
      rating: 2,
    },
    {
      id: 'mock_chat_5',
      userId: 'u5',
      userName: 'David Lee',
      createdAt: { toDate: () => new Date(Date.now() - 1000 * 60 * 60 * 3) },
      crisisDetected: true,
      crisisKeyword: 'Abuse',
      messages: [{ text: 'He hurt me again and I am scared.' }],
      status: 'Pending Review',
      rating: 3,
    },
    {
      id: 'mock_chat_6',
      userId: 'u6',
      userName: 'Lisa Wong',
      createdAt: { toDate: () => new Date(Date.now() - 1000 * 60 * 60 * 12) },
      crisisDetected: true,
      crisisKeyword: 'Suicide',
      messages: [{ text: 'I am writing my goodbyes now.' }],
      status: 'Escalated',
      rating: 5,
    },
    {
      id: 'mock_chat_7',
      userId: 'u7',
      userName: 'Kevin Hart',
      createdAt: { toDate: () => new Date(Date.now() - 1000 * 60 * 60 * 72) },
      crisisDetected: true,
      crisisKeyword: 'Severe Depression',
      messages: [{ text: 'I literally cannot get out of bed to eat.' }],
      status: 'Resolved',
      rating: 4,
    },
    {
      id: 'mock_chat_8',
      userId: 'u8',
      userName: 'Anna Bella',
      createdAt: { toDate: () => new Date(Date.now() - 1000 * 60 * 60 * 10) },
      crisisDetected: true,
      crisisKeyword: 'Self-Harm',
      messages: [{ text: 'I need to feel something.' }],
      status: 'Pending Review',
      rating: 4,
    },
    {
      id: 'mock_chat_9',
      userId: 'u9',
      userName: 'George King',
      createdAt: { toDate: () => new Date(Date.now() - 1000 * 60 * 60 * 14) },
      crisisDetected: true,
      crisisKeyword: 'Violence',
      messages: [{ text: 'I want to hurt them so badly.' }],
      status: 'Escalated',
      rating: 2,
    },
    {
      id: 'mock_chat_10',
      userId: 'u10',
      userName: 'Sarah Jones',
      createdAt: { toDate: () => new Date(Date.now() - 1000 * 60 * 60 * 5) },
      crisisDetected: true,
      crisisKeyword: 'Panic Attack',
      messages: [{ text: 'My heart is racing, I am dying.' }],
      status: 'Pending Review',
      rating: 5,
    }
  ];
  return { data: [...data, ...MOCK_CHATS], loading, error };
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

