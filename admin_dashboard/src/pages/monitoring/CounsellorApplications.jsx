import { useState, useEffect, useMemo, useRef } from 'react';
import { doc, updateDoc, serverTimestamp, setDoc, collection, addDoc } from 'firebase/firestore';
import { db } from '../../firebase';
import { useUsers, useCounsellorApplications, useDeactivationRequests } from '../../hooks/useFirestore';
import { CheckCircle, XCircle, Clock, ExternalLink, ShieldCheck, Mail, BookOpen, Award, Loader2, Search, Filter, X, LayoutGrid, ChevronDown, Download, Upload } from 'lucide-react';
import { customAlert, customConfirm, customPrompt } from '../../utils/dialogUtils';
import {
    BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer,
    CartesianGrid
} from 'recharts';

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
  rose: '#f43f5e',
  error: '#f43f5e',
  success: '#10b981'
};

const sLabel = { fontFamily: 'Outfit', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.08em', color: C.muted };
const badge = (type) => {
    const isApp = type === 'approved';
    const isRej = type === 'rejected';
    return {
        display: 'inline-flex',
        padding: '4px 12px',
        borderRadius: '999px',
        fontSize: '11px',
        fontWeight: 700,
        fontFamily: 'Outfit',
        background: isApp ? 'rgba(16, 185, 129, 0.15)' : isRej ? 'rgba(244, 63, 94, 0.15)' : 'rgba(217, 119, 6, 0.15)',
        color: isApp ? '#10b981' : isRej ? '#f43f5e' : '#d97706',
        textTransform: 'capitalize'
    };
};

export default function CounsellorApplications() {
    const { data: applications, loading } = useCounsellorApplications();
    const { data: deactivationRequests, loading: dLoading } = useDeactivationRequests();
    const { data: users } = useUsers();
    const [processing, setProcessing] = useState(null);
    const [viewingApp, setViewingApp] = useState(null);
    const [preloading, setPreloading] = useState(null);
    const [viewingDeactivation, setViewingDeactivation] = useState(null);
    const [searchQuery, setSearchQuery] = useState('');
    const [specialtyFilter, setSpecialtyFilter] = useState('All');
    const [isDropdownOpen, setIsDropdownOpen] = useState(false);
    const [pendingPage, setPendingPage] = useState(1);
    const [historyPage, setHistoryPage] = useState(1);
    const [deactPage, setDeactPage] = useState(1);
    const itemsPerPage = 4;
    const deactItemsPerPage = 3;

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
        const confirmed = await customConfirm(`Are you sure you want to ${newStatus} this application?`, 'Confirm Action');
        if (!confirmed) return;
        setProcessing(app.id);
        try {
            // 1. Update Application Status
            await updateDoc(doc(db, 'counsellor_applications', app.id), {
                status: newStatus,
                reviewedAt: serverTimestamp()
            });

            // 2. If Approved, update User Role using setDoc merge (works even if doc doesn't exist)
            if (newStatus === 'approved') {
                const userId = app.uid || app.id;
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

                // Send approval notification
                await addDoc(collection(db, 'notifications'), {
                    to: userId,
                    title: 'Application Approved! 🎉',
                    message: 'Congratulations! Your counsellor application has been approved. You can now access the counsellor portal.',
                    type: 'general',
                    timestamp: serverTimestamp(),
                    isRead: false
                });
            }

            await customAlert(`Application ${newStatus} successfully.`, 'Success');
            setViewingApp(null);
        } catch (error) {
            console.error("Action error:", error);
            await customAlert("Error processing application. Check console.", "Error");
        } finally {
            setProcessing(null);
        }
    };

    const handleUpdateDeactivationStatus = async (id, uid, status) => {
        try {
            let reason = '';
            if (status === 'Rejected') {
                reason = await customPrompt("Please provide a reason for rejecting this deactivation request. The counsellor will see this reason.", "Reject Deactivation");
                if (reason === null) return; 
            }
            
            const reqRef = doc(db, 'deactivation_requests', id);
            await updateDoc(reqRef, {
                status: status,
                rejectionReason: reason || null,
                updatedAt: serverTimestamp()
            });

            if (status === 'Approved') {
                const userRef = doc(db, 'users', uid);
                await setDoc(userRef, { role: 'user' }, { merge: true });

                const appRef = doc(db, 'counsellor_applications', uid);
                await setDoc(appRef, { status: 'deactivated' }, { merge: true });
            }

            await customAlert(`Request ${status.toLowerCase()} successfully`, 'Success');
            setViewingDeactivation(null);
        } catch (error) {
            console.error('Error updating deactivation request:', error);
            await customAlert(`Failed to update request: ${error.message}`, 'Error');
        }
    };

    const availableSpecialties = [
        'All', 'Anxiety & Stress', 'Depression', 'Relationship Issues', 
        'Trauma & PTSD', 'Career Counseling', 'Addiction Recovery',
        'OCD', 'Grief & Loss', 'Eating Disorders'
    ];

    const MOCK_DATA = [
        { id: 'm1', name: 'Dr. Elizabeth Chen', email: 'e.chen@wellness.com', specializations: ['Trauma & PTSD', 'Crisis Intervention'], experience: '12', licenseNumber: 'PSY-99281', status: 'pending', motivation: 'I have dedicated my career to trauma recovery and believe Eunoia is the perfect platform for remote support.', certificateUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=800', submittedAt: { toDate: () => new Date('2026-03-28') } },
        { id: 'm2', name: 'Dr. Marcus Thorne', email: 'm.thorne@mentalhealth.org', specializations: ['Anxiety & Stress', 'Depression'], experience: '8', licenseNumber: 'LCSW-8821', status: 'pending', motivation: 'My focus is on cognitive behavioral therapy for young adults dealing with high-stress environments.', certificateUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=800', submittedAt: { toDate: () => new Date('2026-03-30') } },
        { id: 'm3', name: 'Dr. Sarah Winters', email: 's.winters@clinical.edu', specializations: ['Grief & Loss', 'Depression'], experience: '15', licenseNumber: 'PSY-11029', status: 'approved', motivation: 'Childhood mental health is often overlooked. I want to contribute my expertise here.', certificateUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=800', submittedAt: { toDate: () => new Date('2026-03-15') }, reviewedAt: { toDate: () => new Date('2026-03-20') } },
        { id: 'm4', name: 'Dr. James Halloway', email: 'j.halloway@private.me', specializations: ['Relationship Issues', 'Grief & Loss'], experience: '10', licenseNumber: 'MFT-5561', status: 'rejected', motivation: 'Looking to expand my practice into the digital realm.', certificateUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=800', submittedAt: { toDate: () => new Date('2026-03-10') }, reviewedAt: { toDate: () => new Date('2026-03-12') } },
        { id: 'm5', name: 'Dr. Linda Vo', email: 'l.vo@unity.com', specializations: ['Anxiety & Stress', 'Eating Disorders'], experience: '6', licenseNumber: 'PSY-6672', status: 'pending', motivation: 'Mindfulness-based stress reduction is the core of my practice.', certificateUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=800', submittedAt: { toDate: () => new Date('2026-04-01') } }
    ];

    const allApps = useMemo(() => [...(applications || []), ...MOCK_DATA], [applications]);

    const filteredApps = useMemo(() => {
        return allApps.filter(app => {
            const name = (app.name || '').toLowerCase();
            const email = (app.email || '').toLowerCase();
            const query = searchQuery.toLowerCase();
            const matchesSearch = name.includes(query) || email.includes(query);

            const specs = app.specializations || [];
            const matchesSpecialty = specialtyFilter === 'All' || specs.includes(specialtyFilter);

            return matchesSearch && matchesSpecialty;
        });
    }, [allApps, searchQuery, specialtyFilter]);

    const chartData = useMemo(() => {
        const stats = { pending: 0, approved: 0, rejected: 0 };
        filteredApps.forEach(a => {
            const s = (a.status || 'pending').toLowerCase();
            if (stats[s] !== undefined) stats[s]++;
        });
        return [
            { name: 'Pending Review', count: stats.pending, fill: '#d97706' },
            { name: 'Approved', count: stats.approved, fill: '#10b981' },
            { name: 'Rejected', count: stats.rejected, fill: '#f87171' }
        ];
    }, [filteredApps]);

    const pending = filteredApps.filter(a => a.status === 'pending');
    const history = filteredApps.filter(a => a.status !== 'pending');

    const paginatedPending = pending.slice((pendingPage - 1) * itemsPerPage, pendingPage * itemsPerPage);
    const paginatedHistory = history.slice((historyPage - 1) * itemsPerPage, historyPage * itemsPerPage);
    const totalPendingPages = Math.ceil(pending.length / itemsPerPage);
    const totalHistoryPages = Math.ceil(history.length / itemsPerPage);

    const pendingDeactivations = (deactivationRequests || []).filter(r => r.status === 'Pending');
    const paginatedDeactivations = pendingDeactivations.slice((deactPage - 1) * deactItemsPerPage, deactPage * deactItemsPerPage);
    const totalDeactPages = Math.ceil(pendingDeactivations.length / deactItemsPerPage);

    return (
        <div className="flex flex-col gap-6" style={{ position: 'relative' }}>
            <div className="flex flex-row items-center justify-between gap-4">
                <div>
                    <p className="section-label mb-1">Recruitment</p>
                    <h2 className="font-display font-semibold text-2xl text-charcoal">Applications</h2>
                </div>

                <div className="flex flex-wrap items-center gap-3">
                    {/* Search Field */}
                    <div className="relative">
                        <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-charcoal-muted" />
                        <input
                            type="text"
                            placeholder="Search Applicants"
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            className="pl-9 pr-10 py-2 bg-white border border-cream-darker rounded-xl text-sm font-body outline-none focus:border-primary transition w-48 shadow-sm"
                        />
                        {searchQuery && (
                            <button
                                onClick={() => setSearchQuery('')}
                                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-primary p-0.5 rounded-full hover:bg-sage-50 transition"
                            >
                                <X size={14} />
                            </button>
                        )}
                    </div>

                    {/* Specialty Dropdown */}
                    <div className="relative">
                        <button
                            onClick={() => setIsDropdownOpen(!isDropdownOpen)}
                            className={`flex items-center bg-white border ${isDropdownOpen ? 'border-primary ring-2 ring-primary/10' : 'border-cream-darker'} rounded-xl px-4 py-2 shadow-sm cursor-pointer transition-all hover:bg-cream/30 active:scale-95`}
                        >
                            <div className="flex items-center gap-2">
                                <LayoutGrid size={13} className="text-primary" />
                                <span className="text-sm font-medium text-charcoal-muted whitespace-nowrap">
                                    {specialtyFilter === 'All' ? 'All Specialties' : specialtyFilter}
                                </span>
                                <ChevronDown size={14} className={`text-muted transition-transform duration-300 ${isDropdownOpen ? 'rotate-180 text-primary' : ''}`} />
                            </div>
                        </button>

                        {isDropdownOpen && (
                            <>
                                <div className="fixed inset-0 z-40" onClick={() => setIsDropdownOpen(false)} />
                                <div className="absolute top-full right-0 mt-2 w-56 bg-white border border-cream-darker rounded-[1.5rem] shadow-2xl animate-in fade-in zoom-in-95 slide-in-from-top-2 duration-200 z-50 p-2 overflow-y-auto max-h-64 custom-scrollbar transform origin-top-right">
                                    {availableSpecialties.map(s => (
                                        <button
                                            key={s}
                                            onClick={() => {
                                                setSpecialtyFilter(s);
                                                setIsDropdownOpen(false);
                                            }}
                                            className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-xl transition-all font-body text-xs font-bold text-left ${specialtyFilter === s ? 'bg-sage-100 text-primary' : 'text-charcoal-muted hover:bg-cream'}`}
                                        >
                                            <div className={`w-1.5 h-1.5 rounded-full ${specialtyFilter === s ? 'bg-primary' : 'bg-charcoal-muted/20'}`} />
                                            {s === 'All' ? 'All Specialties' : s}
                                        </button>
                                    ))}
                                </div>
                            </>
                        )}
                    </div>
                </div>
            </div>

            <div className="flex flex-col gap-6 p-1">
                {loading ? (
                    <p className="font-body text-sm text-charcoal-muted">Loading applications...</p>
                ) : (
                    <>
                        {/* Recruitment Funnel Stats - Matched to Analytics Style */}
                        <div className="grid grid-cols-5 gap-3 mb-2">
                            <div className="card flex items-center gap-3 py-3 px-4 animate-in slide-in-from-top-4 duration-300">
                                <div className="w-8 h-8 rounded-full bg-amber-500/20 flex items-center justify-center text-amber-500 shrink-0 border border-amber-500/20 shadow-sm">
                                    <Clock size={16} />
                                </div>
                                <div>
                                    <p className="section-label mb-0 !text-[9px] !leading-none text-amber-600/70 whitespace-nowrap uppercase tracking-widest">Pending Intake</p>
                                    <h3 className="font-display text-lg font-bold text-charcoal">{pending.length}</h3>
                                </div>
                            </div>

                            <div className="card flex items-center gap-3 py-3 px-4 animate-in slide-in-from-top-4 duration-500 delay-75">
                                <div className="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center text-primary shrink-0 border border-primary/20 shadow-sm">
                                    <ShieldCheck size={16} />
                                </div>
                                <div>
                                    <p className="section-label mb-0 !text-[9px] !leading-none text-primary/70 whitespace-nowrap uppercase tracking-widest">Qualified Counsellor</p>
                                    <h3 className="font-display text-lg font-bold text-charcoal">
                                        {allApps.filter(a => a.status === 'approved').length}
                                    </h3>
                                </div>
                            </div>

                            <div className="card flex items-center gap-3 py-3 px-4 animate-in slide-in-from-top-4 duration-700 delay-150">
                                <div className="w-8 h-8 rounded-full bg-gray-500/20 flex items-center justify-center text-charcoal-muted shrink-0 border border-gray-500/20 shadow-sm">
                                    <XCircle size={16} />
                                </div>
                                <div>
                                    <p className="section-label mb-0 !text-[9px] !leading-none text-charcoal-muted/70 whitespace-nowrap uppercase tracking-widest">Rejected Counsellor</p>
                                    <h3 className="font-display text-lg font-bold text-charcoal">
                                        {allApps.filter(a => a.status === 'rejected').length}
                                    </h3>
                                </div>
                            </div>

                            <div className="card flex items-center gap-3 py-3 px-4 animate-in slide-in-from-top-4 duration-700 delay-200">
                                <div className="w-8 h-8 rounded-full bg-rose-500/20 flex items-center justify-center text-rose-500 shrink-0 border border-rose-500/20 shadow-sm">
                                    <Clock size={16} />
                                </div>
                                <div>
                                    <p className="section-label mb-0 !text-[9px] !leading-none text-rose-600/70 whitespace-nowrap uppercase tracking-widest">Pending Deactivation</p>
                                    <h3 className="font-display text-lg font-bold text-charcoal">{pendingDeactivations.length}</h3>
                                </div>
                            </div>

                            <div className="card flex items-center gap-3 py-3 px-4 animate-in slide-in-from-top-4 duration-700 delay-300">
                                <div className="w-8 h-8 rounded-full bg-red-500/20 flex items-center justify-center text-red-500 shrink-0 border border-red-500/20 shadow-sm">
                                    <XCircle size={16} />
                                </div>
                                <div>
                                    <p className="section-label mb-0 !text-[9px] !leading-none text-red-600/70 whitespace-nowrap uppercase tracking-widest">Deactivated Counsellor</p>
                                    <h3 className="font-display text-lg font-bold text-charcoal">
                                        {allApps.filter(a => a.status === 'deactivated').length}
                                    </h3>
                                </div>
                            </div>
                        </div>

                        <div className="card">
                            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '20px' }}>
                                <Clock size={18} color={C.amber} />
                                <h3 className="font-display text-lg font-semibold">Pending Intake ({pending.length})</h3>
                            </div>

                            <div className="overflow-x-auto">
                                <table className="w-full font-body text-sm">
                                    <thead>
                                        <tr style={{ borderBottom: `1px solid ${C.creamDarker}`, textAlign: 'left' }}>
                                            {['Applicant', 'Expertise', 'Exp.', 'Action'].map(h => (
                                                <th key={h} className="pb-3 font-semibold section-label text-[10px]">{h}</th>
                                            ))}
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {pending.length === 0 && (
                                            <tr>
                                                <td colSpan="5" className="py-8 text-center text-charcoal-muted opacity-60 font-body text-[14px]">No active applications to review.</td>
                                            </tr>
                                        )}
                                            {paginatedPending.map(app => (
                                                <tr
                                                    key={app.id}
                                                    onClick={() => viewDetailsWithPreload(app)}
                                                    style={{ borderBottom: `1px solid ${C.creamDarker}`, cursor: 'pointer' }}
                                                    className="hover:bg-cream transition-colors group"
                                                >
                                                    <td className="py-4 pr-4">
                                                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                                                            <div className={`w-8 h-8 rounded-full flex items-center justify-center font-bold text-primary text-[11px] shrink-0 overflow-hidden ${preloading === app.id ? 'bg-transparent' : 'bg-primary/20'}`}>
                                                                {preloading === app.id ? <Loader2 size={16} className="animate-spin" /> : (
                                                                    app.profilePhotoUrl ? <img src={app.profilePhotoUrl} alt="profile" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : (app.name ? app.name.charAt(0).toUpperCase() : '?')
                                                                )}
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
                                                    <td className="py-4 pr-4 font-medium text-charcoal">{app.experience}</td>
                                                    <td className="py-4">
                                                        <div style={{ display: 'flex', gap: '8px' }} onClick={e => e.stopPropagation()}>
                                                            <button
                                                                onClick={() => handleAction(app, 'rejected')}
                                                                disabled={processing === app.id}
                                                                className="bg-red-500/10 hover:bg-red-500/20 text-red-500 px-3 py-1.5 rounded-xl text-[11px] font-bold shadow-sm transition-all border border-red-500/20"
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

                                    {/* Pagination for Pending */}
                                    {pending.length > 0 && (
                                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: '20px' }}>
                                            <p style={{ ...sLabel, textTransform: 'none', color: C.muted }}>Showing {paginatedPending.length} of {pending.length} pending</p>
                                            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                                                <button 
                                                    disabled={pendingPage === 1} 
                                                    onClick={() => setPendingPage(p => p - 1)} 
                                                    style={{ padding: '6px 14px', borderRadius: '10px', border: `1px solid ${C.creamDarker}`, background: C.bgCard, fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.charcoal, cursor: pendingPage === 1 ? 'default' : 'pointer', opacity: pendingPage === 1 ? 0.4 : 1 }}
                                                >
                                                    Previous
                                                </button>
                                                {[...Array(totalPendingPages)].map((_, i) => (
                                                    <button 
                                                        key={i}
                                                        onClick={() => setPendingPage(i + 1)}
                                                        style={{ width: '32px', height: '32px', borderRadius: '10px', border: pendingPage === i + 1 ? `1px solid ${C.primary}` : `1px solid ${C.creamDarker}`, background: pendingPage === i + 1 ? C.primary : 'white', fontFamily: 'Outfit', fontSize: '12px', fontWeight: 700, color: pendingPage === i + 1 ? 'white' : C.charcoal, cursor: 'pointer', transition: 'all 0.2s' }}
                                                    >
                                                        {i + 1}
                                                    </button>
                                                ))}
                                                <button 
                                                    disabled={pendingPage >= totalPendingPages || totalPendingPages === 0} 
                                                    onClick={() => setPendingPage(p => p + 1)} 
                                                    style={{ padding: '6px 14px', borderRadius: '10px', border: `1px solid ${C.creamDarker}`, background: C.bgCard, fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.charcoal, cursor: (pendingPage >= totalPendingPages || totalPendingPages === 0) ? 'default' : 'pointer', opacity: (pendingPage >= totalPendingPages || totalPendingPages === 0) ? 0.4 : 1 }}
                                                >
                                                    Next
                                                </button>
                                            </div>
                                        </div>
                                    )}
                                </div>
                        </div>

                        {/* Application Detail Modal Overlay */}
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

                                                {viewingApp.status === 'pending' && (
                                                    <div style={{ marginTop: '40px', display: 'flex', gap: '16px' }}>
                                                        <button
                                                            onClick={() => handleAction(viewingApp, 'rejected')}
                                                            disabled={processing === viewingApp.id}
                                                            style={{ flex: 1, padding: '18px', background: C.bgCard, color: C.error, border: `1px solid ${C.error}44`, borderRadius: '18px', fontWeight: 600, fontSize: '14px', cursor: 'pointer', transition: 'all 0.2s' }}
                                                            onMouseEnter={e => { e.currentTarget.style.background = 'rgba(244,63,94,0.1)'; e.currentTarget.style.transform = 'translateY(-2px)'; }}
                                                            onMouseLeave={e => { e.currentTarget.style.background = C.bgCard; e.currentTarget.style.transform = 'translateY(0)'; }}
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
                                        {paginatedHistory.map(app => (
                                            <tr
                                                key={app.id}
                                                style={{ borderBottom: `1px solid ${C.creamDarker}`, cursor: 'pointer' }}
                                                className="hover:bg-cream transition group"
                                                onClick={() => viewDetailsWithPreload(app)}
                                            >
                                                <td className="py-3 pr-4">
                                                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                                                        <div className="w-8 h-8 rounded-full bg-primary/20 flex items-center justify-center font-bold text-primary text-[11px] shrink-0 overflow-hidden">
                                                            {app.profilePhotoUrl ? <img src={app.profilePhotoUrl} alt="profile" style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : (app.name ? app.name.charAt(0).toUpperCase() : '?')}
                                                        </div>
                                                        <div>
                                                            <div style={{ fontWeight: 600 }} className="text-charcoal group-hover:text-primary transition-colors">{app.name}</div>
                                                            <div style={{ fontSize: '11px', color: C.muted }}>{app.email}</div>
                                                        </div>
                                                    </div>
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
                                                <td colSpan="5" className="py-8 text-center text-charcoal-muted opacity-60 font-body text-[14px]">No application history found.</td>
                                            </tr>
                                        )}
                                    </tbody>
                                </table>

                                {/* Pagination for History */}
                                {history.length > 0 && (
                                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: '20px' }}>
                                        <p style={{ ...sLabel, textTransform: 'none', color: C.muted }}>Showing {paginatedHistory.length} of {history.length} reviews</p>
                                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                                            <button 
                                                disabled={historyPage === 1} 
                                                onClick={() => setHistoryPage(p => p - 1)} 
                                                style={{ padding: '6px 14px', borderRadius: '10px', border: `1px solid ${C.creamDarker}`, background: C.bgCard, fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.charcoal, cursor: historyPage === 1 ? 'default' : 'pointer', opacity: historyPage === 1 ? 0.4 : 1 }}
                                            >
                                                Previous
                                            </button>
                                            {[...Array(totalHistoryPages)].map((_, i) => (
                                                <button 
                                                    key={i}
                                                    onClick={() => setHistoryPage(i + 1)}
                                                    style={{ width: '32px', height: '32px', borderRadius: '10px', border: historyPage === i + 1 ? `1px solid ${C.primary}` : `1px solid ${C.creamDarker}`, background: historyPage === i + 1 ? C.primary : 'white', fontFamily: 'Outfit', fontSize: '12px', fontWeight: 700, color: historyPage === i + 1 ? 'white' : C.charcoal, cursor: 'pointer', transition: 'all 0.2s' }}
                                                >
                                                    {i + 1}
                                                </button>
                                            ))}
                                            <button 
                                                disabled={historyPage >= totalHistoryPages || totalHistoryPages === 0} 
                                                onClick={() => setHistoryPage(p => p + 1)} 
                                                style={{ padding: '6px 14px', borderRadius: '10px', border: `1px solid ${C.creamDarker}`, background: C.bgCard, fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.charcoal, cursor: (historyPage >= totalHistoryPages || totalHistoryPages === 0) ? 'default' : 'pointer', opacity: (historyPage >= totalHistoryPages || totalHistoryPages === 0) ? 0.4 : 1 }}
                                            >
                                                Next
                                            </button>
                                        </div>
                                    </div>
                                )}
                            </div>
                        </div>
                        
                        {/* Pending Deactivation Requests Section */}
                        {pendingDeactivations.length > 0 && (
                            <div className="card mt-6">
                                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '20px' }}>
                                    <XCircle size={18} color={C.error} />
                                    <h3 className="font-display text-lg font-semibold text-rose-600">Pending Deactivation Requests</h3>
                                </div>
                                <div className="overflow-x-auto">
                                    <table className="w-full font-body text-sm">
                                        <thead>
                                            <tr style={{ borderBottom: `1px solid ${C.creamDarker}`, textAlign: 'left' }}>
                                                <th className="pb-2 font-semibold section-label text-[10px]">Counsellor</th>
                                                <th className="pb-2 font-semibold section-label text-[10px]">Reason</th>
                                                <th className="pb-2 font-semibold section-label text-[10px]">Date</th>
                                                <th className="pb-2 font-semibold section-label text-[10px] text-right">Actions</th>
                                            </tr>
                                        </thead>
                                        <tbody>
                                            {paginatedDeactivations.map(req => (
                                                <tr 
                                                    key={req.id} 
                                                    style={{ borderBottom: `1px solid ${C.creamDarker}` }} 
                                                    className="hover:bg-rose-50/50 transition cursor-pointer"
                                                    onClick={() => setViewingDeactivation(req)}
                                                >
                                                    <td className="py-3 pr-4">
                                                        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                                                            <div className="w-8 h-8 rounded-full bg-rose-100 flex items-center justify-center font-bold text-rose-600 text-[11px] overflow-hidden">
                                                                {(() => {
                                                                    const cApp = applications?.find(a => a.uid === req.counsellorId || a.id === req.counsellorId);
                                                                    const avatarUrl = cApp?.profilePhotoUrl;
                                                                    return avatarUrl ? <img src={avatarUrl} alt="avatar" style={{width:'100%',height:'100%',objectFit:'cover'}}/> : (req.counsellorName?.charAt(0) || '?');
                                                                })()}
                                                            </div>
                                                            <div>
                                                                <div style={{ fontWeight: 600 }} className="text-charcoal">{req.counsellorName}</div>
                                                                <div style={{ fontSize: '11px', color: C.muted }}>{req.counsellorEmail}</div>
                                                            </div>
                                                        </div>
                                                    </td>
                                                    <td className="py-3 pr-4 text-charcoal-muted max-w-[200px] truncate" title={req.reason}>
                                                        {req.reason || 'No reason provided'}
                                                    </td>
                                                    <td className="py-3 pr-4 text-muted">
                                                        {req.requestedAt ? (req.requestedAt.toDate ? req.requestedAt.toDate().toLocaleDateString() : new Date(req.requestedAt).toLocaleDateString()) : 'N/A'}
                                                    </td>
                                                    <td className="py-3 text-right">
                                                        <div className="flex justify-end gap-2">
                                                            <button
                                                                onClick={(e) => { e.stopPropagation(); handleUpdateDeactivationStatus(req.id, req.counsellorId || req.uid, 'Rejected'); }}
                                                                className="px-3 py-1.5 rounded-lg text-xs font-bold text-charcoal-muted hover:bg-cream border border-cream-darker transition-colors"
                                                            >
                                                                Reject
                                                            </button>
                                                            <button
                                                                onClick={(e) => { e.stopPropagation(); handleUpdateDeactivationStatus(req.id, req.counsellorId || req.uid, 'Approved'); }}
                                                                className="px-3 py-1.5 rounded-lg text-xs font-bold bg-rose-50 text-rose-600 hover:bg-rose-100 transition-colors"
                                                            >
                                                                Approve Deactivation
                                                            </button>
                                                        </div>
                                                    </td>
                                                </tr>
                                            ))}
                                        </tbody>
                                    </table>
                                </div>

                                {/* Pagination for Deactivations */}
                                {pendingDeactivations.length > 0 && (
                                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: '20px' }}>
                                        <p style={{ ...sLabel, textTransform: 'none', color: C.muted }}>Showing {paginatedDeactivations.length} of {pendingDeactivations.length} requests</p>
                                        <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                                            <button 
                                                disabled={deactPage === 1} 
                                                onClick={() => setDeactPage(p => p - 1)} 
                                                style={{ padding: '6px 14px', borderRadius: '10px', border: `1px solid ${C.creamDarker}`, background: C.bgCard, fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.charcoal, cursor: deactPage === 1 ? 'default' : 'pointer', opacity: deactPage === 1 ? 0.4 : 1 }}
                                            >
                                                Previous
                                            </button>
                                            {[...Array(totalDeactPages)].map((_, i) => (
                                                <button 
                                                    key={i}
                                                    onClick={() => setDeactPage(i + 1)}
                                                    style={{ width: '32px', height: '32px', borderRadius: '10px', border: deactPage === i + 1 ? `1px solid ${C.primary}` : `1px solid ${C.creamDarker}`, background: deactPage === i + 1 ? C.primary : 'white', fontFamily: 'Outfit', fontSize: '12px', fontWeight: 700, color: deactPage === i + 1 ? 'white' : C.charcoal, cursor: 'pointer', transition: 'all 0.2s' }}
                                                >
                                                    {i + 1}
                                                </button>
                                            ))}
                                            <button 
                                                disabled={deactPage === totalDeactPages || totalDeactPages === 0} 
                                                onClick={() => setDeactPage(p => p + 1)} 
                                                style={{ padding: '6px 14px', borderRadius: '10px', border: `1px solid ${C.creamDarker}`, background: C.bgCard, fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.charcoal, cursor: (deactPage === totalDeactPages || totalDeactPages === 0) ? 'default' : 'pointer', opacity: (deactPage === totalDeactPages || totalDeactPages === 0) ? 0.4 : 1 }}
                                            >
                                                Next
                                            </button>
                                        </div>
                                    </div>
                                )}
                            </div>
                        )}
                    </>
                )}
            </div>


        </div>
    );
}

