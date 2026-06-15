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
      { label: 'Reward System Settings', path: '/gamification/rewards', icon: Settings },
      { label: 'Gamification Metrics', path: '/monitoring/gamification', icon: BarChart2 },
    ]
  }
];

function SidebarGroup({ item, collapsed, setCollapsed }) {
  const [open, setOpen] = useState(true);

  if (item.type === 'divider') {
    return <div className="h-px min-h-[1px] shrink-0 border-t border-cream-darker mx-4 my-3 opacity-60" />;
  }

  if (!item.children) {
    return (
      <NavLink 
        to={item.path} 
        onClick={() => { if (collapsed && setCollapsed) setCollapsed(false); }}
        className={({ isActive }) => `flex items-center gap-3 justify-between px-4 py-2.5 rounded-xl w-full text-sm font-body cursor-pointer border-none transition-all whitespace-nowrap outline-none no-underline ${isActive ? 'bg-sage-100 text-primary font-semibold' : 'text-charcoal-muted font-medium hover:bg-cream/50'}`}
      >
        <div className="flex items-center gap-3">
          <item.icon size={17} className="shrink-0" />
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
        className="flex items-center gap-3 justify-between px-4 py-2.5 rounded-xl w-full text-sm font-body cursor-pointer border-none transition-all whitespace-nowrap outline-none no-underline text-charcoal-muted font-medium hover:bg-cream/50"
      >
        <div className="flex items-center gap-3">
          <item.icon size={17} className="shrink-0" />
          {!collapsed && item.label}
        </div>
        {!collapsed && (open ? <ChevronDown size={17} className="shrink-0" /> : <ChevronRight size={17} className="shrink-0" />)}
      </button>
      {open && !collapsed && (
        <div className="ml-4 border-l border-primary/20 flex flex-col gap-0.5 mt-1">
          {item.children.map(c => (
            <NavLink 
              key={c.path} 
              to={c.path} 
              className={({ isActive }) => `ml-2 flex items-center gap-3 px-4 py-2 rounded-xl text-[13px] font-body cursor-pointer no-underline transition-all outline-none ${isActive ? 'bg-sage-100 text-primary font-semibold' : 'text-[#777] hover:bg-cream/50 font-normal'}`}
            >
              <c.icon size={17} className={`shrink-0 ${location.pathname === c.path ? 'text-primary' : 'text-[#999]'}`} /> {c.label}
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

        if (!userData && u.email) {
          const qEmail = query(collection(db, 'users'), where('email', '==', u.email), limit(1));
          const querySnapEmail = await getDocs(qEmail);
          if (!querySnapEmail.empty) {
            userData = querySnapEmail.docs[0].data();
          }
        }

        if (userData) {
          setAdminUser({
            name: userData.name || userData.fullName || 'Admin User',
            role: userData.role === 'admin' ? 'System Administrator' : (userData.role || 'Admin'),
            photo: userData.counsellorImageUrl || userData.profileImageUrl || userData.photoUrl || u.photoURL || null
          });
        }
      } catch (e) { console.error(e); }
    };
    fetchAdmin();
  }, []);

  return (
    <div className="flex h-screen overflow-hidden bg-[#F6F5F2]">
      {/* Sidebar */}
      <aside className={`bg-white border-r border-cream-darker flex flex-col transition-[width] duration-200 ease-in-out overflow-hidden ${collapsed ? 'w-16 min-w-[64px]' : 'w-60 min-w-[240px]'}`}>
        <div className={`py-7 flex mb-2.5 ${collapsed ? 'flex-col items-center justify-center px-2 border-none' : 'items-center justify-between px-5 border-b border-cream-darker'}`}>
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
              width: collapsed ? '40px' : '48px',
              height: collapsed ? '40px' : '48px',
              borderRadius: '50%',
              backgroundColor: '#FFFFFF',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
              border: '1px solid var(--border-color)',
              boxShadow: '0 10px 30px rgba(124,156,132,0.08)',
              overflow: 'hidden'
            }}>
              <img src={logo} alt="Logo" style={{ width: '75%', height: '75%', objectFit: 'contain' }} />
            </div>
            {!collapsed && (
              <div>
                <p className="m-0 font-display font-semibold text-[22px] text-charcoal leading-none">Eunoia</p>
                <p className="m-0 font-body font-semibold text-[10px] text-muted uppercase tracking-[0.08em] mt-0.5">Admin</p>
              </div>
            )}
          </div>

          {!collapsed && (
            <button
              onClick={() => setCollapsed(true)}
              className="bg-transparent border-none cursor-pointer p-1.5 text-charcoal flex items-center rounded-lg hover:bg-primary/10 transition-colors"
            >
              <Menu size={20} />
            </button>
          )}
        </div>
        <nav className="flex-1 overflow-y-auto px-2 py-3 flex flex-col gap-0.5 hide-scrollbar">
          {NAV.map((item, index) => <SidebarGroup key={item.label || `divider-${index}`} item={item} collapsed={collapsed} setCollapsed={setCollapsed} />)}
        </nav>
        {/* Profile Footer Card in Sidebar */}
        <div style={{ padding: '16px', borderTop: collapsed ? 'none' : `1px solid var(--border-color)`, display: collapsed ? 'flex' : 'block', justifyContent: collapsed ? 'center' : 'initial' }} className="border-t border-cream-darker">
          <NavLink to="/account" style={{
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
          }} 
          className="border border-cream-darker hover:border-cream-darker"
          onMouseEnter={e => {
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
              background: '#7C9C84',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              overflow: 'hidden', flexShrink: 0,
              border: collapsed ? 'none' : `1px solid var(--border-color)`,
            }}>
              {adminUser.photo ? (
                <img src={adminUser.photo} alt="P" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              ) : (
                <span style={{ color: 'white', fontWeight: 'bold', fontSize: '13px' }}>{adminUser.name?.charAt(0)}</span>
              )}
            </div>
            {!collapsed && (
              <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
                <span style={{ fontFamily: '"Playfair Display", serif', fontWeight: 700, fontSize: '14px', color: 'var(--text-darker)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {adminUser.name}
                </span>
              </div>
            )}
          </NavLink>
        </div>
      </aside>

      {/* Main */}
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="flex items-center justify-between px-6 py-3.5 bg-white border-b border-cream-darker shrink-0">
          <span className="font-display font-semibold text-lg text-charcoal">System Oversight Hub</span>
          <div className="flex items-center gap-3">
            <div className="relative">
              <button
                onClick={() => setShowNotify(!showNotify)}
                className={`relative p-2 border-none cursor-pointer rounded-xl transition-all ${showNotify ? 'bg-[#E8ECE9]' : 'bg-transparent'}`}
              >
                <Bell size={18} className={showNotify ? "text-primary" : "text-muted"} />
                <span className="absolute top-2 right-2 w-2 h-2 bg-red-400 rounded-full border-2 border-white" />
              </button>

              {showNotify && (
                <div className="absolute top-full right-0 mt-3 w-72 bg-white rounded-2xl shadow-[0_15px_50px_rgba(0,0,0,0.12)] p-5 z-[100]">
                  <p className="font-body font-semibold text-sm mb-2">Recent Activity</p>
                  <div className="text-xs text-muted text-center py-3">No new system notifications.</div>
                </div>
              )}
            </div>

            <NavLink
              to="/settings"
              className={({ isActive }) => `p-2 border-none cursor-pointer rounded-xl transition-all flex items-center justify-center ${isActive ? 'bg-[#E8ECE9] text-primary' : 'bg-transparent text-muted hover:bg-cream-darker'}`}
            >
              <Settings size={18} />
            </NavLink>

            <button
              onClick={onLogout}
              className="ml-3 px-4.5 py-2.5 border border-cream-darker bg-white cursor-pointer rounded-xl text-red-400 font-semibold text-[13px] flex items-center gap-2 shadow-[0_2px_4px_rgba(0,0,0,0.02)] transition-all hover:bg-red-50 hover:border-red-200"
            >
              <LogOut size={16} /> Log Out
            </button>
          </div>
        </header>
        <main className="flex-1 overflow-y-auto p-6">
          {children}
        </main>
      </div>
    </div>
  );
}
