import { useState, useMemo } from 'react';
import { 
  useChatSessions, useAllDiaries, useUsers 
} from '../../hooks/useFirestore';
import { 
  ShieldAlert, Search, Filter, ArrowUpDown, XCircle, 
  Loader2, Calendar, User, Clock, MessageSquare, 
  BookOpen, AlertTriangle, CheckCircle, Zap, ChevronDown
} from 'lucide-react';

export default function CrisisCenter() {
  const { data: chatSessions, loading: chatLoading } = useChatSessions();
  const { data: diaryEntries, loading: diaryLoading } = useAllDiaries();
  const { data: users } = useUsers();

  // Interactive Report States
  const [searchQuery, setSearchQuery] = useState('');
  const [filterSource, setFilterSource] = useState('All'); // 'All', 'Chatbot', 'Diary'
  const [sortField, setSortField] = useState('timestamp');
  const [sortDir, setSortDir] = useState('desc');
  const [currentPage, setCurrentPage] = useState(1);
  const [viewingAlert, setViewingAlert] = useState(null);
  const [isDateOpen, setIsDateOpen] = useState(false);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const itemsPerPage = 8;

  // Unified Crisis Data Stream
  const unifiedAlerts = useMemo(() => {
    const alerts = [];

    // 1. Process Chatbot Crisis
    (chatSessions || []).forEach(s => {
      if (s.crisisDetected || s.crisis_detected) {
        alerts.push({
          id: s.id,
          source: 'Chatbot',
          userId: s.userId,
          userName: s.userName || 'Anonymous User',
          timestamp: s.createdAt?.toDate ? s.createdAt.toDate() : new Date(),
          keyword: s.crisisKeyword || 'Self-Harm / Distress',
          content: s.messages ? s.messages[s.messages.length - 1]?.text : 'Crisis trigger detected in AI session.',
          severity: 'High Risk',
          status: s.status || 'Pending Review'
        });
      }
    });

    // 2. Process Diary Crisis
    (diaryEntries || []).forEach(d => {
      if (d.isCrisis) {
        // Find user name from users list if possible
        const u = (users || []).find(user => user.id === d.parentId);
        alerts.push({
          id: d.id,
          source: 'Diary',
          userId: d.parentId,
          userName: u?.name || d.userName || 'Anonymous User',
          timestamp: d.timestamp?.toDate ? d.timestamp.toDate() : new Date(),
          keyword: d.mood || 'High Distress',
          content: d.content || 'Crisis trigger detected in personal journal entry.',
          severity: 'Critical',
          status: 'Flagged'
        });
      }
    });

    // Filter by Date
    let filtered = alerts;
    if (startDate) {
      const start = new Date(startDate);
      start.setHours(0, 0, 0, 0);
      filtered = filtered.filter(a => a.timestamp >= start);
    }
    if (endDate) {
      const end = new Date(endDate);
      end.setHours(23, 59, 59, 999);
      filtered = filtered.filter(a => a.timestamp <= end);
    }

    // Filter by Source
    if (filterSource !== 'All') {
      filtered = filtered.filter(a => a.source === filterSource);
    }

    // Search
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      filtered = filtered.filter(a => 
        a.userName.toLowerCase().includes(q) || 
        a.keyword.toLowerCase().includes(q) ||
        a.content.toLowerCase().includes(q)
      );
    }

    // Sort
    filtered.sort((a, b) => {
      let valA = a[sortField];
      let valB = b[sortField];
      if (valA < valB) return sortDir === 'asc' ? -1 : 1;
      if (valA > valB) return sortDir === 'asc' ? 1 : -1;
      return 0;
    });

    return filtered;
  }, [chatSessions, diaryEntries, users, startDate, endDate, filterSource, searchQuery, sortField, sortDir]);

  // Derived Stats
  const totalAlerts = unifiedAlerts.length;
  const chatAlerts = unifiedAlerts.filter(a => a.source === 'Chatbot').length;
  const diaryAlerts = unifiedAlerts.filter(a => a.source === 'Diary').length;

  // Pagination
  const totalPages = Math.ceil(totalAlerts / itemsPerPage);
  const currentItems = unifiedAlerts.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const toggleSort = (field) => {
    if (sortField === field) setSortDir(prev => prev === 'asc' ? 'desc' : 'asc');
    else { setSortField(field); setSortDir('desc'); }
  };

  const loading = chatLoading || diaryLoading;

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-row items-center justify-between gap-4 mb-2">
        <div>
          <p className="section-label mb-0.5">Safety Oversight</p>
          <h2 className="font-display font-semibold text-2xl text-charcoal whitespace-nowrap">Crisis & Safety Center</h2>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <div className="relative group">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 group-focus-within:text-red-500 transition-colors" />
            <input 
              type="text" 
              placeholder="Search Safety Logs.." 
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9 pr-10 py-2 bg-white border border-cream-darker rounded-xl text-sm font-body outline-none focus:border-red-500 transition w-56 shadow-sm"
            />
          </div>

          {/* Date Range Selector */}
           <div className="relative">
            <button 
              onClick={() => { setIsDateOpen(!isDateOpen); setIsDropdownOpen(false); }}
              className={`flex items-center gap-2 px-4 py-2 bg-white border ${isDateOpen ? 'border-primary ring-2 ring-primary/10' : 'border-cream-darker'} rounded-xl shadow-sm transition-all hover:bg-cream/30 active:scale-95`}
            >
              <Calendar size={14} className={startDate || endDate ? 'text-primary' : 'text-gray-400'} />
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
                    <p className="section-label mb-0 !text-[10px]">Safety audit period</p>
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
                        max={new Date().toISOString().split('T')[0]}
                        onChange={(e) => setStartDate(e.target.value)}
                        className="w-full px-4 py-2 bg-cream/30 border border-cream-darker rounded-xl text-sm font-body outline-none focus:border-primary transition"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest ml-1">To Date</label>
                      <input 
                        type="date"
                        value={endDate}
                        max={new Date().toISOString().split('T')[0]}
                        onChange={(e) => setEndDate(e.target.value)}
                        className="w-full px-4 py-2 bg-cream/30 border border-cream-darker rounded-xl text-sm font-body outline-none focus:border-primary transition"
                      />
                    </div>
                    <button 
                      onClick={() => setIsDateOpen(false)}
                      className="w-full py-2.5 bg-primary text-white rounded-xl font-bold text-xs shadow-lg shadow-primary/20 hover:opacity-90 transition active:scale-95 mt-2"
                    >
                      APPLY RANGE
                    </button>
                  </div>
                </div>
              </>
            )}
          </div>

          {/* Source Dropdown - Click Based */}
          <div className="relative">
            <button 
              onClick={() => { setIsDropdownOpen(!isDropdownOpen); setIsDateOpen(false); }}
              className={`flex items-center bg-white border ${isDropdownOpen ? 'border-primary ring-2 ring-primary/10' : 'border-cream-darker'} rounded-xl px-4 py-2 shadow-sm cursor-pointer transition-all hover:bg-cream/30 active:scale-95`}
            >
              <div className="flex items-center gap-2">
                <Filter size={13} className="text-primary" />
                <span className="text-sm font-medium text-charcoal-muted whitespace-nowrap">
                  {filterSource === 'All' ? 'All Sources' : filterSource === 'Chatbot' ? 'AI Chatbot' : 'User Diary'}
                </span>
                <ChevronDown size={14} className={`text-muted transition-transform duration-300 ${isDropdownOpen ? 'rotate-180 text-primary' : ''}`} />
              </div>
            </button>

            {isDropdownOpen && (
              <>
                <div className="fixed inset-0 z-40" onClick={() => setIsDropdownOpen(false)} />
                <div className="absolute top-full right-0 mt-2 w-48 bg-white border border-cream-darker rounded-[1.5rem] shadow-2xl animate-in fade-in zoom-in-95 slide-in-from-top-2 duration-200 z-50 p-2 overflow-hidden transform origin-top-right">
                  {[
                    { id: 'All', label: 'All Sources' },
                    { id: 'Chatbot', label: 'AI Chatbot' },
                    { id: 'Diary', label: 'User Diary' }
                  ].map(opt => (
                    <button
                      key={opt.id}
                      onClick={() => {
                        setFilterSource(opt.id);
                        setIsDropdownOpen(false);
                      }}
                      className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-xl transition-all font-body text-xs font-bold ${
                        filterSource === opt.id 
                        ? 'bg-sage-100 text-primary' 
                        : 'text-charcoal-muted hover:bg-cream'
                      }`}
                    >
                      <div className={`w-1.5 h-1.5 rounded-full ${filterSource === opt.id ? 'bg-primary' : 'bg-charcoal-muted/20'}`} />
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
        <div className="card flex flex-col items-center justify-center py-20 opacity-60">
          <Loader2 size={32} className="animate-spin text-red-500 mb-4" />
          <p className="font-display font-medium text-charcoal">Synchronizing Safety Logs...</p>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-3 gap-3">
            <div className="card flex items-center gap-3 py-3 px-4 group border-red-100 bg-red-50/20 transition-all">
              <div className="w-8 h-8 rounded-full bg-red-50 flex items-center justify-center text-red-500 shrink-0">
                <ShieldAlert size={16} />
              </div>
              <div>
                <p className="section-label !text-[9px] mb-0 leading-none text-red-500">Total Safety Alerts</p>
                <p className="font-display font-bold text-lg text-red-600">{totalAlerts}</p>
              </div>
            </div>

            <div className="card flex items-center gap-3 py-3 px-4 group hover:border-red-100 transition-all">
              <div className="w-8 h-8 rounded-full bg-orange-50 flex items-center justify-center text-orange-500 shrink-0">
                <MessageSquare size={16} />
              </div>
              <div>
                <p className="section-label !text-[9px] mb-0 leading-none text-orange-600">AI Alerts</p>
                <p className="font-display font-bold text-lg text-charcoal">{chatAlerts}</p>
              </div>
            </div>

            <div className="card flex items-center gap-3 py-3 px-4 group hover:border-red-100 transition-all">
              <div className="w-8 h-8 rounded-full bg-blue-50 flex items-center justify-center text-blue-500 shrink-0">
                <BookOpen size={16} />
              </div>
              <div>
                <p className="section-label !text-[9px] mb-0 leading-none text-blue-600">Diary Alerts</p>
                <p className="font-display font-bold text-lg text-charcoal">{diaryAlerts}</p>
              </div>
            </div>
          </div>

          <div className="card overflow-hidden">
            <div className="flex justify-between items-center mb-6 px-1">
              <div>
                <p className="section-label mb-1">Safety Audit Log</p>
                <h3 className="font-display font-semibold text-charcoal">Critical Safety Monitoring</h3>
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left font-body">
                <thead>
                  <tr className="text-xs text-charcoal-muted uppercase tracking-wider border-b border-cream-darker">
                    <th className="pb-4 px-4 font-bold cursor-pointer" onClick={() => toggleSort('timestamp')}>
                      <div className="flex items-center gap-1">Date & Time <ArrowUpDown size={12}/></div>
                    </th>
                    <th className="pb-4 px-4 font-bold">Alert Source</th>
                    <th className="pb-4 px-4 font-bold">User</th>
                    <th className="pb-4 px-4 font-bold">Safety Trigger</th>
                    <th className="pb-4 px-4 font-bold">Detection Point</th>
                    <th className="pb-4 px-4 font-bold text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-cream-darker text-sm">
                  {currentItems.map((alert) => (
                    <tr 
                      key={alert.id} 
                      className="group hover:bg-red-50/10 transition-colors cursor-pointer"
                      onClick={() => setViewingAlert(alert)}
                    >
                      <td className="py-4 px-4">
                        <div className="flex flex-col">
                          <span className="font-bold text-charcoal">{alert.timestamp.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}</span>
                          <span className="text-[10px] text-gray-400 font-medium">{alert.timestamp.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
                        </div>
                      </td>
                      <td className="py-4 px-4">
                        <span className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[10px] font-bold border ${
                          alert.source === 'Chatbot' 
                            ? 'bg-orange-50 text-orange-600 border-orange-100' 
                            : 'bg-blue-50 text-blue-600 border-blue-100'
                        }`}>
                          {alert.source === 'Chatbot' ? <Zap size={10} /> : <BookOpen size={10} />}
                          {alert.source}
                        </span>
                      </td>
                      <td className="py-4 px-4">
                        <div className="flex items-center gap-2">
                          <div className="w-7 h-7 rounded-full bg-cream-darker flex items-center justify-center text-charcoal font-bold text-xs border border-white shadow-sm">
                            {alert.userName.charAt(0)}
                          </div>
                          <span className="font-semibold text-charcoal">{alert.userName}</span>
                        </div>
                      </td>
                      <td className="py-4 px-4">
                        <span className="flex items-center gap-1.5 font-bold text-red-500">
                          <AlertTriangle size={12} />
                          {alert.keyword}
                        </span>
                      </td>
                      <td className="py-4 px-4 max-w-[200px]">
                        <p className="text-xs text-charcoal-muted line-clamp-1 italic">"{alert.content}"</p>
                      </td>
                      <td className="py-4 px-4 text-right">
                        <button className="p-2 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-xl transition-all active:scale-90">
                          <ShieldAlert size={18} />
                        </button>
                      </td>
                    </tr>
                  ))}
                  {currentItems.length === 0 && (
                    <tr>
                      <td colSpan="6" className="py-12 text-center">
                        <div className="flex flex-col items-center opacity-40">
                          <CheckCircle size={40} className="text-primary mb-3" />
                          <p className="font-display font-medium text-charcoal">NO CRITICAL ALERTS FOUND</p>
                          <p className="text-xs font-body">All safety monitoring streams are currently stable.</p>
                        </div>
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            {/* Pagination UI */}
            <div className="flex items-center justify-between mt-6 px-2">
              <p className="text-xs font-medium text-charcoal-muted">
                Showing {currentItems.length} of {totalAlerts} safety alerts
              </p>
              <div className="flex items-center gap-1">
                <button 
                  disabled={currentPage === 1}
                  onClick={() => setCurrentPage(prev => prev - 1)}
                  className="px-3 py-1.5 rounded-lg border border-cream-darker text-xs font-bold text-charcoal disabled:opacity-40"
                >
                  Previous
                </button>
                {[...Array(totalPages)].map((_, i) => (
                  <button 
                    key={i}
                    onClick={() => setCurrentPage(i + 1)}
                    className={`w-8 h-8 rounded-lg border text-xs font-bold transition-all ${currentPage === i + 1 ? 'bg-red-500 border-red-500 text-white shadow-sm' : 'border-cream-darker text-charcoal hover:bg-cream'}`}
                  >
                    {i + 1}
                  </button>
                ))}
                <button 
                  disabled={currentPage === totalPages || totalPages === 0}
                  onClick={() => setCurrentPage(prev => prev + 1)}
                  className="px-3 py-1.5 rounded-lg border border-cream-darker text-xs font-bold text-charcoal disabled:opacity-40"
                >
                  Next
                </button>
              </div>
            </div>
          </div>
        </>
      )}

      {/* Alert Viewing Modal (Simplified for now) */}
      {viewingAlert && (
          <div className="fixed inset-0 bg-charcoal/40 backdrop-blur-sm z-[100] flex items-center justify-center p-4 animate-in fade-in duration-200">
            <div className="bg-white rounded-[32px] w-full max-w-lg overflow-hidden shadow-2xl border border-red-100 flex flex-col animate-in zoom-in-95 duration-200">
              <div className="p-8 pb-4 flex justify-between items-start border-b border-cream-darker">
                <div>
                  <div className="flex items-center gap-2 mb-2">
                     <span className={`px-2 py-0.5 rounded-full text-[9px] font-bold border ${viewingAlert.source === 'Chatbot' ? 'bg-orange-50 text-orange-600 border-orange-100' : 'bg-blue-50 text-blue-600 border-blue-100'}`}>
                       {viewingAlert.source.toUpperCase()} ALERT
                     </span>
                     <span className="text-[9px] font-bold bg-red-100 text-red-600 px-2 py-0.5 rounded-full border border-red-200 flex items-center gap-1">
                        CRITICAL RISK
                     </span>
                  </div>
                  <h3 className="font-display font-bold text-2xl text-charcoal">{viewingAlert.userName}</h3>
                  <p className="text-xs text-charcoal-muted flex items-center gap-1 mt-1">
                    <Clock size={12} /> {viewingAlert.timestamp.toLocaleString()}
                  </p>
                </div>
                <button onClick={() => setViewingAlert(null)} className="p-2 hover:bg-cream rounded-full transition-colors">
                  <XCircle size={24} className="text-gray-400" />
                </button>
              </div>
              
              <div className="p-8 flex flex-col gap-6">
                <div>
                  <p className="section-label !text-[10px] mb-2">Detailed Context</p>
                  <div className="bg-red-50/50 p-4 rounded-2xl border border-red-100">
                    <p className="font-body text-charcoal text-sm leading-relaxed italic">"{viewingAlert.content}"</p>
                  </div>
                </div>

                <div className="flex gap-3">
                  <div className="flex-1 bg-cream-darker/10 p-4 rounded-2xl border border-cream-darker">
                      <p className="section-label !text-[9px] mb-1">Safety Trigger</p>
                      <p className="font-display font-bold text-red-500 flex items-center gap-1">
                          <AlertTriangle size={14} /> {viewingAlert.keyword}
                      </p>
                  </div>
                </div>

                <div className="flex gap-2 pt-2">
                  <button onClick={() => setViewingAlert(null)} className="flex-1 py-3 text-sm font-bold text-charcoal-muted hover:bg-cream rounded-2xl transition-all">
                    Dismiss
                  </button>
                  <button className="flex-[2] py-3 bg-red-500 text-white text-sm font-bold rounded-2xl shadow-lg shadow-red-200 hover:bg-red-600 active:scale-95 transition-all">
                    Initiate Safety Protocol
                  </button>
                </div>
              </div>
            </div>
          </div>
      )}
    </div>
  );
}
