import { Routes, Route, Navigate } from 'react-router-dom';
import { useState, useEffect } from 'react';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { doc, getDoc, collection, query, where, getDocs, limit } from 'firebase/firestore';
import { auth, db } from './firebase';
import AdminLayout from './components/AdminLayout.jsx';
import LoginPage from './pages/LoginPage.jsx';
import ErrorBoundary from './components/ErrorBoundary.jsx';
import logo from './assets/leaf.png';
import Dashboard from './pages/Dashboard.jsx';
import Articles from './pages/content/Articles.jsx';
import Meditation from './pages/content/Meditation.jsx';
import Categories from './pages/content/Categories.jsx';
import CommunityRules from './pages/content/CommunityRules.jsx';
import CounsellorMonitoring from './pages/monitoring/CounsellorMonitoring.jsx';
import CounsellorApplications from './pages/monitoring/CounsellorApplications.jsx';
import ChatbotMonitoring from './pages/monitoring/ChatbotMonitoring.jsx';
import ContentMonitoring from './pages/monitoring/ContentMonitoring.jsx';
import GamificationMonitoring from './pages/monitoring/GamificationMonitoring.jsx';
import Engagement from './pages/gamification/Engagement.jsx';
import AccountSettings from './pages/account/AccountSettings.jsx';
import CrisisCenter from './pages/monitoring/CrisisCenter.jsx';
import CommunityMonitoring from './pages/monitoring/CommunityMonitoring.jsx';
import AddFeed from './pages/monitoring/AddFeed.jsx';
import SystemSettings from './pages/settings/SystemSettings.jsx';

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

function LogoutScreen() {
  return (
    <div style={{ minHeight: '100vh', background: '#F9F6F0', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '16px' }}>
      <style>{`
        @keyframes spin {
          0% { transform: rotate(0deg); }
          100% { transform: rotate(360deg); }
        }
      `}</style>
      <div style={{ 
        width: '40px', 
        height: '40px', 
        border: '3px solid rgba(124, 156, 132, 0.2)', 
        borderTop: '3px solid #7C9C84', 
        borderRadius: '50%', 
        animation: 'spin 0.8s linear infinite' 
      }} />
      <p style={{ fontFamily: 'Outfit, sans-serif', fontSize: '14px', color: '#6a7870', fontWeight: 500 }}>Logging out securely…</p>
    </div>
  );
}

export default function App() {
  const [user, setUser] = useState(undefined); // undefined = still checking
  const [authError, setAuthError] = useState('');
  const [loggingOut, setLoggingOut] = useState(false);

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

          // Fallback 2: If still not found, search by email. This happens if Google Login creates a new Auth UID but the old Firestore document uses the old UID.
          if (!userData && u.email) {
            const qEmail = query(collection(db, 'users'), where('email', '==', u.email), limit(1));
            const querySnapEmail = await getDocs(qEmail);
            if (!querySnapEmail.empty) {
              userData = querySnapEmail.docs[0].data();
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

  const handleLogout = async () => {
    setLoggingOut(true);
    try {
      // 1 second delay to display the loading page and avoid instant abrupt transition
      await new Promise(resolve => setTimeout(resolve, 1000));
      await signOut(auth);
    } catch (error) {
      console.error("Signout error:", error);
    } finally {
      setLoggingOut(false);
    }
  };

  if (loggingOut) return <LogoutScreen />;
  if (user === undefined) return <LoadingScreen />;
  if (!user) return <LoginPage externalError={authError} />;

  return (
    <AdminLayout onLogout={handleLogout}>
      <ErrorBoundary>
        <Routes>
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/content/articles" element={<Articles />} />
          <Route path="/content/meditation" element={<Meditation />} />
          <Route path="/content/categories" element={<Categories />} />
          <Route path="/content/community-rules" element={<CommunityRules />} />
          <Route path="/monitoring/counsellors" element={<CounsellorMonitoring />} />
          <Route path="/monitoring/applications" element={<CounsellorApplications />} />
          <Route path="/monitoring/chatbot" element={<ChatbotMonitoring />} />
          <Route path="/monitoring/content" element={<ContentMonitoring />} />
          <Route path="/monitoring/gamification" element={<GamificationMonitoring />} />
          <Route path="/monitoring/crisis" element={<CrisisCenter />} />
          <Route path="/monitoring/post-feeds" element={<CommunityMonitoring />} />
          <Route path="/monitoring/add-feed" element={<AddFeed />} />
          <Route path="/gamification/engagement" element={<Engagement />} />
          <Route path="/account" element={<AccountSettings />} />
          <Route path="/settings" element={<SystemSettings />} />
          <Route path="*" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </ErrorBoundary>
    </AdminLayout>
  );
}
