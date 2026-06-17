import { useState } from 'react';
import {
  ArrowLeft, Share2, Info, LayoutGrid,
  MessageSquare, ShieldCheck, Sparkles, Loader2,
  Trash2, Image as ImageIcon, CheckCircle, ChevronDown
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { collection, addDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../../firebase';

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

export default function AddFeed() {
  const navigate = useNavigate();
  const [content, setContent] = useState('');
  const [topic, setTopic] = useState('General');
  const [isPosting, setIsPosting] = useState(false);
  const [success, setSuccess] = useState(false);

  const handlePost = async () => {
    if (!content.trim()) return;
    setIsPosting(true);
    try {
      await addDoc(collection(db, 'posts'), {
        content: content,
        authorName: 'Eunoia Official',
        authorId: 'system_admin',
        authorProfileImage: null,
        timestamp: serverTimestamp(),
        isAnonymous: false,
        topic: topic,
        moodText: 'Announcement',
        moodColorValue: 0xFF7C9C84,
        likes: [],
        commentCount: 0,
        isAnnouncement: true
      });
      setSuccess(true);
      setTimeout(() => navigate('/monitoring/post-feeds'), 1500);
    } catch (e) {
      console.error(e);
    } finally {
      setIsPosting(false);
    }
  };

  if (success) {
    return (
      <div className="h-[80vh] flex items-center justify-center animate-in fade-in zoom-in duration-700">
        <div className="text-center p-16 rounded-[4rem] bg-white shadow-2xl border border-cream-darker max-w-sm relative overflow-hidden">
          <div className="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-primary/10 via-primary to-primary/10" />
          <div className="w-24 h-24 bg-sage-100 rounded-2xl flex items-center justify-center text-primary mx-auto mb-8 rotate-3 shadow-lg shadow-primary/10">
            <CheckCircle size={48} strokeWidth={1.5} />
          </div>
          <h2 className="font-display font-bold text-3xl text-charcoal mb-3">Published.</h2>
          <p className="font-body text-charcoal-muted text-sm leading-relaxed px-4">
            The community pulse will now reflect your official broadcast.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-5xl mx-auto w-full flex flex-col gap-10 py-6 animate-in fade-in slide-in-from-bottom-8 duration-700 ease-out">
      {/* Immersive Header */}
      <div className="flex items-end justify-between px-2">
        <div className="flex flex-col gap-6">
          <button
            onClick={() => navigate(-1)}
            className="group flex items-center gap-2 text-muted hover:text-primary transition-all font-body text-xs font-bold uppercase tracking-widest"
          >
            <div className="p-2 rounded-full bg-white border border-cream-darker group-hover:border-primary/30 group-hover:bg-sage-100 transition-all">
              <ArrowLeft size={14} />
            </div>
            Back to Pulse
          </button>

          <div>
            <div className="flex items-center gap-2 mb-2">
              <div className="w-1.5 h-1.5 rounded-full bg-primary" />
              <p className="font-body text-[10px] uppercase font-black tracking-[0.2em] text-primary">Global Broadcast Suite</p>
            </div>
            <h2 className="font-display font-normal text-4xl text-charcoal">Design Your <span className="italic font-serif">Message</span></h2>
          </div>
        </div>

        <button
          onClick={handlePost}
          disabled={!content.trim() || isPosting}
          className={`group px-10 py-4 rounded-3xl font-display font-bold text-sm transition-all flex items-center gap-3 relative overflow-hidden ${!content.trim() || isPosting
            ? 'bg-cream-darker text-muted cursor-not-allowed'
            : 'bg-charcoal text-white hover:bg-black hover:scale-[1.02] active:scale-[0.98] shadow-2xl shadow-charcoal/20'
            }`}
        >
          {isPosting ? <Loader2 size={18} className="animate-spin" /> : <Share2 size={18} className="group-hover:rotate-12 transition-transform" />}
          {isPosting ? 'Broadcasting...' : 'Publish Feed'}
        </button>
      </div>

      {/* Main Drafting Canvas */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-start">
        <div className="lg:col-span-8 flex flex-col gap-8">
          <div className="relative group">
            {/* Background flourish */}
            <div className="absolute -inset-1 bg-gradient-to-r from-primary/5 to-primary/10 rounded-[3rem] blur opacity-25 group-hover:opacity-100 transition duration-1000 group-hover:duration-200"></div>

            <div className="relative bg-white rounded-[3rem] border border-cream-darker shadow-xl overflow-hidden transition-all duration-500">
              <div className="px-10 pt-10 pb-6 border-b border-cream/50 bg-cream/20 flex items-center justify-between">
                <div className="flex items-center gap-4">
                  <div className="w-10 h-10 rounded-2xl bg-primary text-white flex items-center justify-center font-display font-bold shadow-lg shadow-primary/20">E</div>
                  <div>
                    <p className="font-display font-bold text-charcoal text-sm leading-none">Eunoia Official</p>
                    <p className="font-body text-[10px] text-muted font-bold mt-1 uppercase tracking-tight">System Identity Verified</p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <span className="px-3 py-1 bg-sage-100 text-primary text-[10px] font-black uppercase tracking-widest rounded-full">Preview Mode</span>
                </div>
              </div>

              <div className="p-10 bg-white">
                <textarea
                  value={content}
                  onChange={(e) => setContent(e.target.value)}
                  placeholder="Share a story, a meditation tip, or an official update..."
                  className="w-full h-[360px] text-xl font-body text-charcoal leading-[1.8] outline-none border-none resize-none bg-transparent placeholder:text-muted/30 scrollbar-hide"
                  autoFocus
                />
              </div>

              <div className="px-10 py-6 bg-cream/10 border-t border-cream/50 flex items-center justify-between">
                <p className="font-body text-[11px] text-muted">
                  {content.length} characters written • Approx. {Math.ceil(content.length / 5 / 60)} min read
                </p>
                <div className="flex items-center gap-4 opacity-40 hover:opacity-100 transition-opacity">
                  <ImageIcon size={16} />
                  <Share2 size={16} />
                </div>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-4 bg-primary/5 p-4 rounded-2xl border border-primary/10">
            <div className="w-10 h-10 bg-white rounded-xl flex items-center justify-center text-primary shadow-sm flex-shrink-0">
              <Info size={18} />
            </div>
            <p className="font-body text-xs text-primary/80 leading-relaxed font-medium">
              This post will be pinned to the community feed pulse. Ensure alignment with the Eunoia Sanctuary moderation guidelines for official communication.
            </p>
          </div>
        </div>

        {/* Configuration Sidebar */}
        <div className="lg:col-span-4 flex flex-col gap-6 sticky top-6">
          {/* Topic Selection */}
          <div className="bg-white rounded-[2.5rem] p-8 border border-cream-darker shadow-lg">
            <h3 className="font-display font-bold text-lg text-charcoal mb-6 flex items-center gap-2">
              <LayoutGrid size={18} className="text-primary" /> Taxonomy
            </h3>

            <div className="grid grid-cols-1 gap-3">
              {[
                { id: 'General', label: 'General Pulse', icon: Sparkles },
                { id: 'Self-Love', label: 'Self-Love Hub', icon: ShieldCheck },
                { id: 'Anxiety', label: 'Anxiety Portal', icon: Sparkles },
                { id: 'Hope', label: 'Hope Station', icon: Sparkles },
              ].map(t => (
                <button
                  key={t.id}
                  onClick={() => setTopic(t.id)}
                  className={`w-full p-4 rounded-2xl transition-all flex items-center justify-between group relative overflow-hidden ${topic === t.id
                    ? 'bg-primary text-white shadow-xl shadow-primary/20 scale-[1.02]'
                    : 'bg-white border border-cream-darker text-charcoal-muted hover:border-primary/30'
                    }`}
                >
                  <div className="flex items-center gap-3 relative z-10">
                    <t.icon size={16} className={topic === t.id ? 'text-white' : 'text-primary transition-colors'} />
                    <span className={`text-[13px] font-bold ${topic === t.id ? '' : 'font-body opacity-80'}`}>{t.label}</span>
                  </div>
                  {topic === t.id ? (
                    <CheckCircle size={16} className="relative z-10 animate-in zoom-in" />
                  ) : (
                    <div className="w-4 h-4 rounded-full border border-cream-darker group-hover:border-primary/50 transition-colors" />
                  )}
                </button>
              ))}
            </div>
          </div>

          {/* Quick Tips Card */}
          <div className="bg-charcoal rounded-[2.5rem] p-8 text-white relative overflow-hidden shadow-2xl">
            <div className="absolute -right-6 -top-6 w-32 h-32 bg-primary/20 rounded-full blur-3xl" />
            <div className="absolute -left-6 -bottom-6 w-24 h-24 bg-white/5 rounded-full blur-2xl" />

            <div className="relative z-10">
              <div className="flex items-center gap-2 mb-4">
                <div className="p-2 bg-white/10 rounded-xl">
                  <Sparkles size={16} className="text-primary" />
                </div>
                <span className="font-body text-[10px] font-black uppercase tracking-[0.2em] text-white/40">Sanctuary Advice</span>
              </div>

              <h4 className="font-display font-bold text-lg mb-4">Quality of Presence</h4>
              <ul className="space-y-4">
                {[
                  "Use compassionate, gentle language.",
                  "Embed a focal point for reflection.",
                  "Maintain the Sage brand voice."
                ].map((tip, i) => (
                  <li key={i} className="flex gap-3 text-xs leading-relaxed text-white/60 font-body">
                    <span className="text-primary font-black">•</span>
                    {tip}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
