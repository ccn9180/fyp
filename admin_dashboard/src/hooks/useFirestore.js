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

/**
 * Hook: fetch chat/chatbot sessions (collection: 'chat_sessions')
 */
export function useChatSessions() {
  return useCollection('chat_sessions');
}

/**
 * Hook: fetch all diary entries (cross-user) using collection group
 */
export function useAllDiaries() {
  return useCollectionGroup('diary_entries');
}
/**
 * Hook: fetch all community posts (collection: 'posts')
 */
export function usePosts() {
  return useCollection('posts', [orderBy('timestamp', 'desc')]);
}
