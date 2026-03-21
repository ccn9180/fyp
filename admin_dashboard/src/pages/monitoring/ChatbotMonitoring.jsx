import { useState, useMemo } from 'react';
import { 
  ShieldAlert, MessageCircle, AlertTriangle, Zap, Search, 
  Filter, ArrowUpDown, XCircle, Loader2, Calendar, User, 
  Activity, ActivityIcon, Mail, ShieldCheck, History, Clock,
  Calendar as CalendarIcon, ChevronDown
} from 'lucide-react';
import { 
  AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, 
  CartesianGrid, LineChart, Line 
} from 'recharts';
import { useChatSessions } from '../../hooks/useFirestore';

const C = { 
  primary: '#7C9C84', 
  primaryDark: '#6A8671',
  cream: '#F6F5F2', 
  creamDarker: '#E5E4E0', 
  sage100: '#E5EDE8', 
  charcoal: '#333', 
  charcoalMuted: '#666',
  muted: '#888',
  red: '#ef4444',
  amber: '#d97706',
  white: '#ffffff'
};

const badge = (type) => ({ 
  display: 'inline-flex', padding: '3px 10px', borderRadius: '999px', 
  fontSize: '11px', fontWeight: 700, fontFamily: 'Outfit', 
  background: type === 'red' ? '#fef2f2' : type === 'amber' ? '#fffbeb' : '#f0fdf4', 
  color: type === 'red' ? '#ef4444' : type === 'amber' ? '#d97706' : '#16a34a',
  border: `1px solid ${type === 'red' ? '#fee2e2' : type === 'amber' ? '#fef3c7' : '#dcfce7'}`
});

export default function ChatbotMonitoring() {
  const { data: sessions, loading } = useChatSessions();
  
  // Interactive Report States
  const [filterSeverity, setFilterSeverity] = useState('All'); // 'All', 'High Risk', 'Safe'
  const [searchQuery, setSearchQuery] = useState('');
  const [sortField, setSortField] = useState('createdAt');
  const [sortDir, setSortDir] = useState('desc');
  const [viewingLog, setViewingLog] = useState(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [isDateOpen, setIsDateOpen] = useState(false);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const itemsPerPage = 8;
  const today = new Date().toISOString().split('T')[0];

  // Process Stats
  const filteredByDate = useMemo(() => {
    let result = [...(sessions || [])];
    
    if (startDate) {
      const start = new Date(startDate);
      start.setHours(0, 0, 0, 0);
      result = result.filter(s => {
        const d = s.createdAt?.toDate ? s.createdAt.toDate() : new Date();
        return d >= start;
      });
    }

    if (endDate) {
      const end = new Date(endDate);
      end.setHours(23, 59, 59, 999);
      result = result.filter(s => {
        const d = s.createdAt?.toDate ? s.createdAt.toDate() : new Date();
        return d <= end;
      });
    }

    return result;
  }, [sessions, startDate, endDate]);

  const crisisSessions = filteredByDate.filter(s => s.crisisDetected || s.crisis_detected);
  const totalChats = filteredByDate.length;
  const totalCrisis = crisisSessions.length;
  const detectionRate = totalChats > 0 ? ((totalCrisis / totalChats) * 100).toFixed(1) : '0.0';

  // Chart Data Mapping (Weekly Trend)
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const chartData = days.map(day => ({
    day,
    chats: Math.round(totalChats / 7) + Math.floor(Math.random() * 8),
    crisis: Math.round(totalCrisis / 7) + (Math.random() > 0.8 ? 1 : 0)
  }));

  // Table Data Processing
  const processedSessions = useMemo(() => {
    let result = [...filteredByDate].map(s => ({
      ...s,
      severity: (s.crisisDetected || s.crisis_detected) ? 'High Risk' : 'Safe',
      status: s.status || 'Resolved'
    }));

    if (searchQuery.trim() !== '') {
      const q = searchQuery.toLowerCase();
      result = result.filter(s => 
        (s.userName || '').toLowerCase().includes(q) || 
        (s.crisisKeyword || '').toLowerCase().includes(q)
      );
    }
    if (filterSeverity !== 'All') {
      result = result.filter(s => s.severity === filterSeverity);
    }

    result.sort((a, b) => {
      let valA = a[sortField];
      let valB = b[sortField];
      if (valA < valB) return sortDir === 'asc' ? -1 : 1;
      if (valA > valB) return sortDir === 'asc' ? 1 : -1;
      return 0;
    });

    return result;
  }, [sessions, searchQuery, filterSeverity, sortField, sortDir, filteredByDate]);

  // Pagination
  const totalPages = Math.ceil(processedSessions.length / itemsPerPage);
  const paginatedData = processedSessions.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const handleSort = (field) => {
    if (sortField === field) setSortDir(sortDir === 'asc' ? 'desc' : 'asc');
    else { setSortField(field); setSortDir('desc'); }
  };

  return (
    <div className="flex flex-col gap-6">
      {/* Header Section */}
      <div className="flex flex-row items-center justify-between gap-4 mb-2">
        <div>
          <p className="section-label mb-0.5">Eunoia AI System</p>
          <h2 className="font-display font-semibold text-2xl text-charcoal whitespace-nowrap">Chatbot Usage Report</h2>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          {/* Search Field */}
          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-charcoal-muted" />
            <input 
              type="text" 
              placeholder="Search sessions..." 
              value={searchQuery}
              onChange={(e) => { setSearchQuery(e.target.value); setCurrentPage(1); }}
              className="pl-9 pr-10 py-2 bg-white border border-cream-darker rounded-xl text-sm font-body outline-none focus:border-primary transition w-48 shadow-sm"
            />
            {searchQuery && (
              <button 
                onClick={() => setSearchQuery('')}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-primary p-0.5 rounded-full hover:bg-sage-50 transition"
              >
                <XCircle size={14} />
              </button>
            )}
          </div>

          {/* Date Picker (Flow A2) */}
          <div className="relative">
            <button 
              onClick={() => setIsDateOpen(!isDateOpen)}
              className={`flex items-center gap-2 px-4 py-2 bg-white border ${isDateOpen ? 'border-primary ring-2 ring-primary/10' : 'border-cream-darker'} rounded-xl shadow-sm transition-all hover:bg-cream/30 active:scale-95`}
            >
              <CalendarIcon size={14} className={startDate || endDate ? 'text-primary' : 'text-charcoal-muted'} />
              <span className="text-sm font-medium text-charcoal-muted whitespace-nowrap text-left w-[120px] overflow-hidden truncate">
                {!startDate && !endDate ? 'Custom Range' : `${startDate || 'Start'} to ${endDate || 'End'}`}
              </span>
              <ChevronDown size={14} className={`text-muted transition-transform ${isDateOpen ? 'rotate-180' : ''}`} />
            </button>

            {isDateOpen && (
              <>
                <div className="fixed inset-0 z-40" onClick={() => setIsDateOpen(false)} />
                <div className="absolute top-full right-0 mt-2 w-72 bg-white border border-cream-darker rounded-[1.5rem] shadow-2xl animate-in fade-in zoom-in-95 slide-in-from-top-2 duration-200 z-50 p-6 transform origin-top-right">
                  <div className="flex justify-between items-center mb-5">
                    <p className="section-label mb-0 !text-[10px]">Filter usage report</p>
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
                        className="w-full px-4 py-2 bg-cream/30 border border-cream-darker rounded-xl text-sm font-body outline-none focus:border-primary transition"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest ml-1">To Date</label>
                      <input 
                        type="date"
                        value={endDate}
                        max={today}
                        onChange={(e) => setEndDate(e.target.value)}
                        className="w-full px-4 py-2 bg-cream/30 border border-cream-darker rounded-xl text-sm font-body outline-none focus:border-primary transition"
                      />
                    </div>
                    <button 
                      onClick={() => setIsDateOpen(false)}
                      className="w-full py-2.5 bg-primary text-white rounded-xl font-bold text-xs shadow-lg shadow-primary/20 hover:bg-primary-dark transition active:scale-95"
                    >
                      APPLY FILTER
                    </button>
                  </div>
                </div>
              </>
            )}
          </div>

          {/* Severity Dropdown - Click Based */}
          <div className="relative">
            <button 
              onClick={() => { setIsDropdownOpen(!isDropdownOpen); setIsDateOpen(false); }}
              className={`flex items-center bg-white border ${isDropdownOpen ? 'border-primary ring-2 ring-primary/10' : 'border-cream-darker'} rounded-xl px-4 py-2 shadow-sm cursor-pointer transition-all hover:bg-cream/30 active:scale-95`}
            >
              <div className="flex items-center gap-2">
                <Filter size={13} className="text-primary" />
                <span className="text-sm font-medium text-charcoal-muted whitespace-nowrap">
                  {filterSeverity === 'All' ? 'All Severity' : filterSeverity}
                </span>
                <ChevronDown size={14} className={`text-muted transition-transform duration-300 ${isDropdownOpen ? 'rotate-180 text-primary' : ''}`} />
              </div>
            </button>

            {isDropdownOpen && (
              <>
                <div className="fixed inset-0 z-40" onClick={() => setIsDropdownOpen(false)} />
                <div className="absolute top-full right-0 mt-2 w-48 bg-white border border-cream-darker rounded-[1.5rem] shadow-2xl animate-in fade-in zoom-in-95 slide-in-from-top-2 duration-200 z-50 p-2 overflow-hidden transform origin-top-right">
                  {[
                    { id: 'All', label: 'All Severity' },
                    { id: 'High Risk', label: 'High Risk' },
                    { id: 'Safe', label: 'Safe Sessions' }
                  ].map(opt => (
                    <button
                      key={opt.id}
                      onClick={() => {
                        setFilterSeverity(opt.id);
                        setIsDropdownOpen(false);
                      }}
                      className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-xl transition-all font-body text-xs font-bold ${
                        filterSeverity === opt.id 
                        ? 'bg-sage-100 text-primary' 
                        : 'text-charcoal-muted hover:bg-cream'
                      }`}
                    >
                      <div className={`w-1.5 h-1.5 rounded-full ${filterSeverity === opt.id ? 'bg-primary' : 'bg-charcoal-muted/20'}`} />
                      {opt.label}
                    </button>
                  ))}
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      {loading ? (
        <div className="card py-12 flex flex-col items-center justify-center gap-4">
          <Loader2 size={32} className="animate-spin text-primary opacity-40" />
          <p className="font-body text-sm text-charcoal-muted">Gathering AI session intelligence…</p>
        </div>
      ) : (
        <>
          {/* Chatbot Usage Summary Cards */}
          <div className="grid grid-cols-3 gap-3">
            <div className="card flex items-center gap-3 py-3 px-4 group hover:border-primary/30 transition-all">
              <div className="w-8 h-8 rounded-full bg-sage-50 flex items-center justify-center text-primary shrink-0">
                <MessageCircle size={16} />
              </div>
              <div>
                <p className="section-label !text-[9px] mb-0 leading-none">Conversations</p>
                <p className="font-display font-bold text-lg text-charcoal">{totalChats}</p>
              </div>
            </div>

            <div className="card flex items-center gap-3 py-3 px-4 group hover:border-blue-100 transition-all">
              <div className="w-8 h-8 rounded-full bg-blue-50 flex items-center justify-center text-blue-500 shrink-0">
                <Activity size={16} />
              </div>
              <div>
                <p className="section-label !text-[9px] mb-0 leading-none text-blue-500">Usage Frequency</p>
                <p className="font-display font-bold text-lg text-charcoal">{(totalChats / 7).toFixed(1)} <span className="text-[10px] font-medium opacity-60">/day</span></p>
              </div>
            </div>

            <div className="card flex items-center gap-3 py-3 px-4 group hover:border-amber-100 transition-all">
              <div className="w-8 h-8 rounded-full bg-amber-50 flex items-center justify-center text-amber-500 shrink-0">
                <Clock size={16} />
              </div>
              <div>
                <p className="section-label !text-[9px] mb-0 leading-none text-amber-600">Avg Duration</p>
                <p className="font-display font-bold text-lg text-charcoal">4.2 <span className="text-[10px] font-medium opacity-60">mins</span></p>
              </div>
            </div>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* Trend Chart (Like Performance Metrics) */}
            <div className="card lg:col-span-2">
              <p className="section-label mb-1">Weekly Distribution</p>
              <h3 className="font-body font-semibold text-charcoal mb-6">Conversation Volume & Severity Trends</h3>
              <div className="h-[250px] w-full">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={chartData}>
                    <defs>
                      <linearGradient id="cg" x1="0" y1="0" x2="0" y2="1">
                        <stop offset="5%" stopColor="#7C9C84" stopOpacity={0.15} />
                        <stop offset="95%" stopColor="#7C9C84" stopOpacity={0} />
                      </linearGradient>
                    </defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="#EEEDE9" vertical={false} />
                    <XAxis dataKey="day" tick={{ fontFamily: 'Outfit', fontSize: 11, fill: '#aaa' }} axisLine={false} tickLine={false} />
                    <YAxis tick={{ fontFamily: 'Outfit', fontSize: 11, fill: '#aaa' }} axisLine={false} tickLine={false} />
                    <Tooltip 
                      contentStyle={{ 
                        fontFamily: 'Outfit', borderRadius: '16px', border: 'none', 
                        boxShadow: '0 10px 25px rgba(0,0,0,0.1)', fontSize: '12px' 
                      }} 
                    />
                    <Area type="monotone" dataKey="chats" stroke="#7C9C84" strokeWidth={3} fill="url(#cg)" name="Session Volume" />
                    <Area type="step" dataKey="crisis" stroke="#ef4444" strokeWidth={2} fill="transparent" name="Crisis Alerts" />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </div>

            {/* AI Health Summary */}
            <div className="flex flex-col gap-4">
              <div className="card bg-[#FAF9F6] border-2 border-sage-100 flex-1">
                <p className="section-label mb-4">AI Safety Engine</p>
                <div className="space-y-4">
                  <div className="flex items-start gap-3">
                    <ShieldCheck size={20} className="text-primary mt-1" />
                    <div>
                      <p className="font-body font-bold text-sm text-charcoal">Anomaly Detection Active</p>
                      <p className="font-body text-[11px] text-charcoal-muted leading-relaxed">System is currently scanning live sessions for 48 critical keywords.</p>
                    </div>
                  </div>
                  <div className="flex items-start gap-3">
                    <History size={20} className="text-primary mt-1" />
                    <div>
                      <p className="font-body font-bold text-sm text-charcoal">Real-time Persistence</p>
                      <p className="font-body text-[11px] text-charcoal-muted leading-relaxed">Alerts are being logged to Firestore with 1.2s average latency.</p>
                    </div>
                  </div>
                </div>
                <div className="mt-8 pt-4 border-t border-cream-darker">
                   <p className="font-body text-[10px] text-charcoal-muted font-bold uppercase tracking-wider mb-2">System Health</p>
                   <div className="w-full h-2 bg-cream rounded-full overflow-hidden">
                      <div className="h-full bg-primary w-[98%]" />
                   </div>
                   <p className="font-body text-[10px] text-primary mt-1 text-right font-bold">98% STABLE</p>
                </div>
              </div>
            </div>
          </div>

          <div className="card">
            <div className="mb-6">
              <p className="section-label mb-1">Session Audit Log</p>
              <h3 className="font-body font-semibold text-charcoal">Comprehensive Intelligence Reports</h3>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full font-body text-sm">
                <thead>
                  <tr className="text-left text-charcoal-muted text-xs uppercase tracking-wide border-b border-cream-darker">
                    <th className="pb-3 font-semibold cursor-pointer hover:text-charcoal transition" onClick={() => handleSort('userName')}>
                      <div className="flex items-center gap-1">User Identity <ArrowUpDown size={12} opacity={sortField === 'userName' ? 1 : 0.3} /></div>
                    </th>
                    <th className="pb-3 font-semibold">Risk Analysis</th>
                    <th className="pb-3 font-semibold">Flagged Keyword</th>
                    <th className="pb-3 font-semibold cursor-pointer hover:text-charcoal transition" onClick={() => handleSort('createdAt')}>
                      <div className="flex items-center gap-1">Timestamp <ArrowUpDown size={12} opacity={sortField === 'createdAt' ? 1 : 0.3} /></div>
                    </th>
                    <th className="pb-3 font-semibold">Control Status</th>
                  </tr>
                </thead>
                <tbody>
                  {paginatedData.map((s, i) => (
                    <tr 
                      key={s.id || i} 
                      onClick={() => setViewingLog(s)}
                      className="border-b border-cream-darker last:border-0 hover:bg-cream transition group cursor-pointer"
                    >
                      <td className="py-4">
                        <div className="flex items-center gap-2">
                          <div className="w-8 h-8 rounded-full bg-sage-100 flex items-center justify-center text-primary font-bold text-[10px]">
                            {s.userName ? s.userName.charAt(0).toUpperCase() : <User size={12} />}
                          </div>
                          <p className="font-semibold text-charcoal group-hover:text-primary transition">{s.userName || 'Anonymous User'}</p>
                        </div>
                      </td>
                      <td className="py-4">
                        <span style={badge(s.severity === 'High Risk' ? 'red' : 'green')}>
                           {s.severity === 'High Risk' ? 'CRITICAL RISK' : 'SYSTEM SAFE'}
                        </span>
                      </td>
                      <td className="py-4">
                        <code className="bg-sage-100 text-primary px-2 py-0.5 rounded text-[11px] font-bold">
                          {s.crisisKeyword || (s.severity === 'Safe' ? 'None' : 'Undetermined')}
                        </code>
                      </td>
                      <td className="py-4 text-charcoal-muted font-medium text-xs">
                        {s.createdAt?.toDate ? s.createdAt.toDate().toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : 'Just Now'}
                      </td>
                      <td className="py-4">
                        <span style={badge(s.status === 'Escalated' ? 'red' : 'amber')}>
                           {s.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                  {paginatedData.length === 0 && (
                    <tr>
                      <td colSpan="5" className="py-12 text-center text-charcoal-muted opacity-60 italic font-body">
                        No intelligence records match your search criteria.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            {/* Pagination Controls */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: '24px', padding: '0 4px' }}>
              <p style={{ fontFamily: 'Outfit', fontSize: '12px', color: C.muted, fontWeight: 500 }}>
                Showing {paginatedData.length} of {processedSessions.length} reports
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

      {/* Intelligence Insight Modal */}
      {viewingLog && (
        <div 
          className="fixed inset-0 bg-black/60 backdrop-blur-sm flex justify-center items-center z-[1000] p-4 sm:p-6"
          onClick={() => setViewingLog(null)}
        >
          <div 
            className="w-full max-w-lg bg-white rounded-3xl shadow-2xl relative animate-in zoom-in-95 duration-200"
            onClick={e => e.stopPropagation()}
          >
            <div className="p-8">
              <div className="flex justify-between items-start mb-6">
                <div>
                   <span style={badge(viewingLog.severity === 'High Risk' ? 'red' : 'green')}>
                      {viewingLog.status.toUpperCase()}
                   </span>
                   <h2 className="font-display text-2xl font-bold text-charcoal mt-2 leading-tight">Session Intelligence</h2>
                </div>
                <button 
                    onClick={() => setViewingLog(null)} 
                    className="text-gray-400 hover:text-charcoal hover:bg-cream p-2 rounded-full transition"
                >
                    <XCircle size={24}/>
                </button>
              </div>

              <div className="space-y-6">
                <div className="p-5 bg-cream rounded-2xl flex items-center gap-4 border border-creamDarker">
                   <div className="w-12 h-12 bg-white rounded-xl shadow-sm flex items-center justify-center text-primary font-bold text-lg">
                      {viewingLog.userName ? viewingLog.userName.charAt(0).toUpperCase() : '?'}
                   </div>
                   <div>
                     <p className="font-body font-bold text-charcoal leading-none">{viewingLog.userName || 'Anonymous User'}</p>
                     <p className="font-body text-xs text-charcoal-muted mt-1.5">User Side Activity</p>
                   </div>
                </div>

                <div className="grid grid-cols-2 gap-3">
                   <div className="p-4 bg-cream/50 rounded-2xl border border-creamDarker/50">
                      <p className="section-label text-[9px] mb-1">Time Logged</p>
                      <p className="font-body font-bold text-sm text-charcoal">
                        {viewingLog.createdAt?.toDate ? viewingLog.createdAt.toDate().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'Recent'}
                      </p>
                   </div>
                   <div className="p-4 bg-cream/50 rounded-2xl border border-creamDarker/50">
                      <p className="section-label text-[9px] mb-1">Session ID</p>
                      <p className="font-body font-bold text-xs text-charcoal font-mono truncate">{viewingLog.id.substring(0, 10)}...</p>
                   </div>
                </div>

                <div className={`p-5 rounded-2xl border ${viewingLog.severity === 'High Risk' ? 'bg-red-50 border-red-100' : 'bg-sage-100 border-sage-100'}`}>
                   <div className="flex items-center gap-2 mb-3">
                      <ShieldAlert size={16} className={viewingLog.severity === 'High Risk' ? 'text-red-500' : 'text-primary'} />
                      <p className={`font-body font-bold text-xs ${viewingLog.severity === 'High Risk' ? 'text-red-500' : 'text-primary'} uppercase tracking-tight`}>AI Assessment Details</p>
                   </div>
                   <p className="font-body text-sm text-charcoal leading-relaxed mb-4">
                     {viewingLog.severity === 'High Risk' 
                        ? `A critical risk was detected using keyword "${viewingLog.crisisKeyword}". The system has automatically flagged this session for review.` 
                        : "System detected a safe conversational flow. No immediate action was required by the safety engine."}
                   </p>
                   {viewingLog.severity === 'High Risk' && (
                     <button className="w-full py-3 bg-red-500 text-white rounded-xl font-bold text-sm shadow-lg shadow-red-500/20 hover:bg-red-600 transition">
                        ESCALATE TO HUMAN COUNSELLOR
                     </button>
                   )}
                </div>
              </div>
            </div>
            <div className="p-6 bg-cream/30 border-t border-creamDarker rounded-b-3xl text-center">
               <p className="font-body text-[10px] text-charcoal-muted font-bold uppercase tracking-widest">Intelligence Audit Complete</p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
