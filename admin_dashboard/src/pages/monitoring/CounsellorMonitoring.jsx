import { useState, useMemo } from 'react';
import { Star, ShieldCheck, Activity, XCircle, Mail, BookOpen, Calendar, Award, ExternalLink, Briefcase, Search, Filter } from 'lucide-react';
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
  
  const allCounsellors = useMemo(() => 
    allUsers.filter(u => (u.role || '').toLowerCase() === 'counsellor'),
    [allUsers]
  );

  // Get unique specializations for filter dropdown
  const availableSpecialties = useMemo(() => {
    const specs = new Set();
    allCounsellors.forEach(c => {
      const s = Array.isArray(c.specializations) ? c.specializations : (c.specialties || []);
      s.forEach(spec => specs.add(spec));
    });
    return ['All', ...Array.from(specs).sort()];
  }, [allCounsellors]);

  const filteredCounsellors = useMemo(() => {
    return allCounsellors.filter(c => {
      const name = (c.name || c.fullName || '').toLowerCase();
      const email = (c.email || '').toLowerCase();
      const query = searchQuery.toLowerCase();
      
      const matchesSearch = name.includes(query) || email.includes(query);
      
      const s = Array.isArray(c.specializations) ? c.specializations : (c.specialties || []);
      const matchesSpecialty = specialtyFilter === 'All' || s.some(spec => spec === specialtyFilter);
      
      return matchesSearch && matchesSpecialty;
    });
  }, [allCounsellors, searchQuery, specialtyFilter]);
  
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
          <h2 className="font-display font-semibold text-2xl text-charcoal">Counsellor Activity</h2>
        </div>

        {/* Improved Search and Filter Bar Row */}
        <div className="flex items-center gap-3">
          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-charcoal-muted" />
            <input 
              type="text" 
              placeholder="Search counsellors..." 
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9 pr-4 py-2 bg-white border border-cream-darker rounded-xl text-sm font-body outline-none focus:border-primary transition w-48 shadow-sm"
            />
          </div>
          <div className="flex items-center bg-white border border-cream-darker rounded-xl px-3 py-2 shadow-sm">
            <Filter size={14} className="text-charcoal-muted mr-2" />
            <select 
              value={specialtyFilter}
              onChange={(e) => setSpecialtyFilter(e.target.value)}
              className="bg-transparent text-sm font-body outline-none text-charcoal cursor-pointer"
            >
              {availableSpecialties.map(s => (
                <option key={s} value={s}>{s === 'All' ? 'All Specialties' : s}</option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {loading ? (
        <p className="font-body text-sm text-charcoal-muted">Loading monitoring data…</p>
      ) : (
        <>
          {/* Summary metrics - Three in one line, different boxes, very compact */}
          <div className="grid grid-cols-3 gap-3">
            <div className="card flex items-center gap-3 py-3 px-4">
              <div className="w-8 h-8 rounded-full bg-sage-50 flex items-center justify-center text-primary shrink-0">
                <ShieldCheck size={16} />
              </div>
              <div>
                <p className="section-label !text-[9px] mb-0 leading-none">Active</p>
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
                <p className="section-label !text-[9px] mb-0 leading-none">Sessions</p>
                <p className="font-display font-bold text-lg text-charcoal leading-tight">{totalSessions}</p>
              </div>
            </div>
          </div>

          {/* Bar chart */}
          <div className="card">
            <div className="flex justify-between items-center mb-4">
              <p className="section-label mb-0">Sessions per Counsellor</p>
              <span className="text-[10px] text-charcoal-muted uppercase font-bold tracking-wider">Top performers</span>
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
            <p className="section-label mb-4">Counsellor Details</p>
            <div className="overflow-x-auto">
              <table className="w-full font-body text-sm">
                <thead>
                  <tr className="text-left text-charcoal-muted text-xs uppercase tracking-wide border-b border-cream-darker">
                    <th className="pb-2 font-semibold font-display">Counsellor</th>
                    <th className="pb-2 font-semibold font-display">Specialization</th>
                    <th className="pb-2 font-semibold font-display">Sessions</th>
                    <th className="pb-2 font-semibold font-display">Rating</th>
                    <th className="pb-2 font-semibold font-display">Status</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredCounsellors.map((c) => (
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
                          {(Array.isArray(c.specializations) ? c.specializations : (c.specialties || [])).length > 1 && (
                            <span className="text-[10px] text-primary self-center ml-1">
                              +{(Array.isArray(c.specializations) ? c.specializations : (c.specialties || [])).length - 1} more
                            </span>
                          )}
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
                  {filteredCounsellors.length === 0 && (
                    <tr>
                      <td colSpan="5" className="py-12 text-center text-charcoal-muted opacity-60 italic">No counsellors match your search.</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}

      {/* Counsellor Info Modal */}
      {selectedCounsellor && (
        <div 
          className="fixed inset-0 bg-black/40 backdrop-blur-sm flex justify-center items-center z-[1000] p-4"
          onClick={() => setSelectedCounsellor(null)}
        >
          <div 
            className="w-full max-w-2xl bg-white rounded-[2rem] shadow-2xl relative animate-in zoom-in-95 duration-200 flex flex-col max-h-[90vh] overflow-hidden"
            onClick={e => e.stopPropagation()}
          >
            {/* Modal Header */}
            <div className="bg-sage-100 p-8 flex items-start justify-between relative">
              <div className="flex items-center gap-6">
                <div className="w-24 h-24 rounded-2xl bg-white shadow-lg overflow-hidden border-4 border-white shrink-0">
                  {selectedCounsellor.counsellorImageUrl || selectedCounsellor.profileImageUrl ? (
                    <img src={selectedCounsellor.counsellorImageUrl || selectedCounsellor.profileImageUrl} alt="" className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-3xl font-bold text-primary">
                       {(selectedCounsellor.name || selectedCounsellor.fullName || '?').charAt(0).toUpperCase()}
                    </div>
                  )}
                </div>
                <div>
                  <div className="flex items-center gap-3 mb-1">
                    <h2 className="font-display font-bold text-2xl text-charcoal">{selectedCounsellor.name || selectedCounsellor.fullName || 'Anonymous'}</h2>
                    <span className={`px-2 py-0.5 rounded-full text-[10px] font-black uppercase tracking-widest ${selectedCounsellor.status === 'active' || !selectedCounsellor.status ? 'bg-emerald-100 text-emerald-700' : 'bg-amber-100 text-amber-700'}`}>
                      {selectedCounsellor.status || 'Active'}
                    </span>
                  </div>
                  <p className="text-primary font-medium flex items-center gap-1.5 text-sm">
                    <Briefcase size={14} />
                    {Array.isArray(selectedCounsellor.specializations) ? selectedCounsellor.specializations[0] : (selectedCounsellor.specialties?.[0] || 'Mental Health Specialist')}
                  </p>
                  <p className="text-charcoal-muted flex items-center gap-1.5 text-xs mt-1">
                    <Mail size={12} />
                    {selectedCounsellor.email || 'No email provided'}
                  </p>
                </div>
              </div>
              <button 
                onClick={() => setSelectedCounsellor(null)}
                className="p-2 hover:bg-white/50 rounded-full transition text-charcoal/40 hover:text-charcoal"
              >
                <XCircle size={24} />
              </button>
            </div>

            {/* Modal Scrollable Body */}
            <div className="p-8 overflow-y-auto custom-scrollbar flex-1 bg-white">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                {/* Left Column - Stats */}
                <div className="space-y-6">
                  <div>
                    <p className="section-label mb-3">Professional Snapshot</p>
                    <div className="grid grid-cols-2 gap-3">
                      <div className="bg-cream/50 p-4 rounded-2xl border border-cream-darker">
                        <div className="flex items-center gap-2 text-amber-500 mb-1">
                          <Star size={16} fill="currentColor" />
                          <span className="text-xs font-bold uppercase tracking-wider">Rating</span>
                        </div>
                        <p className="text-xl font-display font-bold text-charcoal">{selectedCounsellor.rating || '0.0'}</p>
                      </div>
                      <div className="bg-cream/50 p-4 rounded-2xl border border-cream-darker">
                        <div className="flex items-center gap-2 text-primary mb-1">
                          <Activity size={16} />
                          <span className="text-xs font-bold uppercase tracking-wider">Sessions</span>
                        </div>
                        <p className="text-xl font-display font-bold text-charcoal">{selectedCounsellor.totalSessions || 0}</p>
                      </div>
                      <div className="bg-cream/50 p-4 rounded-2xl border border-cream-darker">
                        <div className="flex items-center gap-2 text-blue-500 mb-1">
                          <Award size={16} />
                          <span className="text-xs font-bold uppercase tracking-wider">Exp</span>
                        </div>
                        <p className="text-xl font-display font-bold text-charcoal">{selectedCounsellor.experience || '5+ yrs'}</p>
                      </div>
                      <div className="bg-cream/50 p-4 rounded-2xl border border-cream-darker">
                        <div className="flex items-center gap-2 text-emerald-500 mb-1">
                          <Calendar size={16} />
                          <span className="text-xs font-bold uppercase tracking-wider">Rate</span>
                        </div>
                        <p className="text-xl font-display font-bold text-charcoal">{selectedCounsellor.price || 'Free'}</p>
                      </div>
                    </div>
                  </div>

                  <div>
                    <p className="section-label mb-3">Expertise & Specialties</p>
                    <div className="flex flex-wrap gap-2">
                      {(Array.isArray(selectedCounsellor.specializations) ? selectedCounsellor.specializations : (selectedCounsellor.specialties || [])).map((s, i) => (
                        <span key={i} className="px-3 py-1 bg-sage-50 text-primary text-xs font-semibold rounded-lg border border-primary/10">
                          {s}
                        </span>
                      ))}
                      {(Array.isArray(selectedCounsellor.specializations) ? selectedCounsellor.specializations : (selectedCounsellor.specialties || [])).length === 0 && (
                        <span className="text-xs italic text-charcoal-muted">No specialties listed</span>
                      )}
                    </div>
                  </div>
                </div>

                {/* Right Column - About */}
                <div className="space-y-6">
                  <div>
                    <p className="section-label mb-3">About Counsellor</p>
                    <div className="bg-cream/30 p-5 rounded-2xl border border-cream-darker relative">
                      <BookOpen size={20} className="absolute -top-2.5 -right-2.5 text-primary bg-white rounded-full p-0.5" />
                      <p className="text-sm text-charcoal-muted leading-relaxed italic">
                        "{selectedCounsellor.counsellorBio || selectedCounsellor.about || 'This counsellor hasn\'t provided a bio yet. They are a dedicated professional committed to patient wellness and mental health support.'}"
                      </p>
                    </div>
                  </div>

                  <div className="pt-4 border-t border-cream-darker">
                    <div className="flex items-center justify-between mb-4">
                      <div>
                        <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">Counselor ID</p>
                        <p className="text-xs font-mono text-charcoal/60">{selectedCounsellor.id}</p>
                      </div>
                      <button className="flex items-center gap-2 text-primary hover:underline text-sm font-bold">
                        Full User Record <ExternalLink size={14} />
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <div className="px-8 py-5 bg-cream/50 border-t border-cream-darker flex justify-end gap-3 shrink-0">
               <button 
                onClick={() => setSelectedCounsellor(null)}
                className="px-6 py-2.5 rounded-xl border border-cream-darker text-sm font-bold text-charcoal-muted hover:bg-white transition"
               >
                 Close
               </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
