import React, { useState, useEffect } from 'react';
import { NavLink } from 'react-router-dom';
import { LayoutGrid, Calendar, TrendingUp, User, LogOut, Clock, MessageSquare, ChevronDown, ChevronRight } from 'lucide-react';
import { doc, getDoc, collection, query, where, getDocs, limit } from 'firebase/firestore';
import { auth, db } from '../firebase';
import logo from '../assets/leaf.png';

const SidebarGroup = ({ group }) => {
  const [open, setOpen] = useState(true);

  return (
    <div className="sidebar-group-container">
      <button 
        onClick={() => setOpen(!open)}
        className="sidebar-group-button"
      >
        <span className="sidebar-group-title">{group.label}</span>
        {open ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
      </button>
      {open && (
        <div className="sidebar-group-children">
          {group.items.map((item) => (
            <NavLink 
              key={item.path} 
              to={item.path}
              className={({ isActive }) => `nav-item child-item ${isActive ? 'active' : ''}`}
            >
              <div className="icon-wrapper">{item.icon}</div>
              <span>{item.name}</span>
            </NavLink>
          ))}
        </div>
      )}
    </div>
  );
};

const Sidebar = ({ onLogout }) => {
  const [counsellor, setCounsellor] = useState({ name: 'Counsellor', photo: null });

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
          setCounsellor({
            name: userData.name || userData.fullName || u.displayName || 'Counsellor User',
            photo: userData.profileImageUrl || userData.photoUrl || u.photoURL || null
          });
        }
      } catch (e) {
        console.error("Error fetching counsellor info:", e);
      }
    };
    fetchCounsellor();
  }, []);

  const navGroups = [
    {
      label: 'Core Portal',
      items: [
        { path: '/dashboard', name: 'Dashboard', icon: <LayoutGrid size={16} /> }
      ]
    },
    {
      label: 'Practice & Schedule',
      items: [
        { path: '/sessions', name: 'Sessions', icon: <Calendar size={16} /> },
        { path: '/availability', name: 'Availability', icon: <Clock size={16} /> }
      ]
    },
    {
      label: 'Clinical Insights',
      items: [
        { path: '/shared-insights', name: 'Shared Insights', icon: <MessageSquare size={16} /> },
        { path: '/performance', name: 'Performance', icon: <TrendingUp size={16} /> }
      ]
    },
    {
      label: 'Settings',
      items: [
        { path: '/profile', name: 'Profile', icon: <User size={16} /> }
      ]
    }
  ];

  const handleLogout = async () => {
    if (onLogout) {
      await onLogout();
    } else {
      try {
        await auth.signOut();
      } catch (error) {
        console.error('Error signing out: ', error);
      }
    }
  };

  return (
    <aside className="sidebar">
      {/* Branding */}
      <div className="sidebar-logo">
        <div className="sidebar-logo-icon">
          <img src={logo} alt="Logo" style={{ width: '22px', height: '22px', objectFit: 'contain' }} />
        </div>
        <span>Eunoia</span>
      </div>
      
      {/* Grouped Navigation */}
      <div style={{ flex: 1, overflowY: 'auto', paddingRight: '4px' }}>
        {navGroups.map((group, gIdx) => (
          <SidebarGroup key={gIdx} group={group} />
        ))}
      </div>

      {/* Footer Profile & Logout */}
      <div style={{ marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: '10px', paddingTop: '16px', borderTop: '1px solid var(--border-color)' }}>
        <NavLink to="/profile" className="sidebar-profile">
          <div className="profile-avatar">
            {counsellor.photo ? (
              <img src={counsellor.photo} alt="Profile" />
            ) : (
              <span>{counsellor.name?.charAt(0)}</span>
            )}
          </div>
          <div className="profile-info">
            <p className="profile-name">{counsellor.name}</p>
          </div>
        </NavLink>

        <button 
          onClick={handleLogout}
          className="nav-item" 
          style={{ 
            border: 'none', 
            background: 'none', 
            color: '#f87171', 
            display: 'flex', 
            alignItems: 'center', 
            gap: '12px', 
            padding: '10px 14px',
            borderRadius: '12px',
            cursor: 'pointer',
            fontSize: '13.5px',
            fontWeight: 500
          }}
          onMouseEnter={e => {
            e.currentTarget.style.backgroundColor = '#fef2f2';
            e.currentTarget.style.color = '#ef4444';
          }}
          onMouseLeave={e => {
            e.currentTarget.style.backgroundColor = 'transparent';
            e.currentTarget.style.color = '#f87171';
          }}
        >
          <LogOut size={16} />
          <span>Logout</span>
        </button>
      </div>
    </aside>
  );
};

export default Sidebar;
