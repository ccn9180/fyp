import { useState, useMemo } from 'react';
import { Star, ShieldCheck, Activity, XCircle, Mail, BookOpen, Calendar, Award, ExternalLink, Briefcase, Search, Filter, X, LayoutGrid, ChevronDown, Calendar as CalendarIcon } from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { useUsers } from '../../hooks/useFirestore';

const C = { 
  primary: '#7C9C84', 
  primaryLight: '#BBCBC2',
  cream: '#F6F5F2', 
  creamDarker: '#E5E4E0', 
  sage100: '#E5EDE8', 
  charcoal: '#333', 
  charcoalMuted: '#666',
  muted: '#888',
  amber: '#d97706'
};

export default function CounsellorMonitoring() {
  const { data: allUsers, loading } = useUsers();
  const [selectedCounsellor, setSelectedCounsellor] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [specialtyFilter, setSpecialtyFilter] = useState('All');
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [isDateOpen, setIsDateOpen] = useState(false);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 8;

  const today = new Date().toISOString().split('T')[0];
  
  const allCounsellorsRaw = useMemo(() => 
    allUsers.filter(u => (u.role || '').toLowerCase() === 'counsellor'),
    [allUsers]
  );

  // Get unique specializations for filter dropdown
  const availableSpecialties = useMemo(() => {
    const specs = new Set();
    (allCounsellorsRaw || []).forEach(c => {
      const s = Array.isArray(c.specializations) ? c.specializations : (c.specialties || []);
      s.forEach(spec => specs.add(spec));
    });
    return ['All', ...Array.from(specs).sort()];
  }, [allCounsellorsRaw]);

  const filteredCounsellors = useMemo(() => {
    return (allCounsellorsRaw || []).filter(c => {
      // Basic Text Search
      const name = (c.name || c.fullName || '').toLowerCase();
      const email = (c.email || '').toLowerCase();
      const query = searchQuery.toLowerCase();
      const matchesSearch = name.includes(query) || email.includes(query);
      
      // Specialist Filter
      const s = Array.isArray(c.specializations) ? c.specializations : (c.specialties || []);
      const matchesSpecialty = specialtyFilter === 'All' || s.some(spec => spec === specialtyFilter);

      // Date Range Filter (Using createdAt or Last Active)
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

  const totalPages = Math.ceil(filteredCounsellors.length / itemsPerPage);
  const paginatedCounsellors = filteredCounsellors.slice(
    (currentPage - 1) * itemsPerPage, 
    currentPage * itemsPerPage
  );
  
  const totalSessions = filteredCounsellors.reduce((sum, c) => sum + (c.totalSessions || 0), 0);
  const avgRating = filteredCounsellors.length > 0 
    ? (filteredCounsellors.reduce((sum, c) => sum + (c.rating || 0), 0) / filteredCounsellors.length).toFixed(1)
    : '0.0';

  const chartData = filteredCounsellors.slice(0, 10).map(c => ({ 
    name: (c.name || c.fullName || 'Anonymous').split(' ').pop(), 
    sessions: c.totalSessions || 0, 
    rating: c.rating || 0 
  }));

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-row items-center justify-between gap-4">
        <div>
          <p className="section-label mb-0.5">Monitoring & Analytics</p>
          <h2 className="font-display font-semibold text-2xl text-charcoal">Performance</h2>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          {/* Search Field */}
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

          {/* Premium Date Range Picker */}
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
                 <div className="absolute top-full right-0 mt-2 w-72 bg-white border border-cream-darker rounded-[1.5rem] shadow-2xl animate-in fade-in zoom-in-95 slide-in-from-top-2 duration-200 z-50 p-6 transform origin-top-right">
                    <div className="flex justify-between items-center mb-5">
                       <p className="section-label mb-0 !text-[10px]">Activity periods</p>
                       {(startDate || endDate) && (
                          <button 
                            onClick={() => { setStartDate(''); setEndDate(''); setIsDateOpen(false); }}
                            className="text-[10px] text-primary font-bold hover:underline"
                          >
                            Reset
                          </button>
                       )}
                    </div>
                    
                    <div className="space-y-4">
                       <div className="space-y-1.5">
                          <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest ml-1">From Date</label>
                          <input 
                            type="date"
                            value={startDate}
                            max={today}
                            onChange={(e) => setStartDate(e.target.value)}
                            className="w-full bg-cream/30 border border-cream-darker rounded-xl px-3 py-2 text-xs font-body outline-none focus:border-primary transition"
                          />
                       </div>
                       <div className="space-y-1.5">
                          <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest ml-1">To Date</label>
                          <input 
                            type="date"
                            value={endDate}
                            max={today}
                            onChange={(e) => setEndDate(e.target.value)}
                            className="w-full bg-cream/30 border border-cream-darker rounded-xl px-3 py-2 text-xs font-body outline-none focus:border-primary transition"
                          />
                       </div>
                       
                       <button 
                        onClick={() => setIsDateOpen(false)}
                        className="w-full py-2.5 bg-[#7C9C84] text-white rounded-xl text-xs font-bold hover:opacity-90 transition shadow-md active:scale-95 mt-2"
                       >
                         Apply Range
                       </button>
                    </div>
                 </div>
               </>
             )}
          </div>

          {/* Specialist Dropdown - Click Based */}
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
                <div className="absolute top-full right-0 mt-2 w-56 bg-white border border-cream-darker rounded-[1.5rem] shadow-2xl animate-in fade-in zoom-in-95 slide-in-from-top-2 duration-200 z-50 p-2 overflow-y-auto max-h-64 custom-scrollbar transform origin-top-right">
                  {availableSpecialties.map(s => (
                    <button
                      key={s}
                      onClick={() => {
                        setSpecialtyFilter(s);
                        setIsDropdownOpen(false);
                      }}
                      className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-xl transition-all font-body text-xs font-bold text-left ${
                        specialtyFilter === s 
                        ? 'bg-sage-100 text-primary' 
                        : 'text-charcoal-muted hover:bg-cream'
                      }`}
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

      {loading ? (
        <p className="font-body text-sm text-charcoal-muted">Sourcing counsellor activity data…</p>
      ) : (
        <>
          {/* Summary metrics */}
          <div className="grid grid-cols-3 gap-3">
            <div className="card flex items-center gap-3 py-3 px-4">
              <div className="w-8 h-8 rounded-full bg-sage-50 flex items-center justify-center text-primary shrink-0">
                <ShieldCheck size={16} />
              </div>
              <div>
                <p className="section-label !text-[9px] mb-0 leading-none">Counsellors</p>
                <p className="font-display font-bold text-lg text-primary leading-tight">{filteredCounsellors.length}</p>
              </div>
            </div>
            
            <div className="card flex items-center gap-3 py-3 px-4">
              <div className="w-8 h-8 rounded-full bg-amber-50 flex items-center justify-center text-amber-500 shrink-0">
                <Star size={16} fill="currentColor" />
              </div>
              <div>
                <p className="section-label !text-[9px] mb-0 leading-none">Rating</p>
                <p className="font-display font-bold text-lg text-amber-500 leading-tight">{avgRating} ★</p>
              </div>
            </div>
            
            <div className="card flex items-center gap-3 py-3 px-4">
              <div className="w-8 h-8 rounded-full bg-blue-50 flex items-center justify-center text-blue-500 shrink-0">
                <Activity size={16} />
              </div>
              <div>
                <p className="section-label !text-[9px] mb-0 leading-none">Total Sessions</p>
                <p className="font-display font-bold text-lg text-charcoal leading-tight">{totalSessions}</p>
              </div>
            </div>
          </div>

          {/* Bar chart */}
          <div className="card">
            <div className="flex justify-between items-center mb-4">
              <p className="section-label mb-0">Sessions per Counsellor</p>
              <span className="text-[10px] text-charcoal-muted uppercase font-bold tracking-wider">Filtered View</span>
            </div>
            {chartData.length > 0 ? (
              <ResponsiveContainer width="100%" height={200}>
                <BarChart data={chartData} barSize={28}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#EEEDE9" vertical={false} />
                  <XAxis dataKey="name" tick={{ fontFamily: 'Outfit', fontSize: 11, fill: '#aaa' }} axisLine={false} tickLine={false} />
                  <YAxis tick={{ fontFamily: 'Outfit', fontSize: 11, fill: '#aaa' }} axisLine={false} tickLine={false} />
                  <Tooltip contentStyle={{ fontFamily: 'Outfit', borderRadius: '12px', border: '1px solid #EEEDE9', fontSize: 12 }} />
                  <Bar dataKey="sessions" fill={C.primary} radius={[8, 8, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <p className="text-center py-10 font-body text-charcoal-muted text-sm">No data matches your filters.</p>
            )}
          </div>

          {/* Table */}
          <div className="card">
            <p className="section-label mb-4">Counsellor Performance Audit</p>
            <div className="overflow-x-auto">
              <table className="w-full font-body text-sm">
                <thead>
                  <tr className="text-left text-charcoal-muted text-xs uppercase tracking-wide border-b border-cream-darker">
                    <th className="pb-2 font-semibold font-display">Counsellor</th>
                    <th className="pb-2 font-semibold font-display">Expertise</th>
                    <th className="pb-2 font-semibold font-display">Total Sessions</th>
                    <th className="pb-2 font-semibold font-display">Rating</th>
                    <th className="pb-2 font-semibold font-display">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {paginatedCounsellors.map((c) => (
                    <tr 
                      key={c.id} 
                      onClick={() => setSelectedCounsellor(c)}
                      className="border-b border-cream-darker last:border-0 hover:bg-sage-50 transition cursor-pointer group"
                    >
                      <td className="py-3 pr-4">
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-xl bg-sage-100 flex items-center justify-center text-primary font-bold text-xs overflow-hidden border border-cream-darker shrink-0">
                            {c.counsellorImageUrl || c.profileImageUrl ? (
                              <img src={c.counsellorImageUrl || c.profileImageUrl} alt="" className="w-full h-full object-cover" />
                            ) : (
                              (c.name || c.fullName || '?').charAt(0).toUpperCase()
                            )}
                          </div>
                          <div className="flex flex-col">
                            <span className="font-semibold text-charcoal group-hover:text-primary transition">{c.name || c.fullName || 'Anonymous'}</span>
                            <span className="text-[10px] text-charcoal-muted uppercase tracking-wider">{c.email || 'No email'}</span>
                          </div>
                        </div>
                      </td>
                      <td className="py-3 text-charcoal-muted">
                        <div className="flex flex-wrap gap-1">
                          {(Array.isArray(c.specializations) ? c.specializations : (c.specialties || [])).slice(0, 1).map((s, i) => (
                            <span key={i} className="text-xs bg-cream px-2 py-0.5 rounded-md border border-cream-darker">
                              {s}
                            </span>
                          )) || <span className="text-xs italic opacity-50">General</span>}
                        </div>
                      </td>
                      <td className="py-3 text-charcoal-muted font-mono">{c.totalSessions || 0}</td>
                      <td className="py-3 text-amber-500 font-bold">★ {c.rating || '0.0'}</td>
                      <td className="py-3">
                        <span className={`badge-${(c.status || '').toLowerCase() === 'active' || !c.status ? 'green' : 'amber'} text-[10px] uppercase font-bold tracking-tight`}>
                          {c.status || 'Active'}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Pagination UI */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: '24px', padding: '0 4px' }}>
              <p style={{ fontFamily: 'Outfit', fontSize: '12px', color: C.muted, fontWeight: 500 }}>
                Showing {paginatedCounsellors.length} of {filteredCounsellors.length} counsellors
              </p>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <button 
                  disabled={currentPage === 1}
                  onClick={() => setCurrentPage(prev => prev - 1)}
                  style={{ padding: '6px 14px', borderRadius: '10px', border: `1px solid ${C.creamDarker}`, background: 'white', fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.charcoal, cursor: currentPage === 1 ? 'default' : 'pointer', opacity: currentPage === 1 ? 0.4 : 1 }}
                >
                  Previous
                </button>
                {[...Array(totalPages)].map((_, i) => (
                  <button 
                    key={i}
                    onClick={() => setCurrentPage(i + 1)}
                    style={{ width: '32px', height: '32px', borderRadius: '10px', border: currentPage === i + 1 ? `1px solid ${C.primary}` : `1px solid ${C.creamDarker}`, background: currentPage === i + 1 ? C.primary : 'white', fontFamily: 'Outfit', fontSize: '12px', fontWeight: 700, color: currentPage === i + 1 ? 'white' : C.charcoal, cursor: 'pointer' }}
                  >
                    {i + 1}
                  </button>
                ))}
                <button 
                  disabled={currentPage === totalPages || totalPages === 0}
                  onClick={() => setCurrentPage(prev => prev + 1)}
                  style={{ padding: '6px 14px', borderRadius: '10px', border: `1px solid ${C.creamDarker}`, background: 'white', fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.charcoal, cursor: (currentPage === totalPages || totalPages === 0) ? 'default' : 'pointer', opacity: (currentPage === totalPages || totalPages === 0) ? 0.4 : 1 }}
                >
                  Next
                </button>
              </div>
            </div>
          </div>
        </>
      )}

      {/* HIGH-FIDELITY INTELLIGENCE MODAL: PROFESSIONAL REDESIGN */}
      {selectedCounsellor && (
        <div 
          className="fixed inset-0 bg-black/60 backdrop-blur-md flex justify-center items-center z-[1000] p-4"
          onClick={() => setSelectedCounsellor(null)}
        >
          <div 
            className="w-full max-w-xl bg-white rounded-[2.5rem] shadow-2xl relative animate-in zoom-in-95 duration-300 flex flex-col max-h-[90vh] overflow-hidden border border-cream-darker"
            onClick={e => e.stopPropagation()}
          >
            {/* Minimalist Close Button */}
            <button 
              onClick={() => setSelectedCounsellor(null)}
              className="absolute top-6 right-6 z-50 p-2 bg-cream/80 hover:bg-white rounded-full transition text-charcoal/40 hover:text-charcoal shadow-sm active:scale-95"
            >
              <X size={20} />
            </button>

            <div className="flex-1 overflow-y-auto custom-scrollbar bg-white">
              {/* Profile Header Block */}
              <div className="bg-sage-100/50 p-10 flex flex-col items-center border-b border-cream-darker relative overflow-hidden">
                <div className="absolute top-0 left-0 w-full h-1 bg-primary/20 opacity-30" />
                
                <div className="w-28 h-28 rounded-full bg-white shadow-xl overflow-hidden border-4 border-white mb-6 relative z-10">
                  {selectedCounsellor.counsellorImageUrl || selectedCounsellor.profileImageUrl ? (
                    <img src={selectedCounsellor.counsellorImageUrl || selectedCounsellor.profileImageUrl} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-4xl font-bold text-primary">
                       {(selectedCounsellor.name || selectedCounsellor.fullName || '?').charAt(0).toUpperCase()}
                    </div>
                  )}
                </div>

                <h2 className="font-display font-black text-3xl text-charcoal leading-tight mb-2 text-center">{selectedCounsellor.name || selectedCounsellor.fullName || 'Anonymous'}</h2>
                <div className="flex items-center gap-2 mb-6">
                  <span className={`px-3 py-1 rounded-lg text-[9px] font-black uppercase tracking-widest ${selectedCounsellor.status === 'Active' ? 'bg-primary/10 text-primary border border-primary/10' : 'bg-amber-100 text-amber-700 border border-amber-200'}`}>
                    Counsellor Status: {selectedCounsellor.status || 'Active'}
                  </span>
                  <div className="flex items-center gap-1.5 text-charcoal-muted font-bold text-[10px] uppercase tracking-wider bg-white/60 px-3 py-1 rounded-lg border border-white">
                    <Mail size={12} className="text-primary" /> {selectedCounsellor.email || 'Email Restricted'}
                  </div>
                </div>

                {/* Performance Stats Grid */}
                <div className="grid grid-cols-2 gap-3 w-full max-w-sm">
                   <div className="bg-white/80 p-4 rounded-2xl border border-white shadow-sm flex flex-col items-center">
                      <p className="text-[9px] font-black text-gray-400 uppercase tracking-widest mb-1">Total Impact</p>
                      <div className="flex items-center gap-2">
                        <Activity size={14} className="text-primary" />
                        <span className="text-xl font-display font-bold text-charcoal">{selectedCounsellor.totalSessions || 0} Sessions</span>
                      </div>
                   </div>
                   <div className="bg-white/80 p-4 rounded-2xl border border-white shadow-sm flex flex-col items-center">
                      <p className="text-[9px] font-black text-gray-400 uppercase tracking-widest mb-1">Success Rating</p>
                      <div className="flex items-center gap-2 text-amber-600">
                        <Star size={14} fill="currentColor" />
                        <span className="text-xl font-display font-bold">{selectedCounsellor.rating || '0.0'} Trust</span>
                      </div>
                   </div>
                </div>
              </div>

              {/* Detailed Content Hub */}
              <div className="p-10 space-y-8">
                 {/* Bio Section */}
                 <div>
                    <p className="section-label mb-3 flex items-center gap-2"><BookOpen size={14} className="text-primary" /> Professional Profile</p>
                    <p className="text-sm text-charcoal-muted leading-relaxed font-body">
                       {selectedCounsellor.counsellorBio || selectedCounsellor.about || 'A dedicated mental health professional focused on providing high-quality support and personalized wellness guidance to our user community.'}
                    </p>
                 </div>

                 {/* Specializations Tags */}
                 <div>
                    <p className="section-label mb-3 flex items-center gap-2"><Award size={14} className="text-primary" /> Expert Domains</p>
                    <div className="flex flex-wrap gap-2">
                       {(Array.isArray(selectedCounsellor.specializations) ? selectedCounsellor.specializations : (selectedCounsellor.specialties || [])).map((s, i) => (
                          <span key={i} className="px-3 py-1.5 bg-cream/50 text-charcoal border border-cream-darker rounded-xl text-xs font-bold hover:border-primary/30 transition cursor-default shadow-sm">
                             {s}
                          </span>
                       ))}
                       {(Array.isArray(selectedCounsellor.specializations) ? selectedCounsellor.specializations : (selectedCounsellor.specialties || [])).length === 0 && (
                          <p className="text-xs italic text-charcoal-muted">General Counsellor</p>
                       )}
                    </div>
                 </div>
              </div>
            </div>

            {/* Subtle Footer Hub */}
            <div className="px-10 py-6 bg-cream/20 border-t border-cream-darker flex justify-center items-center shrink-0">
               <div className="flex items-center gap-2 text-[10px] text-charcoal-muted font-bold uppercase tracking-widest">
                  <ShieldCheck size={14} className="text-primary" /> Verified Platform Counsellor
               </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
