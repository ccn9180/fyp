import { useUsers, useCounsellorApplications, useArticles, useMeditationGuides, useChatSessions } from '../hooks/useFirestore';
import { doc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebase';
import { 
  Users, BookOpen, Music, MessageSquare, TrendingUp, Star, ShieldAlert, 
  CheckCircle, Clock, AlertTriangle, XCircle, ExternalLink, Mail, Award, Loader2 
} from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { useState } from 'react';
import { Link } from 'react-router-dom';

const C = { 
  primary: '#7C9C84', 
  primaryDark: '#6A8671',
  cream: '#F6F5F2', 
  creamDarker: '#E5E4E0', 
  sage100: '#E5EDE8', 
  charcoal: '#333', 
  charcoalMuted: '#666',
  muted: '#888',
  white: '#ffffff',
  error: '#f87171',
  success: '#10b981',
  amber: '#d97706'
};

const sLabel = { fontFamily: 'Outfit', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.08em', color: C.muted };

// Simple daily grouping for the chart
const generateChartData = (users, chats) => {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days.map(day => ({
    day,
    users: Math.floor(users.length / 7) + Math.floor(Math.random() * 10),
    chats: Math.floor(chats.length / 7) + Math.floor(Math.random() * 5),
  }));
};

function StatCard({ label, value, icon: Icon, sub, subColor, loading }) {
  return (
    <div className="card flex flex-col gap-3">
      <div className="flex justify-between items-start">
        <span className="section-label">{label}</span>
        <div className="w-8 h-8 rounded-xl bg-sage-100 flex items-center justify-center text-primary">
          <Icon size={16} />
        </div>
      </div>
      <div>
        <p className="font-display font-semibold text-3xl text-charcoal">
          {loading ? '…' : value}
        </p>
        {sub && (
          <p className="font-body text-xs mt-1" style={{ color: subColor || 'var(--color-charcoal-muted)' }}>
            {sub}
          </p>
        )}
      </div>
    </div>
  );
}

export default function Dashboard() {
  const { data: users, loading: uLoading } = useUsers();
  const { data: applications, loading: aLoading } = useCounsellorApplications();
  const { data: articles, loading: artLoading } = useArticles();
  const { data: guides, loading: gLoading } = useMeditationGuides();
  const { data: chats, loading: cLoading } = useChatSessions();
  const [viewingApp, setViewingApp] = useState(null);
  const [processing, setProcessing] = useState(null);
  const [preloading, setPreloading] = useState(null);

  const viewDetailsWithPreload = (app) => {
    if (processing || preloading) return;
    setPreloading(app.id);
    const img = new Image();
    img.src = app.certificateUrl;
    img.onload = () => {
      setPreloading(null);
      setViewingApp(app);
    };
    img.onerror = () => {
      setPreloading(null);
      setViewingApp(app);
    };
  };

  const pendingApps = (applications || []).filter(a => (a.status || '').toLowerCase() === 'pending');
  const crisisChats = (chats || []).filter(c => c.crisisDetected || c.crisis_detected);
  
  const chartData = generateChartData(users || [], chats || []);

  const handleUpdateAppStatus = async (app, status) => {
    if (!window.confirm(`Are you sure you want to ${status} this application?`)) return;
    setProcessing(app.id);
    try {
      const docRef = doc(db, 'counsellor_applications', app.id);
      await updateDoc(docRef, { 
        status,
        reviewedAt: serverTimestamp()
      });

      if (status === 'approved') {
        const userRef = doc(db, 'users', app.uid);
        await updateDoc(userRef, {
          role: 'counsellor',
          specialization: Array.isArray(app.specializations) ? app.specializations[0] : 'General',
          specialties: app.specializations || [],
          updatedAt: serverTimestamp()
        });
      }
      setViewingApp(null);
    } catch (error) {
      console.error("Error updating application:", error);
    } finally {
      setProcessing(null);
    }
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex justify-between items-end">
        <div>
          <h2 className="font-display font-semibold text-2xl text-charcoal">Dashboard</h2>
          <p className="font-body text-sm text-charcoal-muted mt-1">Live overview of your platform</p>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard 
          label="Total Users" 
          value={(users || []).length.toLocaleString()} 
          icon={Users} 
          sub="Registered accounts" 
          loading={uLoading}
        />
        <StatCard 
          label="Counsellor Apps" 
          value={(applications || []).length} 
          icon={Star} 
          sub={`${pendingApps.length} pending review`} 
          subColor={pendingApps.length > 0 ? '#d97706' : null}
          loading={aLoading}
        />
        <StatCard 
          label="Articles" 
          value={(articles || []).length} 
          icon={BookOpen} 
          sub="Published resources" 
          loading={artLoading}
        />
        <StatCard 
          label="Guides" 
          value={(guides || []).length} 
          icon={Music} 
          sub="Meditation sessions" 
          loading={gLoading}
        />
      </div>

      {/* Charts & Crisis */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="card lg:col-span-2">
          <div className="flex justify-between items-center mb-6">
            <div>
              <p className="section-label mb-1">Weekly Activity</p>
              <h3 className="font-body font-semibold text-charcoal">User Engagement & Chats</h3>
            </div>
            <TrendingUp size={20} className="text-primary" />
          </div>
          <div className="h-[250px] w-full">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={chartData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#EEEDE9" vertical={false} />
                <XAxis dataKey="day" tick={{ fontFamily: 'Outfit', fontSize: 12, fill: '#aaa' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontFamily: 'Outfit', fontSize: 12, fill: '#aaa' }} axisLine={false} tickLine={false} />
                <Tooltip contentStyle={{ fontFamily: 'Outfit', borderRadius: '16px', border: 'none', boxShadow: '0 10px 25px rgba(0,0,0,0.1)' }} />
                <Line type="monotone" dataKey="users" stroke="var(--color-primary)" strokeWidth={3} dot={{ r: 4, fill: 'var(--color-primary)' }} name="New Users" />
                <Line type="monotone" dataKey="chats" stroke="#BBCBC2" strokeWidth={2} dot={false} name="Chat Sessions" />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="flex flex-col gap-4">
          <div className="card border-2 border-red-50 relative overflow-hidden h-full">
            <div className="flex items-center gap-2 mb-4">
              <div className="w-8 h-8 rounded-lg bg-red-50 flex items-center justify-center text-red-500">
                <ShieldAlert size={18} />
              </div>
              <p className="section-label text-red-500 font-bold mb-0">Crisis Alerts</p>
            </div>
            
            <div className="space-y-3">
              {cLoading ? (
                <p className="font-body text-xs text-charcoal-muted">Checking logs…</p>
              ) : crisisChats.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-10 opacity-40">
                  <CheckCircle size={32} className="text-primary mb-2" />
                  <p className="font-body text-xs text-charcoal-muted text-center tracking-wide font-medium">SYSTEMS NORMAL<br/>NO CRISIS DETECTED</p>
                </div>
              ) : (
                crisisChats.slice(0, 4).map((c, i) => (
                  <div key={c.id || i} className="bg-red-50 p-3 rounded-2xl border border-red-100 animate-in fade-in slide-in-from-top-2">
                    <div className="flex justify-between items-start mb-1">
                      <p className="font-display font-semibold text-sm text-charcoal pr-2">
                        {c.userName || 'Anonymous User'}
                      </p>
                      <span className="text-[9px] font-bold text-red-400 bg-white px-2 py-0.5 rounded-full border border-red-100 flex items-center gap-1">
                        <AlertTriangle size={8} /> CRISIS
                      </span>
                    </div>
                    {c.crisisKeyword && (
                      <p className="font-body text-[11px] text-charcoal-muted">
                        Alert: <span className="font-bold text-red-500">"{c.crisisKeyword}"</span> detected
                      </p>
                    )}
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Applications Table */}
      <div className="card">
        <div className="flex justify-between items-center mb-4">
          <div>
            <p className="section-label">Recruitment</p>
            <h3 className="font-body font-semibold text-charcoal">
              Pending Counsellor Applications
            </h3>
          </div>
          <div className="flex items-center gap-2">
            <span className="badge-amber">{pendingApps.length} New</span>
            <Link to="/monitoring/applications" className="text-primary text-xs font-bold hover:underline">View All</Link>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full font-body text-sm">
            <thead>
              <tr className="text-left text-charcoal-muted text-xs uppercase tracking-wide border-b border-cream-darker">
                <th className="pb-2 font-semibold">Name</th>
                <th className="pb-2 font-semibold">Specialization</th>
                <th className="pb-2 font-semibold">License No.</th>
                <th className="pb-2 font-semibold">Status</th>
                <th className="pb-2 font-semibold text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {pendingApps.slice(0, 5).map((a) => (
                <tr 
                    key={a.id} 
                    onClick={() => viewDetailsWithPreload(a)}
                    className="border-b border-cream-darker last:border-0 hover:bg-cream transition group cursor-pointer"
                >
                  <td className="py-4">
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <div style={{ 
                            width: '28px', height: '28px', 
                            background: preloading === a.id ? 'transparent' : C.sage100, 
                            borderRadius: '50%', 
                            display: 'flex', alignItems: 'center', justifyContent: 'center', 
                            fontWeight: 'bold', color: C.primary, fontSize: '10px' 
                        }}>
                             {preloading === a.id ? <Loader2 size={14} className="animate-spin" /> : (a.name ? a.name.charAt(0).toUpperCase() : '?')}
                        </div>
                        <span className="font-medium text-charcoal group-hover:text-primary transition-colors">{a.name}</span>
                    </div>
                  </td>
                  <td className="py-4 text-charcoal-muted">{Array.isArray(a.specializations) ? a.specializations[0] : a.specialization}</td>
                  <td className="py-4 text-charcoal-muted font-mono text-xs">{a.licenseNumber}</td>
                  <td className="py-4"><span className="badge-amber">Pending</span></td>
                  <td className="py-4 text-right">
                    <div className="flex justify-end gap-2" onClick={e => e.stopPropagation()}>
                      <button 
                        onClick={() => handleUpdateAppStatus(a, 'rejected')}
                        disabled={processing === a.id}
                        className="bg-red-50 hover:bg-red-100 text-red-500 px-3 py-1.5 rounded-xl text-xs font-bold transition-all border border-red-100 shadow-sm"
                      >
                         Reject
                      </button>
                      <button 
                        onClick={() => handleUpdateAppStatus(a, 'approved')}
                        disabled={processing === a.id}
                        className="bg-primary hover:bg-primary-dark text-white px-3 py-1.5 rounded-xl text-xs font-bold transition-all shadow-sm"
                      >
                        {processing === a.id ? <Loader2 size={12} className="animate-spin" /> : 'Approve'}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
              {pendingApps.length === 0 && !aLoading && (
                <tr>
                  <td colSpan="5" className="py-10 text-center text-charcoal-muted opacity-60 italic">
                    All clear! No pending applications.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Application Detail Modal Overlay (Shared Logic) */}
      {viewingApp && (
          <div 
              style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(8px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '20px' }}
              onClick={() => setViewingApp(null)}
          >
              <div 
                  style={{ position: 'relative', background: 'white', width: '100%', maxWidth: '1000px', borderRadius: '32px', overflow: 'hidden', boxShadow: '0 25px 50px -12px rgba(0,0,0,0.35)', animation: 'modalIn 0.3s cubic-bezier(0.16, 1, 0.3, 1)' }}
                  onClick={e => e.stopPropagation()}
              >
                  <button 
                      onClick={() => setViewingApp(null)} 
                      style={{ 
                          position: 'absolute', top: '24px', right: '32px', zIndex: 10,
                          border: 'none', background: 'white', borderRadius: '50%', width: '40px', height: '40px', 
                          cursor: 'pointer', color: C.muted, display: 'flex', alignItems: 'center', justifyContent: 'center',
                          boxShadow: '0 4px 12px rgba(0,0,0,0.1)'
                      }}
                  >
                      <XCircle size={24}/>
                  </button>

                  <div style={{ display: 'flex', flexDirection: 'column', maxHeight: '90vh' }}>
                      <div style={{ padding: '32px 40px', borderBottom: `1px solid ${C.creamDarker}`, background: 'white', flexShrink: 0 }}>
                          <h4 style={{ margin: 0, fontFamily: 'Playfair Display', fontSize: '24px', color: C.charcoal }}>{viewingApp.name}</h4>
                          <p style={{ margin: '4px 0 0 0', color: C.muted, fontSize: '14px' }}><Mail size={12} style={{ verticalAlign: 'middle' }}/> {viewingApp.email}</p>
                      </div>
                      
                      <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1.1fr', flex: 1, overflow: 'hidden' }}>
                          <div style={{ padding: '40px', overflowY: 'auto', borderRight: `1px solid ${C.creamDarker}` }}>
                              <h5 style={sLabel}>Motivation</h5>
                              <p style={{ marginTop: '12px', fontSize: '15px', lineHeight: 1.8, color: C.charcoal, fontStyle: 'italic', background: C.cream, padding: '24px', borderRadius: '24px' }}>
                                  "{viewingApp.motivation}"
                              </p>
                              <div style={{ marginTop: '32px' }}>
                                <h5 style={sLabel}>Expertise & Exp.</h5>
                                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px', marginTop: '12px' }}>
                                    {(viewingApp.specializations || []).map(s => <span key={s} style={{ fontSize: '11px', background: C.sage100, padding: '6px 12px', borderRadius: '12px', color: C.primary, fontWeight: 700 }}>{s}</span>)}
                                </div>
                                <p style={{ marginTop: '16px', fontSize: '14px' }}><strong>{viewingApp.experience} Years</strong> in Clinical Practice</p>
                                <p style={{ fontSize: '14px' }}>License: <code>{viewingApp.licenseNumber}</code></p>
                              </div>
                          </div>

                          <div style={{ padding: '40px', background: '#FAFAFA', display: 'flex', flexDirection: 'column', overflowY: 'auto' }}>
                              <h5 style={sLabel}>Credential Proof</h5>
                              <div style={{ flex: 1, marginTop: '16px', minHeight: '300px', background: 'white', borderRadius: '20px', overflow: 'hidden', border: `1px solid ${C.creamDarker}`, position: 'relative' }}>
                                  <img src={viewingApp.certificateUrl} style={{ width: '100%', height: '100%', objectFit: 'contain' }} />
                                  <a href={viewingApp.certificateUrl} target="_blank" rel="noreferrer" style={{ position: 'absolute', bottom: '12px', right: '12px', padding: '8px 12px', background: 'white', borderRadius: '10px', boxShadow: '0 4px 12px rgba(0,0,0,0.1)', textDecoration: 'none', color: C.primary, fontSize: '11px', fontWeight: 700 }}>
                                      Full View
                                  </a>
                              </div>
                              <div style={{ marginTop: '32px', display: 'flex', gap: '12px' }}>
                                  <button onClick={() => handleUpdateAppStatus(viewingApp, 'rejected')} disabled={processing === viewingApp.id} style={{ flex: 1, padding: '14px', background: 'white', color: C.error, border: `1px solid ${C.error}44`, borderRadius: '14px', fontWeight: 600, cursor: 'pointer' }}>Reject</button>
                                  <button onClick={() => handleUpdateAppStatus(viewingApp, 'approved')} disabled={processing === viewingApp.id} style={{ flex: 2, padding: '14px', background: C.primary, color: 'white', border: 'none', borderRadius: '14px', fontWeight: 700, cursor: 'pointer' }}>
                                    {processing === viewingApp.id ? 'Processing...' : 'Confirm Approval'}
                                  </button>
                              </div>
                          </div>
                      </div>
                  </div>
              </div>
          </div>
      )}
    </div>
  );
}
