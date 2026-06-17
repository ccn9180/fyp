import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { doc, getDoc, onSnapshot } from 'firebase/firestore';
import { auth, db } from './firebase';
import CounsellorLayout from './components/CounsellorLayout';
import Dashboard from './pages/Dashboard';
import Sessions from './pages/Sessions';
import Availability from './pages/Availability';
import Performance from './pages/Performance';
import Profile from './pages/Profile';
import Login from './pages/Login';
import Clients from './pages/Clients';
import Wallet from './pages/Wallet';
import Settings from './pages/Settings';
import Notifications from './pages/Notifications';
import SupportPage from './pages/SupportPage';

if (localStorage.getItem('counsellorDarkMode') === 'true') {
  document.body.classList.add('dark-mode');
}

function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loggingOut, setLoggingOut] = useState(false);
  const [unauthorized, setUnauthorized] = useState(false);
  const [showLogoutConfirm, setShowLogoutConfirm] = useState(false);
  const [isMaintenance, setIsMaintenance] = useState(false);

  useEffect(() => {
    const unsubMaintenance = onSnapshot(doc(db, 'system', 'settings'), (snapshot) => {
      if (snapshot.exists() && snapshot.data().maintenanceMode) {
        setIsMaintenance(true);
      } else {
        setIsMaintenance(false);
      }
    });

    const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
      if (currentUser) {
        try {
          const userDoc = await getDoc(doc(db, 'users', currentUser.uid));
          if (userDoc.exists() && userDoc.data().role === 'counsellor') {
            const data = userDoc.data();
            setUser(currentUser);
            setUnauthorized(false);
            if (data.preferences?.darkMode) {
              document.body.classList.add('dark-mode');
              localStorage.setItem('counsellorDarkMode', 'true');
            } else {
              document.body.classList.remove('dark-mode');
              localStorage.setItem('counsellorDarkMode', 'false');
            }
          } else {
            // User is not a counsellor
            await signOut(auth);
            setUser(null);
            setUnauthorized(true);
            document.body.classList.remove('dark-mode');
            localStorage.setItem('counsellorDarkMode', 'false');
          }
        } catch (error) {
          console.error("Error verifying counsellor role:", error);
          await signOut(auth);
          setUser(null);
          document.body.classList.remove('dark-mode');
          localStorage.setItem('counsellorDarkMode', 'false');
        }
      } else {
        setUser(null);
      }
      setLoading(false);
    });
    return () => {
      unsubscribe();
      unsubMaintenance();
    };
  }, []);

  if (isMaintenance) {
    return (
      <div style={{ display: 'flex', minHeight: '100vh', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', backgroundColor: '#F9F6F0', padding: '20px', textAlign: 'center' }}>
        <div style={{ backgroundColor: 'white', padding: '40px', borderRadius: '24px', boxShadow: '0 20px 40px rgba(0,0,0,0.05)', maxWidth: '500px', width: '100%' }}>
          <div style={{ width: '80px', height: '80px', backgroundColor: '#FFF7ED', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 24px auto', color: '#EA580C' }}>
            <svg xmlns="http://www.w3.org/2000/svg" width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>
          </div>
          <h1 style={{ fontFamily: 'Playfair Display, serif', color: '#333', fontSize: '28px', margin: '0 0 16px 0' }}>System Maintenance</h1>
          <p style={{ fontFamily: 'Outfit, sans-serif', color: '#666', fontSize: '16px', lineHeight: '1.6', margin: 0 }}>
            Eunoia is currently undergoing scheduled maintenance. 
            The Counsellor Portal is temporarily unavailable. Please check back later.
          </p>
        </div>
      </div>
    );
  }

  if (loggingOut) {
    return (
      <div style={{ display: 'flex', minHeight: '100vh', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: '16px', background: '#F9F6F0' }}>
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

  if (loading) {
    return <div style={{ display: 'flex', minHeight: '100vh', alignItems: 'center', justifyContent: 'center' }}>Loading...</div>;
  }

  if (!user) {
    return <Login unauthorized={unauthorized} onClearUnauthorized={() => setUnauthorized(false)} />;
  }

  const handleLogout = () => {
    setShowLogoutConfirm(true);
  };

  const confirmLogout = async () => {
    setShowLogoutConfirm(false);
    setLoggingOut(true);
    try {
      // 1 second delay to display the loading page and avoid instant abrupt transition
      await new Promise(resolve => setTimeout(resolve, 1000));
      await signOut(auth);
      document.body.classList.remove('dark-mode');
      localStorage.setItem('counsellorDarkMode', 'false');
    } catch (error) {
      console.error('Signout error:', error);
    } finally {
      setLoggingOut(false);
    }
  };

  return (
    <Router>
      <CounsellorLayout onLogout={handleLogout}>
        <Routes>
          <Route path="/" element={<Navigate to="/dashboard" />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/sessions" element={<Sessions />} />
          <Route path="/availability" element={<Availability />} />
          <Route path="/performance" element={<Performance />} />
          <Route path="/profile" element={<Profile />} />
          <Route path="/clients" element={<Clients />} />
          <Route path="/wallet" element={<Wallet />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="/settings/:type" element={<SupportPage />} />
          <Route path="/notifications" element={<Notifications />} />
          <Route path="*" element={<Navigate to="/dashboard" />} />
        </Routes>
      </CounsellorLayout>

      {/* Logout Confirmation Modal */}
      {showLogoutConfirm && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 9999, backdropFilter: 'blur(4px)' }}>
          <div style={{ backgroundColor: 'var(--bg-card)', padding: '32px', borderRadius: '24px', width: '90%', maxWidth: '400px', boxShadow: '0 20px 40px rgba(0,0,0,0.1)' }}>
            <h3 style={{ margin: '0 0 16px 0', fontFamily: 'var(--font-serif)', fontSize: '24px', color: 'var(--text-darker)' }}>Confirm Log Out</h3>
            <p style={{ margin: '0 0 32px 0', fontFamily: 'var(--font-main)', fontSize: '15px', color: 'var(--text-muted)', lineHeight: '1.5' }}>
              Are you sure you want to securely log out of your Counsellor account? You will need to sign in again to access your clinical dashboard.
            </p>
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
              <button
                onClick={() => setShowLogoutConfirm(false)}
                style={{ padding: '12px 24px', backgroundColor: 'transparent', border: '1px solid var(--border-color)', borderRadius: '12px', color: 'var(--text-darker)', fontWeight: 600, cursor: 'pointer' }}
              >
                Cancel
              </button>
              <button
                onClick={confirmLogout}
                style={{ padding: '12px 24px', backgroundColor: '#ef4444', border: 'none', borderRadius: '12px', color: 'white', fontWeight: 600, cursor: 'pointer', boxShadow: '0 4px 12px rgba(239, 68, 68, 0.2)' }}
              >
                Log Out
              </button>
            </div>
          </div>
        </div>
      )}
    </Router>
  );
}

export default App;
