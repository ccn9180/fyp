import { useState } from 'react';
import { 
  Zap, Award, Gift, Plus, Trash2, Copy, X, Send, Ticket, 
  Settings, TrendingUp, Star, Music, BookOpen, 
  MessageSquare, Edit3, Save, ChevronRight, LayoutGrid
} from 'lucide-react';
import { db } from '../../firebase';
import { useVouchers, useXPRules, useBadges } from '../../hooks/useFirestore';
import { doc, deleteDoc, addDoc, updateDoc, collection, serverTimestamp } from 'firebase/firestore';

const C = { 
  primary: '#7C9C84', 
  primaryDark: '#6A8671',
  cream: '#F6F5F2', 
  creamDarker: '#E5E4E0', 
  sage100: '#E5EDE8', 
  charcoal: '#333', 
  charcoalMuted: '#666',
  muted: '#888',
  white: '#ffffff',
  error: '#f87171',
  amber: '#d97706'
};

const INITIAL_BADGES = [
  { name: 'Beginner Meditator', xp: 100, icon: '🌱', desc: 'Starting the journey' },
  { name: 'Mindful Week', xp: 250, icon: '🍃', desc: 'A week of presence' },
  { name: 'Streak Master', xp: 500, icon: '🔥', desc: 'Consistent practice' },
  { name: 'Wellness Sage', xp: 1000, icon: '🧘', desc: 'Deep mental clarity' },
  { name: 'Eunoia Champion', xp: 2000, icon: '🏆', desc: 'Master of self' },
];

const INITIAL_XP_ACTIONS = [
  { action: 'Complete Meditation', xp: 20, icon: Music },
  { action: 'Write Diary Entry', xp: 15, icon: Edit3 },
  { action: 'Read Article', xp: 10, icon: BookOpen },
  { action: 'Daily Login', xp: 5, icon: Zap },
  { action: 'AI Chat Session', xp: 25, icon: MessageSquare },
];

export default function Engagement() {
  const [activeTab, setActiveTab] = useState('xp'); 
  const { data: vouchers, loading: vLoading } = useVouchers();
  const { data: xpRules, loading: xLoading } = useXPRules();
  const { data: badges, loading: bLoading } = useBadges();
  
  const [processing, setProcessing] = useState(null);
  const [isModalOpen, setIsModalOpen] = useState(false); // Reuse for XP/Badge addition
  const [isVoucherOpen, setIsVoucherOpen] = useState(false);
  
  const [xpForm, setXpForm] = useState({ action: '', xp: 10, icon: 'Zap' });
  const [badgeForm, setBadgeForm] = useState({ name: '', xp: 500, icon: '🌱', desc: '' });
  const [voucherForm, setVoucherForm] = useState({
    code: '', discount: '', total: 50, used: 0, expires: '', status: 'Active'
  });

  const iconMap = { Zap, Music, BookOpen, MessageSquare, Edit3, Star, Award, TrendingUp };

  const handleCreateXP = async (e) => {
    e.preventDefault();
    setProcessing('xp-add');
    try {
      await addDoc(collection(db, 'xp_rules'), { ...xpForm, createdAt: serverTimestamp() });
      setIsModalOpen(false);
    } catch (e) { console.error(e); } finally { setProcessing(null); }
  };

  const handleCreateBadge = async (e) => {
    e.preventDefault();
    setProcessing('badge-add');
    try {
      await addDoc(collection(db, 'badges'), { ...badgeForm, createdAt: serverTimestamp() });
      setIsModalOpen(false);
    } catch (e) { console.error(e); } finally { setProcessing(null); }
  };

  const hamdleUpdateRule = async (id, val) => {
    try { await updateDoc(doc(db, 'xp_rules', id), { xp: Number(val) }); } catch (e) { console.error(e); }
  };

  const handleUpdateBadge = async (id, val) => {
    try { await updateDoc(doc(db, 'badges', id), { xp: Number(val) }); } catch (e) { console.error(e); }
  };

  const handleDelete = async (coll, id) => {
    if (!window.confirm('Delete this item permanently?')) return;
    setProcessing(id);
    try { await deleteDoc(doc(db, coll, id)); } catch (e) { console.error(e); } finally { setProcessing(null); }
  };

  const handleCreateVoucher = async (e) => {
    e.preventDefault();
    setProcessing('v-add');
    try {
      await addDoc(collection(db, 'vouchers'), { ...voucherForm, createdAt: serverTimestamp() });
      setIsVoucherOpen(false);
    } catch (e) { console.error(e); } finally { setProcessing(null); }
  };

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-row items-center justify-between gap-4">
        <div>
          <p className="section-label mb-0.5">Engagement Hub</p>
          <h2 className="font-display font-semibold text-2xl text-charcoal">Gamification Management</h2>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <div className="flex bg-white p-1 rounded-2xl border border-cream-darker shadow-sm">
            {[
              { id: 'xp', icon: Zap, label: 'XP Rules' },
              { id: 'badges', icon: Award, label: 'Badges' },
              { id: 'rewards', icon: Gift, label: 'Rewards' }
            ].map(tab => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`flex items-center gap-2 px-4 py-2 rounded-xl font-body text-xs font-bold transition-all ${
                  activeTab === tab.id 
                    ? 'bg-primary text-white shadow-md' 
                    : 'text-charcoal-muted hover:bg-cream'
                }`}
              >
                <tab.icon size={14} />
                {tab.label}
              </button>
            ))}
          </div>

          {activeTab === 'rewards' && (
            <button 
              onClick={() => setIsVoucherOpen(true)}
              className="flex items-center gap-2 px-5 py-2.5 bg-primary text-white rounded-xl text-xs font-bold shadow-lg shadow-primary/20 hover:opacity-90 active:scale-95 transition-all"
            >
              <Plus size={16} /> Create Reward
            </button>
          )}
        </div>
      </div>

      {/* Main Content Area */}
      <div className="min-h-[500px]">
        {activeTab === 'xp' && (
          <div className="animate-in fade-in slide-in-from-bottom-2 duration-300">
             <div className="card max-w-2xl bg-white/40 backdrop-blur-md border border-cream-darker">
                <div className="flex items-center justify-between mb-8">
                  <div className="flex items-center gap-2">
                    <div className="w-10 h-10 rounded-xl bg-sage-100 flex items-center justify-center text-primary">
                      <Zap size={20} fill="currentColor" />
                    </div>
                    <div>
                      <h3 className="font-display font-semibold text-lg text-charcoal">XP Acquisition Rules</h3>
                      <p className="font-body text-xs text-charcoal-muted">Configure how users earn points across the platform</p>
                    </div>
                  </div>
                  <button 
                    onClick={() => { setXpForm({ action: '', xp: 10, icon: 'Zap' }); setIsModalOpen('xp'); }}
                    className="p-3 bg-primary text-white rounded-xl shadow-lg shadow-primary/20 hover:scale-105 active:scale-95 transition-all"
                  >
                    <Plus size={18} />
                  </button>
                </div>

                <div className="space-y-3">
                  {(xpRules || []).map((action) => {
                    const IconComp = iconMap[action.icon] || Zap;
                    return (
                      <div key={action.id} className="flex items-center justify-between p-4 bg-white rounded-2xl border border-cream-darker group hover:border-primary/40 hover:shadow-xl transition-all h-[72px]">
                        <div className="flex items-center gap-4">
                          <div className="w-10 h-10 rounded-xl bg-sage-100/50 flex items-center justify-center text-primary shadow-sm group-hover:bg-primary group-hover:text-white transition-all">
                            <IconComp size={18} />
                          </div>
                          <p className="font-body font-bold text-sm text-charcoal">{action.action}</p>
                        </div>
                        <div className="flex items-center gap-3">
                          <input 
                             type="number"
                             value={action.xp}
                             onChange={e => hamdleUpdateRule(action.id, e.target.value)}
                             className="w-20 bg-cream/30 border border-cream-darker rounded-xl px-3 py-2 text-center font-display font-bold text-primary focus:border-primary focus:bg-white outline-none transition-all"
                          />
                          <button 
                            onClick={() => handleDelete('xp_rules', action.id)}
                            className="p-2 text-gray-300 hover:text-red-500 hover:bg-red-50 rounded-lg transition-all"
                          >
                            <Trash2 size={14} />
                          </button>
                        </div>
                      </div>
                    );
                  })}
                  {(!xpRules || xpRules.length === 0) && !xLoading && (
                    <div className="py-12 text-center opacity-40 italic font-body text-sm">No XP rules established.</div>
                  )}
                </div>
             </div>
          </div>
        )}

        {activeTab === 'badges' && (
          <div className="animate-in fade-in slide-in-from-bottom-2 duration-300">
             <div className="card">
                <div className="flex items-start justify-between mb-10">
                  <div className="flex items-center gap-2">
                    <div className="w-10 h-10 rounded-xl bg-amber-50 flex items-center justify-center text-amber-500">
                      <Award size={20} />
                    </div>
                    <div>
                      <h3 className="font-display font-semibold text-lg text-charcoal">Badge Progression Milestones</h3>
                      <p className="font-body text-xs text-charcoal-muted">Adjust XP thresholds for user level-up achievements</p>
                    </div>
                  </div>
                  <button 
                    onClick={() => { setBadgeForm({ name: '', xp: 500, icon: '🌱', desc: '' }); setIsModalOpen('badge'); }}
                    className="px-5 py-2.5 bg-primary text-white rounded-xl text-xs font-bold shadow-lg shadow-primary/20 hover:opacity-90 transition-all flex items-center gap-2"
                  >
                    <Plus size={16} /> Add Milestone
                  </button>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                   {(badges || []).map((badge) => (
                     <div key={badge.id} className="p-6 bg-white rounded-[32px] border border-cream-darker flex flex-col gap-4 relative overflow-hidden group hover:shadow-2xl hover:border-primary/20 transition-all">
                        <div className="absolute top-0 right-0 w-32 h-32 bg-primary/5 rounded-full -mr-16 -mt-16 transition-transform group-hover:scale-125" />
                        <button 
                          onClick={() => handleDelete('badges', badge.id)}
                          className="absolute top-4 right-4 z-20 p-2 text-gray-300 hover:text-red-500 hover:bg-red-50 rounded-xl transition-all opacity-0 group-hover:opacity-100"
                        >
                          <Trash2 size={14} />
                        </button>

                        <div className="flex items-center gap-4 z-10">
                           <div className="text-4xl bg-sage-100/30 w-16 h-16 rounded-2xl shadow-sm flex items-center justify-center border border-primary/5 group-hover:rotate-6 transition-transform">
                              {badge.icon}
                           </div>
                           <div className="flex-1 min-w-0">
                              <p className="font-display font-bold text-charcoal text-lg group-hover:text-primary transition-colors truncate">{badge.name}</p>
                              <p className="font-body text-[11px] text-charcoal-muted leading-relaxed line-clamp-1">{badge.desc}</p>
                           </div>
                        </div>

                        <div className="mt-2 z-10 bg-cream/30 p-5 rounded-2xl border border-cream-darker/50">
                           <div className="flex justify-between items-end mb-4">
                              <span className="font-body text-[9px] font-bold text-charcoal-muted uppercase tracking-widest">XP Boundary</span>
                              <span className="font-display font-black text-primary text-2xl drop-shadow-sm">
                                {badge.xp}<span className="text-[10px] font-bold ml-1 opacity-60">XP</span>
                              </span>
                           </div>
                           <input 
                             type="range"
                             min={50}
                             max={5000}
                             step={50}
                             value={badge.xp}
                             onChange={e => handleUpdateBadge(badge.id, e.target.value)}
                             className="w-full h-1.5 bg-white rounded-full appearance-none accent-primary cursor-pointer border border-cream-darker shadow-inner"
                           />
                        </div>
                     </div>
                   ))}
                </div>
                {(!badges || badges.length === 0) && !bLoading && (
                  <div className="py-20 text-center opacity-40 italic font-body text-sm bg-cream/30 rounded-3xl border border-dashed border-cream-darker">No milestones documented.</div>
                )}
             </div>
          </div>
        )}

        {activeTab === 'rewards' && (
          <div className="animate-in fade-in slide-in-from-bottom-2 duration-300 flex flex-col gap-6">
             <div className="flex justify-between items-center">
                <div>
                  <p className="section-label mb-1">Inventory Management</p>
                  <h3 className="font-display font-semibold text-charcoal">Digital Strategy Rewards</h3>
                </div>
             </div>

             <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                {(vouchers || []).map((v) => (
                  <div key={v.id} className="card !p-0 overflow-hidden group hover:border-primary/40 transition-all border border-cream-darker hover:shadow-xl">
                     <div className="p-4 bg-sage-100/50 flex justify-between items-center border-b border-cream-darker">
                        <div className="flex items-center gap-2">
                           <div className="w-8 h-8 rounded-lg bg-white flex items-center justify-center text-primary shadow-sm">
                             <Ticket size={14} />
                           </div>
                           <span className="font-mono font-black text-primary text-xs tracking-tight">{v.code}</span>
                        </div>
                        <button 
                           onClick={() => handleDelete('vouchers', v.id)}
                           className="p-1.5 text-gray-300 hover:text-red-500 hover:bg-red-50 rounded-lg transition-all"
                        >
                           <Trash2 size={14} />
                        </button>
                     </div>
                     <div className="p-5">
                        <div className="flex items-baseline gap-1">
                          <p className="font-display font-black text-2xl text-charcoal">{v.discount}</p>
                        </div>
                        <span className={`inline-flex px-2 py-0.5 rounded-full text-[9px] font-bold mt-1 border ${v.status === 'Active' ? 'bg-sage-100 text-primary border-primary/10' : 'bg-gray-100 text-charcoal-muted border-gray-200'}`}>
                          {v.status?.toUpperCase() || 'ACTIVE'}
                        </span>
                        
                        <div className="mt-8">
                           <div className="flex justify-between text-[9px] font-bold text-charcoal-muted uppercase mb-2">
                              <span>Redemption Rate</span>
                              <span>{v.used} / {v.total}</span>
                           </div>
                           <div className="w-full h-1.5 bg-cream rounded-full overflow-hidden border border-cream-darker">
                              <div 
                                className="h-full bg-primary shadow-[0_0_8px_rgba(124,156,132,0.4)]" 
                                style={{ width: `${(v.used / v.total) * 100}%` }}
                              />
                           </div>
                        </div>
                     </div>
                  </div>
                ))}
             </div>
          </div>
        )}
      </div>

      {/* Add XP or Badge Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
          <div className="card w-full max-w-lg animate-in zoom-in-95 duration-200">
             <div className="flex justify-between items-center mb-6">
                <h3 className="font-display font-bold text-xl text-charcoal">
                    Add New {isModalOpen === 'xp' ? 'XP Acquisition Rule' : 'Achievement Badge'}
                </h3>
                <button onClick={() => setIsModalOpen(false)} className="p-2 hover:bg-cream rounded-full transition"><X size={20}/></button>
             </div>

             <form onSubmit={isModalOpen === 'xp' ? handleCreateXP : handleCreateBadge} className="space-y-5">
                {isModalOpen === 'xp' ? (
                  <>
                    <div className="space-y-1.5">
                      <label className="section-label">Acquisition Trigger</label>
                      <input 
                        className="w-full bg-cream/50 border border-cream-darker px-4 py-3 rounded-2xl font-body font-bold outline-none" 
                        value={xpForm.action} 
                        onChange={e => setXpForm({...xpForm, action: e.target.value})} 
                        placeholder="e.g. Complete Meditation"
                        required
                      />
                    </div>
                    <div className="grid grid-cols-2 gap-4">
                      <div className="space-y-1.5">
                        <label className="section-label">XP Award</label>
                        <input 
                          type="number"
                          className="w-full bg-cream/50 border border-cream-darker px-4 py-3 rounded-2xl font-bold outline-none" 
                          value={xpForm.xp} 
                          onChange={e => setXpForm({...xpForm, xp: parseInt(e.target.value)})} 
                        />
                      </div>
                      <div className="space-y-1.5">
                        <label className="section-label">Icon Identifier</label>
                        <select 
                          className="w-full bg-cream/50 border border-cream-darker px-4 py-3 rounded-2xl font-bold outline-none"
                          value={xpForm.icon}
                          onChange={e => setXpForm({...xpForm, icon: e.target.value})}
                        >
                          {Object.keys(iconMap).map(k => <option key={k} value={k}>{k}</option>)}
                        </select>
                      </div>
                    </div>
                  </>
                ) : (
                  <>
                    <div className="space-y-1.5">
                       <label className="section-label">Milestone Identifier</label>
                       <input 
                         className="w-full bg-cream/50 border border-cream-darker px-4 py-3 rounded-2xl font-body font-bold outline-none" 
                         value={badgeForm.name} 
                         onChange={e => setBadgeForm({...badgeForm, name: e.target.value})} 
                         placeholder="e.g. Wellness Sage"
                         required
                       />
                    </div>
                    <div className="space-y-1.5">
                       <label className="section-label">Inspirational Motto</label>
                       <input 
                         className="w-full bg-cream/50 border border-cream-darker px-4 py-3 rounded-2xl font-body outline-none" 
                         value={badgeForm.desc} 
                         onChange={e => setBadgeForm({...badgeForm, desc: e.target.value})} 
                         placeholder="A brief descriptive phrase"
                       />
                    </div>
                    <div className="grid grid-cols-2 gap-4">
                      <div className="space-y-1.5">
                        <label className="section-label">XP Threshold</label>
                        <input 
                          type="number"
                          className="w-full bg-cream/50 border border-cream-darker px-4 py-3 rounded-2xl font-bold outline-none" 
                          value={badgeForm.xp} 
                          onChange={e => setBadgeForm({...badgeForm, xp: parseInt(e.target.value)})} 
                        />
                      </div>
                      <div className="space-y-1.5">
                        <label className="section-label">Emoji Representation</label>
                        <input 
                          className="w-full bg-cream/50 border border-cream-darker px-4 py-3 rounded-2xl font-bold outline-none text-center text-xl" 
                          value={badgeForm.icon} 
                          onChange={e => setBadgeForm({...badgeForm, icon: e.target.value})} 
                          placeholder="🌱"
                        />
                      </div>
                    </div>
                  </>
                )}
                <button 
                  disabled={processing}
                  className="w-full py-4 bg-primary text-white rounded-2xl font-bold shadow-lg shadow-primary/20 hover:bg-primary-dark transition-all disabled:opacity-50"
                >
                  {processing ? <Loader2 size={18} className="animate-spin mx-auto"/> : `Deploy ${isModalOpen === 'xp' ? 'Rule' : 'Badge'}`}
                </button>
             </form>
          </div>
        </div>
      )}

      {/* Voucher Modal */}
      {isVoucherOpen && (
        <div className="fixed inset-0 z-[100] flex justify-end bg-black/40 backdrop-blur-sm">
          <div className="w-full max-w-md bg-white h-full shadow-2xl animate-in slide-in-from-right duration-300 flex flex-col">
            <div className="p-6 border-b border-cream-darker flex items-center justify-between">
              <div>
                <p className="section-label mb-1">Treasury</p>
                <h3 className="font-display font-semibold text-xl">New Reward Item</h3>
              </div>
              <button 
                onClick={() => setIsVoucherOpen(false)}
                className="p-2 hover:bg-cream rounded-full transition text-charcoal-muted"
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleCreateVoucher} className="flex-1 overflow-y-auto p-8 space-y-6">
              <div className="space-y-2">
                <label className="section-label flex items-center gap-1.5">Redemption Code</label>
                <input 
                  className="w-full bg-cream border border-cream-darker px-4 py-3 rounded-2xl font-mono font-black text-primary focus:border-primary outline-none uppercase" 
                  value={voucherForm.code} 
                  onChange={e => setVoucherForm({...voucherForm, code: e.target.value.toUpperCase()})} 
                  placeholder="EUNOI25"
                  required
                />
              </div>

              <div className="space-y-2">
                <label className="section-label">Benefit Details</label>
                <input 
                  className="w-full bg-cream border border-cream-darker px-4 py-3 rounded-2xl font-display font-bold text-charcoal focus:border-primary outline-none" 
                  value={voucherForm.discount} 
                  onChange={e => setVoucherForm({...voucherForm, discount: e.target.value})} 
                  placeholder="e.g. 25% Wellness Pack"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <label className="section-label">Total Supply</label>
                  <input 
                    type="number"
                    className="w-full bg-cream border border-cream-darker px-4 py-3 rounded-2xl font-bold outline-none" 
                    value={voucherForm.total} 
                    onChange={e => setVoucherForm({...voucherForm, total: parseInt(e.target.value)})} 
                  />
                </div>
                <div className="space-y-2">
                  <label className="section-label">Expiry Date</label>
                  <input 
                    type="date"
                    className="w-full bg-cream border border-cream-darker px-4 py-3 rounded-2xl font-bold outline-none" 
                    value={voucherForm.expires} 
                    onChange={e => setVoucherForm({...voucherForm, expires: e.target.value})} 
                  />
                </div>
              </div>
            </form>

            <div className="p-8 border-t border-cream-darker">
               <button 
                 onClick={handleCreateVoucher}
                 disabled={processing}
                 className="w-full py-4 bg-primary text-white rounded-2xl font-bold flex items-center justify-center gap-2 shadow-lg shadow-primary/20 hover:bg-primary-dark transition-all disabled:opacity-50"
               >
                 {processing ? <Loader2 size={18} className="animate-spin" /> : <><Send size={18} /> Deploy Reward</>}
               </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
