import { useState } from 'react';
import { 
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, 
  CartesianGrid, PieChart, Pie, Cell, Legend 
} from 'recharts';
import { useUsers, useVouchers } from '../../hooks/useFirestore';
import { 
  TrendingUp, Award, Gift, Zap, Users, Filter, 
  Search, ArrowUpDown, Loader2, Sparkles, Activity
} from 'lucide-react';

const C = { 
  primary: '#7C9C84', 
  primaryLight: '#BBCBC2',
  cream: '#F6F5F2', 
  creamDarker: '#E5E4E0', 
  charcoal: '#333', 
  charcoalMuted: '#666',
  amber: '#d97706',
  blue: '#3b82f6',
  rose: '#f43f5e'
};

const COLORS = ['#7C9C84', '#BBCBC2', '#d97706', '#3b82f6', '#f43f5e'];

export default function GamificationMonitoring() {
  const { data: users, loading: uLoading } = useUsers();
  const { data: vouchers, loading: vLoading } = useVouchers();
  const [searchQuery, setSearchQuery] = useState('');

  const loading = uLoading || vLoading;

  // Process XP Sources (Simulated for design, normally aggregated from xp_logs)
  const xpSourcesData = [
    { name: 'Meditation', value: 45 },
    { name: 'Diary Entry', value: 25 },
    { name: 'Article Reading', value: 15 },
    { name: 'Daily Login', value: 10 },
    { name: 'AI Chatbot', value: 30 }
  ];

  // Process Reward Redemptions
  const redemptionData = (vouchers || [])
    .map(v => ({ name: v.code, value: v.used || 0 }))
    .sort((a, b) => b.value - a.value)
    .slice(0, 5);

  // Leaderboard Processing
  const leaderboard = [...(users || [])]
    .sort((a, b) => (b.xp || 0) - (a.xp || 0))
    .filter(u => (u.name || '').toLowerCase().includes(searchQuery.toLowerCase()))
    .slice(0, 10);

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-row items-center justify-between gap-4">
        <div>
          <p className="section-label mb-0.5">Monitoring & Analytics</p>
          <h2 className="font-display font-semibold text-2xl text-charcoal">Gamification Intelligence</h2>
        </div>
        <div className="flex items-center gap-2 bg-amber-50 px-3 py-1.5 rounded-xl text-amber-600 font-body text-[10px] font-bold border border-amber-100 shadow-sm animate-in fade-in slide-in-from-right-2">
          <Sparkles size={12} className="animate-pulse" />
          SYSTEM PERFORMANCE
        </div>
      </div>

      {loading ? (
        <div className="card py-12 flex flex-col items-center justify-center gap-4">
          <Loader2 size={32} className="animate-spin text-primary opacity-40" />
          <p className="font-body text-sm text-charcoal-muted">Parsing engagement telemetry…</p>
        </div>
      ) : (
        <>
          {/* Top Level Metrics */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
             <div className="card bg-white border border-creamDarker">
                <div className="flex justify-between items-start mb-3">
                   <div className="w-10 h-10 rounded-xl bg-sage-100 flex items-center justify-center text-primary">
                      <Zap size={20} fill="currentColor" />
                   </div>
                   <span className="section-label text-[9px]">Total XP Earned</span>
                </div>
                <p className="font-display font-black text-3xl text-charcoal">
                    {(users || []).reduce((acc, u) => acc + (u.xp || 0), 0).toLocaleString()} <span className="text-xs text-muted font-normal">pts</span>
                </p>
             </div>
             
             <div className="card bg-white border border-creamDarker">
                <div className="flex justify-between items-start mb-3">
                   <div className="w-10 h-10 rounded-xl bg-amber-50 flex items-center justify-center text-amber-600">
                      <Gift size={20} />
                   </div>
                   <span className="section-label text-[9px]">Redemptions</span>
                </div>
                <p className="font-display font-black text-3xl text-charcoal">
                    {(vouchers || []).reduce((acc, v) => acc + (v.used || 0), 0)} <span className="text-xs text-muted font-normal">claims</span>
                </p>
             </div>

             <div className="card bg-white border border-creamDarker">
                <div className="flex justify-between items-start mb-3">
                   <div className="w-10 h-10 rounded-xl bg-blue-50 flex items-center justify-center text-blue-500">
                      <Activity size={20} />
                   </div>
                   <span className="section-label text-[9px]">Avg. XP / User</span>
                </div>
                <p className="font-display font-black text-3xl text-charcoal">
                    {Math.round((users || []).reduce((acc, u) => acc + (u.xp || 0), 0) / ((users || []).length || 1))} <span className="text-xs text-muted font-normal">pts</span>
                </p>
             </div>
          </div>

          {/* Charts Row */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
             <div className="card">
                <p className="section-label mb-1">XP Productivity</p>
                <h3 className="font-body font-semibold text-charcoal mb-6">User Activity Distribution</h3>
                <ResponsiveContainer width="100%" height={260}>
                   <BarChart data={xpSourcesData}>
                      <CartesianGrid strokeDasharray="3 3" stroke="#EEEDE9" vertical={false} />
                      <XAxis dataKey="name" tick={{ fontFamily: 'Outfit', fontSize: 10, fill: '#888' }} axisLine={false} tickLine={false} />
                      <YAxis tick={{ fontFamily: 'Outfit', fontSize: 10, fill: '#888' }} axisLine={false} tickLine={false} />
                      <Tooltip contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 8px 16px rgba(0,0,0,0.08)', fontSize: '11px' }} />
                      <Bar dataKey="value" fill={C.primary} radius={[10, 10, 0, 0]} name="Relative Frequency" />
                   </BarChart>
                </ResponsiveContainer>
                <div className="mt-4 flex flex-wrap justify-center gap-4">
                   <div className="flex items-center gap-1.5">
                      <div className="w-2 h-2 rounded-full bg-primary" />
                      <span className="text-[10px] font-bold text-charcoal-muted uppercase">Primary XP Source</span>
                   </div>
                </div>
             </div>

             <div className="card">
                <p className="section-label mb-1">Reward Treasury</p>
                <h3 className="font-body font-semibold text-charcoal mb-4">Voucher Redemption Breakdown</h3>
                <ResponsiveContainer width="100%" height={260}>
                   <PieChart>
                      <Pie
                        data={redemptionData}
                        cx="50%"
                        cy="50%"
                        innerRadius={60}
                        outerRadius={80}
                        paddingAngle={5}
                        dataKey="value"
                      >
                        {redemptionData.map((entry, index) => (
                          <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                        ))}
                      </Pie>
                      <Tooltip />
                      <Legend verticalAlign="bottom" height={36} wrapperStyle={{ fontFamily: 'Outfit', fontSize: '11px' }} />
                   </PieChart>
                </ResponsiveContainer>
             </div>
          </div>

          {/* User Leaderboard Performance */}
          <div className="card">
              <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
                 <div>
                    <h3 className="font-display font-semibold text-xl text-charcoal">Eunoia Elite Leaderboard</h3>
                    <p className="font-body text-xs text-charcoal-muted mt-0.5">Top 10 users by total accumulated XP points</p>
                 </div>
                 
                 <div className="relative">
                    <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                    <input
                      type="text"
                      placeholder="Search performers..."
                      value={searchQuery}
                      onChange={(e) => setSearchQuery(e.target.value)}
                      className="pl-9 pr-4 py-2 border border-creamDarker rounded-xl text-sm font-body outline-none focus:border-primary transition w-64 bg-cream/30"
                    />
                 </div>
              </div>

              <div className="overflow-x-auto">
                 <table className="w-full font-body text-sm">
                    <thead>
                       <tr className="text-left text-charcoal-muted text-[10px] uppercase font-bold tracking-widest border-b border-creamDarker">
                          <th className="pb-3 text-center w-12">Rank</th>
                          <th className="pb-3">Performer</th>
                          <th className="pb-3 text-right">Loyalty Points (XP)</th>
                          <th className="pb-3 text-right pr-4">Profile Strength</th>
                       </tr>
                    </thead>
                    <tbody>
                       {leaderboard.map((u, i) => {
                          const maxXP = leaderboard[0].xp || 1;
                          const profileStrength = Math.round(((u.xp || 0) / maxXP) * 100);
                          
                          return (
                             <tr key={u.id || i} className="border-b border-creamDarker last:border-0 hover:bg-cream transition group">
                                <td className="py-4 text-center font-display font-black text-charcoal-muted">
                                   {i === 0 ? '👑' : i + 1}
                                </td>
                                <td className="py-4">
                                   <div className="flex items-center gap-3">
                                      <div className="w-9 h-9 rounded-full bg-sage-100 flex items-center justify-center text-primary font-bold shadow-sm">
                                         {u.name ? u.name.charAt(0).toUpperCase() : '?'}
                                      </div>
                                      <div>
                                         <p className="font-bold text-charcoal mb-0.5 group-hover:text-primary transition">{u.name || 'Anonymous'}</p>
                                         <p className="text-[10px] text-muted uppercase font-bold tracking-tighter">{u.email || 'Private User'}</p>
                                      </div>
                                   </div>
                                </td>
                                <td className="py-4 text-right pr-4 font-mono font-bold text-primary">
                                   {u.xp?.toLocaleString() || 0}
                                </td>
                                <td className="py-4 text-right pr-4">
                                   <div className="flex items-center justify-end gap-2">
                                      <div className="w-24 h-1.5 bg-cream rounded-full overflow-hidden border border-creamDarker">
                                         <div 
                                           className="h-full bg-primary" 
                                           style={{ width: `${profileStrength}%` }}
                                         />
                                      </div>
                                      <span className="text-[10px] font-bold text-charcoal-muted w-8">{profileStrength}%</span>
                                   </div>
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
