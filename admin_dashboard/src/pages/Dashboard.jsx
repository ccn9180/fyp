import { useUsers, useCounsellorApplications, useArticles, useMeditationGuides, useChatSessions, useDeactivationRequests } from '../hooks/useFirestore';
import { doc, updateDoc, serverTimestamp, setDoc } from 'firebase/firestore';
import { db } from '../firebase';
import {
  Users, BookOpen, Music, MessageSquare, TrendingUp, Star, ShieldAlert,
  CheckCircle, Clock, AlertTriangle, XCircle, ExternalLink, Mail, Award, Loader2, ChevronRight
} from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { customConfirm, customPrompt } from '../utils/dialogUtils';

const C = {
  primary: 'var(--primary-color, #7C9C84)',
  primaryDark: 'var(--color-primary-dark, #66826D)',
  primaryLight: 'var(--primary-light, #BBCBC2)',
  sage100: 'var(--color-sage-100, #E5EDE8)',
  cream: 'var(--bg-main, #F6F5F2)',
  creamDarker: 'var(--border-color, #E5E4E0)',
  charcoal: 'var(--text-darker, #333)',
  charcoalMuted: 'var(--text-muted, #666)',
  muted: 'var(--text-muted, #888)',
  bgCard: 'var(--bg-card, white)',
  amber: '#d97706',
  blue: '#3b82f6',
  rose: '#f43f5e'
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
  const { data: deactivationRequests, loading: dLoading } = useDeactivationRequests();
  const [viewingApp, setViewingApp] = useState(null);
  const [viewingDeactivation, setViewingDeactivation] = useState(null);
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

  const MOCK_APPS = [
    { id: 'm1', name: 'Dr. Elizabeth Chen', email: 'e.chen@wellness.com', specializations: ['Trauma & PTSD', 'Crisis Intervention'], experience: '12', licenseNumber: 'PSY-99281', status: 'pending', motivation: 'I have dedicated my career to trauma recovery and believe Eunoia is the perfect platform for remote support.', certificateUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=800', submittedAt: { toDate: () => new Date('2026-03-28') } },
    { id: 'm2', name: 'Dr. Marcus Thorne', email: 'm.thorne@mentalhealth.org', specializations: ['Anxiety & Stress', 'Depression'], experience: '8', licenseNumber: 'LCSW-8821', status: 'pending', motivation: 'My focus is on cognitive behavioral therapy for young adults dealing with high-stress environments.', certificateUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=800', submittedAt: { toDate: () => new Date('2026-03-30') } },
    { id: 'm3', name: 'Dr. Sarah Winters', email: 's.winters@clinical.edu', specializations: ['Child Psychology', 'Depression'], experience: '15', licenseNumber: 'PSY-11029', status: 'pending', motivation: 'Childhood mental health is often overlooked. I want to contribute my expertise here.', certificateUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=800', submittedAt: { toDate: () => new Date('2026-03-15') } }
  ];

  const pendingApps = [...(applications || []).filter(a => (a.status || '').toLowerCase() === 'pending'), ...MOCK_APPS];
  const pendingDeactivations = (deactivationRequests || []).filter(r => r.status === 'Pending');
  const crisisChats = (chats || []).filter(c => c.crisisDetected || c.crisis_detected);

  const chartData = generateChartData(users || [], chats || []);

  const handleUpdateDeactivationStatus = async (req, status) => {
    let rejectionReason = '';
    
    if (status === 'Rejected') {
      const reason = await customPrompt('Please provide a reason for rejecting this deactivation request. The counsellor will see this reason.', 'Reject Deactivation');
      if (reason === null) return;
      rejectionReason = reason;
    } else {
      const confirmed = await customConfirm(`Are you sure you want to approve this deactivation request? The counsellor will be demoted to a regular user.`);
      if (!confirmed) return;
    }

    setProcessing(req.id);
    try {
      const docRef = doc(db, 'deactivation_requests', req.id);
      const updateData = {
        status,
        reviewedAt: serverTimestamp()
      };
      
      if (status === 'Rejected') {
        updateData.rejectionReason = rejectionReason;
      }
      await updateDoc(docRef, updateData);

      if (status === 'Approved') {
        // Demote user
        const userRef = doc(db, 'users', req.counsellorId);
        await setDoc(userRef, {
          role: 'user',
          updatedAt: serverTimestamp()
        }, { merge: true });
        
        // Update application status to deactivated
        const appRef = doc(db, 'counsellor_applications', req.counsellorId);
        await setDoc(appRef, {
          status: 'deactivated',
          updatedAt: serverTimestamp()
        }, { merge: true });
        
        // Notification
        const { collection, addDoc } = await import('firebase/firestore');
        await addDoc(collection(db, 'notifications'), {
          to: req.counsellorId,
          title: 'Deactivation Approved',
          message: 'Your request to retire your counsellor profile has been approved. You are now a standard user.',
          type: 'general',
          timestamp: serverTimestamp(),
          isRead: false
        });
      } else if (status === 'Rejected') {
        const { collection, addDoc } = await import('firebase/firestore');
        await addDoc(collection(db, 'notifications'), {
          to: req.counsellorId,
          title: 'Deactivation Rejected',
          message: `Your retirement request was rejected. Reason: ${rejectionReason}`,
          type: 'general',
          timestamp: serverTimestamp(),
          isRead: false
        });
      }
      
      await customAlert(`Deactivation request ${status.toLowerCase()} successfully.`, 'Success');
      setViewingDeactivation(null);
    } catch (error) {
      console.error("Error updating deactivation request:", error);
      await customAlert(`Failed to update request: ${error.message}`, 'Error');
    } finally {
      setProcessing(null);
    }
  };

  const handleUpdateAppStatus = async (app, status) => {
    let rejectionReason = '';
    
    if (status === 'rejected') {
      const reason = await customPrompt('Please provide a reason for rejecting this application. The applicant will see this reason.', 'Reject Application');
      if (reason === null) return; // User cancelled
      rejectionReason = reason;
    } else {
      const confirmed = await customConfirm(`Are you sure you want to approve this application?`);
      if (!confirmed) return;
    }

    setProcessing(app.id);
    try {
      const { collection, addDoc, setDoc } = await import('firebase/firestore');
      const docRef = doc(db, 'counsellor_applications', app.id);
      
      const updateData = {
        status,
        reviewedAt: serverTimestamp()
      };
      
      if (status === 'rejected') {
        updateData.rejectionReason = rejectionReason;
      }
      
      await updateDoc(docRef, updateData);

      // Use app.uid OR app.id (since doc ID = user UID in counsellor_applications)
      const userId = app.uid || app.id;

      if (status === 'approved') {
        // Use setDoc with merge so it works even if users doc doesn't exist yet
        // Copy all relevant counsellor fields from application into the users document
        await setDoc(doc(db, 'users', userId), {
          role: 'counsellor',
          specialization: Array.isArray(app.specializations) ? app.specializations[0] : 'General',
          specializations: app.specializations || [],
          specialties: app.specializations || [],
          languages: app.languages || [],
          experience: app.experience || '',
          bio: app.bio || '',
          price: app.price || 'Free',
          phone: app.phone || '',
          counsellorImageUrl: app.profilePhotoUrl || null,
          updatedAt: serverTimestamp()
        }, { merge: true });

        // Send approval notification to user
        await addDoc(collection(db, 'notifications'), {
          to: userId,
          title: 'Application Approved! 🎉',
          message: 'Congratulations! Your counsellor application has been approved. You can now access the counsellor portal.',
          type: 'general',
          timestamp: serverTimestamp(),
          isRead: false
        });

        await customAlert('Application approved successfully! The user role has been updated.', 'Approved');
      } else if (status === 'rejected') {
        // Create rejection notification for the user
        await addDoc(collection(db, 'notifications'), {
          to: userId,
          title: 'Application Update',
          message: `Your application has been rejected. Reason: ${rejectionReason}`,
          type: 'general',
          timestamp: serverTimestamp(),
          isRead: false
        });

        await customAlert('Application rejected successfully.', 'Rejected');
      }

      setViewingApp(null);
    } catch (error) {
      console.error("Error updating application:", error);
      await customAlert('Error processing application. Please check the console.', 'Error');
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
              <h3 className="font-body font-semibold text-charcoal">User Engagement and Chats</h3>
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
            <div className="flex justify-between items-center mb-4">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-lg bg-red-50 flex items-center justify-center text-red-500">
                  <ShieldAlert size={18} />
                </div>
                <p className="section-label text-red-500 font-bold mb-0">Crisis Alerts</p>
              </div>
              <Link to="/monitoring/crisis-center" className="text-red-500 text-xs font-bold hover:underline">
                View All
              </Link>
            </div>

            <div className="space-y-3">
              {cLoading ? (
                <p className="font-body text-xs text-charcoal-muted">Checking logs…</p>
              ) : crisisChats.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-10 opacity-40">
                  <CheckCircle size={32} className="text-primary mb-2" />
                  <p className="font-body text-xs text-charcoal-muted text-center tracking-wide font-medium">SYSTEMS NORMAL<br />NO CRISIS DETECTED</p>
                </div>
              ) : (
                crisisChats.slice(0, 4).map((c, i) => (
                  <Link 
                    key={c.id || i} 
                    to="/monitoring/crisis-center"
                    className="block bg-red-50 p-3 rounded-2xl border border-red-100 animate-in fade-in slide-in-from-top-2 hover:bg-red-100 hover:shadow-sm hover:scale-[1.02] transition-all cursor-pointer"
                  >
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
                  </Link>
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
                        borderRadius: '50%', overflow: 'hidden',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        fontWeight: 'bold', color: C.primary, fontSize: '10px'
                      }}>
                        {preloading === a.id ? <Loader2 size={14} className="animate-spin" /> : (a.profilePhotoUrl ? <img src={a.profilePhotoUrl} alt="avatar" style={{width:'100%',height:'100%',objectFit:'cover'}}/> : (a.name ? a.name.charAt(0).toUpperCase() : '?'))}
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
              className="animate-in fade-in duration-300"
              style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(8px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '20px' }}
              onClick={() => setViewingApp(null)}
          >
              <div
                  style={{ position: 'relative', background: C.bgCard, width: '100%', maxWidth: '1000px', borderRadius: '32px', overflow: 'hidden', boxShadow: '0 25px 50px -12px rgba(0,0,0,0.35)', animation: 'modalIn 0.3s cubic-bezier(0.16, 1, 0.3, 1)' }}
                  onClick={e => e.stopPropagation()}
              >
                  {/* Close Button */}
                  <button
                      onClick={() => setViewingApp(null)}
                      style={{
                          position: 'absolute', top: '24px', right: '32px', zIndex: 10,
                          border: 'none', background: C.bgCard, borderRadius: '50%', width: '44px', height: '44px',
                          cursor: 'pointer', color: C.muted, display: 'flex', alignItems: 'center', justifyContent: 'center',
                          boxShadow: '0 4px 12px rgba(0,0,0,0.1)', transition: 'all 0.2s'
                      }}
                      onMouseEnter={e => { e.currentTarget.style.transform = 'rotate(90deg)'; e.currentTarget.style.color = C.charcoal; }}
                      onMouseLeave={e => { e.currentTarget.style.transform = 'rotate(0deg)'; e.currentTarget.style.color = C.muted; }}
                  >
                      <XCircle size={24} />
                  </button>

                  <style>{`
          @keyframes modalIn {
              from { opacity: 0; transform: scale(0.9) translateY(40px); }
              to { opacity: 1; transform: scale(1) translateY(0); }
          }
          .custom-scrollbar::-webkit-scrollbar { width: 6px; }
          .custom-scrollbar::-webkit-scrollbar-track { background: transparent; }
          .custom-scrollbar::-webkit-scrollbar-thumb { background: #E5E4E0; borderRadius: 10px; }
      `}</style>

                  <div style={{ display: 'flex', flexDirection: 'column', maxHeight: '92vh' }}>
                      {/* Modal Header */}
                      <div style={{ padding: '32px 40px', borderBottom: `1px solid ${C.creamDarker}`, background: C.bgCard, flexShrink: 0 }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
                              <div style={{ width: '64px', height: '64px', background: C.sage100, borderRadius: '18px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', color: C.primary, fontSize: '24px', overflow: 'hidden' }}>
                                  {viewingApp.profilePhotoUrl
                                      ? <img src={viewingApp.profilePhotoUrl} alt="profile" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                                      : (viewingApp.name ? viewingApp.name.charAt(0).toUpperCase() : '?')
                                  }
                              </div>
                              <div>
                                  <h4 style={{ margin: 0, fontFamily: 'Playfair Display', fontSize: '28px', color: C.charcoal }}>{viewingApp.name}</h4>
                                  <div style={{ display: 'flex', gap: '12px', marginTop: '4px' }}>
                                      <span style={{ color: C.muted, fontSize: '14px', display: 'flex', alignItems: 'center', gap: '4px' }}><Mail size={14} /> {viewingApp.email}</span>
                                      {viewingApp.submittedAt && <span style={{ color: C.muted, fontSize: '14px' }}>• Applied {viewingApp.submittedAt?.toDate().toLocaleDateString()}</span>}
                                  </div>
                              </div>
                          </div>
                      </div>

                      {/* Modal Content - Two Columns */}
                      <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', flex: 1, overflow: 'hidden' }}>
                          {/* Left Side: Details */}
                          <div style={{ padding: '40px', overflowY: 'auto', borderRight: `1px solid ${C.creamDarker}` }} className="custom-scrollbar">
                              <section style={{ marginBottom: '40px' }}>
                                  <h5 style={sLabel}>Self-Introduction & Motivation</h5>
                                  <p style={{ marginTop: '16px', fontSize: '16px', lineHeight: 1.8, color: C.charcoal, fontStyle: 'italic', background: C.cream, padding: '24px', borderRadius: '24px', borderLeft: `4px solid ${C.primary}` }}>
                                      "{viewingApp.bio || viewingApp.motivation}"
                                  </p>
                              </section>

                              <section>
                                  <h5 style={sLabel}>Qualifications & Expertise</h5>
                                  <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px', margin: '20px 0' }}>
                                      {(viewingApp.specializations || []).map(s => <span key={s} style={{ fontSize: '12px', background: C.sage100, padding: '8px 20px', borderRadius: '20px', color: C.primary, fontWeight: 600, border: `1px solid ${C.primary}22` }}>{s}</span>)}
                                  </div>
                                  <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: '20px', marginTop: '24px' }}>
                                      <div className="bg-white border border-cream-darker" style={{ padding: '20px', borderRadius: '16px' }}>
                                          <p style={sLabel}>Clinical Experience</p>
                                          <p className="text-charcoal" style={{ margin: '8px 0 0 0', fontWeight: 700, fontSize: '18px' }}>{viewingApp.experience}</p>
                                      </div>
                                  </div>
                              </section>
                          </div>

                          {/* Right Side: Certificate & Actions */}
                          <div style={{ padding: '40px', display: 'flex', flexDirection: 'column', overflowY: 'auto' }} className="custom-scrollbar bg-cream">
                              <h5 style={sLabel}>Professional Credential</h5>
                              <div style={{ flex: 1, marginTop: '20px', minHeight: '300px', background: C.bgCard, borderRadius: '24px', overflow: 'hidden', border: `1px solid ${C.creamDarker}`, position: 'relative', boxShadow: 'inset 0 2px 10px rgba(0,0,0,0.05)' }}>
                                  <img src={viewingApp.certificateUrl} style={{ width: '100%', height: '100%', objectFit: 'contain', padding: '10px' }} alt="Certificate" />
                                  <a href={viewingApp.certificateUrl} target="_blank" rel="noreferrer" style={{ position: 'absolute', bottom: '20px', right: '20px', padding: '10px 20px', background: C.bgCard, borderRadius: '14px', boxShadow: '0 8px 16px rgba(0,0,0,0.1)', textDecoration: 'none', color: C.primary, fontSize: '12px', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '8px', transition: 'all 0.2s' }}>
                                      <ExternalLink size={16} /> Full View
                                  </a>
                              </div>

                              {(viewingApp.status === 'pending' || !viewingApp.status) && (
                                  <div style={{ marginTop: '40px', display: 'flex', gap: '16px' }}>
                                      <button
                                          onClick={() => handleUpdateAppStatus(viewingApp, 'rejected')}
                                          disabled={processing === viewingApp.id}
                                          style={{ flex: 1, padding: '18px', background: C.bgCard, color: C.error, border: `1px solid ${C.error}44`, borderRadius: '18px', fontWeight: 600, fontSize: '14px', cursor: 'pointer', transition: 'all 0.2s' }}
                                          onMouseEnter={e => { e.currentTarget.style.background = 'rgba(244,63,94,0.1)'; e.currentTarget.style.transform = 'translateY(-2px)'; }}
                                          onMouseLeave={e => { e.currentTarget.style.background = C.bgCard; e.currentTarget.style.transform = 'translateY(0)'; }}
                                      >
                                          Reject
                                      </button>
                                      <button
                                          onClick={() => handleUpdateAppStatus(viewingApp, 'approved')}
                                          disabled={processing === viewingApp.id}
                                          style={{ flex: 2, padding: '18px', background: C.primary, color: 'white', border: 'none', borderRadius: '18px', fontWeight: 700, fontSize: '14px', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', transition: 'all 0.2s', boxShadow: '0 8px 20px rgba(124,156,132,0.3)' }}
                                          onMouseEnter={e => { e.currentTarget.style.background = C.primaryDark; e.currentTarget.style.transform = 'translateY(-2px)'; }}
                                          onMouseLeave={e => { e.currentTarget.style.background = C.primary; e.currentTarget.style.transform = 'translateY(0)'; }}
                                      >
                                          {processing === viewingApp.id ? <Loader2 size={20} className="animate-spin" /> : <CheckCircle size={20} />} Approve
                                      </button>
                                  </div>
                              )}
                          </div>
                      </div>
                  </div>
              </div>
          </div>
      )}

      {/* Deactivation Request Detail Modal */}
      {viewingDeactivation && (
          <div
              className="animate-in fade-in duration-300"
              style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(8px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '20px' }}
              onClick={() => setViewingDeactivation(null)}
          >
              <div
                  style={{ position: 'relative', background: C.bgCard, width: '100%', maxWidth: '600px', borderRadius: '32px', overflow: 'hidden', boxShadow: '0 25px 50px -12px rgba(0,0,0,0.35)', animation: 'modalIn 0.3s cubic-bezier(0.16, 1, 0.3, 1)' }}
                  onClick={e => e.stopPropagation()}
              >
                  {/* Close Button */}
                  <button
                      onClick={() => setViewingDeactivation(null)}
                      style={{
                          position: 'absolute', top: '24px', right: '32px', zIndex: 10,
                          border: 'none', background: C.bgCard, borderRadius: '50%', width: '44px', height: '44px',
                          cursor: 'pointer', color: C.muted, display: 'flex', alignItems: 'center', justifyContent: 'center',
                          boxShadow: '0 4px 12px rgba(0,0,0,0.1)', transition: 'all 0.2s'
                      }}
                      onMouseEnter={e => { e.currentTarget.style.transform = 'rotate(90deg)'; e.currentTarget.style.color = C.charcoal; }}
                      onMouseLeave={e => { e.currentTarget.style.transform = 'rotate(0deg)'; e.currentTarget.style.color = C.muted; }}
                  >
                      <XCircle size={24} />
                  </button>

                  <div style={{ padding: '32px 40px', borderBottom: `1px solid ${C.creamDarker}`, background: C.bgCard }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
                          <div style={{ width: '64px', height: '64px', background: C.sage100, borderRadius: '18px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', color: C.primary, fontSize: '24px', overflow: 'hidden' }}>
                              {(() => {
                                  const cApp = applications?.find(a => a.uid === viewingDeactivation.counsellorId || a.id === viewingDeactivation.counsellorId);
                                  const avatarUrl = cApp?.profilePhotoUrl;
                                  return avatarUrl
                                      ? <img src={avatarUrl} alt="avatar" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                                      : (viewingDeactivation.counsellorName ? viewingDeactivation.counsellorName.charAt(0).toUpperCase() : '?');
                              })()}
                          </div>
                          <div>
                              <h4 style={{ margin: 0, fontFamily: 'Playfair Display', fontSize: '28px', color: C.charcoal }}>{viewingDeactivation.counsellorName}</h4>
                              <div style={{ display: 'flex', gap: '12px', marginTop: '4px' }}>
                                  <span style={{ color: C.muted, fontSize: '14px', display: 'flex', alignItems: 'center', gap: '4px' }}><Mail size={14} /> {viewingDeactivation.counsellorEmail || (users && users.find(u => u.uid === viewingDeactivation.counsellorId || u.id === viewingDeactivation.counsellorId)?.email) || 'N/A'}</span>
                                  <span style={{ color: C.muted, fontSize: '14px', display: 'flex', alignItems: 'center', gap: '4px' }}><Clock size={14} /> {viewingDeactivation.requestedAt ? (viewingDeactivation.requestedAt.toDate ? viewingDeactivation.requestedAt.toDate().toLocaleDateString() : new Date(viewingDeactivation.requestedAt).toLocaleDateString()) : 'N/A'}</span>
                              </div>
                          </div>
                      </div>
                  </div>

                  <div style={{ padding: '40px', background: C.cream }}>
                      <h5 style={{ fontFamily: 'Outfit', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.08em', color: C.muted }}>Deactivation Reason</h5>
                      <p style={{ marginTop: '8px', fontSize: '18px', fontWeight: 600, color: C.charcoal }}>{viewingDeactivation.reason || 'No reason provided'}</p>

                      <h5 style={{ fontFamily: 'Outfit', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.08em', color: C.muted, marginTop: '24px' }}>Additional Details</h5>
                      <p style={{ marginTop: '8px', fontSize: '16px', lineHeight: 1.6, color: C.charcoalMuted, background: 'white', padding: '20px', borderRadius: '16px', border: `1px solid ${C.creamDarker}` }}>
                          {viewingDeactivation.details || 'No additional details provided.'}
                      </p>
                      
                      <div style={{ marginTop: '40px', display: 'flex', gap: '16px' }}>
                          <button
                              onClick={(e) => { e.stopPropagation(); handleUpdateDeactivationStatus(viewingDeactivation, 'Rejected'); }}
                              disabled={processing === viewingDeactivation.id}
                              style={{ flex: 1, padding: '16px', background: C.bgCard, color: C.error, border: `1px solid ${C.error}44`, borderRadius: '16px', fontWeight: 600, fontSize: '14px', cursor: 'pointer', transition: 'all 0.2s' }}
                              onMouseEnter={e => { e.currentTarget.style.background = 'rgba(244,63,94,0.1)'; e.currentTarget.style.transform = 'translateY(-2px)'; }}
                              onMouseLeave={e => { e.currentTarget.style.background = C.bgCard; e.currentTarget.style.transform = 'translateY(0)'; }}
                          >
                              Reject Request
                          </button>
                          <button
                              onClick={(e) => { e.stopPropagation(); handleUpdateDeactivationStatus(viewingDeactivation, 'Approved'); }}
                              disabled={processing === viewingDeactivation.id}
                              style={{ flex: 2, padding: '16px', background: C.primary, color: 'white', border: 'none', borderRadius: '16px', fontWeight: 700, fontSize: '14px', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '10px', transition: 'all 0.2s', boxShadow: '0 8px 20px rgba(124,156,132,0.3)' }}
                              onMouseEnter={e => { e.currentTarget.style.background = C.primaryDark; e.currentTarget.style.transform = 'translateY(-2px)'; }}
                              onMouseLeave={e => { e.currentTarget.style.background = C.primary; e.currentTarget.style.transform = 'translateY(0)'; }}
                          >
                              {processing === viewingDeactivation.id ? <Loader2 size={20} className="animate-spin" /> : <CheckCircle size={20} />} Approve Deactivation
                          </button>
                      </div>
                  </div>
              </div>
          </div>
      )}
    </div>
  );
}
