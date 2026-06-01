import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { auth } from './firebase';
import CounsellorLayout from './components/CounsellorLayout';
import Dashboard from './pages/Dashboard';
import Sessions from './pages/Sessions';
import Availability from './pages/Availability';
import SharedInsights from './pages/SharedInsights';
import Performance from './pages/Performance';
import Profile from './pages/Profile';
import Login from './pages/Login';

function App() {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [loggingOut, setLoggingOut] = useState(false);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setUser(currentUser);
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

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
    return <Login />;
  }

  const handleLogout = async () => {
    setLoggingOut(true);
    try {
      // 1 second delay to display the loading page and avoid instant abrupt transition
      await new Promise(resolve => setTimeout(resolve, 1000));
      await signOut(auth);
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
          <Route path="/shared-insights" element={<SharedInsights />} />
          <Route path="/performance" element={<Performance />} />
          <Route path="/profile" element={<Profile />} />
          <Route path="*" element={<Navigate to="/dashboard" />} />
        </Routes>
      </CounsellorLayout>
    </Router>
  );
}

export default App;
