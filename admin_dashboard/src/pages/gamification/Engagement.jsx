import { useState } from 'react';
import { 
  Zap, Award, Gift, Plus, Trash2, Pencil, X, Send, Ticket, 
  Settings, TrendingUp, Star, Music, BookOpen, 
  MessageSquare, Edit3, Loader2, Sparkles, ChevronRight
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
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
  success: '#10B981',
  amber: '#d97706'
};

const cardStyle = { background: 'white', borderRadius: '20px', boxShadow: '0 2px 16px rgba(0,0,0,0.06)', padding: '24px' };
const sLabel = { fontFamily: 'Outfit', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.08em', color: C.muted };
const badge = (type) => ({ display: 'inline-flex', padding: '3px 10px', borderRadius: '999px', fontSize: '11px', fontWeight: 700, fontFamily: 'Outfit', background: type === 'green' ? C.sage100 : '#fffbeb', color: type === 'green' ? C.primary : '#d97706' });

const INITIAL_BADGES = [
  { name: 'Beginner Meditator', xp: 100, icon: '🌱', desc: 'Starting the journey' },
  { name: 'Mindful Week', xp: 250, icon: '🍃', desc: 'A week of presence' },
  { name: 'Streak Master', xp: 500, icon: '🔥', desc: 'Consistent practice' },
  { name: 'Wellness Sage', xp: 1000, icon: '🧘', desc: 'Deep mental clarity' },
  { name: 'Eunoia Champion', xp: 2000, icon: '🏆', desc: 'Master of self' },
];

const INITIAL_XP_ACTIONS = [
  { action: 'Complete Meditation', xp: 20, icon: 'Music' },
  { action: 'Write Diary Entry', xp: 15, icon: 'Edit3' },
  { action: 'Read Article', xp: 10, icon: 'BookOpen' },
  { action: 'Daily Login', xp: 5, icon: 'Zap' },
  { action: 'AI Chat Session', xp: 25, icon: 'MessageSquare' },
];

export default function Engagement() {
  const [activeTab, setActiveTab] = useState('xp'); 
  const { data: vouchers, loading: vLoading } = useVouchers();
  const { data: xpRules, loading: xLoading } = useXPRules();
  const { data: badges, loading: bLoading } = useBadges();
  
  const [processing, setProcessing] = useState(null);
  const [isModalOpen, setIsModalOpen] = useState(false); // Reuse for XP/Badge addition
  const [isVoucherOpen, setIsVoucherOpen] = useState(false);
  const [editingItem, setEditingItem] = useState(null); // { type: 'xp'|'badge'|'voucher', data: {} }
  const [xpForm, setXpForm] = useState({ action: '', xp: 10, icon: 'Zap' });
  const [badgeForm, setBadgeForm] = useState({ name: '', xp: 500, icon: '🌱', desc: '' });
  const [voucherForm, setVoucherForm] = useState({
    code: '', discount: '', total: 50, used: 0, expires: '', status: 'Active'
  });

  const iconMap = { Zap, Music, BookOpen, MessageSquare, Edit3, Star, Award, TrendingUp };

  // Pagination for Rewards
  const [rewardPage, setRewardPage] = useState(1);
  const rewardsPerPage = 6;
  const paginatedVouchers = (vouchers || []).slice((rewardPage - 1) * rewardsPerPage, rewardPage * rewardsPerPage);
  const totalRewardPages = Math.ceil((vouchers || []).length / rewardsPerPage);

  // Pagination for Badges
  const [badgePage, setBadgePage] = useState(1);
  const badgesPerPage = 6;
  const paginatedBadges = (badges || []).slice((badgePage - 1) * badgesPerPage, badgePage * badgesPerPage);
  const totalBadgePages = Math.ceil((badges || []).length / badgesPerPage);

  const handleCreateXP = async (e) => {
    e.preventDefault();
    setProcessing('xp-add');
    try {
      if (editingItem) {
        await updateDoc(doc(db, 'xp_rules', editingItem.id), { ...xpForm, updatedAt: serverTimestamp() });
      } else {
        await addDoc(collection(db, 'xp_rules'), { ...xpForm, createdAt: serverTimestamp() });
      }
      setIsModalOpen(false);
      setEditingItem(null);
    } catch (e) { console.error(e); } finally { setProcessing(null); }
  };

  const handleCreateBadge = async (e) => {
    e.preventDefault();
    setProcessing('badge-add');
    try {
      if (editingItem) {
        await updateDoc(doc(db, 'badges', editingItem.id), { ...badgeForm, updatedAt: serverTimestamp() });
      } else {
        await addDoc(collection(db, 'badges'), { ...badgeForm, createdAt: serverTimestamp() });
      }
      setIsModalOpen(false);
      setEditingItem(null);
    } catch (e) { console.error(e); } finally { setProcessing(null); }
  };

  const handleCreateVoucher = async (e) => {
    e.preventDefault();
    setProcessing('v-add');
    try {
      if (editingItem) {
        await updateDoc(doc(db, 'vouchers', editingItem.id), { ...voucherForm, updatedAt: serverTimestamp() });
      } else {
        await addDoc(collection(db, 'vouchers'), { ...voucherForm, createdAt: serverTimestamp() });
      }
      setIsVoucherOpen(false);
      setEditingItem(null);
    } catch (e) { console.error(e); } finally { setProcessing(null); }
  };

  const openEdit = (type, item) => {
    setEditingItem(item);
    if (type === 'xp') {
      setXpForm({ action: item.action, xp: item.xp, icon: item.icon });
      setIsModalOpen('xp');
    } else if (type === 'badge') {
      setBadgeForm({ name: item.name, xp: item.xp, icon: item.icon, desc: item.desc });
      setIsModalOpen('badge');
    } else if (type === 'voucher') {
      setVoucherForm({ code: item.code, discount: item.discount, total: item.total, used: item.used, expires: item.expires, status: item.status });
      setIsModalOpen('reward');
    }
  };

  const handleDelete = async (coll, id) => {
    if (processing) return;
    const isConfirmed = window.confirm("Are you sure you want to permanently delete this item? This action cannot be undone.");
    if (!isConfirmed) return;

    setProcessing(`del-${id}`);
    try {
      await deleteDoc(doc(db, coll, id));
    } catch (e) { console.error(e); } finally { setProcessing(null); }
  };

  const handleSeedData = async () => {
    if (!window.confirm('Populate with standard gamification rules?')) return;
    setProcessing('seed');
    try {
      if (!xpRules || xpRules.length === 0) {
        for (const rule of INITIAL_XP_ACTIONS) {
          await addDoc(collection(db, 'xp_rules'), { ...rule, createdAt: serverTimestamp() });
        }
      }
      if (!badges || badges.length === 0) {
        for (const badge of INITIAL_BADGES) {
          await addDoc(collection(db, 'badges'), { ...badge, createdAt: serverTimestamp() });
        }
      }
    } catch (e) { console.error(e); } finally { setProcessing(null); }
  };

    return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '20px', position: 'relative' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div>
              <span style={sLabel}>Gamification Center</span>
              <h2 style={{ fontFamily: '"Playfair Display", serif', fontWeight: 600, fontSize: '24px', color: C.charcoal, margin: 0 }}>Gamification Management</h2>
            </div>
    
            <div style={{ display: 'flex', gap: '8px', background: C.cream, padding: '4px', borderRadius: '14px', border: `1px solid ${C.creamDarker}` }}>
              {[
                { id: 'xp', label: 'XP Rules' },
                { id: 'badges', label: 'Badges' },
                { id: 'rewards', label: 'Rewards' }
              ].map(tab => (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  style={{
                    padding: '8px 16px',
                    borderRadius: '10px',
                    border: 'none',
                    fontFamily: 'Outfit',
                    fontWeight: 600,
                    fontSize: '13px',
                    cursor: 'pointer',
                    transition: 'all 0.2s',
                    background: activeTab === tab.id ? C.primary : 'transparent',
                    color: activeTab === tab.id ? 'white' : C.charcoalMuted,
                    boxShadow: activeTab === tab.id ? '0 4px 12px rgba(124, 156, 132, 0.2)' : 'none'
                  }}
                >
                  {tab.label}
                </button>
              ))}
            </div>
          </div>

      <div className="min-h-[600px]">
        <AnimatePresence mode="wait">
          {activeTab === 'xp' && (
            <motion.div 
              key="xp"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              style={cardStyle}
            >
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '24px' }}>
                    <div>
                        <h3 style={{ fontFamily: '"Playfair Display", serif', fontSize: '18px', fontWeight: 600, color: C.charcoal, margin: 0 }}>XP Award Rules</h3>
                        <p style={{ fontSize: '12px', color: C.muted, fontFamily: 'Outfit', marginTop: '4px' }}>Ways for users to earn experience points</p>
                    </div>
                    <button 
                        onClick={() => { setEditingItem(null); setXpForm({ action: '', xp: 10, icon: 'Zap' }); setIsModalOpen('xp'); }}
                        style={{ display: 'flex', alignItems: 'center', gap: '6px', background: C.primary, color: 'white', border: 'none', borderRadius: '12px', padding: '10px 20px', fontFamily: 'Outfit', fontWeight: 600, fontSize: '13px', cursor: 'pointer', transition: 'all 0.2s', boxShadow: '0 4px 12px rgba(124, 156, 132, 0.15)' }}
                        onMouseOver={e => e.currentTarget.style.background = C.primaryDark}
                        onMouseOut={e => e.currentTarget.style.background = C.primary}
                    >
                        <Plus size={14} /> New XP Rule
                    </button>
                </div>

                <div style={{ overflowX: 'auto' }}>
                    <table style={{ width: '100%', borderCollapse: 'collapse', fontFamily: 'Outfit', fontSize: '13px' }}>
                        <thead>
                            <tr style={{ borderBottom: `1px solid ${C.creamDarker}`, textAlign: 'left' }}>
                                {['Event Action', 'XP Reward', 'Actions'].map(h => (
                                    <th key={h} style={{ padding: '0 0 12px 0', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.08em', color: C.muted }}>{h}</th>
                                ))}
                            </tr>
                        </thead>
                        <tbody>
                            {(xpRules || []).map((action, idx) => {
                                const IconComp = iconMap[action.icon] || Zap;
                                return (
                                    <tr key={action.id} style={{ borderBottom: idx === (xpRules || []).length - 1 ? 'none' : `1px solid ${C.creamDarker}`, transition: 'background 0.2s' }}>
                                        <td style={{ padding: '20px 0' }}>
                                            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                                                <div style={{ width: '40px', height: '40px', background: C.sage100, borderRadius: '12px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: C.primary }}>
                                                    <IconComp size={18} strokeWidth={1.5} />
                                                </div>
                                                <span style={{ fontWeight: 600, fontSize: '14px', color: C.charcoal }}>{action.action}</span>
                                            </div>
                                        </td>
                                        <td style={{ padding: '20px 0' }}>
                                            <div style={{ 
                                                display: 'flex', 
                                                alignItems: 'center', 
                                                justifyContent: 'center',
                                                background: C.sage100, 
                                                border: `1px solid ${C.creamDarker}`, 
                                                borderRadius: '10px', 
                                                width: '56px',
                                                height: '32px'
                                            }}>
                                              <span style={{ fontSize: '14px', fontWeight: 800, color: C.primary, fontFamily: 'Outfit' }}>{action.xp}</span>
                                            </div>
                                        </td>
                                        <td style={{ padding: '20px 0' }}>
                                            <div style={{ display: 'flex', gap: '4px' }}>
                                              <button 
                                                  onClick={() => openEdit('xp', action)}
                                                  style={{ padding: '8px', border: 'none', background: 'transparent', color: C.muted, cursor: 'pointer', transition: 'color 0.2s' }}
                                                  onMouseOver={e => e.currentTarget.style.color = C.charcoal}
                                                  onMouseOut={e => e.currentTarget.style.color = C.muted}
                                              >
                                                  <Pencil size={14} />
                                              </button>
                                              <button 
                                                  onClick={() => handleDelete('xp_rules', action.id)}
                                                  style={{ padding: '8px', border: 'none', background: 'transparent', color: '#fca5a5', cursor: 'pointer', transition: 'color 0.2s' }}
                                                  onMouseOver={e => e.currentTarget.style.color = C.error}
                                                  onMouseOut={e => e.currentTarget.style.color = '#fca5a5'}
                                              >
                                                  <Trash2 size={14} />
                                              </button>
                                            </div>
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>

                {(xpRules || []).length === 0 && !xLoading && (
                  <div style={{ py: '40px', textAlign: 'center', border: `2px dashed ${C.creamDarker}`, borderRadius: '20px', padding: '40px' }}>
                     <p style={{ fontSize: '14px', fontFamily: 'Outfit', color: C.muted, fontStyle: 'italic', marginBottom: '20px' }}>No active protocols detected.</p>
                     <button onClick={handleSeedData} style={{ padding: '10px 20px', background: 'white', border: `1px solid ${C.primary}`, color: C.primary, borderRadius: '12px', fontWeight: 600, fontSize: '12px', cursor: 'pointer' }}>Initialize Defaults</button>
                  </div>
                )}
            </motion.div>
          )}

          {activeTab === 'badges' && (
            <motion.div 
              key="badges"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              style={cardStyle}
            >
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '32px' }}>
                    <div>
                        <h3 style={{ fontFamily: '"Playfair Display", serif', fontSize: '18px', fontWeight: 600, color: C.charcoal, margin: 0 }}>Badges Milestones</h3>
                        <p style={{ fontSize: '12px', color: C.muted, fontFamily: 'Outfit', marginTop: '4px' }}>Achievement tiers for user milestones</p>
                    </div>
                    <button 
                        onClick={() => { setEditingItem(null); setBadgeForm({ name: '', xp: 500, icon: '🌱', desc: '' }); setIsModalOpen('badge'); }}
                        style={{ display: 'flex', alignItems: 'center', gap: '6px', background: C.primary, color: 'white', border: 'none', borderRadius: '12px', padding: '10px 20px', fontFamily: 'Outfit', fontWeight: 600, fontSize: '13px', cursor: 'pointer', transition: 'all 0.2s', boxShadow: '0 4px 12px rgba(124, 156, 132, 0.15)' }}
                        onMouseOver={e => e.currentTarget.style.background = C.primaryDark}
                        onMouseOut={e => e.currentTarget.style.background = C.primary}
                    >
                        <Plus size={14} /> New Badge
                    </button>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: '24px' }}>
                    {paginatedBadges.map((badgeItem) => (
                        <div key={badgeItem.id} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '32px 24px', background: 'white', borderRadius: '24px', border: `1px solid ${C.creamDarker}`, position: 'relative', boxShadow: '0 4px 20px rgba(0,0,0,0.03)', transition: 'transform 0.2s' }}
                          onMouseOver={e => e.currentTarget.style.transform = 'translateY(-4px)'}
                          onMouseOut={e => e.currentTarget.style.transform = 'translateY(0)'}
                        >
                            <div style={{ width: '64px', height: '64px', background: C.cream, borderRadius: '20px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '32px', marginBottom: '16px', boxShadow: 'inset 0 2px 8px rgba(0,0,0,0.05)' }}>
                              {badgeItem.icon}
                            </div>
                            <h4 style={{ margin: 0, fontSize: '16px', fontWeight: 700, color: C.charcoal, textAlign: 'center' }}>{badgeItem.name}</h4>
                            <p style={{ margin: '8px 0 20px 0', fontSize: '12px', color: C.muted, textAlign: 'center', lineHeight: 1.5, minHeight: '36px' }}>{badgeItem.desc}</p>
                            
                            <div style={{ display: 'flex', alignItems: 'center', gap: '10px', padding: '16px 0 0 0', borderTop: `1px solid ${C.creamDarker}`, width: '100%', justifyContent: 'center', marginTop: 'auto' }}>
                              <div style={{ background: C.sage100, border: `1px solid ${C.creamDarker}`, borderRadius: '8px', padding: '4px 10px', minWidth: '36px', display: 'flex', justifyContent: 'center' }}>
                                <span style={{ fontSize: '13px', fontWeight: 800, color: C.primary, fontFamily: 'Outfit' }}>{badgeItem.xp}</span>
                              </div>
                              <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.04em', color: C.muted }}>XP Required</span>
                            </div>
                            
                            <div style={{ position: 'absolute', top: '16px', right: '16px', display: 'flex', gap: '4px' }}>
                                <button 
                                    onClick={() => openEdit('badge', badgeItem)}
                                    style={{ padding: '6px', border: 'none', background: 'transparent', color: C.muted, cursor: 'pointer', transition: 'color 0.2s' }}
                                    onMouseOver={e => e.currentTarget.style.color = C.charcoal}
                                    onMouseOut={e => e.currentTarget.style.color = C.muted}
                                >
                                    <Pencil size={14} />
                                </button>
                                <button 
                                    onClick={() => handleDelete('badges', badgeItem.id)}
                                    style={{ padding: '6px', border: 'none', background: 'transparent', color: '#fca5a5', cursor: 'pointer', transition: 'color 0.2s' }}
                                    onMouseOver={e => e.currentTarget.style.color = C.error}
                                    onMouseOut={e => e.currentTarget.style.color = '#fca5a5'}
                                >
                                    <Trash2 size={14} />
                                </button>
                            </div>
                        </div>
                    ))}
                </div>

                {(!badges || badges.length === 0) && !bLoading && (
                  <div style={{ py: '40px', textAlign: 'center', border: `2px dashed ${C.creamDarker}`, borderRadius: '24px', padding: '48px', marginTop: '24px' }}>
                     <p style={{ fontSize: '14px', color: C.muted, fontStyle: 'italic', marginBottom: '20px' }}>No milestones have been mapped yet.</p>
                     <button onClick={handleSeedData} style={{ padding: '12px 24px', background: 'white', border: `1px solid ${C.primary}`, color: C.primary, borderRadius: '14px', fontWeight: 600, fontSize: '13px', cursor: 'pointer', transition: 'all 0.2s' }}
                       onMouseOver={e => { e.currentTarget.style.background = C.primary; e.currentTarget.style.color = 'white'; }}
                       onMouseOut={e => { e.currentTarget.style.background = 'white'; e.currentTarget.style.color = C.primary; }}
                     >
                       Initialize Milestone Path
                     </button>
                  </div>
                )}

                {(badges || []).length > 0 && (
                  <div style={{ marginTop: '32px', pt: '24px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderTop: `1px solid ${C.creamDarker}`, paddingTop: '24px' }}>
                      <p style={{ margin: 0, fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.muted }}>
                        Showing {paginatedBadges.length} of {badges.length} milestone assets
                      </p>
                      <div style={{ display: 'flex', gap: '8px' }}>
                          <button 
                            disabled={badgePage === 1} 
                            onClick={() => setBadgePage(p => p - 1)} 
                            style={{ padding: '8px 16px', background: 'white', border: `1px solid ${C.creamDarker}`, borderRadius: '10px', fontSize: '12px', color: C.charcoal, fontWeight: 600, cursor: badgePage === 1 ? 'not-allowed' : 'pointer', opacity: badgePage === 1 ? 0.3 : 1, transition: 'all 0.2s' }}
                          >Prev</button>
                          <button 
                            disabled={badgePage >= totalBadgePages} 
                            onClick={() => setBadgePage(p => p + 1)} 
                            style={{ padding: '8px 16px', background: 'white', border: `1px solid ${C.creamDarker}`, borderRadius: '10px', fontSize: '12px', color: C.charcoal, fontWeight: 600, cursor: badgePage >= totalBadgePages ? 'not-allowed' : 'pointer', opacity: badgePage >= totalBadgePages ? 0.3 : 1, transition: 'all 0.2s' }}
                          >Next</button>
                      </div>
                  </div>
                )}
            </motion.div>
          )}

          {activeTab === 'rewards' && (
            <motion.div 
               key="rewards"
               initial={{ opacity: 0, y: 10 }}
               animate={{ opacity: 1, y: 0 }}
               exit={{ opacity: 0, y: -10 }}
               style={cardStyle}
            >
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
                    <div>
                        <h3 style={{ fontFamily: '"Playfair Display", serif', fontSize: '18px', fontWeight: 600, color: C.charcoal, margin: 0 }}>Treasury Rewards</h3>
                        <p style={{ fontSize: '12px', color: C.muted, fontFamily: 'Outfit', marginTop: '4px' }}>Discount items for user discovery</p>
                    </div>
                    <button 
                        onClick={() => { setEditingItem(null); setVoucherForm({ code: '', discount: '', total: 50, used: 0, expires: '', status: 'Active' }); setIsModalOpen('reward'); }}
                        style={{ display: 'flex', alignItems: 'center', gap: '6px', background: C.primary, color: 'white', border: 'none', borderRadius: '12px', padding: '10px 20px', fontFamily: 'Outfit', fontWeight: 600, fontSize: '13px', cursor: 'pointer', transition: 'all 0.2s', boxShadow: '0 4px 12px rgba(124, 156, 132, 0.15)' }}
                        onMouseOver={e => e.currentTarget.style.background = C.primaryDark}
                        onMouseOut={e => e.currentTarget.style.background = C.primary}
                    >
                        <Plus size={14} /> New Reward
                    </button>
                </div>



               <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))', gap: '24px' }}>
                    {paginatedVouchers.map((v) => (
                        <div key={v.id} style={{ padding: '32px 24px', background: 'white', border: `1px solid ${C.creamDarker}`, borderRadius: '24px', position: 'relative', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px', boxShadow: '0 4px 20px rgba(0,0,0,0.03)', transition: 'transform 0.2s' }}
                          onMouseOver={e => e.currentTarget.style.transform = 'translateY(-4px)'}
                          onMouseOut={e => e.currentTarget.style.transform = 'translateY(0)'}
                        >
                            <div style={{ width: '56px', height: '56px', background: C.sage100, borderRadius: '16px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: C.primary, marginBottom: '8px' }}>
                              <Ticket size={28} />
                            </div>
                            
                            <div style={{ position: 'absolute', top: '16px', right: '16px', display: 'flex', gap: '4px' }}>
                                <button onClick={() => openEdit('voucher', v)} style={{ padding: '6px', border: 'none', background: 'transparent', color: C.muted, cursor: 'pointer', transition: 'color 0.2s' }} onMouseOver={e => e.currentTarget.style.color = C.charcoal} onMouseOut={e => e.currentTarget.style.color = C.muted}><Pencil size={14}/></button>
                                <button onClick={() => handleDelete('vouchers', v.id)} style={{ padding: '6px', border: 'none', background: 'transparent', color: '#fca5a5', cursor: 'pointer', transition: 'color 0.2s' }} onMouseOver={e => e.currentTarget.style.color = C.error} onMouseOut={e => e.currentTarget.style.color = '#fca5a5'}><Trash2 size={14}/></button>
                            </div>

                            <h4 style={{ margin: '8px 0 0 0', fontSize: '20px', fontWeight: 800, color: C.charcoal, textAlign: 'center' }}>{v.discount}</h4>
                            <span style={{ fontFamily: 'monospace', fontWeight: 700, fontSize: '11px', letterSpacing: '0.1em', background: C.cream, padding: '4px 10px', borderRadius: '6px', color: C.primary, marginTop: '4px' }}>{v.code}</span>
                            
                            <div style={{ width: '100%', marginTop: '20px' }}>
                                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
                                    <span style={{ fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', color: C.muted, letterSpacing: '0.02em' }}>Redemption Progress</span>
                                    <span style={{ fontSize: '11px', fontWeight: 700, color: C.charcoal }}>{v.used} / {v.total}</span>
                                </div>
                                <div style={{ width: '100%', height: '8px', background: C.cream, borderRadius: '4px', overflow: 'hidden', border: `1px solid ${C.creamDarker}` }}>
                                    <div style={{ height: '100%', background: C.primary, width: `${(v.used / v.total) * 100}%`, transition: 'width 1s cubic-bezier(0.4, 0, 0.2, 1)' }} />
                                </div>
                            </div>

                            <div style={{ marginTop: '16px', padding: '6px 12px', background: v.status === 'Active' ? C.sage100 : C.cream, borderRadius: '89px', border: `1px solid ${v.status === 'Active' ? C.primary + '22' : C.creamDarker}` }}>
                              <span style={{ fontSize: '10px', fontWeight: 800, textTransform: 'uppercase', color: v.status === 'Active' ? C.primary : C.muted }}>{v.status}</span>
                            </div>
                        </div>
                    ))}
               </div>

                {(!vouchers || vouchers.length === 0) && !vLoading && (
                  <div style={{ py: '40px', textAlign: 'center', border: `2px dashed ${C.creamDarker}`, borderRadius: '24px', padding: '48px', marginTop: '24px' }}>
                     <p style={{ fontSize: '14px', color: C.muted, fontStyle: 'italic', margin: 0 }}>No rewards or vouchers have been added to the treasury yet.</p>
                  </div>
                )}

                <div style={{ marginTop: '32px', pt: '24px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderTop: `1px solid ${C.creamDarker}`, paddingTop: '24px' }}>
                    <p style={{ margin: 0, fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.muted }}>
                      Showing {paginatedVouchers.length} of {vouchers.length} reward assets
                    </p>
                    <div style={{ display: 'flex', gap: '8px' }}>
                        <button 
                          disabled={rewardPage === 1} 
                          onClick={() => setRewardPage(p => p - 1)} 
                          style={{ padding: '8px 16px', background: 'white', border: `1px solid ${C.creamDarker}`, borderRadius: '10px', fontSize: '12px', color: C.charcoal, fontWeight: 600, cursor: rewardPage === 1 ? 'not-allowed' : 'pointer', opacity: rewardPage === 1 ? 0.3 : 1, transition: 'all 0.2s' }}
                        >Prev</button>
                        <button 
                          disabled={rewardPage >= totalRewardPages} 
                          onClick={() => setRewardPage(p => p + 1)} 
                          style={{ padding: '8px 16px', background: 'white', border: `1px solid ${C.creamDarker}`, borderRadius: '10px', fontSize: '12px', color: C.charcoal, fontWeight: 600, cursor: rewardPage >= totalRewardPages ? 'not-allowed' : 'pointer', opacity: rewardPage >= totalRewardPages ? 0.3 : 1, transition: 'all 0.2s' }}
                        >Next</button>
                    </div>
                </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>

      <AnimatePresence>
        {isModalOpen && (
          <div 
            style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)', backdropFilter: 'blur(8px)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px' }}
            onClick={() => setIsModalOpen(false)}
          >
            <motion.div 
               initial={{ scale: 0.9, opacity: 0 }}
               animate={{ scale: 1, opacity: 1 }}
               exit={{ scale: 0.9, opacity: 0 }}
               style={{ width: '100%', maxWidth: '500px', background: 'white', borderRadius: '32px', overflow: 'hidden', display: 'flex', flexDirection: 'column', boxShadow: '0 30px 60px rgba(0,0,0,0.15)' }}
               onClick={e => e.stopPropagation()}
            >
               <div style={{ padding: '32px', borderBottom: `1px solid ${C.creamDarker}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div>
                    <span style={sLabel}>Configuration</span>
                    <h3 style={{ margin: '4px 0 0 0', fontFamily: 'Playfair Display', fontSize: '24px', fontWeight: 600 }}>
                      {editingItem ? 'Edit' : 'New'} {isModalOpen === 'xp' ? 'XP Rule' : isModalOpen === 'badge' ? 'Badge' : 'Reward'}
                    </h3>
                  </div>
                  <button onClick={() => setIsModalOpen(false)} style={{ padding: '8px', background: C.cream, border: 'none', borderRadius: '50%', cursor: 'pointer' }}><X size={20}/></button>
               </div>

               <form onSubmit={isModalOpen === 'xp' ? handleCreateXP : handleCreateBadge} style={{ padding: '32px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
                  <style>
                    {`
                    .form-label { display: block; font-family: 'Outfit'; font-size: 11px; font-weight: 700; text-transform: uppercase; color: ${C.muted}; margin-bottom: 8px; }
                    .form-input { width: 100%; background: ${C.cream}; border: 1px solid ${C.creamDarker}; border-radius: 12px; padding: 12px 14px; font-family: 'Outfit'; font-size: 14px; outline: none; box-sizing: border-box; }
                    .form-input:focus { border-color: ${C.primary}; }
                    `}
                  </style>

                  {isModalOpen === 'xp' ? (
                    <>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 120px', gap: '16px' }}>
                        <div>
                          <label className="form-label">Action for Gain XP</label>
                          <input className="form-input" value={xpForm.action} onChange={e => setXpForm({...xpForm, action: e.target.value})} placeholder="e.g. Complete Meditation" required />
                        </div>
                        <div>
                          <label className="form-label">Gained XP</label>
                          <input type="number" className="form-input" value={xpForm.xp} onChange={e => setXpForm({...xpForm, xp: parseInt(e.target.value)})} />
                        </div>
                      </div>
                      <div>
                        <label className="form-label">XP Icon</label>
                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px', background: C.cream, padding: '16px', borderRadius: '16px', border: `1px solid ${C.creamDarker}` }}>
                          {Object.entries(iconMap).map(([name, Icon]) => (
                            <button
                              key={name}
                              type="button"
                              onClick={() => setXpForm({...xpForm, icon: name})}
                              style={{
                                width: '42px',
                                height: '42px',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                borderRadius: '12px',
                                border: 'none',
                                cursor: 'pointer',
                                background: xpForm.icon === name ? C.primary : 'white',
                                color: xpForm.icon === name ? 'white' : C.charcoalMuted,
                                boxShadow: xpForm.icon === name ? '0 4px 12px rgba(124, 156, 132, 0.3)' : '0 2px 4px rgba(0,0,0,0.02)',
                                transition: 'all 0.2s'
                              }}
                            >
                              <Icon size={20} strokeWidth={2} />
                            </button>
                          ))}
                        </div>
                      </div>
                    </>
                  ) : isModalOpen === 'badge' ? (
                    <>
                      <div>
                         <label className="form-label">Badge Name</label>
                         <input className="form-input" value={badgeForm.name} onChange={e => setBadgeForm({...badgeForm, name: e.target.value})} placeholder="e.g. Wellness Sage" required />
                      </div>
                      <div>
                         <label className="form-label">Short Description</label>
                         <input className="form-input" value={badgeForm.desc} onChange={e => setBadgeForm({...badgeForm, desc: e.target.value})} placeholder="A brief descriptive phrase" />
                      </div>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                        <div>
                          <label className="form-label">Required XP</label>
                          <input type="number" className="form-input" value={badgeForm.xp} onChange={e => setBadgeForm({...badgeForm, xp: parseInt(e.target.value)})} />
                        </div>
                        <div>
                          <label className="form-label">Emoji Icon</label>
                          <input className="form-input" style={{ textAlign: 'center', fontSize: '20px' }} value={badgeForm.icon} onChange={e => setBadgeForm({...badgeForm, icon: e.target.value})} />
                        </div>
                      </div>
                    </>
                  ) : ( // This 'else' branch will now be for 'reward'
                    <>
                      <div>
                        <label className="form-label">Redemption Code</label>
                        <input className="form-input" style={{ fontFamily: 'monospace', fontWeight: 700, fontSize: '18px' }} value={voucherForm.code} onChange={e => setVoucherForm({...voucherForm, code: e.target.value.toUpperCase()})} placeholder="EUNOI25" required />
                      </div>
                      <div>
                        <label className="form-label">Benefit Details</label>
                        <input className="form-input" value={voucherForm.discount} onChange={e => setVoucherForm({...voucherForm, discount: e.target.value})} placeholder="e.g. 25% Wellness Pack" required />
                      </div>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                        <div>
                          <label className="form-label">Total Supply</label>
                          <input type="number" className="form-input" value={voucherForm.total} onChange={e => setVoucherForm({...voucherForm, total: parseInt(e.target.value)})} />
                        </div>
                        <div>
                          <label className="form-label">Expiry Date</label>
                          <input type="date" className="form-input" value={voucherForm.expires} onChange={e => setVoucherForm({...voucherForm, expires: e.target.value})} />
                        </div>
                      </div>
                    </>
                  )}
                  <button 
                    disabled={processing}
                    style={{ marginTop: '12px', padding: '14px', background: C.primary, color: 'white', border: 'none', borderRadius: '14px', fontWeight: 600, cursor: 'pointer', transition: 'background 0.2s' }}
                  >
                    {processing ? <Loader2 size={18} className="animate-spin" style={{ margin: '0 auto' }}/> : `Save ${isModalOpen === 'xp' ? 'XP Rule' : isModalOpen === 'badge' ? 'Badge' : 'Reward'}`}
                  </button>
               </form>
            </motion.div>
          </div>
        )}
      </AnimatePresence>
    </div>
  );
}
