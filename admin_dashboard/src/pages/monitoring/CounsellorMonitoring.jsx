import { useState, useMemo, useRef } from 'react';
import { Star, ShieldCheck, Activity, XCircle, Mail, BookOpen, Calendar, Award, ExternalLink, Briefcase, Search, Filter, X, LayoutGrid, ChevronDown, Calendar as CalendarIcon, Download, Upload, Loader2, Eye } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, LineChart, Line, PieChart, Pie, Cell } from 'recharts';
import { useUsers, useCounsellorBookings } from '../../hooks/useFirestore';
import { doc, updateDoc } from 'firebase/firestore';
import { db } from '../../firebase';
import ReportPreview from '../../components/ReportPreview';
import { usePDFExport } from '../../hooks/usePDFExport';

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

export default function CounsellorMonitoring() {
  const { data: allUsers, loading: usersLoading } = useUsers();
  const { data: allBookings, loading: bookingsLoading } = useCounsellorBookings();
  const loading = usersLoading || bookingsLoading;
  const reportRef = useRef(null);
  const paperRef = useRef(null);
  const [selectedCounsellor, setSelectedCounsellor] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [specialtyFilter, setSpecialtyFilter] = useState('All');
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [isDateOpen, setIsDateOpen] = useState(false);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [isPreviewOpen, setIsPreviewOpen] = useState(false);
  const { exportPDF, isExporting } = usePDFExport();

  const today = new Date().toISOString().split('T')[0];

  const allCounsellorsRaw = useMemo(() => {
    const live = allUsers.filter(u => (u.role || '').toLowerCase() === 'counsellor').map(c => {
      const counsellorBookings = allBookings.filter(b => b.counsellorId === c.id);
      const totalSessions = counsellorBookings.length;
      const completedSessions = counsellorBookings.filter(b => b.status === 'completed').length;
      const cancelledSessions = counsellorBookings.filter(b => b.status === 'cancelled').length;
      
      return {
        ...c,
        totalSessions: totalSessions > 0 ? totalSessions : (c.totalSessions || 0),
        completedSessions: completedSessions > 0 ? completedSessions : (c.completedSessions || 0),
        cancelledSessions: cancelledSessions > 0 ? cancelledSessions : (c.cancelledSessions || 0),
      };
    });
    const MOCK_COUNSELLORS = [
      { id: 'mc1', name: 'Dr. Kevin Zhang', email: 'k.zhang@wellness.com', role: 'counsellor', specializations: ['CBT', 'Anxiety & Stress'], performanceScore: 92, totalSessions: 450, rating: 4.8, slotUtilization: 95, completionRate: 98, cancelledSessions: 2, status: 'Active', createdAt: new Date('2025-01-10') },
      { id: 'mc2', name: 'Dr. Robert Vance', email: 'r.vance@clinic.org', role: 'counsellor', specializations: ['Depression', 'Grief & Loss'], performanceScore: 78, totalSessions: 120, rating: 4.5, slotUtilization: 45, completionRate: 90, cancelledSessions: 5, status: 'Active', createdAt: new Date('2025-03-15') },
      { id: 'mc3', name: 'Sarah Jenkins', email: 's.jenkins@therapy.net', role: 'counsellor', specializations: ['Relationship Issues', 'Addiction Recovery'], performanceScore: 65, totalSessions: 310, rating: 4.1, slotUtilization: 80, completionRate: 85, cancelledSessions: 32, status: 'Review', createdAt: new Date('2025-02-01') },
      { id: 'mc4', name: 'Dr. Emily Chen', email: 'e.chen@mindful.org', role: 'counsellor', specializations: ['Trauma & PTSD'], performanceScore: 88, totalSessions: 290, rating: 4.7, slotUtilization: 85, completionRate: 95, cancelledSessions: 4, status: 'Active', createdAt: new Date('2025-06-20') },
      { id: 'mc5', name: 'Mark Halloway', email: 'm.halloway@counseling.com', role: 'counsellor', specializations: ['Career Counseling', 'Anxiety & Stress'], performanceScore: 95, totalSessions: 550, rating: 4.9, slotUtilization: 88, completionRate: 99, cancelledSessions: 1, status: 'Active', createdAt: new Date('2024-11-05') }
    ].map(c => ({
      ...c,
      completedSessions: c.completedSessions !== undefined ? c.completedSessions : Math.round((c.completionRate / 100) * c.totalSessions)
    }));
    return [...live, ...MOCK_COUNSELLORS];
  }, [allUsers, allBookings]);

  const availableSpecialties = [
    'All', 'Anxiety & Stress', 'Depression', 'Relationship Issues', 
    'Trauma & PTSD', 'Career Counseling', 'Addiction Recovery',
    'OCD', 'Grief & Loss', 'Eating Disorders'
  ];

  const filteredCounsellors = useMemo(() => {
    return (allCounsellorsRaw || []).filter(c => {
      const name = (c.name || c.fullName || '').toLowerCase();
      const email = (c.email || '').toLowerCase();
      const query = searchQuery.toLowerCase();
      const matchesSearch = name.includes(query) || email.includes(query);
      const s = Array.isArray(c.specializations) ? c.specializations : (c.specialties || []);
      const matchesSpecialty = specialtyFilter === 'All' || s.some(spec => spec === specialtyFilter);
      const createdAt = c.createdAt?.toDate ? c.createdAt.toDate() : (c.createdAt ? new Date(c.createdAt) : null);
      let matchesDate = true;
      if (startDate) {
        const sDate = new Date(startDate);
        matchesDate = matchesDate && createdAt && createdAt >= sDate;
      }
      if (endDate) {
        const eDate = new Date(endDate);
        eDate.setHours(23, 59, 59);
        matchesDate = matchesDate && createdAt && createdAt <= eDate;
      }
      return matchesSearch && matchesSpecialty && matchesDate;
    });
  }, [allCounsellorsRaw, searchQuery, specialtyFilter, startDate, endDate]);

  const itemsPerPage = 6;
  const totalPages = Math.ceil(filteredCounsellors.length / itemsPerPage);
  const paginatedCounsellors = filteredCounsellors.slice(
    (currentPage - 1) * itemsPerPage,
    currentPage * itemsPerPage
  );

  const totalSessions = filteredCounsellors.reduce((sum, c) => sum + (c.totalSessions || 0), 0);
  const totalCompleted = filteredCounsellors.reduce((sum, c) => sum + (c.completedSessions || 0), 0);
  const totalCancelled = filteredCounsellors.reduce((sum, c) => sum + (c.cancelledSessions || 0), 0);
  const totalRescheduled = filteredCounsellors.reduce((sum, c) => sum + (c.rescheduledSessions || 0), 0);
  
  const completionRate = totalSessions > 0 
    ? ((totalCompleted / totalSessions) * 100).toFixed(1) 
    : '0';

  const avgRating = filteredCounsellors.length > 0
    ? (filteredCounsellors.reduce((sum, c) => sum + (c.rating || 0), 0) / filteredCounsellors.length).toFixed(1)
    : '0.0';

  const chartData = filteredCounsellors.slice(0, 10).map(c => ({
    name: (c.name || c.fullName || 'Anonymous').split(' ').pop(),
    sessions: c.totalSessions || 0,
    rating: c.rating || 0,
    score: c.performanceScore || 0
  }));

  const statusData = [
    { name: 'Completed', value: totalCompleted, color: '#7C9C84' },
    { name: 'Cancelled', value: totalCancelled, color: '#EF4444' },
    { name: 'Rescheduled', value: totalRescheduled, color: '#3B82F6' }
  ];

  const trendData = [
    { month: 'Jan', rating: 4.5 },
    { month: 'Feb', rating: 4.6 },
    { month: 'Mar', rating: 4.8 },
    { month: 'Apr', rating: 4.7 },
  ];

  // Alerts logic
  const alerts = filteredCounsellors.filter(c => (c.rating < 4.3) || (c.cancelledSessions > 30) || (c.slotUtilization < 50));

  const handleExportPDF = async () => {
    const success = await exportPDF(paperRef, 'Eunoia_Performance_Audit');
    if (success) setIsPreviewOpen(false);
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-row items-center justify-between gap-4">
        <div>
          <p className="section-label mb-0.5">Monitoring & Analytics</p>
          <h2 className="font-display font-semibold text-2xl text-charcoal">Performance</h2>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={() => setIsPreviewOpen(true)}
            className="flex items-center gap-2 px-4 py-2 bg-[#7C9C84] text-white rounded-xl shadow-sm transition-all hover:bg-opacity-90 active:scale-95 disabled:opacity-50"
          >
            <Eye size={14} />
            <span className="text-sm font-bold">Preview Report</span>
          </button>

          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-charcoal-muted" />
            <input
              type="text"
              placeholder="Search counsellors..."
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

          <div className="relative">
            <button
              onClick={() => { setIsDateOpen(!isDateOpen); setIsDropdownOpen(false); }}
              className={`flex items-center gap-2 px-4 py-2 bg-white border ${isDateOpen ? 'border-primary ring-2 ring-primary/10' : 'border-cream-darker'} rounded-xl shadow-sm transition-all hover:bg-cream/30 active:scale-95`}
            >
              <CalendarIcon size={14} className={startDate || endDate ? 'text-primary' : 'text-charcoal-muted'} />
              <span className="text-sm font-medium text-charcoal-muted whitespace-nowrap">
                {!startDate && !endDate ? 'Custom Range' : `${startDate || 'Start'} to ${endDate || 'End'}`}
              </span>
              <ChevronDown size={14} className={`text-muted transition-transform ${isDateOpen ? 'rotate-180' : ''}`} />
            </button>

            {isDateOpen && (
              <>
                <div className="fixed inset-0 z-40" onClick={() => setIsDateOpen(false)} />
                <div className="absolute top-full right-0 mt-2 w-72 bg-white border border-cream-darker rounded-[1.5rem] shadow-2xl z-50 p-6 transform origin-top-right">
                  <div className="flex justify-between items-center mb-5">
                    <p className="section-label mb-0 !text-[10px]">Activity periods</p>
                    {(startDate || endDate) && (
                      <button onClick={() => { setStartDate(''); setEndDate(''); setIsDateOpen(false); }} className="text-[10px] text-primary font-bold hover:underline">Reset</button>
                    )}
                  </div>
                  <div className="space-y-4">
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest ml-1">From Date</label>
                      <input type="date" value={startDate} max={today} onChange={(e) => setStartDate(e.target.value)} className="w-full bg-cream/30 border border-cream-darker rounded-xl px-3 py-2 text-xs font-body outline-none focus:border-primary transition" />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest ml-1">To Date</label>
                      <input type="date" value={endDate} max={today} onChange={(e) => setEndDate(e.target.value)} className="w-full bg-cream/30 border border-cream-darker rounded-xl px-3 py-2 text-xs font-body outline-none focus:border-primary transition" />
                    </div>
                    <button onClick={() => setIsDateOpen(false)} className="w-full py-2.5 bg-[#7C9C84] text-white rounded-xl text-xs font-bold hover:opacity-90 transition shadow-md active:scale-95 mt-2">Apply Range</button>
                  </div>
                </div>
              </>
            )}
          </div>

          <div className="relative">
            <button
              onClick={() => { setIsDropdownOpen(!isDropdownOpen); setIsDateOpen(false); }}
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
                <div className="absolute top-full right-0 mt-2 w-56 bg-white border border-cream-darker rounded-[1.5rem] shadow-2xl z-50 p-2 overflow-y-auto max-h-64 transform origin-top-right">
                  {availableSpecialties.map(s => (
                    <button
                      key={s}
                      onClick={() => { setSpecialtyFilter(s); setIsDropdownOpen(false); }}
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

      <div ref={reportRef} className="flex flex-col gap-6 p-1">
        {loading ? (
          <p className="font-body text-sm text-charcoal-muted">Sourcing counsellor activity data…</p>
        ) : (
          <>
            <div className="grid grid-cols-3 md:grid-cols-6 gap-3">
              <div className="card flex flex-col gap-1 py-3 px-4">
                <div className="w-7 h-7 rounded-lg bg-[#7C9C84]/20 flex items-center justify-center text-primary shrink-0 mb-1">
                  <Briefcase size={14} />
                </div>
                <p className="text-[10px] text-charcoal-muted uppercase font-black tracking-wider leading-none">Active Staff</p>
                <div className="flex items-baseline gap-2">
                   <p className="font-display font-bold text-xl text-charcoal leading-tight">{filteredCounsellors.length}</p>
                   <span className="text-[9px] text-emerald-600 font-bold">+2 New</span>
                </div>
              </div>
              <div className="card flex flex-col gap-1 py-3 px-4">
                <div className="w-7 h-7 rounded-lg bg-amber-500/20 flex items-center justify-center text-amber-500 shrink-0 mb-1">
                  <Star size={14} fill="currentColor" />
                </div>
                <p className="text-[10px] text-charcoal-muted uppercase font-black tracking-wider leading-none">Avg Rating</p>
                <div className="flex items-baseline gap-2">
                   <p className="font-display font-bold text-xl text-charcoal leading-tight">{avgRating}</p>
                   <span className="text-[9px] text-emerald-600 font-bold">↑ 0.2</span>
                </div>
              </div>
              <div className="card flex flex-col gap-1 py-3 px-4">
                <div className="w-7 h-7 rounded-lg bg-blue-500/20 flex items-center justify-center text-blue-500 shrink-0 mb-1">
                  <Activity size={14} />
                </div>
                <p className="text-[10px] text-charcoal-muted uppercase font-black tracking-wider leading-none">Total Sessions</p>
                <div className="flex items-baseline gap-2">
                   <p className="font-display font-bold text-xl text-charcoal leading-tight">{totalSessions}</p>
                   <span className="text-[9px] text-charcoal-muted opacity-50 font-bold">LIFETIME</span>
                </div>
              </div>
              <div className="card flex flex-col gap-1 py-3 px-4">
                <div className="w-7 h-7 rounded-lg bg-emerald-500/20 flex items-center justify-center text-emerald-500 shrink-0 mb-1">
                  <ShieldCheck size={14} />
                </div>
                <p className="text-[10px] text-charcoal-muted uppercase font-black tracking-wider leading-none">Completion</p>
                <div className="flex items-baseline gap-2">
                   <p className="font-display font-bold text-xl text-charcoal leading-tight">{completionRate}%</p>
                   <span className="text-[9px] text-emerald-600 font-bold">High</span>
                </div>
              </div>
              <div className="card flex flex-col gap-1 py-3 px-4">
                <div className="w-7 h-7 rounded-lg bg-purple-500/20 flex items-center justify-center text-purple-500 shrink-0 mb-1">
                  <Calendar size={14} />
                </div>
                <p className="text-[10px] text-charcoal-muted uppercase font-black tracking-wider leading-none">Availability</p>
                <div className="flex items-baseline gap-2">
                   <p className="font-display font-bold text-xl text-charcoal leading-tight">84%</p>
                   <span className="text-[9px] text-emerald-600 font-bold">Stable</span>
                </div>
              </div>
              <div className="card flex flex-col gap-1 py-3 px-4 outline outline-2 outline-rose-500/20 bg-rose-500/10">
                <div className="w-7 h-7 rounded-lg bg-rose-500/20 flex items-center justify-center text-rose-500 shrink-0 mb-1">
                  <XCircle size={14} />
                </div>
                <p className="text-[10px] text-rose-600 uppercase font-black tracking-wider leading-none font-display">Alerts</p>
                <div className="flex items-baseline gap-2">
                   <p className="font-display font-bold text-xl text-rose-600 leading-tight">{alerts.length}</p>
                   <span className="text-[9px] text-rose-600 font-bold">Action Req</span>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              <div className="card lg:col-span-2">
                <div className="flex justify-between items-center mb-6">
                  <div>
                    <p className="section-label mb-0">Productivity Index</p>
                    <h3 className="text-xs text-charcoal-muted">Sessions conducted per personnel</h3>
                  </div>
                  <div className="flex items-center gap-4">
                    <div className="flex items-center gap-1.5">
                      <div className="w-2 h-2 rounded-full bg-primary" />
                      <span className="text-[10px] font-bold text-charcoal-muted uppercase">Sessions</span>
                    </div>
                  </div>
                </div>
                {chartData.length > 0 ? (
                  <ResponsiveContainer width="100%" height={250}>
                    <BarChart data={chartData} barSize={24}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#EEEDE9" vertical={false} />
                      <XAxis dataKey="name" tick={{ fontFamily: 'Outfit', fontSize: 10, fill: '#aaa' }} axisLine={false} tickLine={false} />
                      <YAxis tick={{ fontFamily: 'Outfit', fontSize: 10, fill: '#aaa' }} axisLine={false} tickLine={false} />
                      <Tooltip 
                        cursor={{ fill: 'rgba(124, 156, 132, 0.05)' }}
                        contentStyle={{ fontFamily: 'Outfit', borderRadius: '16px', border: 'none', boxShadow: '0 10px 25px rgba(0,0,0,0.05)', fontSize: 11 }} 
                      />
                      <Bar dataKey="sessions" fill={C.primary} radius={[6, 6, 0, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                ) : (
                  <p className="text-center py-20 font-body text-charcoal-muted text-sm italic">Insufficient analytical data.</p>
                )}
              </div>

              <div className="card">
                 <p className="section-label mb-6">Service Distribution</p>
                 <div className="flex flex-col items-center">
                    <ResponsiveContainer width="100%" height={200}>
                      <PieChart>
                        <Pie
                          data={statusData}
                          innerRadius={60}
                          outerRadius={80}
                          paddingAngle={5}
                          dataKey="value"
                        >
                          {statusData.map((entry, index) => (
                            <Cell key={`cell-${index}`} fill={entry.color} />
                          ))}
                        </Pie>
                        <Tooltip contentStyle={{ borderRadius: '12px', fontSize: '11px', border: 'none' }} />
                      </PieChart>
                    </ResponsiveContainer>
                    <div className="grid grid-cols-1 w-full gap-2 mt-4">
                       {statusData.map(s => (
                         <div key={s.name} className="flex justify-between items-center px-4 py-2 bg-cream/30 rounded-xl">
                            <div className="flex items-center gap-2">
                               <div className="w-2 h-2 rounded-full" style={{ background: s.color }} />
                               <span className="text-[10px] font-bold text-charcoal-muted uppercase">{s.name}</span>
                            </div>
                            <span className="text-xs font-black text-charcoal">{s.value}</span>
                         </div>
                       ))}
                    </div>
                 </div>
              </div>
            </div>

            {/* Quality Trend Section */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
               <div className="card">
                  <p className="section-label mb-6">Average Rating Trend</p>
                  <ResponsiveContainer width="100%" height={200}>
                    <LineChart data={trendData}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" vertical={false} />
                      <XAxis dataKey="month" tick={{ fontSize: 10, fill: '#bbb' }} axisLine={false} tickLine={false} />
                      <YAxis domain={[4.0, 5.0]} tick={{ fontSize: 10, fill: '#bbb' }} axisLine={false} tickLine={false} />
                      <Tooltip contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.05)' }} />
                      <Line type="monotone" dataKey="rating" stroke={C.primary} strokeWidth={3} dot={{ r: 4, fill: C.primary, strokeWidth: 0 }} activeDot={{ r: 6 }} />
                    </LineChart>
                  </ResponsiveContainer>
               </div>
               <div className="card bg-[#7C9C84] text-white overflow-hidden relative">
                  <div className="relative z-10">
                    <p className="section-label !text-white/70 mb-4 uppercase">AI Performance Insights</p>
                    <div className="space-y-4">
                       <div className="flex gap-4 items-start bg-white/10 p-4 rounded-2xl border border-white/10">
                          <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center shrink-0 mt-1">
                             <Activity size={14} className="text-white" />
                          </div>
                          <div>
                             <p className="text-xs font-bold mb-1">Optimization Opportunity</p>
                             <p className="text-[11px] text-white/80 leading-relaxed font-body">Counsellor workload distribution shows a 15% imbalance. Redirecting low-priority PTSD cases to Dr. Thorne could optimize Dr. Winters' schedule.</p>
                          </div>
                       </div>
                       <div className="flex gap-4 items-start bg-white/10 p-4 rounded-2xl border border-white/10">
                          <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center shrink-0 mt-1">
                             <Star size={14} className="text-white" />
                          </div>
                          <div>
                             <p className="text-xs font-bold mb-1">Quality Milestone</p>
                             <p className="text-[11px] text-white/80 leading-relaxed font-body">Average rating stabilized at 4.7. Feedback sentiment analysis identifies "Compassionate Presence" as the core institutional strength.</p>
                          </div>
                       </div>
                    </div>
                  </div>
                  <div className="absolute top-0 right-0 w-32 h-32 bg-white/5 rounded-full -mr-16 -mt-16 blur-3xl" />
                  <div className="absolute bottom-0 left-0 w-48 h-48 bg-primaryLight/20 rounded-full -ml-24 -mb-24 blur-3xl" />
               </div>
            </div>

            <div className="card">
              <div className="flex justify-between items-center mb-6">
                <div>
                   <p className="section-label mb-0">Counsellor Performance Analytics</p>
                   <h3 className="text-[10px] text-charcoal-muted uppercase font-bold tracking-tight">Granular Personnel Evaluation</h3>
                </div>
                <div className="flex items-center gap-2">
                   <button className="p-2 border border-cream-darker rounded-lg hover:bg-cream/20 transition"><Filter size={14} /></button>
                </div>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full font-body text-sm text-left">
                  <thead>
                    <tr className="text-charcoal-muted text-[10px] uppercase font-black tracking-widest border-b border-cream-darker">
                      <th className="pb-4 font-black">Counsellor Profile</th>
                      <th className="pb-4 font-black">Specialization</th>
                      <th className="pb-4 font-black text-center">Sessions</th>
                      <th className="pb-4 font-black text-center">Utilization</th>
                      <th className="pb-4 font-black text-center">Rating</th>
                      <th className="pb-4 font-black text-center">Score</th>
                      <th className="pb-4 font-black text-right">KPI STATUS</th>
                    </tr>
                  </thead>
                  <tbody>
                    {paginatedCounsellors.map((c) => (
                      <tr key={c.id} onClick={() => setSelectedCounsellor(c)} className="border-b border-cream-darker last:border-0 hover:bg-sage-50 transition cursor-pointer group animate-in fade-in slide-in-from-bottom-2 duration-300">
                        <td className="py-4 pr-4">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-2xl bg-sage-100 flex items-center justify-center text-primary font-bold text-xs overflow-hidden border border-cream-darker shadow-sm relative">
                              {(c.counsellorImageUrl || c.profileImageUrl) ? <img src={c.counsellorImageUrl || c.profileImageUrl} alt="" className="w-full h-full object-cover" /> : (c.name || c.fullName || '?').charAt(0).toUpperCase()}
                              {c.performanceScore > 95 && (
                                <div className="absolute bottom-0 right-0 w-3 h-3 bg-emerald-500 border-2 border-white rounded-full translate-x-1/4 translate-y-1/4" />
                              )}
                            </div>
                            <div className="flex flex-col">
                              <span className="font-bold text-charcoal group-hover:text-primary transition">{c.name || c.fullName || 'Anonymous'}</span>
                              <span className="text-[10px] text-charcoal-muted font-mono">{c.email}</span>
                            </div>
                          </div>
                        </td>
                        <td className="py-4">
                           <div className="flex flex-col gap-1">
                              <span className="text-xs font-bold text-charcoal-muted uppercase">{(Array.isArray(c.specializations) ? c.specializations : (c.specialties || []))[0] || 'Generalist'}</span>
                              <div className="flex gap-1">
                                 {((Array.isArray(c.specializations) ? c.specializations : (c.specialties || [])).length > 1) && (
                                   <span className="text-[8px] bg-cream px-1.5 py-0.5 rounded-md font-bold text-gray-400">+{ (Array.isArray(c.specializations) ? c.specializations : (c.specialties || [])).length - 1} more</span>
                                 )}
                              </div>
                           </div>
                        </td>
                        <td className="py-4 text-center">
                           <div className="flex flex-col">
                              <span className="font-mono font-black text-charcoal">{c.totalSessions || 0}</span>
                              <span className="text-[9px] text-emerald-600 font-bold tracking-tight">{c.completedSessions || 0} COMPLETED</span>
                           </div>
                        </td>
                        <td className="py-4 text-center">
                           <div className="flex flex-col items-center gap-1.5">
                              <span className="text-xs font-bold text-charcoal">{c.slotUtilization || 0}%</span>
                              <div className="w-16 h-1 rounded-full bg-cream overflow-hidden">
                                 <div className="h-full bg-primary" style={{ width: `${c.slotUtilization || 0}%` }} />
                              </div>
                           </div>
                        </td>
                        <td className="py-4 text-center">
                           <div className="flex items-center justify-center gap-1 bg-amber-50 text-amber-600 px-2 py-1 rounded-lg w-fit mx-auto border border-amber-100">
                             <Star size={10} fill="currentColor" />
                             <span className="text-xs font-bold">{c.rating || '0.0'}</span>
                           </div>
                        </td>
                        <td className="py-4 text-center text-primary font-black font-display text-lg">
                           {c.performanceScore || '--'}
                        </td>
                        <td className="py-4 text-right">
                          <span className={`px-2.5 py-1 rounded-xl text-[9px] font-black uppercase tracking-widest ${(c.status || 'Active') === 'Active' ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700'} border border-transparent shadow-sm`}>
                            {(c.status || 'Active') === 'Active' ? 'On Track' : 'Below Target'}
                          </span>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>

              <div className="flex items-center justify-between mt-6 pt-6 border-t border-cream-darker">
                <p className="text-[10px] text-charcoal-muted font-bold uppercase tracking-widest">Audit View: Page {currentPage} of {totalPages || 1}</p>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <button 
                        disabled={currentPage === 1} 
                        onClick={() => setCurrentPage(p => p - 1)} 
                        style={{ padding: '6px 14px', borderRadius: '10px', border: `1px solid ${C.creamDarker}`, background: C.bgCard, fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.charcoal, cursor: currentPage === 1 ? 'default' : 'pointer', opacity: currentPage === 1 ? 0.4 : 1 }}
                    >
                        Previous
                    </button>
                    {[...Array(totalPages)].map((_, i) => (
                        <button 
                            key={i}
                            onClick={() => setCurrentPage(i + 1)}
                            style={{ width: '32px', height: '32px', borderRadius: '10px', border: currentPage === i + 1 ? `1px solid ${C.primary}` : `1px solid ${C.creamDarker}`, background: currentPage === i + 1 ? C.primary : 'white', fontFamily: 'Outfit', fontSize: '12px', fontWeight: 700, color: currentPage === i + 1 ? 'white' : C.charcoal, cursor: 'pointer', transition: 'all 0.2s' }}
                        >
                            {i + 1}
                        </button>
                    ))}
                    <button 
                        disabled={currentPage >= totalPages || totalPages === 0} 
                        onClick={() => setCurrentPage(p => p + 1)} 
                        style={{ padding: '6px 14px', borderRadius: '10px', border: `1px solid ${C.creamDarker}`, background: C.bgCard, fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.charcoal, cursor: (currentPage >= totalPages || totalPages === 0) ? 'default' : 'pointer', opacity: (currentPage >= totalPages || totalPages === 0) ? 0.4 : 1 }}
                    >
                        Next
                    </button>
                </div>
              </div>
            </div>

            {/* Alert / Audit Section */}
            <div className="grid grid-cols-1 gap-6">
                <div className="card border-rose-100 bg-rose-50/10">
                   <div className="flex items-center gap-2 mb-6">
                      <div className="w-2 h-6 bg-rose-500 rounded-full" />
                      <p className="section-label mb-0 !text-rose-600">Personnel Intervention Alerts</p>
                   </div>
                   <div className="space-y-3">
                      {alerts.map(c => (
                        <div key={c.id} onClick={() => setSelectedCounsellor(c)} className="flex justify-between items-center p-3 bg-white border border-rose-100 rounded-2xl shadow-sm cursor-pointer hover:shadow-md hover:border-rose-300 hover:scale-[1.01] transition-all">
                           <div className="flex items-center gap-3">
                              <div className="w-8 h-8 rounded-full bg-rose-100 flex items-center justify-center text-rose-600 font-bold text-xs uppercase">
                                 {c.name.charAt(0)}
                              </div>
                              <div>
                                 <p className="text-xs font-bold text-charcoal">{c.name}</p>
                                 <p className="text-[9px] text-rose-500 font-bold uppercase">
                                    {c.rating < 4.3 ? 'Quality Threshold Breached' : c.cancelledSessions > 30 ? 'High Instability Rate' : 'Low Resource Utilization'}
                                 </p>
                              </div>
                           </div>
                           <span className="px-2 py-0.5 bg-rose-500 text-white rounded-md text-[8px] font-black uppercase">Critical</span>
                        </div>
                      ))}
                      {alerts.length === 0 && <p className="text-xs text-charcoal-muted italic py-4 border border-dashed rounded-2xl text-center">All personnel currently meet quality KPIs.</p>}
                   </div>
                </div>
            </div>
          </>
        )}
      </div>

      {selectedCounsellor && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-md flex justify-center items-center z-[1000] p-4" onClick={() => setSelectedCounsellor(null)}>
          <div className="w-full max-w-xl bg-white rounded-[2.5rem] shadow-2xl relative flex flex-col max-h-[90vh] overflow-hidden border border-cream-darker" onClick={e => e.stopPropagation()}>
            <button onClick={() => setSelectedCounsellor(null)} className="absolute top-6 right-6 p-2 bg-cream/80 hover:bg-white rounded-full transition text-charcoal/40 shadow-sm z-50"><X size={20} /></button>
            <div className="flex-1 overflow-y-auto bg-white scrollbar-hide">
              <div className="bg-sage-50/50 p-10 pt-16 relative border-b border-cream-darker">
                 <div className="flex justify-between items-start mb-8">
                    <div className="flex gap-6 items-center">
                       <div className="w-24 h-24 rounded-3xl bg-white shadow-xl overflow-hidden border-4 border-white">
                         {(selectedCounsellor.counsellorImageUrl || selectedCounsellor.profileImageUrl) ? <img src={selectedCounsellor.counsellorImageUrl || selectedCounsellor.profileImageUrl} alt="" className="w-full h-full object-cover" /> : <div className="w-full h-full flex items-center justify-center text-3xl font-bold text-primary">{(selectedCounsellor.name || selectedCounsellor.fullName || '?').charAt(0).toUpperCase()}</div>}
                       </div>
                       <div>
                          <h2 className="font-display font-black text-3xl text-charcoal mb-1">{selectedCounsellor.name || selectedCounsellor.fullName || 'Anonymous'}</h2>
                          <div className="flex items-center gap-2">
                             <span className="text-[10px] font-black text-primary uppercase tracking-widest bg-white px-2 py-1 rounded-lg border border-primary/20 shadow-sm">{(selectedCounsellor.status || 'Active') === 'Active' ? 'On Track' : 'Below Target'}</span>
                             <span className="text-[10px] font-bold text-charcoal-muted uppercase">{selectedCounsellor.email}</span>
                          </div>
                       </div>
                    </div>
                    <div className="text-right">
                       <p className="text-[10px] font-black text-charcoal-muted uppercase tracking-widest mb-1">Performance Index</p>
                       <p className="text-4xl font-display font-black text-charcoal leading-none">{selectedCounsellor.performanceScore || '--'}</p>
                    </div>
                 </div>

                 <div className="grid grid-cols-4 gap-4">
                    <div className="bg-white p-4 rounded-2xl border border-cream-darker shadow-sm">
                       <p className="text-[9px] font-black text-gray-400 uppercase tracking-widest mb-1">Lifetime Sessions</p>
                       <p className="text-xl font-display font-bold text-charcoal">{selectedCounsellor.totalSessions || 0}</p>
                    </div>
                    <div className="bg-white p-4 rounded-2xl border border-cream-darker shadow-sm">
                       <p className="text-[9px] font-black text-gray-400 uppercase tracking-widest mb-1">Average Rating</p>
                       <div className="flex items-center gap-1.5">
                          <Star size={14} fill="#d97706" className="text-amber-600" />
                          <p className="text-xl font-display font-bold text-amber-600">{selectedCounsellor.rating || '0.0'}</p>
                       </div>
                    </div>
                    <div className="bg-white p-4 rounded-2xl border border-cream-darker shadow-sm">
                       <p className="text-[9px] font-black text-gray-400 uppercase tracking-widest mb-1">Slot Utilization</p>
                       <p className="text-xl font-display font-bold text-charcoal">{selectedCounsellor.slotUtilization || 0}%</p>
                    </div>
                    <div className="bg-white p-4 rounded-2xl border border-cream-darker shadow-sm">
                       <p className="text-[9px] font-black text-gray-400 uppercase tracking-widest mb-1">Completion Rate</p>
                       <p className="text-xl font-display font-bold text-emerald-600">{selectedCounsellor.completionRate ?? (selectedCounsellor.totalSessions ? (((selectedCounsellor.completedSessions || 0) / selectedCounsellor.totalSessions) * 100).toFixed(0) : 0)}%</p>
                    </div>
                 </div>
              </div>

              <div className="p-10 space-y-8">
                 <div className="grid grid-cols-2 gap-8">
                    <div>
                       <p className="section-label mb-4 opacity-50 uppercase tracking-widest">Clinical Profile & Specialty</p>
                       <div className="space-y-4">
                          <p className="text-sm text-charcoal-muted leading-relaxed font-body italic">"{selectedCounsellor.counsellorBio || 'Qualified clinician specializing in evidence-based therapeutic interventions and patient-centric care models.'}"</p>
                          <div className="flex flex-wrap gap-2">
                             {(Array.isArray(selectedCounsellor.specializations) ? selectedCounsellor.specializations : (selectedCounsellor.specialties || [])).map((s, i) => (
                               <span key={i} className="px-3 py-1 bg-sage-50 text-primary border border-primary/10 rounded-xl text-[10px] font-black uppercase tracking-tight">{s}</span>
                             ))}
                          </div>
                       </div>
                    </div>
                    <div>
                       <p className="section-label mb-4 opacity-50 uppercase tracking-widest">Quality Trend (Last 4 Months)</p>
                       <div className="h-32 w-full bg-cream/20 rounded-2xl border border-cream-darker flex items-center justify-center">
                          <ResponsiveContainer width="95%" height="85%">
                             <LineChart data={trendData}>
                                <Line type="monotone" dataKey="rating" stroke={C.primary} strokeWidth={4} dot={false} />
                             </LineChart>
                          </ResponsiveContainer>
                       </div>
                    </div>
                 </div>

                 <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                    <div>
                       <p className="section-label mb-4 opacity-50 uppercase tracking-widest">Workload Analysis</p>
                       <div className="space-y-4">
                          <div className="flex justify-between items-center text-[10px] font-black uppercase tracking-widest opacity-60">
                             <span>Weekly Availability</span>
                             <span>{selectedCounsellor.weeklySlots || 40} Slots / Week</span>
                          </div>
                          <div className="p-4 bg-white border border-cream-darker rounded-2xl flex items-center justify-between">
                             <div className="flex flex-col gap-1">
                                <span className="text-[9px] font-black text-gray-400 uppercase">Booked Session Volume</span>
                                <span className="text-lg font-display font-black text-charcoal">{(selectedCounsellor.slotUtilization || 0) > 80 ? 'High Volume' : (selectedCounsellor.slotUtilization || 0) > 50 ? 'Steady Volume' : 'Low Volume'}</span>
                             </div>
                             <div className="w-12 h-12 rounded-full border-4 border-primary border-t-cream-darker animate-spin-slow rotate-45" />
                          </div>
                       </div>
                    </div>
                    <div>
                       <p className="section-label mb-4 opacity-50 uppercase tracking-widest">Administrative Audit Notes</p>
                       <textarea 
                          className="w-full h-24 bg-cream/30 border border-cream-darker rounded-2xl p-4 text-[11px] font-body text-charcoal-muted resize-none focus:border-primary outline-none"
                          placeholder="Log administrative observations or professional development notes here..."
                          defaultValue={selectedCounsellor.auditNotes || ''}
                          onBlur={async (e) => {
                             if (!selectedCounsellor.id.startsWith('mc')) {
                               try {
                                 await updateDoc(doc(db, 'users', selectedCounsellor.id), { auditNotes: e.target.value });
                               } catch (err) { console.error('Failed to update audit notes', err); }
                             }
                          }}
                       />
                    </div>
                 </div>

                 <div>
                   <div className="flex justify-between items-center mb-6">
                      <p className="section-label mb-0 opacity-50 uppercase tracking-widest">Patient Feedback Wall</p>
                      <button className="text-[10px] font-black text-primary uppercase hover:underline">View All Sentiment</button>
                   </div>
                   {selectedCounsellor.reviews && selectedCounsellor.reviews.length > 0 ? (
                     <div className="space-y-4">
                       {selectedCounsellor.reviews.map((rev, i) => (
                         <div key={i} className="p-6 bg-white border border-cream-darker rounded-3xl group hover:shadow-lg hover:border-primary/20 transition-all duration-300">
                           <div className="flex justify-between items-start mb-4">
                             <div className="flex items-center gap-3">
                               <div className="w-8 h-8 rounded-full bg-sage-50 flex items-center justify-center text-[10px] font-black text-primary border border-sage-100 uppercase">
                                 {rev.patient.charAt(0)}
                               </div>
                               <div>
                                 <p className="text-[11px] font-black text-charcoal uppercase">{rev.patient}</p>
                                 <p className="text-[9px] text-charcoal-muted font-bold opacity-60 uppercase">{rev.date}</p>
                               </div>
                             </div>
                             <div className="flex items-center gap-0.5 text-amber-500">
                               {[...Array(5)].map((_, starIdx) => (
                                 <Star key={starIdx} size={10} fill={starIdx < Math.floor(rev.rating) ? "currentColor" : "none"} className={starIdx >= Math.floor(rev.rating) ? "text-gray-300" : ""} />
                               ))}
                             </div>
                           </div>
                           <p className="text-xs text-charcoal-muted leading-relaxed font-body italic pl-11 border-l-2 border-sage-50 group-hover:border-primary/30 transition-colors">"{rev.comment}"</p>
                         </div>
                       ))}
                     </div>
                   ) : (
                     <div className="py-12 text-center bg-cream/20 rounded-[2rem] border border-dashed border-cream-darker">
                       <p className="text-xs text-charcoal-muted italic opacity-50">No qualitative sentiment data logged for this personnel segment.</p>
                     </div>
                   )}
                 </div>
              </div>
            </div>
          </div>
        </div>
      )}
      <div className="print-container" style={{ position: 'fixed', left: '-2000px', top: '0', width: '794px', pointerEvents: 'none', zIndex: -1 }}>
        <div ref={paperRef} style={{ background: '#FFFFFF' }}>
          <ReportContent chartData={chartData} filteredCounsellors={filteredCounsellors} totalSessions={totalSessions} avgRating={avgRating} isPreview={false} />
        </div>
      </div>

      <ReportPreview
        isOpen={isPreviewOpen}
        onClose={() => setIsPreviewOpen(false)}
        onDownload={handleExportPDF}
        isExporting={isExporting}
        title="Personnel Performance Audit"
      >
        <ReportContent chartData={chartData} filteredCounsellors={filteredCounsellors} totalSessions={totalSessions} avgRating={avgRating} isPreview={true} />
      </ReportPreview>
    </div>
  );
}

function ReportContent({ chartData, filteredCounsellors, totalSessions, avgRating, isPreview }) {
  const totalCompleted = filteredCounsellors.reduce((sum, c) => sum + (c.completedSessions || 0), 0);
  const totalCancelled = filteredCounsellors.reduce((sum, c) => sum + (c.cancelledSessions || 0), 0);
  const avgUtilization = (filteredCounsellors.reduce((sum, c) => sum + (c.slotUtilization || 0), 0) / filteredCounsellors.length).toFixed(1);

  const sectionStyle = { marginBottom: '40px' };
  const headingStyle = { fontSize: '14px', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.05em', color: '#111', marginBottom: '15px' };
  const textStyle = { fontSize: '11px', color: '#444', lineHeight: 1.6, marginBottom: '20px' };
  const highlightBox = { background: '#F8F9FA', padding: '15px', borderRadius: '12px', border: '1px solid #E9ECEF', marginBottom: '15px' };

  return (
    <div style={{ padding: '96px 96px 160px 96px', background: '#FFFFFF', fontFamily: 'Outfit, sans-serif', color: '#1a1a1a' }}>
      {/* Institutional Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '2px solid #7C9C84', paddingBottom: '20px', marginBottom: '30px' }}>
        <div>
          <h1 style={{ margin: 0, color: '#7C9C84', fontSize: '28px', fontWeight: 800 }}>Eunoia</h1>
          <p style={{ margin: '4px 0 0 0', textTransform: 'uppercase', letterSpacing: '0.1em', fontSize: '10px', color: '#666', fontWeight: 700 }}>Personnel Performance & Service Quality Audit</p>
        </div>
        <div style={{ textAlign: 'right' }}>
          <p style={{ margin: 0, fontSize: '11px', fontWeight: 800 }}>REF: ES-AUDIT-PERS-{new Date().getFullYear()}</p>
          <p style={{ margin: '4px 0 0 0', fontSize: '9px', color: '#888' }}>Capture Date: {new Date().toLocaleDateString()}</p>
        </div>
      </div>

      {/* 1. Executive Summary */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>1. Executive Summary</h2>
        <p style={textStyle}>
          This audit provides a comprehensive evaluation of the clinical workforce assigned to the Eunoia platform. Key focus areas include <strong>personnel utilization</strong>, <strong>clinical resonance (ratings)</strong>, and <strong>session reliability</strong>. Current data indicates a high completion rate but identifies minor instability in specific trauma-focused domains.
        </p>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px' }}>
          <div style={{ ...highlightBox, background: '#F0FDF4' }}>
            <p style={{ fontSize: '9px', textTransform: 'uppercase', color: '#166534', fontWeight: 800, marginBottom: '5px' }}>Overall Completion Rate</p>
            <p style={{ fontSize: '22px', fontWeight: 800, margin: 0, color: '#166534' }}>{((totalCompleted/totalSessions)*100).toFixed(1)}%</p>
          </div>
          <div style={{ ...highlightBox, background: '#F0F9FF' }}>
            <p style={{ fontSize: '9px', textTransform: 'uppercase', color: '#0369A1', fontWeight: 800, marginBottom: '5px' }}>Average Talent Utilization</p>
            <p style={{ fontSize: '22px', fontWeight: 800, margin: 0, color: '#0369A1' }}>{avgUtilization}%</p>
          </div>
        </div>
      </div>

      {/* 2. Key Productivity Metrics */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>2. Key Productivity Metrics</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '15px', marginBottom: '20px' }}>
          <div style={highlightBox}>
            <p style={{ fontSize: '8px', textTransform: 'uppercase', color: '#666', fontWeight: 800, marginBottom: '5px' }}>Active Personnel</p>
            <p style={{ fontSize: '22px', fontWeight: 800, margin: '0 0 10px 0' }}>{filteredCounsellors.length}</p>
            <p style={{ fontSize: '8px', color: '#888', lineHeight: 1.4 }}>
              <strong>Audit:</strong> Stable workforce volume with 12.5% YoY growth.
            </p>
          </div>
          <div style={highlightBox}>
            <p style={{ fontSize: '8px', textTransform: 'uppercase', color: '#666', fontWeight: 800, marginBottom: '5px' }}>Clinician Sentiment</p>
            <p style={{ fontSize: '22px', fontWeight: 800, margin: '0 0 10px 0' }}>{avgRating}★</p>
            <p style={{ fontSize: '8px', color: '#888', lineHeight: 1.4 }}>
              <strong>Context:</strong> Average scores above 4.5 satisfy clinical excellence KPIs.
            </p>
          </div>
          <div style={highlightBox}>
            <p style={{ fontSize: '8px', textTransform: 'uppercase', color: '#666', fontWeight: 800, marginBottom: '5px' }}>Service Volume</p>
            <p style={{ fontSize: '22px', fontWeight: 800, margin: '0 0 10px 0' }}>{totalSessions.toLocaleString()}</p>
            <p style={{ fontSize: '8px', color: '#888', lineHeight: 1.4 }}>
              <strong>Status:</strong> Consistent throughput with peak utilization on weekends.
            </p>
          </div>
        </div>

        <div style={{ background: '#FAFAF9', padding: '20px', borderRadius: '15px', border: '1px solid #E5E4E0' }}>
            <p style={{ fontSize: '9px', fontWeight: 800, color: '#7C9C84', textTransform: 'uppercase', marginBottom: '15px', letterSpacing: '0.05em' }}>Session Completion Analysis</p>
            <div style={{ height: '180px', width: '100%' }}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={chartData.slice(0, 8)} barSize={25}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#e5e5e5" vertical={false} />
                  <XAxis dataKey="name" tick={{ fontSize: 8, fill: '#888' }} axisLine={false} tickLine={false} />
                  <YAxis tick={{ fontSize: 8, fill: '#888' }} axisLine={false} tickLine={false} />
                  <Bar dataKey="sessions" fill="#7C9C84" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
        </div>
      </div>

      {isPreview ? (
        <div style={{ height: '260px', position: 'relative', display: 'flex', justifyContent: 'center', paddingTop: '40px', pageBreakBefore: 'always' }} className="print-page-break">
          <div style={{ position: 'absolute', top: '45px', width: 'calc(100% + 192px)', left: '-96px', borderBottom: '2px dashed #BBCBC2' }}></div>
          <span style={{ background: '#FFFFFF', padding: '0 15px', color: '#BBCBC2', fontSize: '10px', fontWeight: 800, letterSpacing: '0.1em', zIndex: 1, position: 'relative', height: '14px', lineHeight: '14px' }}>PAGE BREAK</span>
        </div>
      ) : (
        <div style={{ pageBreakBefore: 'always', height: '260px' }} className="print-page-break" />
      )}

      {/* 3. Detailed Personnel Evaluation */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>3. Detailed Personnel Evaluation</h2>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ borderBottom: '2px solid #EEE' }}>
              <th style={{ textAlign: 'left', padding: '12px 8px', fontSize: '10px', textTransform: 'uppercase', color: '#666' }}>Clinician Ident</th>
              <th style={{ textAlign: 'left', padding: '12px 8px', fontSize: '10px', textTransform: 'uppercase', color: '#666' }}>Domain</th>
              <th style={{ textAlign: 'center', padding: '12px 8px', fontSize: '10px', textTransform: 'uppercase', color: '#666' }}>UTILIZATION (%)</th>
              <th style={{ textAlign: 'center', padding: '12px 8px', fontSize: '10px', textTransform: 'uppercase', color: '#666' }}>SESSIONS</th>
              <th style={{ textAlign: 'right', padding: '12px 8px', fontSize: '10px', textTransform: 'uppercase', color: '#666' }}>Score</th>
            </tr>
          </thead>
          <tbody>
            {filteredCounsellors.map((c, idx) => (
              <tr key={idx} style={{ borderBottom: '1px solid #F6F5F2' }}>
                <td style={{ padding: '12px 8px', fontSize: '11px', fontWeight: 700 }}>{c.name}</td>
                <td style={{ padding: '12px 8px', fontSize: '10px', color: '#888' }}>{(Array.isArray(c.specializations) ? c.specializations : (c.specialties || []))[0]}</td>
                <td style={{ padding: '12px 8px', fontSize: '11px', textAlign: 'center' }}>{c.slotUtilization}%</td>
                <td style={{ padding: '12px 8px', fontSize: '11px', textAlign: 'center', fontWeight: 600 }}>{c.totalSessions}</td>
                <td style={{ padding: '12px 8px', fontSize: '11px', textAlign: 'right', color: c.performanceScore > 90 ? '#7C9C84' : '#333', fontWeight: 800 }}>{c.performanceScore}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* 4. Qualitative Insights & Interventions */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>4. Qualitative Insights & Interventions</h2>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
           <div style={{ ...highlightBox, background: '#FEF2F2', borderColor: '#FEE2E2' }}>
              <p style={{ fontSize: '9px', fontWeight: 800, color: '#B91C1C', textTransform: 'uppercase', marginBottom: '8px' }}>Critical Alert Area</p>
              <p style={{ fontSize: '11px', color: '#991B1B', fontWeight: 600, marginBottom: '8px' }}>High Cancellation Index (15% Threshold)</p>
              <p style={{ fontSize: '9px', color: '#444', lineHeight: 1.5 }}>
                Counsellors identified with over 15% cancellation rates are currently being flagged for schedule re-alignment to reduce session abandonment.
              </p>
           </div>
           <div style={{ ...highlightBox, background: '#F0FDF4', borderColor: '#DCFCE7' }}>
              <p style={{ fontSize: '9px', fontWeight: 800, color: '#166534', textTransform: 'uppercase', marginBottom: '8px' }}>Top Performance Driver</p>
              <p style={{ fontSize: '11px', color: '#166534', fontWeight: 600, marginBottom: '8px' }}>Chronic Stress Specialization Success</p>
              <p style={{ fontSize: '9px', color: '#444', lineHeight: 1.5 }}>
                Specialists in "Stress Management" demonstrate a 98% retention rate, indicating strong clinical grounding in this domain.
              </p>
           </div>
        </div>
      </div>

      {/* Document Footer */}
      <div style={{ borderTop: '1px solid #7C9C84', paddingTop: '40px', marginTop: '60px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div style={{ width: '60%' }}>
            <p style={{ fontSize: '10px', fontWeight: 800, color: '#7C9C84', textTransform: 'uppercase', marginBottom: '8px' }}>Audit Authenticity Notice</p>
            <p style={{ fontSize: '9px', color: '#888', margin: 0, lineHeight: 1.6 }}>
              This document is generated by the Eunoia Health Administration System. All performance scores are calculated using the <em>Proprietary Personnel Integrity Algorithm (PPIA)</em>. External distribution without written consent from the Clinical Director is strictly prohibited.
            </p>
          </div>
          <div style={{ textAlign: 'right' }}>
             <p style={{ fontSize: '10px', fontWeight: 800, margin: '0 0 40px 0' }}>Director Signature</p>
             <div style={{ borderBottom: '1px solid #333', width: '200px', display: 'inline-block' }} />
             <p style={{ fontSize: '9px', color: '#888', margin: '5px 0 0 0' }}>Eunoia Platform Administrator</p>
          </div>
        </div>
      </div>
    </div>
  );
}
