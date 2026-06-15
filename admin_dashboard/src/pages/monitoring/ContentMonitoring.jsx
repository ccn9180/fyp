import { useState, useMemo, useRef } from 'react';
import {
  Search, Filter, ArrowUpDown, Eye, Headphones,
  XCircle, Image as ImageIcon, Loader2, Star,
  TrendingUp, Activity, FileText, Music, BookOpen, ChevronDown, LayoutGrid, X, Calendar as CalendarIcon,
  Download, Upload, TrendingDown, AlertCircle
} from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, AreaChart, Area } from 'recharts';
import { useArticles, useMeditationGuides } from '../../hooks/useFirestore';
import { usePDFExport } from '../../hooks/usePDFExport';
import ReportPreview from '../../components/ReportPreview';

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
  const reportRef = useRef(null);
  const paperRef = useRef(null);

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
  const [isPreviewOpen, setIsPreviewOpen] = useState(false);
  const { exportPDF, isExporting } = usePDFExport();
  const today = new Date().toISOString().split('T')[0];

  const loading = artLoading || gLoading;

  // Process Data for Table
  const processedData = useMemo(() => {
    const allArticles = articles || [];
    const allGuides = guides || [];

    let combined = [
      ...allArticles.map(a => ({
        id: a.id, title: a.title || 'Untitled', type: 'Article',
        category: a.tag || 'General', duration: a.readingTime || 'N/A',
        status: a.status || 'draft', engagement: a.views || 0,
        rating: a.rating || 0, imageUrl: a.imageUrl,
        content: a.content || 'N/A', authorName: a.authorName,
        createdAt: a.createdAt?.toDate ? a.createdAt.toDate() : (a.createdAt ? new Date(a.createdAt) : null)
      })),
      ...allGuides.map(g => ({
        id: g.id, title: g.title || 'Untitled', type: 'Guide',
        category: g.category || 'General', duration: g.duration || 'N/A',
        status: g.status || 'draft', engagement: g.plays || 0,
        rating: g.rating || 0, imageUrl: g.imageUrl,
        content: g.subtitle || 'N/A', audioUrl: g.audioUrl,
        createdAt: g.createdAt?.toDate ? g.createdAt.toDate() : (g.createdAt ? new Date(g.createdAt) : null)
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

  // Aggregate Stats
  const totalEngagement = processedData.reduce((s, c) => s + c.engagement, 0);
  const avgRating = processedData.length > 0
    ? (processedData.reduce((s, c) => s + (c.rating || 0), 0) / processedData.length).toFixed(1)
    : '0.0';

  // Enhanced Analytics for PDF
  const topPerformers = useMemo(() =>
    [...processedData].sort((a, b) => b.engagement - a.engagement).slice(0, 3)
    , [processedData]);

  const underPerformers = useMemo(() =>
    [...processedData].sort((a, b) => a.engagement - b.engagement).slice(0, 3)
    , [processedData]);

  // Chart Data
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

  const handleExportPDF = async () => {
    await exportPDF(paperRef, `Eunoia_Content_Audit_${today}`);
    setIsPreviewOpen(false);
  };

  return (
    <div className="flex flex-col gap-6">
      {/* Header */}
      <div className="flex flex-row items-center justify-between gap-4">
        <div>
          <p className="section-label mb-0.5">Monitoring & Analytics</p>
          <h2 className="font-display font-semibold text-2xl text-charcoal">Content Report</h2>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          {/* Export Button */}
          <button
            onClick={() => setIsPreviewOpen(true)}
            className="flex items-center gap-2 px-4 py-2 bg-[#7C9C84] text-white rounded-xl shadow-sm transition-all hover:bg-opacity-90 active:scale-95"
          >
            <Eye size={14} />
            <span className="text-sm font-bold">Preview Report</span>
          </button>

          {/* Search Box */}
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

          {/* Date Picker */}
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
                    <p className="section-label mb-0 !text-[10px]">Analysis Period</p>
                    {(startDate || endDate) && (
                      <button onClick={() => { setStartDate(''); setEndDate(''); setIsDateOpen(false); }} className="text-[10px] text-primary font-bold hover:underline">Reset</button>
                    )}
                  </div>
                  <div className="space-y-4">
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest ml-1">From Date</label>
                      <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} className="w-full bg-cream/30 border border-cream-darker rounded-xl px-3 py-2 text-xs font-body outline-none focus:border-primary transition" />
                    </div>
                    <div className="space-y-1.5">
                      <label className="text-[10px] font-black text-gray-400 uppercase tracking-widest ml-1">To Date</label>
                      <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} className="w-full bg-cream/30 border border-cream-darker rounded-xl px-3 py-2 text-xs font-body outline-none focus:border-primary transition" />
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
                <div className="absolute top-full right-0 mt-2 w-48 bg-white border border-cream-darker rounded-[1.5rem] shadow-2xl z-50 p-2 transform origin-top-right">
                  {[
                    { id: 'All', icon: LayoutGrid, label: 'All Content', color: 'text-primary' },
                    { id: 'Article', icon: FileText, label: 'Articles Only', color: 'text-amber-500' },
                    { id: 'Guide', icon: Music, label: 'Meditations Only', color: 'text-emerald-500' }
                  ].map(opt => (
                    <button
                      key={opt.id}
                      onClick={() => { setFilterType(opt.id); setIsDropdownOpen(false); }}
                      className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-xl transition-all font-body text-xs font-bold ${filterType === opt.id ? 'bg-sage-100 text-primary' : 'text-charcoal-muted hover:bg-cream'}`}
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

      <div ref={reportRef} className="flex flex-col gap-6 p-1">
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
                      <tr key={c.id || i} className="border-b border-cream-darker last:border-0 hover:bg-sage-50 transition group">
                        <td className="py-4">
                          <div className="flex items-center gap-3">
                            <div className="w-9 h-9 rounded-xl bg-sage-100 flex items-center justify-center text-primary font-bold text-xs overflow-hidden border border-cream-darker shrink-0">
                              {c.imageUrl ? <img src={c.imageUrl} alt="" className="w-full h-full object-cover shadow-inner" /> : (c.title || '?').charAt(0).toUpperCase()}
                            </div>
                            <div className="flex flex-col">
                              <span className="font-bold text-charcoal group-hover:text-primary transition truncate max-w-[280px] leading-tight">{c.title}</span>
                              <span className={`text-[9px] font-bold uppercase tracking-tight mt-0.5 ${c.status === 'published' ? 'text-primary' : 'text-amber-500'}`}>{c.status}</span>
                            </div>
                          </div>
                        </td>
                        <td className="py-4">
                          <div className="flex flex-col gap-0.5">
                            <span className={`text-[10px] font-black uppercase tracking-tight ${c.type === 'Article' ? 'text-amber-600' : 'text-emerald-600'}`}>{c.type === 'Article' ? '📝 Article' : '🎧 Guide'}</span>
                            <span className="text-[9px] font-bold text-charcoal-muted uppercase">{c.category}</span>
                          </div>
                        </td>
                        <td className="py-4 text-center text-charcoal-muted font-mono text-[11px]">{c.duration}</td>
                        <td className="py-4 text-right pr-4 font-display font-black text-charcoal">{c.engagement.toLocaleString()}</td>
                        <td className="py-4 text-right pr-4"><div className="flex items-center justify-end gap-1 text-amber-500 font-bold"><Star size={11} fill="currentColor" /> {c.rating ? c.rating.toFixed(1) : '0.0'}</div></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </>
        )}
      </div>

      {/* Intelligence Modal */}
      {viewingDetails && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex justify-center items-center z-[1000] p-4" onClick={() => setViewingDetails(null)}>
          <div className="w-full max-w-2xl bg-white rounded-[2rem] shadow-2xl relative animate-in zoom-in-95 duration-200 overflow-hidden flex flex-col max-h-[90vh]" onClick={e => e.stopPropagation()}>
            <div className="bg-sage-100 p-8 flex items-start justify-between relative shrink-0">
              <div className="flex items-center gap-6">
                <div className="w-24 h-20 rounded-2xl bg-white shadow-lg overflow-hidden border-4 border-white shrink-0">
                  {viewingDetails.imageUrl ? <img src={viewingDetails.imageUrl} className="w-full h-full object-cover" /> : <div className="w-full h-full flex items-center justify-center text-primary-light"><ImageIcon size={32} /></div>}
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
              <div className="bg-cream/30 p-5 rounded-2xl border border-creamDarker relative italic text-sm text-charcoal-muted leading-relaxed">{viewingDetails.content}</div>
            </div>
          </div>
        </div>
      )}
      {/* --- HIDDEN FORMAL PAPER REPORT (PRINT-ONLY CAPTURE) --- */}
      <div className="print-container" style={{ position: 'fixed', left: '-2000px', top: '0', width: '794px', pointerEvents: 'none', zIndex: -1 }}>
        <div ref={paperRef} style={{ background: 'white' }}>
          <ReportContent
            processedData={processedData}
            chartData={chartData}
            avgRating={avgRating}
            totalEngagement={totalEngagement}
            topPerformers={topPerformers}
            underPerformers={underPerformers}
            isPreview={false}
          />
        </div>
      </div>

      <ReportPreview
        isOpen={isPreviewOpen}
        onClose={() => setIsPreviewOpen(false)}
        onDownload={handleExportPDF}
        isExporting={isExporting}
        title="Content Performance Audit Report"
      >
        <ReportContent
          processedData={processedData}
          chartData={chartData}
          avgRating={avgRating}
          totalEngagement={totalEngagement}
          topPerformers={topPerformers}
          underPerformers={underPerformers}
          isPreview={true}
        />
      </ReportPreview>
    </div>
  );
}

function ReportContent({ processedData, chartData, avgRating, totalEngagement, topPerformers, underPerformers, isPreview }) {
  const sectionStyle = { marginBottom: '35px' };
  const headingStyle = { fontSize: '14px', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.05em', color: '#111', marginBottom: '15px' };
  const textStyle = { fontSize: '11px', color: '#444', lineHeight: 1.6, marginBottom: '20px' };
  const highlightBox = { background: '#F8F9FA', padding: '15px', borderRadius: '12px', border: '1px solid #E9ECEF', marginBottom: '15px' };

  return (
    <div style={{ padding: '96px 96px 160px 96px', background: 'white', fontFamily: 'Outfit, sans-serif', color: '#1a1a1a' }}>
      {/* Institutional Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '2px solid #7C9C84', paddingBottom: '20px', marginBottom: '30px' }}>
        <div>
          <h1 style={{ margin: 0, color: '#7C9C84', fontSize: '28px', fontWeight: 800 }}>Eunoia</h1>
          <p style={{ margin: '4px 0 0 0', textTransform: 'uppercase', letterSpacing: '0.1em', fontSize: '10px', color: '#666', fontWeight: 700 }}>Content Performance Audit Report</p>
        </div>
        <div style={{ textAlign: 'right' }}>
          <p style={{ margin: 0, fontSize: '11px', fontWeight: 800 }}>REF: ES-AUDIT-CONTENT-{new Date().getFullYear()}</p>
          <p style={{ margin: '4px 0 0 0', fontSize: '9px', color: '#888' }}>Capture Date: {new Date().toLocaleDateString()}</p>
        </div>
      </div>

      {/* 1. Executive Summary */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>1. Executive Summary</h2>
        <div style={highlightBox}>
          <p style={textStyle}>
            This report provides a comprehensive performance audit of the <strong>Eunoia</strong> digital resource ecosystem. Eunoia leverages deep learning architectures to deliver personalized emotional support, and the content library serves as the core therapeutic foundation.
          </p>
          <p style={textStyle}>
            Initial analysis indicates a robust library of <strong>{processedData.length} assets</strong> with a high qualitative baseline (<strong>{avgRating}★ avg rating</strong>). However, significant variance in user engagement (<strong>{totalEngagement.toLocaleString()} total interactions</strong>) suggests a need for targeted optimization of low-performing categories to ensure equitable support delivery across all emotional domains.
          </p>
        </div>
      </div>

      {/* 2. Key Metrics Overview */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>2. Key Metrics Overview & Interpretation</h2>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '20px' }}>
          <div style={{ ...highlightBox, background: '#F4F7F5' }}>
            <p style={{ fontSize: '8px', textTransform: 'uppercase', color: '#7C9C84', fontWeight: 800, marginBottom: '5px' }}>Total Resource Assets</p>
            <p style={{ fontSize: '22px', fontWeight: 800, margin: '0 0 10px 0' }}>{processedData.length}</p>
            <p style={{ fontSize: '8px', color: '#666', lineHeight: 1.4 }}>
              <strong>Interpretation:</strong> Sufficient volume for a launched MVP. The library provides diverse coverage, but further scaling is required for granular deep-learning personalization.
            </p>
          </div>
          <div style={{ ...highlightBox, background: '#FFFBEB' }}>
            <p style={{ fontSize: '8px', textTransform: 'uppercase', color: '#D97706', fontWeight: 800, marginBottom: '5px' }}>Average Quality Score</p>
            <p style={{ fontSize: '22px', fontWeight: 800, margin: '0 0 10px 0' }}>{avgRating} ★</p>
            <p style={{ fontSize: '8px', color: '#666', lineHeight: 1.4 }}>
              <strong>Interpretation:</strong> Outstanding. A score above 4.5 indicates that content satisfies user clinical needs and effectively follows the "Eunoia Sage" design system.
            </p>
          </div>
          <div style={{ ...highlightBox, background: '#F0F9FF' }}>
            <p style={{ fontSize: '8px', textTransform: 'uppercase', color: '#0284C7', fontWeight: 800, marginBottom: '5px' }}>Total Engagement</p>
            <p style={{ fontSize: '22px', fontWeight: 800, margin: '0 0 10px 0' }}>{totalEngagement.toLocaleString()}</p>
            <p style={{ fontSize: '8px', color: '#666', lineHeight: 1.4 }}>
              <strong>Interpretation:</strong> Strong active user base. Engagement depth correlates with successful emotional anchoring and platform retention.
            </p>
          </div>
        </div>
      </div>

      {/* 3. High-Impact Content Analysis */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>3. High-Impact Content Analysis</h2>
        <p style={textStyle}>
          The following assets demonstrate maximum efficacy in user engagement and clinical value. Preliminary analysis suggests these resources perform well due to <strong>high topical relevance</strong> (addressing acute anxiety or sleep disruption) and <strong>low cognitive friction</strong>.
        </p>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '15px' }}>
          {topPerformers.map((item, idx) => (
            <div key={idx} style={{ border: '1px solid #E5E4E0', padding: '15px', borderRadius: '10px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '10px', alignItems: 'center' }}>
                <span style={{ fontSize: '8px', fontWeight: 900, background: '#7C9C84', color: 'white', padding: '5px 8px', display: 'inline-block', borderRadius: '4px', lineHeight: 1, textTransform: 'uppercase', verticalAlign: 'middle', textAlign: 'center' }}>TOP PERFORMER</span>
                <span style={{ fontSize: '7px', fontWeight: 800, color: '#666' }}>{item.type}</span>
              </div>
              <p style={{ fontSize: '11px', fontWeight: 800, margin: '0 0 10px 0', minHeight: '30px' }}>{item.title}</p>
              <p style={{ fontSize: '7px', color: '#888', fontStyle: 'italic', margin: '0 0 10px 0' }}>Trend: Persistent High Engagement</p>
              <div style={{ borderTop: '1px solid #F6F5F2', paddingTop: '10px', display: 'flex', justifyContent: 'space-between' }}>
                <div style={{ textAlign: 'left' }}>
                  <p style={{ fontSize: '7px', color: '#999', margin: 0 }}>Engagement</p>
                  <p style={{ fontSize: '10px', fontWeight: 800, margin: 0 }}>{item.engagement.toLocaleString()}</p>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <p style={{ fontSize: '7px', color: '#999', margin: 0 }}>Clinical Rating</p>
                  <p style={{ fontSize: '10px', fontWeight: 800, margin: 0, color: '#7C9C84' }}>{item.rating}★</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {isPreview ? (
        <div style={{ height: '200px', position: 'relative', display: 'flex', justifyContent: 'center', paddingTop: '40px' }}>
          <div style={{ position: 'absolute', top: '45px', width: 'calc(100% + 192px)', left: '-96px', borderBottom: '2px dashed #BBCBC2' }}></div>
          <span style={{ background: 'white', padding: '0 15px', color: '#BBCBC2', fontSize: '10px', fontWeight: 800, letterSpacing: '0.1em', zIndex: 1, position: 'relative', height: '14px', lineHeight: '14px' }}>PAGE BREAK</span>
        </div>
      ) : (
        <div style={{ height: '200px' }} />
      )}

      {/* 4. Low-Engagement Risk Analysis */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>4. Low-Engagement Risk Analysis</h2>
        <p style={textStyle}>
          Content identified in this category presents a risk of <strong>"Digital Information Siloing"</strong>. If key therapeutic resources are under-engaged, the platform fails to provide holistic support. Primary causes are often <strong>buried navigation</strong> or <strong>low metadata relevance</strong> for the AI recommendation engine.
        </p>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '15px' }}>
          {underPerformers.map((item, idx) => (
            <div key={idx} style={{ border: '1px solid #FEE2E2', padding: '15px', borderRadius: '10px', background: '#FFF5F5' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '10px', alignItems: 'center' }}>
                <span style={{ fontSize: '8px', fontWeight: 900, background: '#EF4444', color: 'white', padding: '5px 8px', display: 'inline-block', borderRadius: '4px', lineHeight: 1, textTransform: 'uppercase', verticalAlign: 'middle', textAlign: 'center' }}>UNDER-PERFORMER</span>
                <span style={{ fontSize: '7px', fontWeight: 800, color: '#666' }}>{item.type}</span>
              </div>
              <p style={{ fontSize: '11px', fontWeight: 800, margin: '0 0 10px 0', minHeight: '30px' }}>{item.title}</p>
              <p style={{ fontSize: '7px', color: '#EF4444', fontWeight: 700, margin: '0 0 10px 0' }}>Risk: Information Atrophy</p>
              <div style={{ borderTop: '1px solid #FEE2E2', paddingTop: '10px', display: 'flex', justifyContent: 'space-between' }}>
                <div style={{ textAlign: 'left' }}>
                  <p style={{ fontSize: '7px', color: '#999', margin: 0 }}>Engagement</p>
                  <p style={{ fontSize: '10px', fontWeight: 800, margin: 0 }}>{item.engagement.toLocaleString()}</p>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <p style={{ fontSize: '7px', color: '#999', margin: 0 }}>Rating</p>
                  <p style={{ fontSize: '10px', fontWeight: 800, margin: 0 }}>{item.rating}★</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Spacer removed as Part 4 handled the page break */}

      {/* 5. Comparative Performance Analysis */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>5. Comparative Performance Analysis</h2>
        <p style={textStyle}>
          The bar chart below illustrates the relative engagement density across top-tier resources. A steep drop-off between the top 3 and top 6 items suggests that user attention is heavily concentrated on a few "Hero" assets, leaving significant performance gaps.
        </p>
        <div style={{ background: '#FAFAF9', padding: '20px', borderRadius: '20px', border: '1px solid #E5E4E0', marginBottom: '15px' }}>
          <div style={{ height: '160px', width: '100%' }}>
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData.slice(0, 6)} barSize={35}>
                <CartesianGrid strokeDasharray="3 3" stroke="#e1e1e1" vertical={false} />
                <XAxis dataKey="name" tick={{ fontSize: 8, fill: '#666' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 8, fill: '#666' }} axisLine={false} tickLine={false} />
                <Bar dataKey="engagement" fill="#7C9C84" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* 6. Portfolio Evaluation */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>6. Portfolio Evaluation</h2>
        <p style={textStyle}>
          The Eunoia portfolio currently shows a bias towards <strong>Guides</strong> versus <strong>Articles</strong>. While Guides provide actionable steps for crisis management, long-form Articles are essential for sustained psychological education.
        </p>
        <ul style={{ ...textStyle, paddingLeft: '15px' }}>
          <li><strong>Diverse Content:</strong> High variety in mindfulness and resilience modules.</li>
          <li><strong>Quality Consistency:</strong> Minimal variance in rating scores across different categories.</li>
          <li><strong>Accessibility:</strong> Content is structured for rapid mobile consumption.</li>
        </ul>
      </div>

      {/* 7. Strategic Recommendations */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>7. Strategic Recommendations</h2>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '15px' }}>
          <div style={{ borderLeft: '3px solid #7C9C84', paddingLeft: '10px' }}>
            <p style={{ fontSize: '10px', fontWeight: 800, margin: '0 0 4px 0' }}>AI-Driven Dynamic Interlinking</p>
            <p style={{ fontSize: '8px', color: '#666', margin: 0 }}>Implement deep-learning based related-content nodes to surface low-engagement assets based on emotional state detected in the AI Chatbot.</p>
          </div>
          <div style={{ borderLeft: '3px solid #7C9C84', paddingLeft: '10px' }}>
            <p style={{ fontSize: '10px', fontWeight: 800, margin: '0 0 4px 0' }}>Therapeutic Gamification</p>
            <p style={{ fontSize: '8px', color: '#666', margin: 0 }}>Introduce XP rewards for completing under-utilized content paths to encourage exploratory learning and emotional variety.</p>
          </div>
          <div style={{ borderLeft: '3px solid #7C9C84', paddingLeft: '10px' }}>
            <p style={{ fontSize: '10px', fontWeight: 800, margin: '0 0 4px 0' }}>Content Category Re-Mapping</p>
            <p style={{ fontSize: '8px', color: '#666', margin: 0 }}>Review categories with engagement &lt; 500 total and perform keyword optimization for better NLP indexing.</p>
          </div>
          <div style={{ borderLeft: '3px solid #7C9C84', paddingLeft: '10px' }}>
            <p style={{ fontSize: '10px', fontWeight: 800, margin: '0 0 4px 0' }}>A/B Testing Content Mediums</p>
            <p style={{ fontSize: '8px', color: '#666', margin: 0 }}>Convert lowest-performing Articles into short-form video or audio guides to test accessibility improvements.</p>
          </div>
        </div>
      </div>

      {isPreview ? (
        <div style={{ height: '260px', position: 'relative', display: 'flex', justifyContent: 'center', paddingTop: '40px' }}>
          <div style={{ position: 'absolute', top: '45px', width: 'calc(100% + 192px)', left: '-96px', borderBottom: '2px dashed #BBCBC2' }}></div>
          <span style={{ background: 'white', padding: '0 15px', color: '#BBCBC2', fontSize: '10px', fontWeight: 800, letterSpacing: '0.1em', zIndex: 1, position: 'relative', height: '14px', lineHeight: '14px' }}>PAGE BREAK</span>
        </div>
      ) : (
        <div style={{ height: '260px' }} />
      )}

      {/* 8. Conclusion */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>8. Conclusion</h2>
        <p style={{ ...textStyle, marginBottom: '20px' }}>
          The audit confirms that the **Eunoia Content Ecosystem** is fundamentally sound but requires strategic redistribution of user attention. By implementing the proposed AI-driven interlinking and gamified discovery features, the platform can maximize its clinical impact and ensure no user is left without appropriate emotional guidance due to content invisibility.
        </p>
      </div>

      {/* 9. Data Appendix: Full Content Inventory */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>9. Audit Appendix: Portfolio Inventory</h2>
        <table style={{ width: '100%', borderCollapse: 'collapse', marginBottom: '40px' }}>
          <thead>
            <tr style={{ background: '#f9f9f9' }}>
              <th style={{ textAlign: 'left', padding: '10px', fontSize: '8px', borderBottom: '1px solid #7C9C84', color: '#7C9C84' }}>TITLE / CATALOGUE</th>
              <th style={{ textAlign: 'left', padding: '10px', fontSize: '8px', borderBottom: '11px solid #7C9C84', color: '#7C9C84' }}>TYPE</th>
              <th style={{ textAlign: 'right', padding: '10px', fontSize: '8px', borderBottom: '1px solid #7C9C84', color: '#7C9C84' }}>ENGAGEMENT</th>
              <th style={{ textAlign: 'right', padding: '10px', fontSize: '8px', borderBottom: '1px solid #7C9C84', color: '#7C9C84' }}>QUALITY</th>
            </tr>
          </thead>
          <tbody>
            {processedData.slice(0, 15).map((c, idx) => (
              <tr key={idx}>
                <td style={{ padding: '8px 10px', fontSize: '9px', borderBottom: '1px solid #f2f2f2', fontWeight: 600 }}>{c.title}</td>
                <td style={{ padding: '8px 10px', fontSize: '8px', borderBottom: '1px solid #f2f2f2', color: '#666' }}>{c.type}</td>
                <td style={{ padding: '8px 10px', fontSize: '9px', borderBottom: '1px solid #f2f2f2', textAlign: 'right', fontWeight: 700 }}>{c.engagement.toLocaleString()}</td>
                <td style={{ padding: '8px 10px', fontSize: '9px', borderBottom: '1px solid #f2f2f2', textAlign: 'right', fontWeight: 700, color: '#7C9C84' }}>{c.rating ? c.rating.toFixed(1) : '0.0'}★</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Signature & Audit Appendix */}
      <div style={{ borderTop: '1px solid #eee', paddingTop: '30px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
          <div>
            <p style={{ fontSize: '9px', color: '#1a1a1a', margin: 0, fontWeight: 800 }}>Institutional Review & Safety Oversight</p>
            <p style={{ fontSize: '8px', color: '#aaa', margin: '2px 0 0 0' }}>Access Level: Tier 1 Strategic Dashboard</p>
          </div>
          <div style={{ borderTop: '2px solid #1a1a1a', width: '180px', textAlign: 'center', paddingTop: '6px' }}>
            <p style={{ margin: 0, fontSize: '9px', fontWeight: 800, textTransform: 'uppercase' }}>Academic Supervisor Approval</p>
          </div>
        </div>
      </div>
    </div>
  );
}
