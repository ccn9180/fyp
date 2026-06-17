import React, { useState, useEffect } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard, Calendar, Clock, MessageSquare, TrendingUp, User,
  LogOut, Menu, Bell, ChevronDown, ChevronRight, Users, DollarSign, MessageCircle, Settings, Star
} from 'lucide-react';
import { auth, db } from '../firebase';
import { doc, getDoc, collection, query, where, getDocs, limit, onSnapshot } from 'firebase/firestore';
import logo from '../assets/leaf.png';
import ChatbotWidget from './ChatbotWidget';

const C = { primary: '#7C9C84', cream: '#F9F6F0', creamDarker: '#E5E4E0', charcoal: '#2C3630', muted: '#8A968F' };

const NAV = [
  { label: 'Overview', icon: LayoutDashboard, path: '/dashboard' },
  { type: 'divider' },
  {
    label: 'Management', icon: Calendar, children: [
      { label: 'Client Directory', path: '/clients', icon: Users },
      { label: 'Sessions Schedule', path: '/sessions', icon: Calendar },
      { label: 'Set Time Slot', path: '/availability', icon: Clock },
    ]
  },
  { type: 'divider' },
  {
    label: 'Insights & Earnings', icon: TrendingUp, children: [
      { label: 'Metrics & Performance', path: '/performance', icon: TrendingUp },
      { label: 'Wallet', path: '/wallet', icon: DollarSign }
    ]
  }
];

const S = {
  sidebar: (collapsed) => ({
    width: collapsed ? '64px' : '240px',
    minWidth: collapsed ? '64px' : '240px',
    background: 'var(--bg-card)',
    borderRight: '1px solid var(--border-color)',
    display: 'flex',
    flexDirection: 'column',
    transition: 'width 0.25s ease',
    overflow: 'hidden',
    height: '100vh',
    position: 'fixed',
    left: 0,
    top: 0,
    zIndex: 10,
  }),
  logoIcon: {
    width: '48px', height: '48px', borderRadius: '50%',
    background: '#FFFFFF', display: 'flex', alignItems: 'center',
    justifyContent: 'center', flexShrink: 0,
    border: '1px solid var(--border-color)',
    boxShadow: '0 10px 30px rgba(124,156,132,0.08)',
    overflow: 'hidden',
  },
  nav: { flex: 1, overflowY: 'auto', padding: '12px 8px', display: 'flex', flexDirection: 'column', gap: '2px' },
  navGroup: (isActive) => ({
    display: 'flex', alignItems: 'center', gap: '12px', justifyContent: 'space-between',
    padding: '10px 16px', borderRadius: '12px', width: '100%',
    fontSize: '14px', fontFamily: 'Outfit, sans-serif', fontWeight: isActive ? 600 : 500,
    color: isActive ? 'var(--primary-color)' : 'var(--text-muted)',
    background: isActive ? 'var(--primary-light)' : 'transparent',
    boxShadow: 'none',
    cursor: 'pointer', border: 'none', transition: 'all 0.15s',
    textDecoration: 'none', whiteSpace: 'nowrap',
  }),
  divider: { height: '1px', minHeight: '1px', flexShrink: 0, background: 'var(--border-color)', margin: '12px 16px', opacity: 1 },
  subNav: { display: 'flex', flexDirection: 'column', gap: '2px', marginTop: '4px', marginLeft: '16px', borderLeft: '1px solid rgba(124, 156, 132, 0.2)' },
  subLink: (isActive) => ({
    display: 'flex', alignItems: 'center', gap: '12px',
    padding: '8px 16px', borderRadius: '12px', marginLeft: '8px',
    fontSize: '13px', fontFamily: 'Outfit, sans-serif', fontWeight: isActive ? 600 : 400,
    color: isActive ? 'var(--primary-color)' : '#777777',
    background: isActive ? 'rgba(124, 156, 132, 0.12)' : 'transparent',
    cursor: 'pointer', textDecoration: 'none', transition: 'all 0.15s',
  }),
  topbar: {
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    padding: '14px 24px', background: 'var(--bg-card)', borderBottom: '1px solid var(--border-color)', flexShrink: 0,
    position: 'sticky', top: 0, zIndex: 9,
  },
  topbarTitle: { fontFamily: '"Playfair Display", serif', fontWeight: 600, fontSize: '18px', color: 'var(--text-darker)' },
};

function SidebarGroup({ item, collapsed, setCollapsed }) {
  const [open, setOpen] = useState(true);

  if (item.type === 'divider') {
    return <div style={S.divider} />;
  }

  if (!item.children) {
    return (
      <NavLink 
        to={item.path} 
        style={({ isActive }) => S.navGroup(isActive)}
        className="sidebar-hover"
        onClick={() => { if (collapsed && setCollapsed) setCollapsed(false); }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <item.icon size={19} style={{ flexShrink: 0 }} />
          {!collapsed && item.label}
        </div>
      </NavLink>
    );
  }
  return (
    <div>
      <button 
        onClick={() => {
          if (collapsed && setCollapsed) {
            setOpen(true);
            setCollapsed(false);
          } else {
            setOpen(o => !o);
          }
        }} 
        style={S.navGroup(false)}
        className="sidebar-hover"
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <item.icon size={19} style={{ flexShrink: 0 }} />
          {!collapsed && item.label}
        </div>
        {!collapsed && (open ? <ChevronDown size={19} style={{ flexShrink: 0 }} /> : <ChevronRight size={19} style={{ flexShrink: 0 }} />)}
      </button>
      {open && !collapsed && (
        <div style={S.subNav}>
          {item.children.map(c => (
            <NavLink key={c.path} to={c.path} style={({ isActive }) => S.subLink(isActive)} className="sidebar-hover">
          <c.icon size={19} style={{ flexShrink: 0, opacity: 0.8 }} /> {c.label}
            </NavLink>
          ))}
        </div>
      )}
    </div>
  );
}

export default function CounsellorLayout({ children, onLogout }) {
  const [collapsed, setCollapsed] = useState(false);
  const [counsellorUser, setCounsellorUser] = useState({ name: 'Counsellor', role: 'Therapist', photo: null });
  const [hasUnread, setHasUnread] = useState(false);
  const [showNotify, setShowNotify] = useState(false);
  const [recentNotifications, setRecentNotifications] = useState([]);
  const navigate = useNavigate();

  useEffect(() => {
    const fetchCounsellor = async () => {
      const u = auth.currentUser;
      if (!u) return;
      try {
        let userData = null;
        const docRef = doc(db, 'users', u.uid);
        const docSnap = await getDoc(docRef);
        if (docSnap.exists()) {
          userData = docSnap.data();
        } else {
          const q = query(collection(db, 'users'), where('uid', '==', u.uid), limit(1));
          const querySnap = await getDocs(q);
          if (!querySnap.empty) userData = querySnap.docs[0].data();
        }

        if (userData) {
          setCounsellorUser({
            name: userData.name || userData.fullName || u.displayName || 'Counsellor User',
            role: userData.specialty || (userData.role === 'counsellor' ? 'Therapist' : (userData.role || 'Counsellor')),
            photo: userData.counsellorImageUrl || userData.profileImageUrl || userData.photoUrl || u.photoURL || null
          });
        }
      } catch (e) { console.error(e); }
    };

    let unsubscribeSnap = () => {};
    const unsubscribeAuth = auth.onAuthStateChanged(user => {
      if (user) {
        fetchCounsellor(user);
        
        const q = query(collection(db, 'notifications'), where('to', '==', user.uid));
        unsubscribeSnap = onSnapshot(q, (snap) => {
          let unreadCount = 0;
          const notifList = [];
          snap.forEach(docSnap => {
            const data = docSnap.data();
            const titleLower = data.title ? data.title.toLowerCase() : '';
            const messageLower = data.message ? data.message.toLowerCase() : '';
            if (
              data.type === 'reminder' || 
              data.type === 'daily_checkin' ||
              data.type === 'checkin' ||
              titleLower.includes('daily reminder') || 
              titleLower.includes('daily checkin') || 
              titleLower.includes('daily check-in') ||
              titleLower.includes('daily check in') ||
              titleLower.includes('comment') ||
              titleLower.includes('post') ||
              titleLower.includes('test') ||
              titleLower.includes('friend request') ||
              titleLower.includes('connection request') ||
              titleLower.includes('support resources') ||
              titleLower.includes('share') ||
              titleLower.includes('like') ||
              titleLower.includes('level') ||
              titleLower.includes('badge') ||
              messageLower.includes('friend request') ||
              messageLower.includes('connection request') ||
              messageLower.includes('support resources') ||
              messageLower.includes('share') ||
              messageLower.includes('like')
            ) return;
            
            if (!data.isRead) unreadCount++;
            
            notifList.push({
              id: docSnap.id,
              ...data,
              timestamp: data.timestamp?.toDate ? data.timestamp.toDate() : new Date()
            });
          });
          
          notifList.sort((a, b) => b.timestamp - a.timestamp);
          setRecentNotifications(notifList.slice(0, 5));
          setHasUnread(unreadCount > 0);
        });
      } else {
        setHasUnread(false);
        unsubscribeSnap();
      }
    });

    return () => {
      unsubscribeAuth();
      unsubscribeSnap();
    };
  }, []);

  return (
    <div style={{ display: 'flex', height: '100vh', overflow: 'hidden', background: 'var(--bg-main)' }}>
      
      {/* Collapsible Sidebar */}
      <aside style={S.sidebar(collapsed)}>
        <div style={{
          padding: collapsed ? '28px 8px' : '28px 20px',
          display: 'flex',
          flexDirection: collapsed ? 'column' : 'row',
          alignItems: 'center',
          justifyContent: collapsed ? 'center' : 'space-between',
          gap: collapsed ? '16px' : '0px',
          borderBottom: collapsed ? 'none' : `1px solid var(--border-color)`,
          marginBottom: '10px'
        }}>
          <div 
            onClick={() => { if (collapsed) setCollapsed(false); }}
            style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            justifyContent: collapsed ? 'center' : 'flex-start',
            cursor: collapsed ? 'pointer' : 'default',
            padding: '4px',
            borderRadius: '8px'
          }}
          >
            <div style={{
              ...S.logoIcon,
              width: collapsed ? '40px' : '48px',
              height: collapsed ? '40px' : '48px',
            }}>
              <img src={logo} alt="Logo" style={{ width: '75%', height: '75%', objectFit: 'contain' }} />
            </div>
            {!collapsed && (
              <div>
                <p style={{ margin: 0, fontFamily: '"Playfair Display", serif', fontWeight: 600, fontSize: '22px', color: 'var(--text-darker)', lineHeight: 1 }}>Eunoia</p>
                <p style={{ margin: 0, fontFamily: 'Outfit, sans-serif', fontWeight: 600, fontSize: '10px', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.08em', marginTop: '2px' }}>Counsellor</p>
              </div>
            )}
          </div>

          {!collapsed && (
            <button
              onClick={() => setCollapsed(true)}
              style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: '6px', color: 'var(--text-darker)', display: 'flex', alignItems: 'center', borderRadius: '8px' }}
              onMouseEnter={e => e.currentTarget.style.backgroundColor = 'var(--primary-light)'}
              onMouseLeave={e => e.currentTarget.style.backgroundColor = 'transparent'}
            >
              <Menu size={20} />
            </button>
          )}
        </div>

        <nav style={S.nav}>
          {NAV.map((item, index) => <SidebarGroup key={item.label || `divider-${index}`} item={item} collapsed={collapsed} setCollapsed={setCollapsed} />)}
        </nav>

        {/* Profile Footer Card in Sidebar */}
        <div style={{ padding: '16px', borderTop: collapsed ? 'none' : `1px solid var(--border-color)`, display: collapsed ? 'flex' : 'block', justifyContent: collapsed ? 'center' : 'initial' }}>
          <NavLink to="/profile" style={{
            display: 'flex',
            alignItems: 'center',
            gap: collapsed ? '0' : '12px',
            textDecoration: 'none',
            color: 'inherit',
            background: collapsed ? 'transparent' : 'var(--bg-main)',
            padding: collapsed ? '0' : '12px',
            borderRadius: collapsed ? '16px' : '16px',
            border: collapsed ? '2px solid var(--primary-light)' : `1px solid var(--border-color)`,
            width: collapsed ? '40px' : '100%',
            height: collapsed ? '40px' : 'auto',
            justifyContent: collapsed ? 'center' : 'flex-start',
            transition: 'all 0.2s',
            boxShadow: collapsed ? '0 1px 3px rgba(0,0,0,0.05)' : 'none'
          }} onMouseEnter={e => {
            if (collapsed) { e.currentTarget.style.transform = 'scale(1.05)'; }
            else { e.currentTarget.style.backgroundColor = 'var(--border-color)'; }
          }} onMouseLeave={e => {
            if (collapsed) { e.currentTarget.style.transform = 'none'; }
            else { e.currentTarget.style.backgroundColor = 'var(--bg-main)'; }
          }}>
            <div style={{
              width: '32px',
              height: '32px',
              borderRadius: '10px',
              background: C.primary,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              overflow: 'hidden', flexShrink: 0,
              border: collapsed ? 'none' : `1px solid var(--border-color)`,
            }}>
              {counsellorUser.photo ? (
                <img src={counsellorUser.photo} alt="P" style={{ width: '100%', height: '100%', objectFit: 'cover' }} onError={() => setCounsellorUser(prev => ({ ...prev, photo: null }))} />
              ) : (
                <span style={{ color: 'white', fontWeight: 700, fontSize: '13px' }}>{counsellorUser.name?.charAt(0)}</span>
              )}
            </div>
            {!collapsed && (
              <div style={{ flex: 1, minWidth: 0, display: 'flex', alignItems: 'center' }}>
                <p style={{ margin: 0, fontSize: '14px', fontWeight: 700, color: 'var(--text-darker)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{counsellorUser.name}</p>
              </div>
            )}
          </NavLink>
        </div>
      </aside>

      {/* Main Panel */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden', marginLeft: collapsed ? '64px' : '240px', transition: 'margin-left 0.25s ease' }}>
        <header style={S.topbar}>
          <span style={S.topbarTitle}>Clinical Practice Hub</span>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>


            <div style={{ position: 'relative' }}>
              <button
                onClick={() => setShowNotify(!showNotify)}
                style={{ position: 'relative', padding: '8px', border: 'none', background: showNotify ? '#E8ECE9' : 'transparent', cursor: 'pointer', borderRadius: '12px', transition: 'all 0.2s', display: 'flex', alignItems: 'center' }}
              >
                <Bell size={18} color={showNotify ? "var(--primary-color)" : "var(--text-muted)"} />
                {hasUnread && (
                  <span style={{ position: 'absolute', top: '8px', right: '8px', width: '8px', height: '8px', background: '#f87171', borderRadius: '50%', border: '2px solid var(--bg-card)' }} />
                )}
              </button>

              {showNotify && (
                <>
                  <style>{`
                    .notify-scroll::-webkit-scrollbar { width: 4px; }
                    .notify-scroll::-webkit-scrollbar-track { background: transparent; }
                    .notify-scroll::-webkit-scrollbar-thumb { background: rgba(138, 150, 143, 0.2); border-radius: 10px; }
                    .notify-scroll:hover::-webkit-scrollbar-thumb { background: rgba(138, 150, 143, 0.4); }
                  `}</style>
                  <div style={{ position: 'absolute', top: '100%', right: 0, marginTop: '12px', width: '320px', background: 'var(--bg-card)', borderRadius: '16px', boxShadow: '0 15px 50px rgba(0,0,0,0.12)', padding: '20px', zIndex: 100, border: '1px solid var(--border-color)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                      <p style={{ margin: 0, fontFamily: 'Outfit, sans-serif', fontWeight: 600, color: 'var(--text-darker)', fontSize: '15px' }}>Recent Activity</p>
                      {hasUnread && <span style={{ fontSize: '11px', fontWeight: 700, background: 'var(--primary-color)', color: 'white', padding: '2px 8px', borderRadius: '12px' }}>New</span>}
                    </div>
                    
                    {recentNotifications.length === 0 ? (
                      <div style={{ textAlign: 'center', padding: '24px 0', color: 'var(--text-muted)', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                        <Bell size={24} color="var(--border-color)" style={{ marginBottom: '8px' }} />
                        <p style={{ margin: 0, fontSize: '12px' }}>No new system notifications.</p>
                      </div>
                    ) : (
                      <div className="notify-scroll" style={{ display: 'flex', flexDirection: 'column', gap: '12px', maxHeight: '300px', overflowY: 'auto', paddingRight: '8px', marginRight: '-8px' }}>
                        {recentNotifications.map(n => (
                          <div key={n.id} onClick={() => { setShowNotify(false); navigate('/notifications'); }} style={{ display: 'flex', gap: '12px', alignItems: 'flex-start', cursor: 'pointer', padding: '8px', borderRadius: '12px', transition: 'background 0.2s' }} onMouseEnter={e => e.currentTarget.style.background = 'var(--cream)'} onMouseLeave={e => e.currentTarget.style.background = 'transparent'}>
                            <div style={{ width: '32px', height: '32px', borderRadius: '50%', background: n.isRead ? 'var(--cream)' : '#fef3c7', color: n.isRead ? 'var(--text-muted)' : '#d97706', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: '2px' }}>
                              <Bell size={14} />
                            </div>
                            <div style={{ flex: 1, minWidth: 0 }}>
                              <p style={{ margin: '0 0 4px 0', fontSize: '13px', fontWeight: 700, color: 'var(--text-darker)' }}>{n.title || 'New Notification'}</p>
                              <p style={{ margin: '0 0 6px 0', fontSize: '12px', color: 'var(--text-muted)', lineHeight: 1.3 }}>{n.message}</p>
                              <p style={{ margin: 0, fontSize: '10px', fontWeight: 600, color: 'var(--text-muted)', opacity: 0.6 }}>{n.timestamp.toLocaleDateString()} {n.timestamp.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}</p>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}

                    <div style={{ marginTop: '16px', paddingTop: '16px', borderTop: '1px solid var(--border-color)', textAlign: 'center' }}>
                      <NavLink to="/notifications" onClick={() => setShowNotify(false)} style={{ fontSize: '13px', fontWeight: 600, color: 'var(--primary-color)', textDecoration: 'none' }}>View All Notifications</NavLink>
                    </div>
                  </div>
                </>
              )}
            </div>

            <NavLink
              to="/settings"
              style={({ isActive }) => ({ padding: '8px', border: 'none', background: isActive ? '#E8ECE9' : 'transparent', cursor: 'pointer', borderRadius: '12px', transition: 'all 0.2s', display: 'flex', alignItems: 'center' })}
            >
              {({ isActive }) => (
                <Settings size={18} color={isActive ? "var(--primary-color)" : "var(--text-muted)"} />
              )}
            </NavLink>

            <button
              onClick={onLogout}
              style={{
                marginLeft: '12px',
                padding: '10px 18px',
                border: `1px solid var(--border-color)`,
                background: 'var(--bg-card)',
                cursor: 'pointer',
                borderRadius: '12px',
                color: '#f87171',
                fontWeight: 600,
                fontSize: '13px',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                boxShadow: '0 2px 4px rgba(0,0,0,0.02)',
                transition: 'all 0.2s'
              }}
              onMouseEnter={e => { e.currentTarget.style.background = '#fef2f2'; e.currentTarget.style.borderColor = '#fecaca'; }}
              onMouseLeave={e => { e.currentTarget.style.background = 'var(--bg-card)'; e.currentTarget.style.borderColor = 'var(--border-color)'; }}
            >
              <LogOut size={16} /> Log Out
            </button>
          </div>
        </header>
        <main style={{ flex: 1, overflowY: 'auto', padding: '24px' }}>
          {children}
        </main>
      </div>

      <ChatbotWidget />
    </div>
  );
}
