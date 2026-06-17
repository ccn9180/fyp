import { useState, useMemo, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Search, Filter, ArrowUpDown, Eye, MessageSquare,
  Trash2, Plus, Loader2, Star, TrendingUp, Activity,
  Heart, ShieldCheck, Share2, Filter as FilterIcon,
  Calendar as CalendarIcon, ChevronDown, Flag, User,
  MoreHorizontal, Pin, Download, Upload
} from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, AreaChart, Area } from 'recharts';
import { usePosts } from '../../hooks/useFirestore';
import { usePDFExport } from '../../hooks/usePDFExport';
import { doc, deleteDoc, addDoc, collection, serverTimestamp } from 'firebase/firestore';
import { db } from '../../firebase';
import { customConfirm } from '../../utils/dialogUtils';
import ReportPreview from '../../components/ReportPreview';

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

export default function CommunityMonitoring() {
  const navigate = useNavigate();
  const { data: posts, loading } = usePosts();
  const [searchQuery, setSearchQuery] = useState('');
  const [filterTopic, setFilterTopic] = useState('All');
  const [sortField, setSortField] = useState('timestamp');
  const [sortDir, setSortDir] = useState('desc');
  const [isAddingAnnouncement, setIsAddingAnnouncement] = useState(false);
  const [announcementText, setAnnouncementText] = useState('');
  const [announcementTopic, setAnnouncementTopic] = useState('General');
  const [isPreviewOpen, setIsPreviewOpen] = useState(false);
  const reportRef = useRef(null);
  const paperRef = useRef(null);

  const { exportPDF, isExporting } = usePDFExport();

  // Process Stats
  const stats = useMemo(() => {
    const all = [...(posts || [])];
    if (all.length === 0) return { total: 0, likes: 0, comments: 0, activeTopics: 0 };
    return {
      total: all.length,
      likes: all.reduce((s, p) => s + (p.likes?.length || 0), 0),
      comments: all.reduce((s, p) => s + (p.commentCount || 0), 0),
      activeTopics: new Set(all.map(p => p.topic)).size
    };
  }, [posts]);

  // Table Data
  const processedPosts = useMemo(() => {
    const all = [...(posts || [])];
    let combined = all.filter(p => !p.isArchived);

    if (searchQuery.trim() !== '') {
      const q = searchQuery.toLowerCase();
      combined = combined.filter(p =>
        (p.content || '').toLowerCase().includes(q) ||
        (p.authorName || '').toLowerCase().includes(q) ||
        (p.topic || '').toLowerCase().includes(q)
      );
    }

    if (filterTopic !== 'All') {
      combined = combined.filter(p => p.topic === filterTopic);
    }

    combined.sort((a, b) => {
      let valA = a[sortField];
      let valB = b[sortField];

      // Handle timestamp comparison
      if (sortField === 'timestamp') {
        valA = a.timestamp?.toDate ? a.timestamp.toDate().getTime() : (a.timestamp || 0);
        valB = b.timestamp?.toDate ? b.timestamp.toDate().getTime() : (b.timestamp || 0);
      }

      if (valA < valB) return sortDir === 'asc' ? -1 : 1;
      if (valA > valB) return sortDir === 'asc' ? 1 : -1;
      return 0;
    });

    return combined;
  }, [posts, searchQuery, filterTopic, sortField, sortDir]);

  const chartData = useMemo(() => {
    const topics = {};
    processedPosts.forEach(p => {
      topics[p.topic] = (topics[p.topic] || 0) + 1;
    });
    return Object.keys(topics).map(t => ({ name: t, count: topics[t] })).sort((a, b) => b.count - a.count).slice(0, 5);
  }, [processedPosts]);

  // Enhanced Analytics for PDF
  const topPerformers = useMemo(() => 
    [...processedPosts].sort((a, b) => ((b.likes?.length || 0) + (b.commentCount || 0)) - ((a.likes?.length || 0) + (a.commentCount || 0))).slice(0, 3)
  , [processedPosts]);

  const underPerformers = useMemo(() => 
    [...processedPosts].sort((a, b) => ((a.likes?.length || 0) + (a.commentCount || 0)) - ((b.likes?.length || 0) + (b.commentCount || 0))).slice(0, 3)
  , [processedPosts]);

  const handleSort = (field) => {
    if (sortField === field) setSortDir(sortDir === 'asc' ? 'desc' : 'asc');
    else { setSortField(field); setSortDir('desc'); }
  };

  const handleDelete = async (postId) => {
    const confirmed = await customConfirm("Delete this community post permanently?", "Confirm Delete");
    if (confirmed) {
      try {
        await deleteDoc(doc(db, 'posts', postId));
      } catch (e) {
        console.error("Delete error:", e);
      }
    }
  };

  const handlePostAnnouncement = async () => {
    if (!announcementText.trim()) return;
    try {
      await addDoc(collection(db, 'posts'), {
        content: announcementText,
        authorName: 'Eunoia Official',
        authorId: 'system_admin',
        authorProfileImage: null,
        timestamp: serverTimestamp(),
        isAnonymous: false,
        topic: announcementTopic,
        moodText: 'Announcement',
        moodColorValue: 0xFF7C9C84,
        likes: [],
        commentCount: 0,
        isAnnouncement: true
      });
      setAnnouncementText('');
      setIsAddingAnnouncement(false);
    } catch (e) { console.error(e); }
  };

  const handleExportPDF = async () => {
    const success = await exportPDF(paperRef, 'Eunoia_Community_Audit');
    if (success) setIsPreviewOpen(false);
  };

  return (
    <div className="flex flex-col gap-6 w-full animate-in fade-in duration-500">
      {/* Header with Plus Button */}
      <div className="flex flex-row items-center justify-between gap-4">
        <div>
          <p className="section-label mb-0.5">Global Pulse / Community Hub</p>
          <h2 className="font-display font-semibold text-2xl text-charcoal">Community Monitoring</h2>
        </div>

        <div className="flex items-center gap-3">
          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-charcoal-muted" />
            <input
              type="text"
              placeholder="Search pulse..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9 pr-4 py-2 bg-white border border-cream-darker rounded-xl text-sm font-body outline-none focus:border-primary transition w-48 shadow-sm"
            />
          </div>
          <button
            onClick={() => setIsPreviewOpen(true)}
            className="flex items-center gap-2 px-4 py-2 bg-[#7C9C84] text-white rounded-xl shadow-sm transition-all hover:bg-opacity-90 active:scale-95"
          >
            <Eye size={14} />
            <span className="text-sm font-bold">Preview Report</span>
          </button>
          <button
            onClick={() => navigate('/monitoring/add-feed')}
            className="px-5 py-2 bg-[#7C9C84] text-white rounded-xl font-body text-xs font-bold transition-all uppercase tracking-widest flex items-center gap-2 shadow-lg shadow-[#7C9C84]/20 hover:scale-105 active:scale-95"
          >
            <Plus size={14} /> Draft Pulse
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-20">
          <Loader2 className="animate-spin text-primary" size={32} />
        </div>
      ) : (
        <div ref={reportRef} className="flex flex-col gap-6 p-1">
          {/* Summary Stats */}
          <div className="grid grid-cols-4 gap-4">
            {[
              { label: 'Total Posts', value: stats.total, icon: MessageSquare, color: 'text-primary', bg: 'bg-sage-50' },
              { label: 'Likes Given', value: stats.likes, icon: Heart, color: 'text-rose', bg: 'bg-rose-50/50' },
              { label: 'Discussion Depth', value: stats.comments, icon: Share2, color: 'text-blue', bg: 'bg-blue-50' },
              { label: 'Trending Topics', value: stats.activeTopics, icon: TrendingUp, color: 'text-amber', bg: 'bg-amber-50' }
            ].map((s, i) => (
              <div key={i} className="card p-5 flex items-center gap-4 border border-cream-darker shadow-sm">
                <div className={`w-10 h-10 rounded-xl ${s.bg} flex items-center justify-center ${s.color}`}>
                  <s.icon size={18} fill={i === 1 ? 'currentColor' : 'none'} />
                </div>
                <div>
                  <p className="section-label !text-[9px] mb-0">{s.label}</p>
                  <p className="font-display font-bold text-xl text-charcoal">{s.value}</p>
                </div>
              </div>
            ))}
          </div>

          {/* Table of Posts */}
          <div className="card shadow-sm border border-cream-darker overflow-hidden">
            <div className="p-6 border-b border-cream-darker flex justify-between items-center bg-white/50">
              <h3 className="font-display font-bold text-lg text-charcoal flex items-center gap-2">
                <ShieldCheck size={18} className="text-primary" /> Community Feed Audit
              </h3>
              <div className="flex gap-2">
                <select
                  value={filterTopic}
                  onChange={(e) => setFilterTopic(e.target.value)}
                  className="px-3 py-1.5 bg-cream/30 border border-cream-darker rounded-lg text-[10px] font-bold uppercase tracking-widest outline-none"
                >
                  <option value="All">All Topics</option>
                  <option value="Self-Love">Self-Love</option>
                  <option value="Anxiety">Anxiety</option>
                  <option value="Hope">Hope</option>
                  <option value="General">General</option>
                </select>
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full font-body text-sm">
                <thead>
                  <tr className="text-left text-charcoal-muted text-[10px] uppercase font-bold tracking-widest border-b border-cream/50">
                    <th className="px-6 py-4 cursor-pointer hover:text-primary transition" onClick={() => handleSort('authorName')}>Author <ArrowUpDown size={10} className="inline ml-1" /></th>
                    <th className="px-6 py-4">Reflection Fragment</th>
                    <th className="px-6 py-4 cursor-pointer hover:text-primary transition" onClick={() => handleSort('topic')}>Topic <ArrowUpDown size={10} className="inline ml-1" /></th>
                    <th className="px-6 py-4 text-center cursor-pointer hover:text-primary transition" onClick={() => handleSort('likes')}>Reach <ArrowUpDown size={10} className="inline ml-1" /></th>
                    <th className="px-6 py-4 text-right pr-8">Oversight</th>
                  </tr>
                </thead>
                <tbody>
                  {processedPosts.map((p, i) => (
                    <tr key={p.id || i} className="border-b border-cream-darker/40 hover:bg-sage-100/20 transition-all group">
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <div className={`w-8 h-8 rounded-lg ${p.isAnnouncement ? 'bg-primary text-white' : 'bg-sage-100 text-primary'} flex items-center justify-center font-bold text-xs shrink-0 border border-cream-darker shadow-sm`}>
                            {p.authorName?.charAt(0) || '?'}
                          </div>
                          <div className="flex flex-col">
                            <span className="font-bold text-charcoal leading-none mb-1">{p.authorName || 'Anonymous'}</span>
                            <span className="text-[9px] text-muted uppercase tracking-tighter opacity-70">
                              {p.isAnonymous ? 'Masked Identity' : 'Verified ID'}
                            </span>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 max-w-sm">
                        <p className="text-charcoal-muted line-clamp-2 leading-relaxed italic text-[13px]">{p.content}</p>
                      </td>
                      <td className="px-6 py-4">
                        <span className={`px-2.5 py-1 rounded-full text-[9px] font-black uppercase tracking-widest ${p.isAnnouncement ? 'bg-primary/10 text-primary' : 'bg-amber-50 text-amber-600'}`}>
                          {p.topic}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-center">
                        <div className="flex items-center justify-center gap-2">
                          <span className="flex items-center gap-1.5 text-rose font-bold text-xs"><Heart size={12} fill="currentColor" /> {p.likes?.length || 0}</span>
                          <span className="flex items-center gap-1.5 text-blue font-bold text-xs"><MessageSquare size={12} /> {p.commentCount || 0}</span>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-right pr-6">
                        <div className="flex items-center justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                          <button
                            className="p-2 text-charcoal/20 hover:text-primary hover:bg-sage-50 rounded-lg transition-all"
                            title="Moderation Detail"
                          >
                            <MoreHorizontal size={16} />
                          </button>
                          <button
                            onClick={() => handleDelete(p.id)}
                            className="p-2 text-charcoal/20 hover:text-rose hover:bg-rose-50 rounded-lg transition-all"
                            title="Remove Fragment"
                          >
                            <Trash2 size={16} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                  {processedPosts.length === 0 && (
                    <tr>
                      <td colSpan="5" className="py-20 text-center text-charcoal-muted opacity-50 font-body text-xs italic tracking-widest">
                        Zero pulse detected for current selection.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      <div style={{ position: 'fixed', left: '-2000px', top: '0', width: '794px', pointerEvents: 'none', zIndex: -1 }}>
        <div ref={paperRef} style={{ background: C.bgCard }}>
          <ReportContent 
            processedPosts={processedPosts} 
            chartData={chartData} 
            stats={stats}
            topPerformers={topPerformers}
            underPerformers={underPerformers}
          />
        </div>
      </div>

      <ReportPreview
        isOpen={isPreviewOpen}
        onClose={() => setIsPreviewOpen(false)}
        onDownload={handleExportPDF}
        isExporting={isExporting}
        title="Community Pulse & Social Audit"
      >
        <ReportContent 
          processedPosts={processedPosts} 
          chartData={chartData} 
          stats={stats}
          topPerformers={topPerformers}
          underPerformers={underPerformers}
        />
      </ReportPreview>
    </div>
  );
}

function ReportContent({ processedPosts, chartData, stats, topPerformers, underPerformers }) {
  return (
    <div style={{ padding: '96px 96px 160px 96px', background: C.bgCard, fontFamily: 'Outfit, sans-serif', color: '#333' }}>
      {/* Paper Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '2px solid #7C9C84', paddingBottom: '20px', marginBottom: '30px' }}>
        <div>
          <h1 style={{ margin: 0, color: '#7C9C84', fontSize: '28px', fontWeight: 800 }}>Eunoia</h1>
          <p style={{ margin: '4px 0 0 0', textTransform: 'uppercase', letterSpacing: '0.1em', fontSize: '9px', color: '#666', fontWeight: 700 }}>Institutional Community Pulse & Discussion Audit</p>
        </div>
        <div style={{ textAlign: 'right' }}>
          <p style={{ margin: 0, fontSize: '11px', fontWeight: 700 }}>REF: ES-AUDIT-COMM-{new Date().getFullYear()}</p>
          <p style={{ margin: '4px 0 0 0', fontSize: '9px', color: '#888' }}>Audit Date: {new Date().toLocaleString()}</p>
        </div>
      </div>

      {/* High Level Stats */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '15px', marginBottom: '30px' }}>
        <div style={{ border: '1px solid #7C9C84', padding: '12px', borderRadius: '10px' }}>
            <p style={{ fontSize: '7px', fontWeight: 800, color: '#7C9C84', textTransform: 'uppercase', marginBottom: '5px' }}>Platform Reach</p>
            <p style={{ fontSize: '18px', fontWeight: 800, margin: 0 }}>{processedPosts.length}</p>
        </div>
        <div style={{ border: '1px solid #F43F5E', padding: '12px', borderRadius: '10px' }}>
            <p style={{ fontSize: '7px', fontWeight: 800, color: '#F43F5E', textTransform: 'uppercase', marginBottom: '5px' }}>Gross appreciation</p>
            <p style={{ fontSize: '18px', fontWeight: 800, margin: 0 }}>{stats.likes}</p>
        </div>
        <div style={{ border: '1px solid #3B82F6', padding: '12px', borderRadius: '10px' }}>
            <p style={{ fontSize: '7px', fontWeight: 800, color: '#3B82F6', textTransform: 'uppercase', marginBottom: '5px' }}>Discussions</p>
            <p style={{ fontSize: '18px', fontWeight: 800, margin: 0 }}>{stats.comments}</p>
        </div>
        <div style={{ border: '1px solid #D97706', padding: '12px', borderRadius: '10px' }}>
            <p style={{ fontSize: '7px', fontWeight: 800, color: '#D97706', textTransform: 'uppercase', marginBottom: '5px' }}>Active domains</p>
            <p style={{ fontSize: '18px', fontWeight: 800, margin: 0 }}>{stats.activeTopics}</p>
        </div>
      </div>

      <div style={{ marginBottom: '30px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '15px' }}>
            <div style={{ width: '4px', height: '20px', background: '#7C9C84', borderRadius: '2px' }}></div>
            <h2 style={{ fontSize: '15px', fontWeight: 800, margin: 0 }}>Viral Community Pulse (Top Engagement)</h2>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '15px' }}>
          {topPerformers.map((post, idx) => (
            <div key={idx} style={{ border: '1px solid #E5E4E0', padding: '12px', borderRadius: '10px', background: '#FAFAF9' }}>
               <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px' }}>
                  <span style={{ fontSize: '8px', fontWeight: 900, background: '#7C9C84', color: 'white', padding: '3px 8px', display: 'inline-block', borderRadius: '4px', lineHeight: 'normal', textTransform: 'uppercase', verticalAlign: 'middle', textAlign: 'center' }}>#{idx+1} VIRAL</span>
                  <span style={{ fontSize: '7px', fontWeight: 800, color: '#666' }}>{post.authorName}</span>
               </div>
               <p style={{ fontSize: '10px', lineHeight: 1.5, margin: '0 0 8px 0', minHeight: '42px', fontStyle: 'italic' }}>"{post.content}"</p>
               <div style={{ display: 'flex', gap: '8px', borderTop: '1px solid #EEE', paddingTop: '6px' }}>
                  <span style={{ fontSize: '8px', fontWeight: 800, color: '#F43F5E' }}>♥ {post.likes?.length || 0}</span>
                  <span style={{ fontSize: '8px', fontWeight: 800, color: '#3B82F6' }}>● {post.commentCount || 0}</span>
               </div>
            </div>
          ))}
        </div>
      </div>

      {/* Lowest Engagement Content */}
      <div style={{ marginBottom: '30px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '15px' }}>
            <div style={{ width: '4px', height: '20px', background: '#EF4444', borderRadius: '2px' }}></div>
            <h2 style={{ fontSize: '15px', fontWeight: 800, margin: 0 }}>Low Visibility Fragments</h2>
        </div>
        <div style={{ border: '1px solid #FEE2E2', background: '#FEF2F2', padding: '15px', borderRadius: '12px' }}>
           <table style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                 <tr>
                    <th style={{ textAlign: 'left', fontSize: '9px', textTransform: 'uppercase', paddingBottom: '10px' }}>CONTENT FRAGMENT</th>
                    <th style={{ textAlign: 'center', fontSize: '9px', textTransform: 'uppercase', paddingBottom: '10px' }}>DOMAIN</th>
                    <th style={{ textAlign: 'right', fontSize: '9px', textTransform: 'uppercase', paddingBottom: '10px' }}>REACH</th>
                 </tr>
              </thead>
              <tbody>
                 {underPerformers.map((post, idx) => (
                    <tr key={idx} style={{ borderTop: '1px solid #FECACA' }}>
                       <td style={{ padding: '10px 0', fontSize: '11px', fontStyle: 'italic', width: '60%' }}>"{post.content.slice(0, 70)}..."</td>
                       <td style={{ padding: '10px 0', fontSize: '10px', textAlign: 'center', fontWeight: 800 }}>{post.topic}</td>
                       <td style={{ padding: '10px 0', fontSize: '10px', textAlign: 'right', color: '#EF4444', fontWeight: 800 }}>{(post.likes?.length || 0) + (post.commentCount || 0)} Total Engagement</td>
                    </tr>
                 ))}
              </tbody>
           </table>
        </div>
      </div>

      {/* Domain Pulse Chart */}
      <h2 style={{ fontSize: '15px', marginBottom: '15px', fontWeight: 800 }}>Community Discussion Domain pulse</h2>
      <div style={{ marginBottom: '30px', background: '#FAFAF9', padding: '20px', borderRadius: '20px', border: '1px solid #E5E4E0' }}>
        <div style={{ height: '180px', width: '100%' }}>
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={chartData.slice(0, 6)} barSize={35}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e5e5" vertical={false} />
              <XAxis dataKey="name" tick={{ fontSize: 8, fill: '#888' }} axisLine={false} tickLine={false} />
              <YAxis tick={{ fontSize: 8, fill: '#888' }} axisLine={false} tickLine={false} />
              <Bar dataKey="Reach" fill="#7C9C84" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      <h2 style={{ fontSize: '18px', marginBottom: '20px', fontWeight: 700 }}>Community Feed Inventory Log</h2>
      <table style={{ width: '100%', borderCollapse: 'collapse', marginBottom: '60px' }}>
        <thead>
          <tr style={{ background: '#f9fafb' }}>
            <th style={{ textAlign: 'left', padding: '12px', fontSize: '11px', borderBottom: '1px solid #eee', width: '40%' }}>CONTENT</th>
            <th style={{ textAlign: 'left', padding: '12px', fontSize: '11px', borderBottom: '1px solid #eee' }}>AUTHOR</th>
            <th style={{ textAlign: 'left', padding: '12px', fontSize: '11px', borderBottom: '1px solid #eee' }}>DOMAIN</th>
            <th style={{ textAlign: 'right', padding: '12px', fontSize: '11px', borderBottom: '1px solid #eee' }}>ACTIVITY</th>
          </tr>
        </thead>
        <tbody>
          {processedPosts.slice(0, 15).map((p, idx) => (
            <tr key={idx}>
              <td style={{ padding: '12px', fontSize: '10px', borderBottom: '1px solid #f2f2f2', color: '#666', fontStyle: 'italic' }}>
                "{p.content.length > 80 ? p.content.slice(0, 80) + '...' : p.content}"
              </td>
              <td style={{ padding: '12px', fontSize: '11px', borderBottom: '1px solid #f2f2f2', fontWeight: 700 }}>{p.authorName}</td>
              <td style={{ padding: '12px', fontSize: '10px', borderBottom: '1px solid #f2f2f2', color: '#7C9C84', fontWeight: 800 }}>{p.topic}</td>
              <td style={{ padding: '12px', fontSize: '11px', borderBottom: '1px solid #f2f2f2', textAlign: 'right' }}>{p.commentCount || 0} Comments</td>
            </tr>
          ))}
        </tbody>
      </table>

      <div style={{ borderTop: '1px solid #eee', paddingTop: '40px', marginTop: 'auto' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <p style={{ fontSize: '11px', color: '#333', margin: 0, fontWeight: 800 }}>Institutional Platform Governance Record</p>
            <p style={{ fontSize: '9px', color: '#aaa', margin: '4px 0 0 0' }}>PRIVILEGED INFORMATION: Access restricted to authorized portal monitors only.</p>
          </div>
          <div style={{ borderTop: '1px solid #7C9C84', width: '200px', textAlign: 'center', paddingTop: '8px' }}>
            <p style={{ margin: 0, fontSize: '10px', fontWeight: 800, textTransform: 'uppercase', color: '#7C9C84' }}>Platform Monitor Signature</p>
          </div>
        </div>
      </div>
    </div>
  );
}
