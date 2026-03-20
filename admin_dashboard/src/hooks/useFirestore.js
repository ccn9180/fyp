import { useState, useEffect } from 'react';
import { collection, getDocs, onSnapshot, query, orderBy, limit, where } from 'firebase/firestore';
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
 * Hook: fetch chat/chatbot sessions (collection: 'chat_sessions')
 */
export function useChatSessions() {
  return useCollection('chat_sessions');
}
