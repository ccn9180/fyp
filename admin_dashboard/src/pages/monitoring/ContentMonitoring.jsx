import { useState, useMemo } from 'react';
import {
  Search, Filter, ArrowUpDown, Eye, Headphones,
  XCircle, Image as ImageIcon, Loader2, Star,
  TrendingUp, Activity, FileText, Music, BookOpen, ChevronDown, LayoutGrid, X, Calendar as CalendarIcon
} from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { useArticles, useMeditationGuides } from '../../hooks/useFirestore';

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

export default function ContentMonitoring() {
  const { data: articles, loading: artLoading } = useArticles();
  const { data: guides, loading: gLoading } = useMeditationGuides();

  const [filterType, setFilterType] = useState('All');
  const [searchQuery, setSearchQuery] = useState('');
  const [sortField, setSortField] = useState('engagement');
  const [sortDir, setSortDir] = useState('desc');
  const [viewingDetails, setViewingDetails] = useState(null);
  const [loadingDetails, setLoadingDetails] = useState(null);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [isDateOpen, setIsDateOpen] = useState(false);

  const loading = artLoading || gLoading;

  // Process Data for Table
  const processedData = useMemo(() => {
    let combined = [
      ...(articles || []).map(a => ({
        id: a.id, title: a.title || 'Untitled', type: 'Article',
        category: a.tag || 'General', duration: a.readingTime || 'N/A',
        status: a.status || 'draft', engagement: a.views || 0,
        rating: a.rating || 0, imageUrl: a.imageUrl,
        content: a.content || 'N/A', authorName: a.authorName,
        createdAt: a.createdAt?.toDate ? a.createdAt.toDate() : (a.createdAt || null)
      })),
      ...(guides || []).map(g => ({
        id: g.id, title: g.title || 'Untitled', type: 'Guide',
        category: g.category || 'General', duration: g.duration || 'N/A',
        status: g.status || 'draft', engagement: g.plays || 0,
        rating: g.rating || 0, imageUrl: g.imageUrl,
        content: g.subtitle || 'N/A', audioUrl: g.audioUrl,
        createdAt: g.createdAt?.toDate ? g.createdAt.toDate() : (g.createdAt || null)
      }))
    ];

    if (searchQuery.trim() !== '') {
      const q = searchQuery.toLowerCase();
      combined = combined.filter(c => c.title.toLowerCase().includes(q) || c.category.toLowerCase().includes(q));
    }

    if (filterType !== 'All') {
      combined = combined.filter(c => c.type === filterType);
    }

    if (startDate) {
      const s = new Date(startDate);
      combined = combined.filter(c => c.createdAt && c.createdAt >= s);
    }
    if (endDate) {
      const e = new Date(endDate);
      e.setHours(23, 59, 59);
      combined = combined.filter(c => c.createdAt && c.createdAt <= e);
    }

    combined.sort((a, b) => {
      let valA = a[sortField];
      let valB = b[sortField];
      if (valA < valB) return sortDir === 'asc' ? -1 : 1;
      if (valA > valB) return sortDir === 'asc' ? 1 : -1;
      return 0;
    });

    return combined;
  }, [articles, guides, searchQuery, filterType, sortField, sortDir, startDate, endDate]);

  // Aggregate Stats (Mirroring Counsellor Stats)
  const totalEngagement = processedData.reduce((s, c) => s + c.engagement, 0);
  const avgRating = processedData.length > 0
    ? (processedData.reduce((s, c) => s + (c.rating || 0), 0) / processedData.length).toFixed(1)
    : '0.0';

  // Chart Data (Top 8 for visibility)
  const chartData = processedData.slice(0, 8).map(c => ({
    name: c.title.length > 15 ? c.title.substring(0, 15) + '...' : c.title,
    engagement: c.engagement,
    type: c.type
  }));

  const handleSort = (field) => {
    if (sortField === field) setSortDir(sortDir === 'asc' ? 'desc' : 'asc');
    else { setSortField(field); setSortDir('desc'); }
  };

  const handleViewDetails = (content) => {
    if (loadingDetails) return;
    if (!content.imageUrl) { setViewingDetails(content); return; }
    setLoadingDetails(content.id);
    const img = new Image();
    img.src = content.imageUrl;
    img.onload = () => { setLoadingDetails(null); setViewingDetails(content); };
    img.onerror = () => { setLoadingDetails(null); setViewingDetails(content); };
  };

  return (
    <div className="flex flex-col gap-6">
      {/* Header - Mirrored from Counsellor Monitoring */}
      <div className="flex flex-row items-center justify-between gap-4">
        <div>
          <p className="section-label mb-0.5">Monitoring & Analytics</p>
          <h2 className="font-display font-semibold text-2xl text-charcoal">Content Report</h2>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          {/* Search Box with Clear Button */}
          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-charcoal-muted" />
            <input
              type="text"
              placeholder="Search resource..."
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
                    <p className="section-label mb-0 !text-[10px]">Analysis Period</p>
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
                        onChange={(e) => setStartDate(e.target.value)}
                        className="w-full bg-cream/30 border border-cream-darker rounded-xl px-3 py-2 text-xs font-body outline-none focus:border-primary transition"
                      />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest ml-1">To Date</label>
                      <input
                        type="date"
                        value={endDate}
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

          {/* Custom Designed Dropdown - Click Based */}
          <div className="relative">
            <button
              onClick={() => { setIsDropdownOpen(!isDropdownOpen); setIsDateOpen(false); }}
              className={`flex items-center bg-white border ${isDropdownOpen ? 'border-primary ring-2 ring-primary/10' : 'border-cream-darker'} rounded-xl px-4 py-2 shadow-sm cursor-pointer transition-all hover:bg-cream/30 active:scale-95`}
            >
              <div className="flex items-center gap-2">
                {filterType === 'All' && <LayoutGrid size={13} className="text-primary" />}
                {filterType === 'Article' && <FileText size={13} className="text-amber-500" />}
                {filterType === 'Guide' && <Music size={13} className="text-emerald-500" />}
                <span className="text-sm font-medium text-charcoal-muted whitespace-nowrap">
                  {filterType === 'All' ? 'All Formats' : filterType === 'Article' ? 'Articles' : 'Meditations'}
                </span>
                <ChevronDown size={14} className={`text-muted transition-transform duration-300 ${isDropdownOpen ? 'rotate-180 text-primary' : ''}`} />
              </div>
            </button>

            {isDropdownOpen && (
              <>
                <div className="fixed inset-0 z-40" onClick={() => setIsDropdownOpen(false)} />
                <div className="absolute top-full right-0 mt-2 w-48 bg-white border border-cream-darker rounded-[1.5rem] shadow-2xl animate-in fade-in zoom-in-95 slide-in-from-top-2 duration-200 z-50 p-2 overflow-hidden transform origin-top-right">
                  {[
                    { id: 'All', icon: LayoutGrid, label: 'All Content', color: 'text-primary' },
                    { id: 'Article', icon: FileText, label: 'Articles Only', color: 'text-amber-500' },
                    { id: 'Guide', icon: Music, label: 'Meditations Only', color: 'text-emerald-500' }
                  ].map(opt => (
                    <button
                      key={opt.id}
                      onClick={() => {
                        setFilterType(opt.id);
                        setIsDropdownOpen(false);
                      }}
                      className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-xl transition-all font-body text-xs font-bold ${filterType === opt.id
                          ? 'bg-sage-100 text-primary'
                          : 'text-charcoal-muted hover:bg-cream'
                        }`}
                    >
                      <opt.icon size={14} className={opt.color} />
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
        <p className="font-body text-sm text-charcoal-muted">Sourcing performance telemetry…</p>
      ) : (
        <>
          {/* Summary Stats Grid */}
          <div className="grid grid-cols-3 gap-3">
            <div className="card flex items-center gap-3 py-3 px-4">
              <div className="w-8 h-8 rounded-full bg-sage-50 flex items-center justify-center text-primary shrink-0">
                <FileText size={16} />
              </div>
              <div>
                <p className="section-label !text-[9px] mb-0 leading-none">Resources</p>
                <p className="font-display font-bold text-lg text-primary leading-tight">{processedData.length}</p>
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
                <p className="section-label !text-[9px] mb-0 leading-none">Engagement</p>
                <p className="font-display font-bold text-lg text-charcoal leading-tight">{totalEngagement.toLocaleString()}</p>
              </div>
            </div>
          </div>

          {/* Performance Bar Chart */}
          <div className="card">
            <div className="flex justify-between items-center mb-6">
              <div>
                <p className="section-label mb-0">Resource Performance</p>
                <h3 className="font-body font-semibold text-charcoal text-sm">Engagement analysis for current selection</h3>
              </div>
              <span className="text-[10px] text-charcoal-muted uppercase font-bold tracking-wider bg-cream px-2 py-1 rounded-md">Relative View Rank</span>
            </div>

            {chartData.length > 0 ? (
              <ResponsiveContainer width="100%" height={200}>
                <BarChart data={chartData} barSize={32}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#EEEDE9" vertical={false} />
                  <XAxis dataKey="name" tick={{ fontFamily: 'Outfit', fontSize: 10, fill: '#aaa' }} axisLine={false} tickLine={false} />
                  <YAxis tick={{ fontFamily: 'Outfit', fontSize: 10, fill: '#aaa' }} axisLine={false} tickLine={false} />
                  <Tooltip
                    cursor={{ fill: '#F6F5F2' }}
                    contentStyle={{ fontFamily: 'Outfit', borderRadius: '12px', border: 'none', boxShadow: '0 8px 16px rgba(0,0,0,0.08)', fontSize: '11px' }}
                  />
                  <Bar dataKey="engagement" fill={C.primary} radius={[8, 8, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="py-20 text-center">
                <p className="font-body text-sm text-charcoal-muted">No data points for this filter.</p>
              </div>
            )}
          </div>

          {/* Content Performance Audit Table */}
          <div className="card">
            <p className="section-label mb-4">Content Performance Audit</p>
            <div className="overflow-x-auto">
              <table className="w-full font-body text-sm">
                <thead>
                  <tr className="text-left text-charcoal-muted text-[10px] uppercase font-bold tracking-widest border-b border-cream-darker">
                    <th className="pb-3 cursor-pointer hover:text-charcoal transition" onClick={() => handleSort('title')}>
                      <div className="flex items-center gap-1">Identifier <ArrowUpDown size={10} opacity={sortField === 'title' ? 1 : 0.4} /></div>
                    </th>
                    <th className="pb-3">Type & Focus</th>
                    <th className="pb-3 text-center">Length</th>
                    <th className="pb-3 text-right pr-4 cursor-pointer hover:text-charcoal transition" onClick={() => handleSort('engagement')}>
                      <div className="flex justify-end items-center gap-1">Engagement <ArrowUpDown size={10} opacity={sortField === 'engagement' ? 1 : 0.4} /></div>
                    </th>
                    <th className="pb-3 text-right pr-4">Quality Score</th>
                  </tr>
                </thead>
                <tbody>
                  {processedData.map((c, i) => (
                    <tr
                      key={c.id || i}
                      onClick={() => handleViewDetails(c)}
                      className="border-b border-cream-darker last:border-0 hover:bg-sage-50 transition group cursor-pointer"
                    >
                      <td className="py-4">
                        <div className="flex items-center gap-3">
                          <div className="w-9 h-9 rounded-xl bg-sage-100 flex items-center justify-center text-primary font-bold text-xs overflow-hidden border border-cream-darker shrink-0">
                            {c.imageUrl ? (
                              <img src={c.imageUrl} alt="" className="w-full h-full object-cover shadow-inner" />
                            ) : (
                              (c.title || '?').charAt(0).toUpperCase()
                            )}
                          </div>
                          <div className="flex flex-col">
                            <span className="font-bold text-charcoal group-hover:text-primary transition truncate max-w-[280px] leading-tight">{c.title}</span>
                            <span className={`text-[9px] font-bold uppercase tracking-tight mt-0.5 ${c.status === 'published' ? 'text-primary' : 'text-amber-500'}`}>{c.status}</span>
                          </div>
                        </div>
                      </td>
                      <td className="py-4">
                        <div className="flex flex-col gap-0.5">
                          <span className={`text-[10px] font-black uppercase tracking-tight ${c.type === 'Article' ? 'text-amber-600' : 'text-emerald-600'}`}>
                            {c.type === 'Article' ? '📝 Article' : '🎧 Guide'}
                          </span>
                          <span className="text-[9px] font-bold text-charcoal-muted uppercase">{c.category}</span>
                        </div>
                      </td>
                      <td className="py-4 text-center text-charcoal-muted font-mono text-[11px]">{c.duration}</td>
                      <td className="py-4 text-right pr-4 font-display font-black text-charcoal">
                        {c.engagement.toLocaleString()}
                      </td>
                      <td className="py-4 text-right pr-4">
                        <div className="flex items-center justify-end gap-1 text-amber-500 font-bold">
                          <Star size={11} fill="currentColor" /> {c.rating ? c.rating.toFixed(1) : '0.0'}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}

      {/* Intelligence Modal */}
      {viewingDetails && (
        <div
          className="fixed inset-0 bg-black/60 backdrop-blur-sm flex justify-center items-center z-[1000] p-4"
          onClick={() => setViewingDetails(null)}
        >
          <div
            className="w-full max-w-2xl bg-white rounded-[2rem] shadow-2xl relative animate-in zoom-in-95 duration-200 overflow-hidden flex flex-col max-h-[90vh]"
            onClick={e => e.stopPropagation()}
          >
            <div className="bg-sage-100 p-8 flex items-start justify-between relative shrink-0">
              <div className="flex items-center gap-6">
                <div className="w-24 h-20 rounded-2xl bg-white shadow-lg overflow-hidden border-4 border-white shrink-0">
                  {viewingDetails.imageUrl ? (
                    <img src={viewingDetails.imageUrl} className="w-full h-full object-cover" />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-primary-light">
                      <ImageIcon size={32} />
                    </div>
                  )}
                </div>
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <span className="text-[9px] font-black uppercase tracking-widest text-primary bg-white/60 px-2 py-0.5 rounded-md">{viewingDetails.type}</span>
                    <span className="text-[9px] font-black uppercase tracking-widest text-charcoal-muted bg-white/60 px-2 py-0.5 rounded-md">{viewingDetails.status}</span>
                  </div>
                  <h2 className="font-display font-bold text-2xl text-charcoal leading-tight">{viewingDetails.title}</h2>
                  <p className="text-primary font-medium text-xs mt-1">Focus: {viewingDetails.category}</p>
                </div>
              </div>
              <button onClick={() => setViewingDetails(null)} className="text-gray-400 hover:text-charcoal transition bg-white/50 p-2 rounded-full"><XCircle size={24} /></button>
            </div>

            <div className="p-8 overflow-y-auto custom-scrollbar flex-1 bg-white">
              <div className="grid grid-cols-2 gap-3 mb-8">
                <div className="p-4 bg-cream/50 rounded-2xl border border-cream-darker">
                  <p className="text-[9px] font-black text-charcoal-muted uppercase mb-1 flex items-center gap-1.5"><Eye size={12} /> Interaction Count</p>
                  <p className="font-display font-bold text-xl text-charcoal">{viewingDetails.engagement.toLocaleString()}</p>
                </div>
                <div className="p-4 bg-cream/50 rounded-2xl border border-cream-darker">
                  <p className="text-[9px] font-black text-charcoal-muted uppercase mb-1 flex items-center gap-1.5"><Star size={12} fill="currentColor" className="text-amber-500" /> Satisfaction Score</p>
                  <p className="font-display font-bold text-xl text-charcoal">{viewingDetails.rating ? viewingDetails.rating.toFixed(1) : '–'}</p>
                </div>
              </div>

              <p className="section-label mb-3">Resource Insight</p>
              <div className="bg-cream/30 p-5 rounded-2xl border border-creamDarker relative italic text-sm text-charcoal-muted leading-relaxed">
                {viewingDetails.content}
              </div>

              {viewingDetails.audioUrl && (
                <div className="mt-6 p-4 bg-sage-50 rounded-xl border border-primary/10 flex items-center gap-3">
                  <div className="w-10 h-10 bg-primary rounded-full flex items-center justify-center text-white shadow-md">
                    <Music size={20} />
                  </div>
                  <div>
                    <p className="text-xs font-black text-primary uppercase">Audio Companion Attached</p>
                    <p className="text-[10px] text-charcoal-muted">Valid for meditation streaming</p>
                  </div>
                </div>
              )}
            </div>

            <div className="px-8 py-5 bg-cream/50 border-t border-cream-darker flex justify-end shrink-0">
              <button onClick={() => setViewingDetails(null)} className="px-6 py-2.5 rounded-xl border border-cream-darker text-xs font-bold text-charcoal-muted hover:bg-white transition">Dismiss Analysis</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
