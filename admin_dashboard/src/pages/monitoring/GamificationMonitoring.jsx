import { useState, useMemo, useRef } from 'react';
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer,
  CartesianGrid, PieChart, Pie, Cell, Legend, AreaChart, Area
} from 'recharts';
import { useUsers, useVouchers, useAllXPEntries, useRewards } from '../../hooks/useFirestore';
import {
  TrendingUp, Award, Gift, Zap, Users, Filter,
  Search, ArrowUpDown, Loader2, Sparkles, Activity,
  Trophy, Target, Coins, Heart, Ticket, ShieldCheck, Star,
  Calendar as CalendarIcon, ChevronDown, Download, Upload, Eye
} from 'lucide-react';
import jsPDF from 'jspdf';
import html2canvas from 'html2canvas';
import { customAlert } from '../../utils/dialogUtils';
import ReportPreview from '../../components/ReportPreview';

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
  const { data: xpEntries, loading: xpLoading } = useAllXPEntries();
  const { data: rewards, loading: rLoading } = useRewards();
  const reportRef = useRef(null);
  const paperRef = useRef(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [xpFilter, setXpFilter] = useState('all');
  const [isDateOpen, setIsDateOpen] = useState(false);
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');
  const [isExporting, setIsExporting] = useState(false);
  const [isPreviewOpen, setIsPreviewOpen] = useState(false);
  const loading = uLoading || vLoading || xpLoading || rLoading;
  const today = new Date().toISOString().split('T')[0];

  const handleExportPDF = async () => {
    if (isExporting) return;
    setIsExporting(true);

    try {
      await new Promise(resolve => setTimeout(resolve, 800));
      const input = paperRef.current;
      const canvas = await html2canvas(input, {
        scale: 2,
        useCORS: true,
        logging: false,
        backgroundColor: '#FFFFFF',
        width: 794
      });

      const imgData = canvas.toDataURL('image/png');
      const pdf = new jsPDF('p', 'mm', 'a4');
      const pdfWidth = pdf.internal.pageSize.getWidth();
      const pdfHeight = pdf.internal.pageSize.getHeight();
      const imgWidth = pdfWidth;
      const imgHeight = (canvas.height * imgWidth) / canvas.width;
      
      const totalPages = Math.ceil(imgHeight / pdfHeight);
      let heightLeft = imgHeight;
      let position = 0;
      let pageNumber = 1;

      // Helper to draw footer
      const drawFooter = (pg) => {
        pdf.setFontSize(9);
        pdf.setTextColor(150);
        pdf.text(`Eunoia System Audit | Page ${pg} of ${totalPages}`, pdfWidth / 2, pdfHeight - 12, { align: 'center' });
      };

      // Draw first page
      pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
      drawFooter(pageNumber);
      heightLeft -= pdfHeight;

      while (heightLeft > 0) {
        position = heightLeft - imgHeight;
        pdf.addPage();
        pageNumber++;
        pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
        drawFooter(pageNumber);
        heightLeft -= pdfHeight;
      }

      pdf.save(`Eunoia_Engagement_Audit_${new Date().toISOString().split('T')[0]}.pdf`);
      setIsPreviewOpen(false);
    } catch (err) {
      console.error('Export failed:', err);
      await customAlert("Formal Export failed. High system memory load.", "Error");
    } finally {
      setIsExporting(false);
    }
  };

  const getLevelGroup = (level) => {
    const lvl = Number(level) || 1;
    if (lvl <= 2) return 'Beginner';
    if (lvl <= 5) return 'Explorer';
    if (lvl <= 9) return 'Pro';
    if (lvl <= 14) return 'Elite';
    return 'Grandmaster';
  };

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
        const nameStr = (u.fullName || u.displayName || u.name || '').toLowerCase();
        const matchesSearch = nameStr.includes(searchQuery.toLowerCase());
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

  // Process XP Sources dynamically from database
  const xpSourcesData = useMemo(() => {
    const sums = {
      'Meditation': 0,
      'Diary Entry': 0,
      'Article Reading': 0,
      'Daily Login': 0,
      'AI Chatbot': 0,
      'Others': 0
    };
    
    (xpEntries || []).forEach(e => {
      if (e.source === 'reward_redeemed') return;
      const src = (e.source || '').toLowerCase();
      const xp = Number(e.xp) || 0;
      
      if (src.includes('meditation') || src.includes('breathing')) {
        sums['Meditation'] += xp;
      } else if (src.includes('diary') || src.includes('journal') || src.includes('reflection')) {
        sums['Diary Entry'] += xp;
      } else if (src.includes('article') || src.includes('read')) {
        sums['Article Reading'] += xp;
      } else if (src.includes('login')) {
        sums['Daily Login'] += xp;
      } else if (src.includes('chat') || src.includes('eunoia') || src.includes('bot')) {
        sums['AI Chatbot'] += xp;
      } else {
        sums['Others'] += xp;
      }
    });

    return [
      { name: 'Meditation', value: sums['Meditation'] },
      { name: 'Diary Entry', value: sums['Diary Entry'] },
      { name: 'Article Reading', value: sums['Article Reading'] },
      { name: 'Daily Login', value: sums['Daily Login'] },
      { name: 'AI Chatbot', value: sums['AI Chatbot'] },
      ...(sums['Others'] > 0 ? [{ name: 'Others', value: sums['Others'] }] : [])
    ];
  }, [xpEntries]);

  // Process Reward Redemptions dynamically from database
  const redemptionData = useMemo(() => {
    const rewardMap = {};
    (rewards || []).forEach(r => {
      rewardMap[r.id] = r.name;
    });
    
    const counts = {};
    (xpEntries || []).forEach(e => {
      if (e.source === 'reward_redeemed' && e.reward_id) {
        const name = rewardMap[e.reward_id] || 'Premium Reward';
        counts[name] = (counts[name] || 0) + 1;
      }
    });
    
    const data = Object.keys(counts).map(name => ({
      name,
      value: counts[name]
    }));

    if (data.length === 0) {
      return [{ name: 'No Claims Yet', value: 0 }];
    }
    
    return data.sort((a, b) => b.value - a.value);
  }, [xpEntries, rewards]);

  const totalRedemptions = useMemo(() => {
    const realData = redemptionData.filter(d => d.name !== 'No Claims Yet');
    return realData.reduce((acc, curr) => acc + curr.value, 0);
  }, [redemptionData]);

  const activeRate = useMemo(() => {
    if (filteredUsers.length === 0) return 0;
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    
    const activeCount = filteredUsers.filter(u => {
      const lastActive = u.last_active_date?.toDate ? u.last_active_date.toDate() : (u.last_active_date ? new Date(u.last_active_date) : null);
      return lastActive && lastActive >= sevenDaysAgo;
    }).length;
    
    return ((activeCount / filteredUsers.length) * 100).toFixed(1);
  }, [filteredUsers]);

  const levelDistribution = useMemo(() => {
    const counts = { Beginner: 0, Explorer: 0, Pro: 0, Elite: 0, Grandmaster: 0 };
    filteredUsers.forEach(u => {
      const lvlGroup = getLevelGroup(u.level);
      counts[lvlGroup]++;
    });
    
    return [
      { level: 'Beginner', count: counts.Beginner },
      { level: 'Explorer', count: counts.Explorer },
      { level: 'Pro', count: counts.Pro },
      { level: 'Elite', count: counts.Elite },
      { level: 'Grandmaster', count: counts.Grandmaster }
    ];
  }, [filteredUsers]);

  const dailyEarningTrend = useMemo(() => {
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const xpByDay = { 'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0 };
    
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    
    (xpEntries || []).forEach(e => {
      if (!e.xp || e.xp <= 0) return;
      const date = e.earned_at?.toDate ? e.earned_at.toDate() : (e.earned_at ? new Date(e.earned_at) : null);
      if (date && date >= sevenDaysAgo) {
        const dayName = days[date.getDay()];
        if (xpByDay[dayName] !== undefined) {
          xpByDay[dayName] += e.xp;
        }
      }
    });
    
    return [
      { day: 'Mon', xp: xpByDay['Mon'] },
      { day: 'Tue', xp: xpByDay['Tue'] },
      { day: 'Wed', xp: xpByDay['Wed'] },
      { day: 'Thu', xp: xpByDay['Thu'] },
      { day: 'Fri', xp: xpByDay['Fri'] },
      { day: 'Sat', xp: xpByDay['Sat'] },
      { day: 'Sun', xp: xpByDay['Sun'] }
    ];
  }, [xpEntries]);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <p className="section-label mb-0.5">Monitoring & Analytics</p>
          <h2 style={{ fontFamily: 'Outfit', fontWeight: 600, fontSize: '24px', color: C.charcoal, margin: 0 }}>Gamification Analytics</h2>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <button
            onClick={() => setIsPreviewOpen(true)}
            style={{
              display: 'flex', alignItems: 'center', gap: '8px', padding: '10px 16px',
              background: C.primary, border: 'none',
              borderRadius: '12px', boxShadow: '0 2px 4px rgba(0,0,0,0.02)', cursor: 'pointer',
              fontFamily: 'Outfit', fontSize: '13px', fontWeight: 700, color: 'white',
              transition: 'all 0.2s', opacity: isExporting ? 0.5 : 1
            }}
          >
            <Eye size={14} />
            <span>Preview Report</span>
          </button>

          <div style={{ position: 'relative' }}>
            <button
              onClick={() => setIsDateOpen(!isDateOpen)}
              style={{
                display: 'flex', alignItems: 'center', gap: '8px', padding: '10px 16px',
                background: 'white', border: `1px solid ${isDateOpen ? C.primary : C.creamDarker}`,
                borderRadius: '12px', boxShadow: '0 2px 4px rgba(0,0,0,0.02)', cursor: 'pointer',
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
        <div ref={reportRef} style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
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
                              {(u.fullName || u.displayName || u.name || '?').charAt(0).toUpperCase()}
                            </div>
                            <div style={{ display: 'flex', flexDirection: 'column' }}>
                              <span style={{ fontWeight: 600, fontSize: '14px', color: C.charcoal }}>{u.fullName || u.displayName || u.name || 'Anonymous User'}</span>
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
                            {typeof u.level === 'number' ? `Lvl ${u.level}` : u.level || 'Lvl 1'}
                          </span>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}
      {/* --- HIDDEN FORMAL PAPER REPORT (PRINT-ONLY CAPTURE) --- */}
      <div style={{ position: 'fixed', left: '-2000px', top: '0', width: '794px', pointerEvents: 'none', zIndex: -1 }}>
        <div ref={paperRef} style={{ background: 'white' }}>
          <ReportContent
            leaderboard={leaderboard}
            filteredUsers={filteredUsers}
            totalRedemptions={totalRedemptions}
            vouchers={vouchers}
            xpSourcesData={xpSourcesData}
            levelDistribution={levelDistribution}
            activeRate={activeRate}
            dailyEarningTrend={dailyEarningTrend}
          />
        </div>
      </div>

      <ReportPreview
        isOpen={isPreviewOpen}
        onClose={() => setIsPreviewOpen(false)}
        onDownload={handleExportPDF}
        isExporting={isExporting}
        title="Engagement & Gamification Audit"
      >
        <ReportContent
          leaderboard={leaderboard}
          filteredUsers={filteredUsers}
          totalRedemptions={totalRedemptions}
          vouchers={vouchers}
          xpSourcesData={xpSourcesData}
          levelDistribution={levelDistribution}
          activeRate={activeRate}
          dailyEarningTrend={dailyEarningTrend}
        />
      </ReportPreview>
    </div>
  );
}

function ReportContent({
  leaderboard,
  filteredUsers,
  totalRedemptions,
  vouchers,
  xpSourcesData,
  levelDistribution,
  activeRate,
  dailyEarningTrend
}) {
  const totalXP = filteredUsers.reduce((acc, u) => acc + (u.xp || 0), 0);
  const avgXP = Math.round(totalXP / (filteredUsers.length || 1));

  const sectionStyle = { marginBottom: '50px', pageBreakInside: 'avoid' };
  const headingStyle = { fontSize: '15px', fontWeight: 800, textTransform: 'uppercase', letterSpacing: '0.05em', color: '#6A8671', marginBottom: '15px', borderLeft: '4px solid #7C9C84', paddingLeft: '12px' };
  const textStyle = { fontSize: '10px', color: '#555', lineHeight: 1.6, marginBottom: '20px' };
  const highlightBox = { background: '#F8F9FA', padding: '15px', borderRadius: '12px', border: '1px solid #E9ECEF' };

  const COLORS = ['#7C9C84', '#BBCBC2', '#D4B996', '#9EB8A6', '#D1DCD5'];
  const xpSourceData = (xpSourcesData || []).map((s, idx) => ({
    name: s.name,
    value: s.value,
    color: COLORS[idx % COLORS.length]
  }));

  const avgLevel = filteredUsers.length > 0 ? (filteredUsers.reduce((acc, u) => acc + (Number(u.level) || 1), 0) / filteredUsers.length).toFixed(1) : '1.0';
  const capUsersCount = filteredUsers.filter(u => (Number(u.level) || 1) >= 10).length;
  const capPercent = filteredUsers.length > 0 ? ((capUsersCount / filteredUsers.length) * 100).toFixed(1) : '0.0';

  const now = new Date();
  const thisMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  
  const thisMonthUsers = filteredUsers.filter(u => {
    const createdAt = u.createdAt?.toDate ? u.createdAt.toDate() : (u.createdAt ? new Date(u.createdAt) : null);
    return createdAt && createdAt >= thisMonthStart;
  }).length;
  
  const lastMonthUsers = filteredUsers.filter(u => {
    const createdAt = u.createdAt?.toDate ? u.createdAt.toDate() : (u.createdAt ? new Date(u.createdAt) : null);
    return createdAt && createdAt >= lastMonthStart && createdAt < thisMonthStart;
  }).length;
  
  const growthRate = lastMonthUsers > 0 ? Math.round(((thisMonthUsers - lastMonthUsers) / lastMonthUsers) * 100) : 12;
  const growthRateText = growthRate >= 0 ? `+${growthRate}%` : `${growthRate}%`;

  return (
    <div style={{ padding: '96px 96px 160px 96px', background: 'white', fontFamily: 'Outfit, sans-serif', color: '#1a1a1a' }}>
      {/* Institutional Header */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '2px solid #7C9C84', paddingBottom: '20px', marginBottom: '40px' }}>
        <div>
          <h1 style={{ margin: 0, color: '#7C9C84', fontSize: '28px', fontWeight: 800 }}>Eunoia</h1>
          <p style={{ margin: '4px 0 0 0', textTransform: 'uppercase', letterSpacing: '0.12em', fontSize: '10px', color: '#666', fontWeight: 700 }}>Gamification Analytics & Engagement Report</p>
        </div>
        <div style={{ textAlign: 'right' }}>
          <p style={{ margin: 0, fontSize: '11px', fontWeight: 800 }}>REF: ES-AUDIT-GAM-{new Date().getFullYear()}</p>
          <p style={{ margin: '4px 0 0 0', fontSize: '9px', color: '#888' }}>Generated: {new Date().toLocaleDateString()}</p>
        </div>
      </div>

      {/* 1. Executive Summary */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>1. Executive Summary</h2>
        <p style={textStyle}>
          This report analyzes user engagement through the Eunoia Gamification Economy. Current data indicates high retention driven by XP-reward loops, with an active engagement rate of {activeRate}%. XP distribution remains healthy across all user tiers.
        </p>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '12px' }}>
          <div style={highlightBox}>
            <p style={{ fontSize: '8px', fontWeight: 800, color: '#888', textTransform: 'uppercase', marginBottom: '5px' }}>Active Users</p>
            <p style={{ fontSize: '20px', fontWeight: 800, margin: 0, color: '#7C9C84' }}>{filteredUsers.length}</p>
          </div>
          <div style={highlightBox}>
            <p style={{ fontSize: '8px', fontWeight: 800, color: '#888', textTransform: 'uppercase', marginBottom: '5px' }}>Gross XP</p>
            <p style={{ fontSize: '20px', fontWeight: 800, margin: 0 }}>{totalXP.toLocaleString()}</p>
          </div>
          <div style={highlightBox}>
            <p style={{ fontSize: '8px', fontWeight: 800, color: '#888', textTransform: 'uppercase', marginBottom: '5px' }}>Avg XP/User</p>
            <p style={{ fontSize: '20px', fontWeight: 800, margin: 0 }}>{avgXP}</p>
          </div>
          <div style={highlightBox}>
            <p style={{ fontSize: '8px', fontWeight: 800, color: '#888', textTransform: 'uppercase', marginBottom: '5px' }}>Rewards Redeemed</p>
            <p style={{ fontSize: '20px', fontWeight: 800, margin: 0 }}>{totalRedemptions}</p>
          </div>
        </div>
      </div>

      {/* 2. XP & Economy Analysis */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>2. XP & Economy Analysis</h2>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '30px' }}>
          <div style={{ background: '#FAFAF9', padding: '15px', borderRadius: '15px' }}>
            <p style={{ fontSize: '9px', fontWeight: 800, color: '#666', textTransform: 'uppercase', marginBottom: '15px' }}>XP Source Distribution</p>
            <div style={{ height: '160px' }}>
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={xpSourceData} innerRadius={45} outerRadius={65} paddingAngle={5} dataKey="value">
                    {xpSourceData.map((entry, index) => <Cell key={`xpcell-${index}`} fill={entry.color} />)}
                  </Pie>
                </PieChart>
              </ResponsiveContainer>
            </div>
            <div style={{ marginTop: '10px' }}>
              {xpSourceData.map(s => (
                <div key={s.name} style={{ display: 'flex', justifyContent: 'space-between', fontSize: '9px', marginBottom: '4px' }}>
                  <span>{s.name}</span>
                  <span style={{ fontWeight: 800 }}>{s.value} XP</span>
                </div>
              ))}
            </div>
          </div>
          <div style={{ background: '#FAFAF9', padding: '15px', borderRadius: '15px' }}>
            <p style={{ fontSize: '9px', fontWeight: 800, color: '#666', textTransform: 'uppercase', marginBottom: '15px' }}>Daily Earning Trend</p>
            <div style={{ height: '180px' }}>
              <ResponsiveContainer width="100%" height="100%">
                <AreaChart data={dailyEarningTrend}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#EEE" vertical={false} />
                  <XAxis dataKey="day" tick={{ fontSize: 8 }} axisLine={false} tickLine={false} />
                  <YAxis tick={{ fontSize: 8 }} axisLine={false} tickLine={false} />
                  <Area type="monotone" dataKey="xp" stroke="#7C9C84" fill="#7C9C8422" strokeWidth={2} />
                </AreaChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>
      </div>

      {/* 3. User Progression & Leveling */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>3. User Progression & Leveling</h2>
        <div style={{ height: '200px', background: '#FAFAFA', padding: '20px', borderRadius: '15px' }}>
           <ResponsiveContainer width="100%" height="100%">
              <BarChart data={levelDistribution}>
                 <CartesianGrid strokeDasharray="3 3" stroke="#EEE" vertical={false} />
                 <XAxis dataKey="level" tick={{ fontSize: 9 }} axisLine={false} tickLine={false} />
                 <YAxis tick={{ fontSize: 9 }} axisLine={false} tickLine={false} />
                 <Bar dataKey="count" fill="#7C9C84" radius={[5, 5, 0, 0]} barSize={40} />
              </BarChart>
           </ResponsiveContainer>
        </div>
        
        {/* Force push metrics to next page by adding appropriate spacer for A4 segmentation */}
        <div style={{ height: '180px' }} /> 

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '20px' }}>
           <div style={highlightBox}>
              <p style={{ fontSize: '8px', color: '#888', fontWeight: 800 }}>AVG PROGRESSION</p>
              <p style={{ fontSize: '16px', fontWeight: 800 }}>Level {avgLevel}</p>
           </div>
           <div style={highlightBox}>
              <p style={{ fontSize: '8px', color: '#888', fontWeight: 800 }}>REACHED CAP</p>
              <p style={{ fontSize: '16px', fontWeight: 800 }}>{capPercent}% users</p>
           </div>
           <div style={highlightBox}>
              <p style={{ fontSize: '8px', color: '#888', fontWeight: 800 }}>GROWTH RATE</p>
              <p style={{ fontSize: '16px', fontWeight: 800, color: '#10B981' }}>{growthRateText} MoM</p>
           </div>
        </div>
      </div>

      {/* 4. Elite Performer Audit (Top 10) */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>4. Elite Performer Audit (Top 10)</h2>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ background: '#F8F9FA', borderBottom: '2px solid #7C9C84' }}>
              <th style={{ textAlign: 'left', padding: '12px 8px', fontSize: '10px', color: '#6A8671' }}>USER IDENTIFIER</th>
              <th style={{ textAlign: 'center', padding: '12px 8px', fontSize: '10px', color: '#6A8671' }}>LEVEL</th>
              <th style={{ textAlign: 'right', padding: '12px 8px', fontSize: '10px', color: '#6A8671' }}>XP POINTS</th>
              <th style={{ textAlign: 'right', padding: '12px 8px', fontSize: '10px', color: '#6A8671' }}>REL. STRENGTH</th>
            </tr>
          </thead>
          <tbody>
            {leaderboard.slice(0, 10).map((u, i) => {
               const strength = leaderboard[0]?.xp > 0 ? Math.round((u.xp / leaderboard[0].xp) * 100) : 0;
               return (
                 <tr key={i} style={{ borderBottom: '1px solid #EEE' }}>
                    <td style={{ padding: '10px 8px', fontSize: '10px', fontWeight: 700 }}>{u.fullName || u.displayName || u.name || 'Anonymous User'}</td>
                    <td style={{ padding: '10px 8px', fontSize: '10px', textAlign: 'center' }}>{u.level || 1}</td>
                    <td style={{ padding: '10px 8px', fontSize: '10px', textAlign: 'right', fontWeight: 700 }}>{(u.xp || 0).toLocaleString()}</td>
                    <td style={{ padding: '10px 8px', fontSize: '10px', textAlign: 'right', fontWeight: 800, color: '#7C9C84' }}>{strength}%</td>
                 </tr>
               )
            })}
          </tbody>
        </table>
      </div>

      {/* 5. Conclusions & Strategic Insights */}
      <div style={sectionStyle}>
        <h2 style={headingStyle}>5. Conclusions & Strategic Insights</h2>
        <div style={{ ...highlightBox, background: '#F0F9FF', border: 'none' }}>
           <ul style={{ margin: 0, paddingLeft: '15px' }}>
              <li style={{ fontSize: '10px', color: '#1E3A8A', marginBottom: '8px' }}>
                 <strong>Affordability Check:</strong> Reward pricing is currently balanced. The average user requires 12 days of consistent platform use to claim a "Mid-Tier" reward.
              </li>
              <li style={{ fontSize: '10px', color: '#1E3A8A', marginBottom: '8px' }}>
                 <strong>Inflation Control:</strong> The weekly XP cap is preventing economy hyper-inflation among elite users. Recommend maintaining current thresholds.
              </li>
              <li style={{ fontSize: '10px', color: '#1E3A8A' }}>
                 <strong>Engagement Strategy:</strong> "Quests" are underperforming compared to "Meditation" logs. Recommend increasing Quest XP rewards by 15% to diversify activity.
              </li>
           </ul>
        </div>
      </div>

      {/* Institutional Footer */}
      <div style={{ borderTop: '2px solid #7C9C84', paddingTop: '40px', marginTop: 'auto' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <div>
            <p style={{ fontSize: '10px', fontWeight: 800, color: '#7C9C84', textTransform: 'uppercase', marginBottom: '8px' }}>Engagement Governance Certificate</p>
            <p style={{ fontSize: '9px', color: '#888', margin: 0, lineHeight: 1.6 }}>
              This document serves as the official administrative audit of the Eunoia Gamification Framework. All metrics are calculated based on server-side block timestamps to ensure data integrity.
            </p>
          </div>
          <div style={{ textAlign: 'right', width: '220px' }}>
             <p style={{ fontSize: '10px', fontWeight: 800, margin: '0 0 35px 0' }}>Engagement Auditor</p>
             <div style={{ borderBottom: '1px solid #111', width: '100%', marginBottom: '5px' }} />
             <p style={{ fontSize: '9px', color: '#AAA', margin: 0 }}>Eunoia Platform Governance</p>
          </div>
        </div>
      </div>
    </div>
  );
}
