import { Routes, Route, Navigate } from 'react-router-dom';
import { useState, useEffect } from 'react';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { doc, getDoc, collection, query, where, getDocs, limit } from 'firebase/firestore';
import { auth, db } from './firebase';
import AdminLayout from './components/AdminLayout.jsx';
import LoginPage from './pages/LoginPage.jsx';
import logo from './assets/leaf.png';
import Dashboard from './pages/Dashboard.jsx';
import Articles from './pages/content/Articles.jsx';
import Meditation from './pages/content/Meditation.jsx';
import Categories from './pages/content/Categories.jsx';
import CounsellorMonitoring from './pages/monitoring/CounsellorMonitoring.jsx';
import CounsellorApplications from './pages/monitoring/CounsellorApplications.jsx';
import ChatbotMonitoring from './pages/monitoring/ChatbotMonitoring.jsx';
import ContentMonitoring from './pages/monitoring/ContentMonitoring.jsx';
import GamificationMonitoring from './pages/monitoring/GamificationMonitoring.jsx';
import Engagement from './pages/gamification/Engagement.jsx';
import AccountSettings from './pages/account/AccountSettings.jsx';
import CrisisCenter from './pages/monitoring/CrisisCenter.jsx';
import CommunityMonitoring from './pages/monitoring/CommunityMonitoring.jsx';

const C = { primary: '#7C9C84', cream: '#F6F5F2', charcoal: '#333' };

function LoadingScreen() {
  return (
    <div style={{ minHeight: '100vh', background: C.cream, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '16px' }}>
      <div style={{ width: '100px', height: '100px', borderRadius: '50%', background: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 10px 40px rgba(124,156,132,0.08)' }}>
        <img src={logo} alt="Logo" style={{ width: '56px', height: '56px' }} />
      </div>
      <p style={{ fontFamily: 'Outfit, sans-serif', fontSize: '14px', color: '#888' }}>Loading Eunoia Admin…</p>
    </div>
  );
}

export default function App() {
  const [user, setUser] = useState(undefined); // undefined = still checking
  const [authError, setAuthError] = useState('');

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (u) => {
      if (u) {
        try {
          // Try fetching by Document ID (Standard)
          const docRef = doc(db, 'users', u.uid);
          const docSnap = await getDoc(docRef);
          let userData = docSnap.exists() ? docSnap.data() : null;

          // Fallback: If not found by ID, search by the 'uid' field (handles auto-generated document IDs)
          if (!userData) {
            const q = query(collection(db, 'users'), where('uid', '==', u.uid), limit(1));
            const querySnap = await getDocs(q);
            if (!querySnap.empty) {
              userData = querySnap.docs[0].data();
            }
          }
          
          if (userData && userData.role === 'admin') {
            setUser(u);
            setAuthError('');
          } else {
            await signOut(auth);
            setUser(null);
            setAuthError('Access Denied. You do not have admin privileges.');
          }
        } catch (error) {
          console.error("Role check error:", error);
          await signOut(auth);
          setUser(null);
          setAuthError('Error verifying privileges.');
        }
      } else {
        setUser(null);
      }
    });
    return () => unsub();
  }, []);

  if (user === undefined) return <LoadingScreen />;
  if (!user) return <LoginPage externalError={authError} />;

  return (
    <AdminLayout onLogout={() => auth.signOut()}>
      <Routes>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/content/articles" element={<Articles />} />
        <Route path="/content/meditation" element={<Meditation />} />
        <Route path="/content/categories" element={<Categories />} />
        <Route path="/monitoring/counsellors" element={<CounsellorMonitoring />} />
        <Route path="/monitoring/applications" element={<CounsellorApplications />} />
        <Route path="/monitoring/chatbot" element={<ChatbotMonitoring />} />
        <Route path="/monitoring/content" element={<ContentMonitoring />} />
        <Route path="/monitoring/gamification" element={<GamificationMonitoring />} />
        <Route path="/monitoring/crisis" element={<CrisisCenter />} />
        <Route path="/gamification/engagement" element={<Engagement />} />
        <Route path="/account" element={<AccountSettings />} />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </AdminLayout>
  );
}
