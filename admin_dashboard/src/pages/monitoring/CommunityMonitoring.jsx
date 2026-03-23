import { useState, useMemo } from 'react';
import { 
  Search, Filter, ArrowUpDown, Eye, MessageSquare, 
  Trash2, Plus, Loader2, Star, TrendingUp, Activity, 
  Heart, ShieldCheck, Share2, Filter as FilterIcon,
  Calendar as CalendarIcon, ChevronDown, Flag, User,
  MoreHorizontal, Pin
} from 'lucide-react';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, AreaChart, Area } from 'recharts';
import { usePosts } from '../../hooks/useFirestore';
import { doc, deleteDoc, addDoc, collection, serverTimestamp } from 'firebase/firestore';
import { db } from '../../firebase';

const C = { 
  primary: '#7C9C84', 
  primaryLight: '#BBCBC2',
  cream: '#F6F5F2', 
  creamDarker: '#E5E4E0', 
  sage100: '#E5EDE8', 
  charcoal: '#333', 
  charcoalMuted: '#666',
  muted: '#888',
  amber: '#d97706',
  rose: '#f43f5e'
};

export default function CommunityMonitoring() {
  const { data: posts, loading } = usePosts();
  const [searchQuery, setSearchQuery] = useState('');
  const [filterTopic, setFilterTopic] = useState('All');
  const [sortField, setSortField] = useState('timestamp');
  const [sortDir, setSortDir] = useState('desc');
  const [isAddingAnnouncement, setIsAddingAnnouncement] = useState(false);
  const [announcementText, setAnnouncementText] = useState('');
  const [announcementTopic, setAnnouncementTopic] = useState('General');

  // Process Stats
  const stats = useMemo(() => {
    if (!posts) return { total: 0, likes: 0, comments: 0, activeTopics: 0 };
    return {
      total: posts.length,
      likes: posts.reduce((s, p) => s + (p.likes?.length || 0), 0),
      comments: posts.reduce((s, p) => s + (p.commentCount || 0), 0),
      activeTopics: new Set(posts.map(p => p.topic)).size
    };
  }, [posts]);

  // Table Data
  const processedPosts = useMemo(() => {
    let combined = (posts || []).filter(p => !p.isArchived);

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

  const handleSort = (field) => {
    if (sortField === field) setSortDir(sortDir === 'asc' ? 'desc' : 'asc');
    else { setSortField(field); setSortDir('desc'); }
  };

  const handleDelete = async (postId) => {
    if (window.confirm("Delete this community post permanently?")) {
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
            onClick={() => setIsAddingAnnouncement(true)}
            className="px-5 py-2 bg-[#7C9C84] text-white rounded-xl font-body text-xs font-bold transition-all uppercase tracking-widest flex items-center gap-2 shadow-lg shadow-[#7C9C84]/20 hover:scale-105 active:scale-95"
          >
            <Plus size={14} /> New Announcement
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex items-center justify-center py-20">
          <Loader2 className="animate-spin text-primary" size={32} />
        </div>
      ) : (
        <>
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
        </>
      )}

      {/* NEW ANNOUNCEMENT MODAL */}
      {isAddingAnnouncement && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-[1000] flex items-center justify-center p-6 animate-in fade-in duration-300">
          <div className="w-full max-w-lg bg-white rounded-[2rem] shadow-2xl p-8 transform animate-in slide-in-from-bottom-5 duration-400">
            <h3 className="font-display font-bold text-2xl text-charcoal mb-2">Publish Announcement</h3>
            <p className="text-charcoal-muted text-[10px] uppercase font-bold tracking-widest mb-8 opacity-60">Broadcast to entire user base</p>
            
            <div className="space-y-6">
              <div className="space-y-2">
                <label className="text-[10px] font-black text-primary uppercase tracking-widest ml-1">Target Topic</label>
                <select 
                  value={announcementTopic}
                  onChange={(e) => setAnnouncementTopic(e.target.value)}
                  className="w-full bg-cream/30 border border-cream-darker rounded-xl px-4 py-3 text-sm font-body outline-none focus:border-primary transition appearance-none"
                >
                  <option value="General">General Broadcast</option>
                  <option value="Self-Love">Self-Love Fragment</option>
                  <option value="Anxiety">Anxiety Support</option>
                  <option value="Hope">Hope Channel</option>
                </select>
              </div>

              <div className="space-y-2">
                <label className="text-[10px] font-black text-primary uppercase tracking-widest ml-1">Message Body</label>
                <textarea 
                  value={announcementText}
                  onChange={(e) => setAnnouncementText(e.target.value)}
                  placeholder="Draft your message here..."
                  className="w-full h-40 bg-cream/30 border border-cream-darker rounded-2xl px-5 py-4 text-sm font-body outline-none focus:border-primary transition resize-none"
                />
              </div>

              <div className="flex gap-3 pt-4">
                <button 
                  onClick={() => setIsAddingAnnouncement(false)}
                  className="flex-1 py-3 border border-cream-darker rounded-xl text-xs font-black uppercase text-charcoal-muted tracking-widest hover:bg-cream/20 transition active:scale-95"
                >
                  Discard
                </button>
                <button 
                  onClick={handlePostAnnouncement}
                  className="flex-[2] py-3 bg-[#7C9C84] text-white rounded-xl text-xs font-black uppercase tracking-widest shadow-lg shadow-[#7C9C84]/20 hover:scale-[1.02] active:scale-95 transition"
                >
                  Publish Now
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
