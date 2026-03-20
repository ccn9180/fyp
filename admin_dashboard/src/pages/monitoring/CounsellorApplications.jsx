import { useState, useEffect } from 'react';
import { doc, updateDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../../firebase';
import { useCounsellorApplications } from '../../hooks/useFirestore';
import { CheckCircle, XCircle, Clock, ExternalLink, ShieldCheck, Mail, BookOpen, Award, Loader2 } from 'lucide-react';

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
const badge = (type) => ({ 
    display: 'inline-flex', 
    padding: '4px 12px', 
    borderRadius: '999px', 
    fontSize: '11px', 
    fontWeight: 700, 
    fontFamily: 'Outfit', 
    background: type === 'approved' ? '#ecfdf5' : type === 'rejected' ? '#fef2f2' : '#fffbeb', 
    color: type === 'approved' ? C.success : type === 'rejected' ? C.error : C.amber,
    textTransform: 'capitalize'
});

export default function CounsellorApplications() {
  const { data: applications, loading } = useCounsellorApplications();
  const [processing, setProcessing] = useState(null);
  const [viewingApp, setViewingApp] = useState(null);
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
      setViewingApp(app); // Show even if fail, but usually good to have fallback
    };
  };

  const handleAction = async (app, newStatus) => {
    if (!window.confirm(`Are you sure you want to ${newStatus} this application?`)) return;
    setProcessing(app.id);
    try {
      // 1. Update Application Status
      await updateDoc(doc(db, 'counsellor_applications', app.id), {
        status: newStatus,
        reviewedAt: serverTimestamp()
      });

      // 2. If Approved, update User Role
      if (newStatus === 'approved') {
        const userRef = doc(db, 'users', app.uid);
        await updateDoc(userRef, {
          role: 'counsellor',
          specialization: Array.isArray(app.specializations) ? app.specializations[0] : 'General',
          specialties: app.specializations || [],
          updatedAt: serverTimestamp()
        });
      }

      alert(`Application ${newStatus} successfully.`);
      setViewingApp(null);
    } catch (error) {
      console.error("Action error:", error);
      alert("Error processing application. Check console.");
    } finally {
      setProcessing(null);
    }
  };

  const pending = applications.filter(a => a.status === 'pending');
  const history = applications.filter(a => a.status !== 'pending');

  return (
    <div className="flex flex-col gap-6" style={{ position: 'relative' }}>
      <div>
        <p className="section-label mb-1">Recruitment</p>
        <h2 className="font-display font-semibold text-2xl text-charcoal">Counsellor Applications</h2>
      </div>

      {loading ? (
        <p className="font-body text-sm text-charcoal-muted">Loading applications...</p>
      ) : (
        <>
            <div className="card">
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '20px' }}>
                    <Clock size={18} color={C.amber} />
                    <h3 className="font-display text-lg font-semibold">Active Applications ({pending.length})</h3>
                </div>

                {pending.length === 0 ? (
                    <p style={{ fontFamily: 'Outfit', fontSize: '14px', color: C.muted, textAlign: 'center', padding: '40px 0' }}>No active applications to review.</p>
                ) : (
                    <div className="overflow-x-auto">
                        <table className="w-full font-body text-sm">
                            <thead>
                                <tr style={{ borderBottom: `1px solid ${C.creamDarker}`, textAlign: 'left' }}>
                                    {['Applicant', 'Expertise', 'Exp.', 'License', 'Action'].map(h => (
                                        <th key={h} className="pb-3 font-semibold section-label text-[10px]">{h}</th>
                                    ))}
                                </tr>
                            </thead>
                            <tbody>
                                {pending.map(app => (
                                    <tr 
                                        key={app.id} 
                                        onClick={() => viewDetailsWithPreload(app)}
                                        style={{ borderBottom: `1px solid ${C.creamDarker}`, cursor: 'pointer' }} 
                                        className="hover:bg-cream transition-colors group"
                                    >
                                        <td className="py-4 pr-4">
                                            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                                                <div style={{ 
                                                    width: '32px', height: '32px', 
                                                    background: preloading === app.id ? 'transparent' : C.sage100, 
                                                    borderRadius: '50%', 
                                                    display: 'flex', alignItems: 'center', justifyContent: 'center', 
                                                    fontWeight: 'bold', color: C.primary, fontSize: '11px', flexShrink: 0 
                                                }}>
                                                    {preloading === app.id ? <Loader2 size={16} className="animate-spin" /> : (app.name ? app.name.charAt(0).toUpperCase() : '?')}
                                                </div>
                                                <div>
                                                    <p style={{ margin: 0, fontWeight: 600, fontSize: '14px' }} className="text-charcoal group-hover:text-primary transition-colors">{app.name}</p>
                                                    <p style={{ margin: 0, fontSize: '11px', color: C.muted }}>{app.email}</p>
                                                </div>
                                            </div>
                                        </td>
                                        <td className="py-4 pr-4">
                                            <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px' }}>
                                                {(app.specializations || []).slice(0, 2).map(s => <span key={s} style={{ fontSize: '10px', background: C.cream, padding: '2px 8px', borderRadius: '4px', color: C.charcoalMuted }}>{s}</span>)}
                                            </div>
                                        </td>
                                        <td className="py-4 pr-4 font-medium text-charcoal">{app.experience} Yrs</td>
                                        <td className="py-4 pr-4 font-mono text-xs text-charcoal-muted">{app.licenseNumber}</td>
                                        <td className="py-4">
                                            <div style={{ display: 'flex', gap: '8px' }} onClick={e => e.stopPropagation()}>
                                                <button 
                                                    onClick={() => handleAction(app, 'rejected')}
                                                    disabled={processing === app.id}
                                                    className="bg-red-50 hover:bg-red-100 text-red-500 px-3 py-1.5 rounded-xl text-[11px] font-bold shadow-sm transition-all border border-red-100"
                                                >
                                                     Reject
                                                </button>
                                                <button 
                                                    onClick={() => handleAction(app, 'approved')}
                                                    disabled={processing === app.id}
                                                    className="bg-primary hover:bg-primary-dark text-white px-3 py-1.5 rounded-xl text-[11px] font-bold shadow-sm transition-all"
                                                >
                                                    {processing === app.id ? <Loader2 size={12} className="animate-spin" /> : 'Approve'}
                                                </button>
                                            </div>
                                        </td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                )}
            </div>

            {/* Application Detail Modal Overlay */}
            {viewingApp && (
                <div 
                    className="animate-in fade-in duration-300"
                    style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(8px)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1000, padding: '20px' }}
                    onClick={() => setViewingApp(null)}
                >
                    <div 
                        style={{ position: 'relative', background: 'white', width: '100%', maxWidth: '1000px', borderRadius: '32px', overflow: 'hidden', boxShadow: '0 25px 50px -12px rgba(0,0,0,0.35)', animation: 'modalIn 0.3s cubic-bezier(0.16, 1, 0.3, 1)' }}
                        onClick={e => e.stopPropagation()}
                    >
                        {/* Close Button */}
                        <button 
                            onClick={() => setViewingApp(null)} 
                            style={{ 
                                position: 'absolute', top: '24px', right: '32px', zIndex: 10,
                                border: 'none', background: 'white', borderRadius: '50%', width: '44px', height: '44px', 
                                cursor: 'pointer', color: C.muted, display: 'flex', alignItems: 'center', justifyContent: 'center',
                                boxShadow: '0 4px 12px rgba(0,0,0,0.1)', transition: 'all 0.2s'
                            }}
                            onMouseEnter={e => { e.currentTarget.style.transform = 'rotate(90deg)'; e.currentTarget.style.color = C.charcoal; }}
                            onMouseLeave={e => { e.currentTarget.style.transform = 'rotate(0deg)'; e.currentTarget.style.color = C.muted; }}
                        >
                            <XCircle size={24}/>
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
                            <div style={{ padding: '32px 40px', borderBottom: `1px solid ${C.creamDarker}`, background: 'white', flexShrink: 0 }}>
                                <div style={{ display: 'flex', alignItems: 'center', gap: '20px' }}>
                                    <div style={{ width: '64px', height: '64px', background: C.sage100, borderRadius: '18px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', color: C.primary, fontSize: '24px' }}>
                                        {viewingApp.name ? viewingApp.name.charAt(0).toUpperCase() : '?'}
                                    </div>
                                    <div>
                                        <h4 style={{ margin: 0, fontFamily: 'Playfair Display', fontSize: '28px', color: C.charcoal }}>{viewingApp.name}</h4>
                                        <div style={{ display: 'flex', gap: '12px', marginTop: '4px' }}>
                                            <span style={{ color: C.muted, fontSize: '14px', display: 'flex', alignItems: 'center', gap: '4px' }}><Mail size={14}/> {viewingApp.email}</span>
                                            <span style={{ color: C.muted, fontSize: '14px' }}>• Applied {viewingApp.submittedAt?.toDate().toLocaleDateString()}</span>
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
                                            "{viewingApp.motivation}"
                                        </p>
                                    </section>

                                    <section>
                                        <h5 style={sLabel}>Qualifications & Expertise</h5>
                                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '10px', margin: '20px 0' }}>
                                            {(viewingApp.specializations || []).map(s => <span key={s} style={{ fontSize: '12px', background: C.sage100, padding: '8px 20px', borderRadius: '20px', color: C.primary, fontWeight: 600, border: `1px solid ${C.primary}22` }}>{s}</span>)}
                                        </div>
                                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', marginTop: '24px' }}>
                                            <div style={{ padding: '20px', background: '#f8faf9', borderRadius: '16px', border: '1px solid #eee' }}>
                                                <p style={sLabel}>License Number</p>
                                                <p style={{ margin: '8px 0 0 0', fontWeight: 700, fontSize: '18px', color: C.charcoal }}>{viewingApp.licenseNumber}</p>
                                            </div>
                                            <div style={{ padding: '20px', background: '#f8faf9', borderRadius: '16px', border: '1px solid #eee' }}>
                                                <p style={sLabel}>Clinical Experience</p>
                                                <p style={{ margin: '8px 0 0 0', fontWeight: 700, fontSize: '18px', color: C.charcoal }}>{viewingApp.experience} Years</p>
                                            </div>
                                        </div>
                                    </section>
                                </div>

                                {/* Right Side: Certificate & Actions */}
                                <div style={{ padding: '40px', background: '#FAFAFA', display: 'flex', flexDirection: 'column', overflowY: 'auto' }} className="custom-scrollbar">
                                    <h5 style={sLabel}>Professional Credential</h5>
                                    <div style={{ flex: 1, marginTop: '20px', minHeight: '300px', background: 'white', borderRadius: '24px', overflow: 'hidden', border: `1px solid ${C.creamDarker}`, position: 'relative', boxShadow: 'inset 0 2px 10px rgba(0,0,0,0.05)' }}>
                                        <img src={viewingApp.certificateUrl} style={{ width: '100%', height: '100%', objectFit: 'contain', padding: '10px' }} alt="Certificate" />
                                        <a href={viewingApp.certificateUrl} target="_blank" rel="noreferrer" style={{ position: 'absolute', bottom: '20px', right: '20px', padding: '10px 20px', background: 'white', borderRadius: '14px', boxShadow: '0 8px 16px rgba(0,0,0,0.1)', textDecoration: 'none', color: C.primary, fontSize: '12px', fontWeight: 700, display: 'flex', alignItems: 'center', gap: '8px', transition: 'all 0.2s' }}>
                                            <ExternalLink size={16} /> Full View
                                        </a>
                                    </div>

                                     {viewingApp.status === 'pending' && (
                                        <div style={{ marginTop: '40px', display: 'flex', gap: '16px' }}>
                                            <button 
                                                onClick={() => handleAction(viewingApp, 'rejected')}
                                                disabled={processing === viewingApp.id}
                                                style={{ flex: 1, padding: '18px', background: 'white', color: C.error, border: `1px solid ${C.error}44`, borderRadius: '18px', fontWeight: 600, fontSize: '14px', cursor: 'pointer', transition: 'all 0.2s' }}
                                                onMouseEnter={e => { e.currentTarget.style.background = '#fff5f5'; e.currentTarget.style.transform = 'translateY(-2px)'; }}
                                                onMouseLeave={e => { e.currentTarget.style.background = 'white'; e.currentTarget.style.transform = 'translateY(0)'; }}
                                            >
                                                Reject
                                            </button>
                                            <button 
                                                onClick={() => handleAction(viewingApp, 'approved')}
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

            {/* History Section */}
            <div className="card">
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '20px' }}>
                    <ShieldCheck size={18} color={C.primary} />
                    <h3 className="font-display text-lg font-semibold">Recent History ({history.length})</h3>
                </div>

                <div className="overflow-x-auto">
                    <table className="w-full font-body text-sm">
                        <thead>
                            <tr style={{ borderBottom: `1px solid ${C.creamDarker}`, textAlign: 'left' }}>
                                {['Applicant', 'Status', 'License', 'Specialization', 'Reviewed On'].map(h => (
                                    <th key={h} className="pb-2 font-semibold section-label text-[10px]">{h}</th>
                                ))}
                            </tr>
                        </thead>
                        <tbody>
                            {history.slice(0, 10).map(app => (
                                <tr 
                                    key={app.id} 
                                    style={{ borderBottom: `1px solid ${C.creamDarker}`, cursor: 'pointer' }} 
                                    className="hover:bg-cream transition group"
                                    onClick={() => viewDetailsWithPreload(app)}
                                >
                                    <td className="py-3 pr-4">
                                        <div style={{ fontWeight: 600 }} className="text-charcoal group-hover:text-primary transition-colors">{app.name}</div>
                                        <div style={{ fontSize: '11px', color: C.muted }}>{app.email}</div>
                                    </td>
                                    <td className="py-3 pr-4">
                                        <span style={badge(app.status)}>{app.status}</span>
                                    </td>
                                    <td className="py-3 pr-4 text-charcoal-muted font-mono text-xs">{app.licenseNumber}</td>
                                    <td className="py-3 pr-4 text-charcoal-muted">
                                        <div className="flex flex-wrap gap-1">
                                            {(Array.isArray(app.specializations) ? app.specializations : []).slice(0, 1).map(s => (
                                                <span key={s}>{s}</span>
                                            )) || 'General'}
                                        </div>
                                    </td>
                                    <td className="py-3 pr-4 text-muted">
                                        {app.reviewedAt?.toDate ? app.reviewedAt.toDate().toLocaleDateString() : 'N/A'}
                                    </td>
                                </tr>
                            ))}
                            {history.length === 0 && (
                                <tr>
                                    <td colSpan="5" className="py-8 text-center text-charcoal-muted opacity-60">No application history found.</td>
                                </tr>
                            )}
                        </tbody>
                    </table>
                </div>
            </div>
        </>
      )}
    </div>
  );
}
