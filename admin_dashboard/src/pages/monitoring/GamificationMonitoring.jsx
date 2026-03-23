import { useState, useMemo } from 'react';
import { 
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, 
  CartesianGrid, PieChart, Pie, Cell, Legend 
} from 'recharts';
import { useUsers, useVouchers } from '../../hooks/useFirestore';
import { 
  TrendingUp, Award, Gift, Zap, Users, Filter, 
  Search, ArrowUpDown, Loader2, Sparkles, Activity,
  Trophy, Target, Coins, Heart, Ticket, ShieldCheck, Star,
  Calendar as CalendarIcon, ChevronDown
} from 'lucide-react';

const C = { 
  primary: '#7C9C84', 
  primaryDark: '#66826D',
  primaryLight: '#BBCBC2',
  sage100: '#E5EDE8', // Synced with CounsellorMonitoring
  cream: '#F6F5F2', 
  creamDarker: '#E5E4E0', 
  charcoal: '#333', 
  charcoalMuted: '#666',
  muted: '#888',
  amber: '#d97706',
  blue: '#3b82f6',
  rose: '#f43f5e'
};

const COLORS = ['#7C9C84', '#BBCBC2', '#D4B996', '#9EB8A6', '#D1DCD5'];

const sLabel = {
  fontSize: '10px',
  fontWeight: 800,
  textTransform: 'uppercase',
  letterSpacing: '0.12em',
  color: C.muted,
  marginBottom: '4px',
  display: 'block',
  fontFamily: 'Outfit'
};

const cardStyle = {
  background: 'white',
  borderRadius: '24px',
  padding: '32px',
  border: `1px solid ${C.creamDarker}`,
  boxShadow: '0 4px 20px rgba(0,0,0,0.02)'
};

export default function GamificationMonitoring() {
  const { data: users, loading: uLoading } = useUsers();
  const { data: vouchers, loading: vLoading } = useVouchers();
  const [searchQuery, setSearchQuery] = useState('');
  const [xpFilter, setXpFilter] = useState('all');
  const [isDateOpen, setIsDateOpen] = useState(false);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');

  const loading = uLoading || vLoading;
  const today = new Date().toISOString().split('T')[0];

  // Filter users by date for global metrics
  const filteredUsers = useMemo(() => {
    return (users || []).filter(u => {
      const createdAt = u.createdAt?.toDate ? u.createdAt.toDate() : (u.createdAt ? new Date(u.createdAt) : null);
      let matchesDate = true;
      if (startDate) {
        const sDate = new Date(startDate);
        matchesDate = matchesDate && createdAt && createdAt >= sDate;
      }
      if (endDate) {
        const eDate = new Date(endDate);
        eDate.setHours(23, 59, 59);
        matchesDate = matchesDate && createdAt && createdAt <= eDate;
      }
      return matchesDate;
    });
  }, [users, startDate, endDate]);

  // Leaderboard Processing with Filtering (inherits date filtering)
  const leaderboard = useMemo(() => {
    return [...filteredUsers]
      .sort((a, b) => (b.xp || 0) - (a.xp || 0))
      .filter(u => {
        const matchesSearch = (u.name || '').toLowerCase().includes(searchQuery.toLowerCase());
        const xp = u.xp || 0;
        
        // XP Range Filter
        let matchesXP = true;
        if (xpFilter === 'high') matchesXP = xp >= 1000;
        else if (xpFilter === 'mid') matchesXP = xp >= 500 && xp < 1000;
        else if (xpFilter === 'low') matchesXP = xp < 500;

        return matchesSearch && matchesXP;
      })
      .slice(0, 10);
  }, [filteredUsers, searchQuery, xpFilter]);

  // Process XP Sources
  const xpSourcesData = [
    { name: 'Meditation', value: 45 },
    { name: 'Diary Entry', value: 25 },
    { name: 'Article Reading', value: 15 },
    { name: 'Daily Login', value: 10 },
    { name: 'AI Chatbot', value: 30 }
  ];

  // HARDCODED REFERENCE: Process Reward Redemptions
  const redemptionData = [
    { name: 'RM10 Starbucks', value: 42 },
    { name: 'RM5 Grab Food', value: 35 },
    { name: 'RM20 Netflix', value: 18 },
    { name: 'RM15 Touch \'n Go', value: 26 },
    { name: 'RM50 AEON Card', value: 12 }
  ].sort((a, b) => b.value - a.value);

  const totalRedemptions = redemptionData.reduce((acc, curr) => acc + curr.value, 0);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <p className="section-label mb-0.5">Monitoring & Analytics</p>
          <h2 style={{ fontFamily: 'Outfit', fontWeight: 600, fontSize: '24px', color: C.charcoal, margin: 0 }}>Gamification Analytics</h2>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
           <div style={{ position: 'relative' }}>
              <button 
               onClick={() => setIsDateOpen(!isDateOpen)}
               style={{ 
                 display: 'flex', alignItems: 'center', gap: '8px', padding: '10px 16px', 
                 background: 'white', border: `1px solid ${isDateOpen ? C.primary : C.creamDarker}`, 
                 borderRadius: '12px', shadow: '0 2px 4px rgba(0,0,0,0.02)', cursor: 'pointer',
                 fontFamily: 'Outfit', fontSize: '13px', fontWeight: 600, color: C.charcoalMuted,
                 transition: 'all 0.2s'
               }}
               onMouseEnter={e => { if (!isDateOpen) e.currentTarget.style.background = C.cream; }}
               onMouseLeave={e => { if (!isDateOpen) e.currentTarget.style.background = 'white'; }}
              >
                <CalendarIcon size={14} className={startDate || endDate ? 'text-primary' : 'text-charcoal-muted'} />
                <span style={{ whiteSpace: 'nowrap' }}>
                  {!startDate && !endDate ? 'Custom Range' : `${startDate || 'Start'} - ${endDate || 'End'}`}
                </span>
                <ChevronDown size={14} style={{ opacity: 0.5, transition: 'transform 0.3s', transform: isDateOpen ? 'rotate(180deg)' : 'none' }} />
              </button>

              {isDateOpen && (
                <>
                  <div style={{ position: 'fixed', inset: 0, zIndex: 40 }} onClick={() => setIsDateOpen(false)} />
                  <div style={{ position: 'absolute', top: 'calc(100% + 8px)', right: 0, width: '280px', background: 'white', border: `1px solid ${C.creamDarker}`, borderRadius: '24px', boxShadow: '0 15px 40px rgba(0,0,0,0.12)', zIndex: 50, padding: '24px', animation: 'fadeInDown 0.2s cubic-bezier(0.16, 1, 0.3, 1)' }}>
                     <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
                        <p style={{ ...sLabel, marginBottom: 0 }}>Activity periods</p>
                        {(startDate || endDate) && (
                           <button 
                             onClick={() => { setStartDate(''); setEndDate(''); setIsDateOpen(false); }}
                             style={{ background: 'none', border: 'none', padding: 0, color: C.primary, fontSize: '10px', fontWeight: 800, cursor: 'pointer', textTransform: 'uppercase' }}
                           >
                             Reset
                           </button>
                        )}
                     </div>
                     
                     <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                           <label style={{ fontSize: '9px', fontWeight: 900, textTransform: 'uppercase', color: '#999', letterSpacing: '0.1em' }}>From Date</label>
                           <input 
                             type="date"
                             value={startDate}
                             max={today}
                             onChange={(e) => setStartDate(e.target.value)}
                             style={{ width: '100%', background: C.cream, border: `1px solid ${C.creamDarker}`, borderRadius: '12px', padding: '10px 14px', fontSize: '12px', fontFamily: 'Outfit', outline: 'none' }}
                           />
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                           <label style={{ fontSize: '9px', fontWeight: 900, textTransform: 'uppercase', color: '#999', letterSpacing: '0.1em' }}>To Date</label>
                           <input 
                             type="date"
                             value={endDate}
                             max={today}
                             onChange={(e) => setEndDate(e.target.value)}
                             style={{ width: '100%', background: C.cream, border: `1px solid ${C.creamDarker}`, borderRadius: '12px', padding: '10px 14px', fontSize: '12px', fontFamily: 'Outfit', outline: 'none' }}
                           />
                        </div>
                        
                        <button 
                         onClick={() => setIsDateOpen(false)}
                         style={{ width: '100%', padding: '12px', background: C.primary, color: 'white', border: 'none', borderRadius: '12px', fontSize: '12px', fontWeight: 700, cursor: 'pointer', marginTop: '8px', boxShadow: '0 4px 12px rgba(124, 156, 132, 0.2)' }}
                        >
                          Apply Range
                        </button>
                     </div>
                  </div>
                </>
              )}
           </div>
        </div>
      </div>

      {loading ? (
        <div style={{ ...cardStyle, padding: '80px', textAlign: 'center', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '16px' }}>
          <Loader2 size={32} className="animate-spin" style={{ color: C.primary }} />
          <p style={{ fontFamily: 'Outfit', color: C.muted, fontSize: '14px' }}>Loading analytics data…</p>
        </div>
      ) : (
        <>
          {/* Top Level Summary Metrics (Counsellor Style) - USES FILTERED USERS */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '12px' }}>
             <div style={{ ...cardStyle, padding: '16px 20px', display: 'flex', alignItems: 'center', gap: '16px' }}>
                <div style={{ width: '40px', height: '40px', borderRadius: '50%', background: C.sage100, display: 'flex', alignItems: 'center', justifyContent: 'center', color: C.primary, flexShrink: 0 }}>
                   <Zap size={20} fill="currentColor" />
                </div>
                <div>
                   <p className="section-label !text-[9px] mb-0 leading-none">Total XP Earned</p>
                   <p style={{ margin: 0, fontFamily: 'Outfit', fontSize: '20px', fontWeight: 700, color: C.primary }}>
                     {filteredUsers.reduce((acc, u) => acc + (u.xp || 0), 0).toLocaleString()}
                   </p>
                </div>
             </div>
             
             <div style={{ ...cardStyle, padding: '16px 20px', display: 'flex', alignItems: 'center', gap: '16px' }}>
                <div style={{ width: '40px', height: '40px', borderRadius: '50%', background: '#FFF7ED', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#EA580C', flexShrink: 0 }}>
                   <Ticket size={20} />
                </div>
                <div>
                   <p className="section-label !text-[9px] mb-0 leading-none">Rewards Claimed</p>
                   <p style={{ margin: 0, fontFamily: 'Outfit', fontSize: '20px', fontWeight: 700, color: '#EA580C' }}>
                     {totalRedemptions}
                   </p>
                </div>
             </div>

             <div style={{ ...cardStyle, padding: '16px 20px', display: 'flex', alignItems: 'center', gap: '16px' }}>
                <div style={{ width: '40px', height: '40px', borderRadius: '50%', background: '#EFF6FF', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#2563EB', flexShrink: 0 }}>
                   <Activity size={20} />
                </div>
                <div>
                   <p className="section-label !text-[9px] mb-0 leading-none">Avg. XP / User</p>
                   <p style={{ margin: 0, fontFamily: 'Outfit', fontSize: '20px', fontWeight: 700, color: C.charcoal }}>
                     {Math.round(filteredUsers.reduce((acc, u) => acc + (u.xp || 0), 0) / (filteredUsers.length || 1))}
                   </p>
                </div>
             </div>
          </div>

          {/* Charts Row */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(400px, 1fr))', gap: '24px' }}>
             <div style={cardStyle}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
                   <p className="section-label mb-0">XP by Action</p>
                   <span style={{ fontSize: '10px', color: C.muted, fontWeight: 700, textTransform: 'uppercase' }}>Filtered View</span>
                </div>
                <ResponsiveContainer width="100%" height={260}>
                   <BarChart data={xpSourcesData} barSize={32}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#EEEDE9" vertical={false} />
                      <XAxis dataKey="name" tick={{ fontFamily: 'Outfit', fontSize: 10, fill: C.muted, fontWeight: 600 }} axisLine={false} tickLine={false} />
                      <YAxis tick={{ fontFamily: 'Outfit', fontSize: 10, fill: C.muted, fontWeight: 600 }} axisLine={false} tickLine={false} />
                      <Tooltip contentStyle={{ borderRadius: '16px', border: '1px solid #EEEDE9', boxShadow: '0 8px 32px rgba(0,0,0,0.06)', fontSize: '12px', fontFamily: 'Outfit' }} />
                      <Bar dataKey="value" fill={C.primary} radius={[10, 10, 0, 0]} />
                   </BarChart>
                </ResponsiveContainer>
             </div>

             <div style={cardStyle}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
                   <p className="section-label mb-0">Redemption Summary</p>
                   <span style={{ fontSize: '10px', color: C.muted, fontWeight: 700, textTransform: 'uppercase' }}>Voucher Stats</span>
                </div>
                <div style={{ position: 'relative', height: '260px' }}>
                    <ResponsiveContainer width="100%" height="100%">
                    <PieChart>
                        <Pie
                            data={redemptionData}
                            cx="50%"
                            cy="50%"
                            innerRadius={75}
                            outerRadius={100}
                            paddingAngle={8}
                            dataKey="value"
                            stroke="none"
                        >
                            {redemptionData.map((entry, index) => (
                            <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                            ))}
                        </Pie>
                        <Tooltip 
                            contentStyle={{ borderRadius: '16px', border: `1px solid ${C.creamDarker}`, boxShadow: '0 8px 32px rgba(0,0,0,0.06)', fontSize: '12px' }}
                        />
                        <Legend verticalAlign="bottom" height={36} iconType="circle" wrapperStyle={{ fontFamily: 'Outfit', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', color: C.muted, paddingTop: '15px' }} />
                    </PieChart>
                    </ResponsiveContainer>
                    
                    {/* Central Label for Donut */}
                    <div style={{ position: 'absolute', top: '42%', left: '50%', transform: 'translate(-50%, -50%)', textAlign: 'center', pointerEvents: 'none' }}>
                        <p style={{ margin: 0, fontSize: '28px', fontWeight: 800, color: C.charcoal, fontFamily: 'Outfit', lineHeight: 1 }}>{totalRedemptions}</p>
                        <p style={{ margin: 0, fontSize: '10px', fontWeight: 700, color: C.muted, textTransform: 'uppercase', letterSpacing: '0.05em', marginTop: '4px' }}>Total Claims</p>
                    </div>
                </div>
             </div>
          </div>

          {/* User Leaderboard Performance (Counsellor Style) */}
          <div style={cardStyle}>
              <p className="section-label mb-6">Gamification Performance Audit</p>
              
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '24px' }}>
                <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
                  <div style={{ position: 'relative' }}>
                    <Search size={14} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: C.charcoalMuted }} />
                    <input
                      type="text"
                      placeholder="Search performers..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      style={{ padding: '8px 16px 8px 36px', width: '220px', background: 'white', border: `1px solid ${C.creamDarker}`, borderRadius: '12px', fontSize: '13px', fontFamily: 'Outfit', outline: 'none' }}
                    />
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '4px', background: C.cream, padding: '4px', borderRadius: '12px', border: `1px solid ${C.creamDarker}` }}>
                    {[
                      { id: 'all', label: 'All' },
                      { id: 'high', label: '1000+' },
                      { id: 'mid', label: '500+' },
                      { id: 'low', label: '<500' }
                    ].map(f => (
                      <button
                        key={f.id}
                        onClick={() => setXpFilter(f.id)}
                        style={{
                          padding: '6px 12px',
                          borderRadius: '8px',
                          border: 'none',
                          fontSize: '11px',
                          fontWeight: 700,
                          fontFamily: 'Outfit',
                          cursor: 'pointer',
                          background: xpFilter === f.id ? C.primary : 'transparent',
                          color: xpFilter === f.id ? 'white' : C.charcoalMuted,
                          transition: 'all 0.2s'
                        }}
                      >
                        {f.label}
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              <div style={{ overflowX: 'auto' }}>
                 <table style={{ width: '100%', borderCollapse: 'collapse' }}>
                    <thead>
                       <tr style={{ textAlign: 'left', textTransform: 'uppercase', fontSize: '10px', fontWeight: 700, letterSpacing: '0.05em', color: C.charcoalMuted, borderBottom: `1px solid ${C.creamDarker}` }}>
                          <th style={{ padding: '0 12px 10px 12px', textAlign: 'center' }}>Rank</th>
                          <th style={{ padding: '0 0 10px 0' }}>User</th>
                          <th style={{ padding: '0 0 10px 0' }}>XP Points</th>
                          <th style={{ padding: '0 0 10px 0' }}>Progress</th>
                          <th style={{ padding: '0 24px 10px 0', textAlign: 'right' }}>Status</th>
                       </tr>
                    </thead>
                    <tbody>
                       {leaderboard.map((u, i) => {
                          const maxXP = (leaderboard[0]?.xp || 1);
                          const profileStrength = Math.round(((u.xp || 0) / maxXP) * 100);
                          
                          return (
                             <tr key={u.id || i} style={{ borderBottom: `1px solid ${C.creamDarker}`, cursor: 'pointer' }} onMouseEnter={e => e.currentTarget.style.background = C.sage100 + '44'} onMouseLeave={e => e.currentTarget.style.background = 'transparent'}>
                                <td style={{ padding: '16px 12px', textAlign: 'center' }}>
                                   <div style={{ width: '28px', height: '28px', borderRadius: '8px', background: i === 0 ? '#FEF3C7' : i === 1 ? '#F3F4F6' : i === 2 ? '#FFEDD5' : C.cream, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '12px', fontWeight: 800, color: i < 3 ? '#92400E' : C.charcoalMuted }}>
                                      {i === 0 ? '👑' : i + 1}
                                   </div>
                                </td>
                                <td style={{ padding: '16px 0' }}>
                                   <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                                      <div style={{ width: '36px', height: '36px', borderRadius: '10px', background: C.sage100, display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 800, color: C.primary, fontSize: '13px', border: `1px solid ${C.creamDarker}` }}>
                                         {u.name ? u.name.charAt(0).toUpperCase() : '?'}
                                      </div>
                                      <div style={{ display: 'flex', flexDirection: 'column' }}>
                                         <span style={{ fontWeight: 600, fontSize: '14px', color: C.charcoal }}>{u.name || 'Anonymous User'}</span>
                                         <span style={{ fontSize: '10px', color: C.muted, textTransform: 'uppercase', letterSpacing: '0.05em' }}>{u.email || 'Private'}</span>
                                      </div>
                                   </div>
                                </td>
                                <td style={{ padding: '16px 0', fontWeight: 700, fontSize: '14px', color: C.primary, fontFamily: 'monospace' }}>
                                   {u.xp?.toLocaleString() || 0}
                                </td>
                                <td style={{ padding: '16px 0' }}>
                                   <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                                      <div style={{ width: '80px', height: '6px', background: C.cream, borderRadius: '4px', border: `1px solid ${C.creamDarker}`, overflow: 'hidden' }}>
                                         <div 
                                           style={{ height: '100%', background: C.primary, width: `${profileStrength}%`, transition: 'width 1s' }}
                                         />
                                      </div>
                                      <span style={{ fontSize: '10px', fontWeight: 800, color: C.charcoalMuted }}>{profileStrength}%</span>
                                   </div>
                                </td>
                                <td style={{ padding: '16px 24px 16px 0', textAlign: 'right' }}>
                                    <span style={{ padding: '4px 10px', borderRadius: '20px', background: C.sage100, color: C.primary, fontSize: '9px', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                                       Active
                                    </span>
                                </td>
                             </tr>
                          );
                       })}
                    </tbody>
                 </table>
              </div>
          </div>
        </>
      )}
    </div>
  );
}
