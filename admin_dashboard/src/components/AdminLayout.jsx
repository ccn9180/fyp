import { useState, useEffect } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard, FileText, Music, Tag, Users, MessageSquare,
  BarChart2, Gift, Award, Settings, LogOut, ChevronDown, ChevronRight,
  Menu, Bell, ShieldCheck, AlertTriangle
} from 'lucide-react';
import { auth, db } from '../firebase';
import { doc, getDoc, collection, query, where, getDocs, limit } from 'firebase/firestore';
import logo from '../assets/leaf.png';

const C = { primary: '#7C9C84', cream: '#F6F5F2', creamDarker: '#E5E4E0', charcoal: '#333', muted: '#888' };

const NAV = [
  { label: 'Overview', icon: LayoutDashboard, path: '/dashboard' },
  { type: 'divider' },
  {
    label: 'Resource Control', icon: FileText, children: [
      { label: 'Article Content', path: '/content/articles', icon: FileText },
      { label: 'Meditation Guide', path: '/content/meditation', icon: Music },
      { label: 'Content Report', path: '/monitoring/content', icon: BarChart2 },
    ]
  },
  {
    label: 'Expert Oversight', icon: Users, children: [
      { label: 'Applications', path: '/monitoring/applications', icon: ShieldCheck },
      { label: 'Performance', path: '/monitoring/counsellors', icon: Users },
    ]
  },
  {
    label: 'AI Intelligence', icon: MessageSquare, children: [
      { label: 'Eunoia AI Monitoring', path: '/monitoring/chatbot', icon: MessageSquare },
    ]
  },
  {
    label: 'Safety Hub', icon: AlertTriangle, children: [
      { label: 'Crisis Center', path: '/monitoring/crisis', icon: AlertTriangle },
    ]
  },
  { type: 'divider' },
  {
    label: 'Gamification Hub', icon: Gift, children: [
      { label: 'Gamification Management', path: '/gamification/engagement', icon: Award },
      { label: 'Gamification Metrics', path: '/monitoring/gamification', icon: BarChart2 },
    ]
  },
];

const S = {
  sidebar: (collapsed) => ({
    width: collapsed ? '64px' : '240px',
    minWidth: collapsed ? '64px' : '240px',
    background: 'white',
    borderRight: '1px solid #E5E4E0',
    display: 'flex',
    flexDirection: 'column',
    transition: 'width 0.25s ease',
    overflow: 'hidden',
  }),
  logoBox: {
    display: 'flex', alignItems: 'center', gap: '12px',
    padding: '20px 16px', borderBottom: '1px solid #E5E4E0',
  },
  logoIcon: {
    width: '48px', height: '48px', borderRadius: '50%',
    background: 'white', display: 'flex', alignItems: 'center',
    justifyContent: 'center', flexShrink: 0,
    border: '1px solid #E5E4E0',
    boxShadow: '0 10px 30px rgba(124,156,132,0.08)', // Match exact 0.08 Flutter opacity
  },
  logoText: {
    fontFamily: '"Playfair Display", serif', fontWeight: 600,
    fontSize: '15px', color: '#333', lineHeight: '1.3',
  },
  logoSub: { fontFamily: 'Outfit, sans-serif', fontSize: '11px', fontWeight: 400, color: '#888' },
  nav: { flex: 1, overflowY: 'auto', padding: '12px 8px', display: 'flex', flexDirection: 'column', gap: '2px' },
  navGroup: (isActive) => ({
    display: 'flex', alignItems: 'center', gap: '12px', justifyContent: 'space-between',
    padding: '10px 16px', borderRadius: '12px', width: '100%',
    fontSize: '14px', fontFamily: 'Outfit, sans-serif', fontWeight: isActive ? 600 : 500,
    color: isActive ? '#7C9C84' : '#555',
    background: isActive ? '#E5EDE8' : 'transparent',
    cursor: 'pointer', border: 'none', transition: 'all 0.15s',
    textDecoration: 'none', whiteSpace: 'nowrap',
  }),
  divider: { height: '1px', minHeight: '1px', flexShrink: 0, background: '#E5E4E0', margin: '12px 16px', opacity: 0.6 },
  subNav: { marginLeft: '16px', borderLeft: '1px solid #E5EDE8', display: 'flex', flexDirection: 'column', gap: '2px' },
  subLink: (isActive) => ({
    display: 'flex', alignItems: 'center', gap: '12px',
    padding: '8px 16px', borderRadius: '10px',
    fontSize: '13px', fontFamily: 'Outfit, sans-serif', fontWeight: isActive ? 600 : 400,
    color: isActive ? '#7C9C84' : '#777',
    background: isActive ? '#E5EDE8' : 'transparent',
    cursor: 'pointer', textDecoration: 'none', transition: 'all 0.15s',
  }),
  topbar: {
    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
    padding: '14px 24px', background: 'white', borderBottom: '1px solid #E5E4E0', flexShrink: 0,
  },
  topbarTitle: { fontFamily: '"Playfair Display", serif', fontWeight: 600, fontSize: '18px', color: '#333' },
  avatar: {
    width: '32px', height: '32px', borderRadius: '50%',
    background: '#BBCBC2', display: 'flex', alignItems: 'center', justifyContent: 'center',
    color: '#7C9C84', fontFamily: 'Outfit, sans-serif', fontWeight: 700, fontSize: '14px',
  },
};

function SidebarGroup({ item, collapsed }) {
  const [open, setOpen] = useState(true);

  if (item.type === 'divider') {
    return <div style={S.divider} />;
  }

  if (!item.children) {
    return (
      <NavLink to={item.path} style={({ isActive }) => S.navGroup(isActive)}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <item.icon size={17} style={{ flexShrink: 0 }} />
          {!collapsed && item.label}
        </div>
      </NavLink>
    );
  }
  return (
    <div>
      <button onClick={() => setOpen(o => !o)} style={S.navGroup(false)}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <item.icon size={17} style={{ flexShrink: 0 }} />
          {!collapsed && item.label}
        </div>
        {!collapsed && (open ? <ChevronDown size={17} style={{ flexShrink: 0 }} /> : <ChevronRight size={17} style={{ flexShrink: 0 }} />)}
      </button>
      {open && !collapsed && (
        <div style={S.subNav}>
          {item.children.map(c => (
            <NavLink key={c.path} to={c.path} style={({ isActive }) => S.subLink(isActive)}>
              <c.icon size={17} style={{ flexShrink: 0, opacity: 0.8 }} /> {c.label}
            </NavLink>
          ))}
        </div>
      )}
    </div>
  );
}

export default function AdminLayout({ children, onLogout }) {
  const [collapsed, setCollapsed] = useState(false);
  const [adminUser, setAdminUser] = useState({ name: 'Eunoia Admin', role: 'Super Admin', photo: null });
  const [showNotify, setShowNotify] = useState(false);

  useEffect(() => {
    const fetchAdmin = async () => {
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
          setAdminUser({
            name: userData.name || userData.fullName || 'Admin User',
            role: userData.role === 'admin' ? 'System Administrator' : (userData.role || 'Admin'),
            photo: userData.profileImageUrl || userData.photoUrl || null
          });
        }
      } catch (e) { console.error(e); }
    };
    fetchAdmin();
  }, []);

  return (
    <div style={{ display: 'flex', height: '100vh', overflow: 'hidden', background: '#F6F5F2' }}>
      {/* Sidebar */}
      <aside style={S.sidebar(collapsed)}>
        <div style={{
          padding: '28px 20px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: collapsed ? 'center' : 'space-between',
          borderBottom: collapsed ? 'none' : `1px solid ${C.creamDarker}`,
          marginBottom: '10px'
        }}>
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            justifyContent: collapsed ? 'center' : 'flex-start'
          }}>
            <div style={{
              ...S.logoIcon,
              width: collapsed ? '40px' : '48px',
              height: collapsed ? '40px' : '48px',
            }}>
              <img src={logo} alt="Logo" style={{ width: collapsed ? '22px' : '28px', height: collapsed ? '22px' : '28px' }} />
            </div>
            {!collapsed && (
              <div>
                <p style={{ margin: 0, fontFamily: '"Playfair Display", serif', fontWeight: 600, fontSize: '22px', color: C.charcoal, lineHeight: 1 }}>Eunoia</p>
                <p style={{ margin: 0, fontFamily: 'Outfit, sans-serif', fontWeight: 600, fontSize: '10px', color: C.muted, textTransform: 'uppercase', letterSpacing: '0.08em', marginTop: '2px' }}>Admin</p>
              </div>
            )}
          </div>

          <button
            onClick={() => setCollapsed(!collapsed)}
            style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '6px', color: C.charcoal, display: 'flex', alignItems: 'center', borderRadius: '8px' }}
            className="hover:bg-cream transition-colors"
          >
            <Menu size={20} />
          </button>
        </div>
        <nav style={S.nav}>
          {NAV.map((item, index) => <SidebarGroup key={item.label || `divider-${index}`} item={item} collapsed={collapsed} />)}
        </nav>
        <div style={{ padding: '16px', borderTop: collapsed ? 'none' : `1px solid ${C.creamDarker}`, marginTop: 'auto' }}>
          <NavLink to="/account" style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            textDecoration: 'none',
            color: 'inherit',
            background: C.cream,
            padding: '12px',
            borderRadius: '16px',
            border: `1px solid ${C.creamDarker}`,
            width: '100%',
            justifyContent: collapsed ? 'center' : 'flex-start'
          }} className="hover:bg-cream-darker transition-all group">
            <div style={{
              width: '32px', height: '32px',
              borderRadius: '50%',
              background: C.primary,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              overflow: 'hidden', flexShrink: 0,
              border: `1px solid ${C.creamDarker}`,
            }}>
              {adminUser.photo ? (
                <img src={adminUser.photo} alt="P" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              ) : (
                <span style={{ color: 'white', fontWeight: 700, fontSize: '13px' }}>{adminUser.name?.charAt(0)}</span>
              )}
            </div>
            {!collapsed && (
              <div style={{ flex: 1, minWidth: 0 }}>
                <p style={{ margin: 0, fontSize: '13px', fontWeight: 700, color: '#333', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{adminUser.name}</p>
                <p style={{ margin: 0, fontSize: '10px', color: C.primary, fontWeight: 500, textTransform: 'uppercase', letterSpacing: '0.5px' }}>{adminUser.role}</p>
              </div>
            )}
          </NavLink>
        </div>
      </aside>

      {/* Main */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        <header style={S.topbar}>
          <span style={S.topbarTitle}>System Oversight Hub</span>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{ position: 'relative' }}>
              <button
                onClick={() => setShowNotify(!showNotify)}
                style={{ position: 'relative', padding: '8px', border: 'none', background: showNotify ? '#E8ECE9' : 'transparent', cursor: 'pointer', borderRadius: '10px', transition: 'all 0.2s' }}
              >
                <Bell size={18} color={showNotify ? C.primary : "#888"} />
                  <span style={{ position: 'absolute', top: '8px', right: '8px', width: '8px', height: '8px', background: '#f87171', borderRadius: '50%', border: '2px solid white' }} />
              </button>

              {showNotify && (
                <div style={{ position: 'absolute', top: '100%', right: 0, marginTop: '12px', width: '280px', background: 'white', borderRadius: '20px', boxShadow: '0 15px 50px rgba(0,0,0,0.12)', padding: '20px', zIndex: 100 }}>
                  <p style={{ fontFamily: 'Outfit', fontWeight: 600, fontSize: '14px', marginBottom: '8px' }}>Recent Activity</p>
                  <div style={{ fontSize: '12px', color: '#888', textAlign: 'center', padding: '12px 0' }}>No new system notifications.</div>
                </div>
              )}
            </div>

            <button
              onClick={onLogout}
              style={{
                marginLeft: '12px',
                padding: '10px 18px',
                border: `1px solid ${C.creamDarker}`,
                background: 'white',
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
              onMouseLeave={e => { e.currentTarget.style.background = 'white'; e.currentTarget.style.borderColor = C.creamDarker; }}
            >
              <LogOut size={16} /> Log Out
            </button>
          </div>
        </header>
        <main style={{ flex: 1, overflowY: 'auto', padding: '24px' }}>
          {children}
        </main>
      </div>
    </div>
  );
}
