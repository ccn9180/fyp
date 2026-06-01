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
      { label: 'Community Pulse', path: '/monitoring/post-feeds', icon: MessageSquare },
      { label: 'Community Rules', path: '/content/community-rules', icon: ShieldCheck },
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
  },
];

function SidebarGroup({ item, collapsed, setCollapsed }) {
  const [open, setOpen] = useState(true);

  if (item.type === 'divider') {
    return <div className="h-px min-h-[1px] shrink-0 bg-[#E5E4E0] mx-4 my-3 opacity-60" />;
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
        <div className="ml-4 border-l border-sage-100 flex flex-col gap-0.5">
          {item.children.map(c => (
            <NavLink 
              key={c.path} 
              to={c.path} 
              className={({ isActive }) => `flex items-center gap-3 px-4 py-2 rounded-xl text-[13px] font-body cursor-pointer no-underline transition-all outline-none ${isActive ? 'bg-sage-100 text-primary font-semibold' : 'text-[#777] hover:bg-cream/50 font-normal'}`}
            >
              <c.icon size={17} className="shrink-0 opacity-80" /> {c.label}
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
            photo: userData.profileImageUrl || userData.photoUrl || null
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
        <div className={`py-7 flex mb-2.5 ${collapsed ? 'flex-col items-center justify-center gap-4 px-2 border-none' : 'items-center justify-between px-5 border-b border-cream-darker'}`}>
          <div className={`flex items-center gap-2 ${collapsed ? 'justify-center' : 'justify-start'}`}>
            <div className={`bg-white flex flex-col items-center justify-center shrink-0 border border-cream-darker rounded-full shadow-[0_10px_30px_rgba(124,156,132,0.08)] ${collapsed ? 'w-10 h-10' : 'w-12 h-12'}`}>
              <img src={logo} alt="Logo" className={`${collapsed ? 'w-[27px] h-[27px]' : 'w-[33px] h-[33px]'}`} />
            </div>
            {!collapsed && (
              <div>
                <p className="m-0 font-display font-semibold text-[22px] text-charcoal leading-none">Eunoia</p>
                <p className="m-0 font-body font-semibold text-[10px] text-muted uppercase tracking-[0.08em] mt-0.5">Admin</p>
              </div>
            )}
          </div>

          <button
            onClick={() => setCollapsed(!collapsed)}
            className="bg-transparent border-none cursor-pointer p-1.5 text-charcoal flex items-center rounded-lg hover:bg-cream transition-colors"
          >
            <Menu size={20} />
          </button>
        </div>
        <nav className="flex-1 overflow-y-auto px-2 py-3 flex flex-col gap-0.5 custom-scrollbar">
          {NAV.map((item, index) => <SidebarGroup key={item.label || `divider-${index}`} item={item} collapsed={collapsed} setCollapsed={setCollapsed} />)}
        </nav>
        <div className={`p-4 mt-auto flex-shrink-0 ${collapsed ? 'border-none flex justify-center' : 'border-t border-cream-darker'}`}>
          <NavLink to="/account" className={`flex items-center no-underline text-inherit transition-all group ${collapsed ? 'justify-center p-0 rounded-xl w-10 h-10 min-w-[40px] min-h-[40px] aspect-square mx-auto hover:scale-105 border-2 border-primary/20 shadow-sm' : 'justify-start gap-3 p-3 rounded-2xl w-full bg-cream border border-cream-darker hover:bg-cream-darker'}`}>
            <div className={`bg-primary flex items-center justify-center overflow-hidden shrink-0 ${collapsed ? 'rounded-xl w-full h-full' : 'rounded-full w-8 h-8 border border-cream-darker'}`}>
              {adminUser.photo ? (
                <img src={adminUser.photo} alt="P" className="w-full h-full object-cover" />
              ) : (
                <span className="text-white font-bold text-[13px]">{adminUser.name?.charAt(0)}</span>
              )}
            </div>
            {!collapsed && (
              <div className="flex-1 min-w-0 flex items-center">
                <p className="m-0 text-[14px] font-bold text-charcoal truncate">{adminUser.name}</p>
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
