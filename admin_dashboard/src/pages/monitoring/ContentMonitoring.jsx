import { useState, useMemo } from 'react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { useArticles, useMeditationGuides } from '../../hooks/useFirestore';
import { Search, Filter, ArrowUpDown, Eye, Headphones, XCircle, Image as ImageIcon, Loader2 } from 'lucide-react';

const C = { 
  primary: '#7C9C84', 
  primaryLight: '#BBCBC2',
  cream: '#F6F5F2', 
  creamDarker: '#E5E4E0', 
  charcoal: '#333', 
  charcoalMuted: '#666' 
};

export default function ContentMonitoring() {
  const { data: articles, loading: artLoading } = useArticles();
  const { data: guides, loading: gLoading } = useMeditationGuides();
  
  // Interactive Report States
  const [filterType, setFilterType] = useState('All'); // 'All', 'Article', 'Guide'
  const [searchQuery, setSearchQuery] = useState('');
  const [sortField, setSortField] = useState('engagement'); // 'engagement', 'rating', 'title'
  const [sortDir, setSortDir] = useState('desc'); // 'asc', 'desc'
  const [currentPage, setCurrentPage] = useState(1);
  const [viewingDetails, setViewingDetails] = useState(null);
  const [loadingDetails, setLoadingDetails] = useState(null); // ID of the content being pre-loaded
  const itemsPerPage = 8;

  const loading = artLoading || gLoading;

  // Transform data for charts
  const articleChartData = articles
    .sort((a, b) => (b.views || 0) - (a.views || 0))
    .slice(0, 5)
    .map(a => ({ title: a.title.length > 15 ? a.title.substring(0, 15) + '...' : a.title, value: a.views || 0 }));

  const guideChartData = guides
    .sort((a, b) => (b.plays || 0) - (a.plays || 0))
    .slice(0, 5)
    .map(g => ({ title: g.title.length > 15 ? g.title.substring(0, 15) + '...' : g.title, value: g.plays || 0 }));

  // Comprehensive Data Processing for Table
  const processedData = useMemo(() => {
    // 1. Map & Combine
    let combined = [
      ...articles.map(a => ({ 
        id: a.id, 
        title: a.title || 'Untitled', 
        type: 'Article', 
        category: a.tag || 'General',
        duration: a.readingTime || 'N/A',
        status: a.status || 'draft',
        engagement: a.views || 0, 
        rating: a.rating || 0,
        imageUrl: a.imageUrl,
        content: a.content || 'No detailed content or text available for this article.',
        authorName: a.authorName,
      })),
      ...guides.map(g => ({ 
        id: g.id, 
        title: g.title || 'Untitled', 
        type: 'Guide', 
        category: g.category || 'General',
        duration: g.duration || 'N/A',
        status: g.status || 'draft',
        engagement: g.plays || 0, 
        rating: g.rating || 0,
        imageUrl: g.imageUrl,
        content: g.subtitle || 'No detailed description provided for this session.',
        audioUrl: g.audioUrl,
      }))
    ];

    // 2. Filter by Search Query
    if (searchQuery.trim() !== '') {
      const q = searchQuery.toLowerCase();
      combined = combined.filter(c => c.title.toLowerCase().includes(q) || c.category.toLowerCase().includes(q));
    }

    // 3. Filter by Type
    if (filterType !== 'All') {
      combined = combined.filter(c => c.type === filterType);
    }

    // 4. Sort
    combined.sort((a, b) => {
      let valA = a[sortField];
      let valB = b[sortField];
      
      if (typeof valA === 'string') valA = valA.toLowerCase();
      if (typeof valB === 'string') valB = valB.toLowerCase();

      if (valA < valB) return sortDir === 'asc' ? -1 : 1;
      if (valA > valB) return sortDir === 'asc' ? 1 : -1;
      return 0;
    });

    return combined;
  }, [articles, guides, searchQuery, filterType, sortField, sortDir]);

  // Pagination Logic
  const totalPages = Math.ceil(processedData.length / itemsPerPage);
  const paginatedData = processedData.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage);

  const handleSort = (field) => {
    if (sortField === field) {
      setSortDir(sortDir === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDir('desc'); // Default to descending when changing sort to see highest performers first
    }
  };

  const handleViewDetails = (content) => {
    if (loadingDetails) return;
    
    // If no image, show immediately
    if (!content.imageUrl) {
      setViewingDetails(content);
      return;
    }

    setLoadingDetails(content.id);
    const img = new Image();
    img.src = content.imageUrl;
    img.onload = () => {
      setLoadingDetails(null);
      setViewingDetails(content);
    };
    img.onerror = () => {
      setLoadingDetails(null);
      setViewingDetails(content); // Show anyway even if image fails
    };
  };

  return (
    <div className="flex flex-col gap-6">
      <div>
        <p className="section-label mb-1">Monitoring & Analytics</p>
        <h2 className="font-display font-semibold text-2xl text-charcoal">Content Reports</h2>
      </div>

      {loading ? (
        <p className="font-body text-sm text-charcoal-muted">Gathering report data…</p>
      ) : (
        <>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
            {/* Articles chart */}
            <div className="card">
              <p className="section-label mb-1">Articles</p>
              <h3 className="font-body font-semibold text-charcoal mb-4">View Frequency</h3>
              <ResponsiveContainer width="100%" height={200}>
                <BarChart data={articleChartData} layout="vertical" barSize={16}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#EEEDE9" horizontal={false} />
                  <XAxis type="number" tick={{ fontFamily: 'Outfit', fontSize: 11, fill: '#aaa' }} axisLine={false} tickLine={false} />
                  <YAxis dataKey="title" type="category" width={110} tick={{ fontFamily: 'Outfit', fontSize: 10, fill: '#888' }} axisLine={false} tickLine={false} />
                  <Tooltip contentStyle={{ fontFamily: 'Outfit', borderRadius: '12px', border: '1px solid #EEEDE9', fontSize: 12 }} />
                  <Bar dataKey="value" fill={C.primary} radius={[0, 8, 8, 0]} name="Views" />
                </BarChart>
              </ResponsiveContainer>
            </div>

            {/* Meditation chart */}
            <div className="card">
              <p className="section-label mb-1">Meditation Guides</p>
              <h3 className="font-body font-semibold text-charcoal mb-4">Play Frequency</h3>
              <ResponsiveContainer width="100%" height={200}>
                <BarChart data={guideChartData} layout="vertical" barSize={16}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#EEEDE9" horizontal={false} />
                  <XAxis type="number" tick={{ fontFamily: 'Outfit', fontSize: 11, fill: '#aaa' }} axisLine={false} tickLine={false} />
                  <YAxis dataKey="title" type="category" width={110} tick={{ fontFamily: 'Outfit', fontSize: 10, fill: '#888' }} axisLine={false} tickLine={false} />
                  <Tooltip contentStyle={{ fontFamily: 'Outfit', borderRadius: '12px', border: '1px solid #EEEDE9', fontSize: 12 }} />
                  <Bar dataKey="value" fill={C.primaryLight} radius={[0, 8, 8, 0]} name="Plays" />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Comprehensive Content Report Table */}
          <div className="card mt-2">
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
              <div>
                <p className="section-label mb-1">Content Engagement Overview</p>
                <h3 className="font-body font-semibold text-charcoal">Detailed Performance Report</h3>
              </div>
              
              <div className="flex flex-wrap items-center gap-3">
                {/* Search Bar */}
                <div className="relative">
                  <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                    <Search size={14} className="text-gray-400" />
                  </div>
                  <input
                    type="text"
                    placeholder="Search titles..."
                    value={searchQuery}
                    onChange={(e) => { setSearchQuery(e.target.value); setCurrentPage(1); }}
                    className="pl-9 pr-4 py-2 border border-cream-darker rounded-xl text-sm font-body outline-none focus:border-[#7C9C84] transition w-56"
                  />
                </div>
                
                {/* Type Filter Dropdown */}
                <div className="relative flex items-center bg-white border border-cream-darker rounded-xl px-3 py-2">
                  <Filter size={14} className="text-gray-400 mr-2" />
                  <select
                    value={filterType}
                    onChange={(e) => { setFilterType(e.target.value); setCurrentPage(1); }}
                    className="bg-transparent text-sm font-body outline-none text-charcoal cursor-pointer"
                  >
                    <option value="All">All Types</option>
                    <option value="Article">Articles</option>
                    <option value="Guide">Meditation Guides</option>
                  </select>
                </div>
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full font-body text-sm">
                <thead>
                  <tr className="text-left text-charcoal-muted text-xs uppercase tracking-wide border-b border-cream-darker">
                    <th className="pb-3 font-semibold cursor-pointer hover:text-charcoal transition" onClick={() => handleSort('title')}>
                      <div className="flex items-center gap-1">Content Title <ArrowUpDown size={12} opacity={sortField === 'title' ? 1 : 0.3} /></div>
                    </th>
                    <th className="pb-3 font-semibold">Type & Category</th>
                    <th className="pb-3 font-semibold">Duration</th>
                    <th className="pb-3 font-semibold">Status</th>
                    <th className="pb-3 font-semibold cursor-pointer hover:text-charcoal transition" onClick={() => handleSort('engagement')}>
                      <div className="flex items-center gap-1"><Eye size={12} className="mr-1"/> Engagement <ArrowUpDown size={12} opacity={sortField === 'engagement' ? 1 : 0.3} /></div>
                    </th>
                    <th className="pb-3 font-semibold cursor-pointer hover:text-charcoal transition" onClick={() => handleSort('rating')}>
                      <div className="flex items-center gap-1">Rating <ArrowUpDown size={12} opacity={sortField === 'rating' ? 1 : 0.3} /></div>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {paginatedData.map((c, i) => (
                    <tr 
                      key={c.id || i} 
                      onClick={() => handleViewDetails(c)}
                      className={`border-b border-cream-darker last:border-0 transition group cursor-pointer ${loadingDetails === c.id ? 'bg-sage-50' : 'hover:bg-sage-100'}`}
                    >
                      <td className="py-4 pr-4">
                        <div className="flex items-center gap-2">
                          {loadingDetails === c.id && <Loader2 size={14} className="animate-spin text-primary" />}
                          <p className="font-medium text-charcoal group-hover:text-[#7C9C84] transition truncate max-w-[250px]">{c.title}</p>
                        </div>
                      </td>
                      <td className="py-4">
                        <div className="flex flex-col items-start gap-1">
                          <span className={c.type === 'Article' ? 'badge-amber !bg-amber-50 !text-amber-600 border border-amber-100' : 'badge-green !bg-emerald-50 !text-emerald-600 border border-emerald-100'}>
                            {c.type === 'Article' ? '📝 Article' : '🎧 Guide'}
                          </span>
                          <span className="text-[10px] uppercase font-bold text-gray-400 tracking-wider ml-1">{c.category}</span>
                        </div>
                      </td>
                      <td className="py-4 text-charcoal-muted text-xs font-medium">{c.duration}</td>
                      <td className="py-4">
                         <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold border ${c.status === 'published' ? 'bg-green-50 text-green-600 border-green-200' : 'bg-gray-100 text-gray-500 border-gray-200'}`}>
                           {c.status.toUpperCase()}
                         </span>
                      </td>
                      <td className="py-4 font-mono text-charcoal font-semibold">{c.engagement.toLocaleString()}</td>
                      <td className="py-4 text-amber-500 font-semibold flex items-center gap-1 mt-1">
                        ★ {c.rating > 0 ? c.rating.toFixed(1) : '–'}
                      </td>
                    </tr>
                  ))}
                  {paginatedData.length === 0 && (
                    <tr>
                      <td colSpan="6" className="py-12 text-center text-charcoal-muted opacity-60">
                        No content matches your filters.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            {/* Pagination Controls */}
            {totalPages > 1 && (
              <div className="flex items-center justify-between border-t border-cream-darker pt-4 mt-2">
                <p className="text-xs font-body text-charcoal-muted">
                  Showing <span className="font-bold text-charcoal">{(currentPage - 1) * itemsPerPage + 1}</span> to <span className="font-bold text-charcoal">{Math.min(currentPage * itemsPerPage, processedData.length)}</span> of <span className="font-bold text-charcoal">{processedData.length}</span> results
                </p>
                <div className="flex gap-2">
                  <button 
                    onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                    disabled={currentPage === 1}
                    className="px-3 py-1.5 rounded-lg border border-cream-darker text-xs font-bold text-charcoal disabled:opacity-30 hover:bg-cream transition"
                  >
                    Previous
                  </button>
                  <button 
                    onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                    disabled={currentPage === totalPages}
                    className="px-3 py-1.5 rounded-lg border border-cream-darker text-xs font-bold text-charcoal disabled:opacity-30 hover:bg-cream transition"
                  >
                    Next
                  </button>
                </div>
              </div>
            )}
          </div>
        </>
      )}

      {/* Detail Modal Overlay */}
      {viewingDetails && (
        <div 
          className="fixed inset-0 bg-black/60 backdrop-blur-sm flex justify-center items-center z-[1000] p-4 sm:p-6"
          onClick={() => setViewingDetails(null)}
        >
          <div 
            className="w-full max-w-2xl bg-white rounded-3xl shadow-2xl relative animate-in zoom-in-95 duration-200 flex flex-col max-h-[90vh]"
            onClick={e => e.stopPropagation()}
          >
            {/* Header (Sticky) */}
            <div className="flex justify-between items-center px-8 py-6 border-b border-cream-darker shrink-0">
              <div className="flex items-center gap-3">
                 <span className={viewingDetails.type === 'Article' ? 'badge-amber !bg-amber-50 !text-amber-600 border border-amber-100' : 'badge-green !bg-emerald-50 !text-emerald-600 border border-emerald-100'}>
                   {viewingDetails.type === 'Article' ? '📝 Article' : '🎧 Guide'}
                 </span>
                 <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold border ${viewingDetails.status === 'published' ? 'bg-green-50 text-green-600 border-green-200' : 'bg-gray-100 text-gray-500 border-gray-200'}`}>
                   {viewingDetails.status.toUpperCase()}
                 </span>
              </div>
              <button 
                  onClick={() => setViewingDetails(null)} 
                  className="text-gray-400 hover:text-charcoal hover:bg-cream p-2 rounded-full transition"
              >
                  <XCircle size={24}/>
              </button>
            </div>

            {/* Scrollable Body */}
            <div className="p-8 overflow-y-auto hidden-scrollbar flex-1">
               <div className="flex flex-col sm:flex-row gap-6 mb-8 items-start border-b border-cream-darker pb-8">
                 <div className="w-52 h-28 sm:w-64 sm:h-32 shrink-0 bg-sage-100 rounded-2xl flex items-center justify-center overflow-hidden shadow-sm border border-cream-darker">
                   {viewingDetails.imageUrl ? (
                     <img src={viewingDetails.imageUrl} alt={viewingDetails.title} className="w-full h-full object-cover" />
                   ) : (
                     <ImageIcon size={32} className="text-[#7C9C84]/40" />
                   )}
                 </div>
                 
                 <div className="flex flex-col flex-1 h-full w-full">
                   <h2 className="font-display text-2xl font-bold text-charcoal leading-tight mb-2">
                     {viewingDetails.title}
                   </h2>
                   {viewingDetails.authorName && (
                     <p className="font-body text-sm text-charcoal-muted mb-4 font-semibold">By {viewingDetails.authorName}</p>
                   )}
                   
                   <div className="flex flex-wrap gap-x-6 gap-y-3 mt-auto pt-2">
                     <div>
                       <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest block mb-0.5">Category</span>
                       <span className="text-sm font-semibold text-charcoal">{viewingDetails.category}</span>
                     </div>
                     <div>
                       <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest block mb-0.5">Duration</span>
                       <span className="text-sm font-semibold text-charcoal">{viewingDetails.duration}</span>
                     </div>
                     <div>
                       <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest block mb-0.5">Rating</span>
                       <span className="text-sm font-bold text-amber-500">★ {viewingDetails.rating > 0 ? viewingDetails.rating.toFixed(1) : '-'}</span>
                     </div>
                     <div>
                       <span className="text-[10px] font-bold text-gray-400 uppercase tracking-widest block mb-0.5">Engagement</span>
                       <span className="text-sm font-bold text-[#7C9C84]">{viewingDetails.engagement.toLocaleString()} {viewingDetails.type === 'Article' ? 'Views' : 'Plays'}</span>
                     </div>
                   </div>
                 </div>
               </div>

               <p className="section-label mb-4">Content Inspect</p>
               {viewingDetails.audioUrl && (
                 <div className="mb-6 p-4 bg-sage-100 rounded-xl flex items-center gap-4 border border-[#7C9C84]/20 shadow-sm inline-flex">
                   <div className="w-10 h-10 bg-[#7C9C84] rounded-full flex items-center justify-center text-white shadow-md">
                     <Headphones size={20} />
                   </div>
                   <div>
                     <p className="font-bold text-sm text-[#7C9C84]">Audio Attached</p>
                     <p className="text-xs text-[#6A8671]">Users can stream this guide</p>
                   </div>
                 </div>
               )}
               <div className="font-body text-sm text-charcoal leading-relaxed whitespace-pre-wrap">
                 {viewingDetails.content ? (
                   viewingDetails.content
                 ) : (
                   <div className="py-10 text-center opacity-60">
                       <p className="italic">No detailed content or description available.</p>
                   </div>
                 )}
               </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
