import { ShieldAlert, MessageCircle, AlertTriangle, Zap } from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';
import { useChatSessions } from '../../hooks/useFirestore';

const C = { 
  primary: '#7C9C84', 
  cream: '#F6F5F2', 
  creamDarker: '#E5E4E0', 
  sage100: '#E5EDE8', 
  charcoal: '#333', 
  charcoalMuted: '#666',
  muted: '#888',
  red: '#ef4444'
};

export default function ChatbotMonitoring() {
  const { data: sessions, loading } = useChatSessions();

  const crisisSessions = sessions.filter(s => s.crisisDetected || s.crisis_detected);
  
  // Calculate stats
  const totalChats = sessions.length;
  const totalCrisis = crisisSessions.length;
  const detectionRate = totalChats > 0 ? ((totalCrisis / totalChats) * 100).toFixed(1) : '0.0';

  // Group by day for chart (simple mock grouping for now based on current week)
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const chartData = days.map(day => {
    // In a real app, we'd filter sessions by timestamp for each day
    // For now, we'll use actual data but distributed (mocked distribution)
    return {
      day,
      chats: Math.round(totalChats / 7) + Math.floor(Math.random() * 5),
      crisis: Math.round(totalCrisis / 7) + (Math.random() > 0.8 ? 1 : 0)
    };
  });

  return (
    <div className="flex flex-col gap-6">
      <div>
        <p className="section-label mb-1">Monitoring & Analytics</p>
        <h2 className="font-display font-semibold text-2xl text-charcoal">Chatbot Usage</h2>
      </div>

      {loading ? (
        <p className="font-body text-sm text-charcoal-muted">Loading analytics…</p>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="card text-center flex flex-col items-center gap-2">
              <div className="w-10 h-10 rounded-full bg-sage-100 flex items-center justify-center text-primary">
                <MessageCircle size={20} />
              </div>
              <div>
                <p className="section-label text-[10px]">Total Chats</p>
                <p className="font-display font-semibold text-3xl text-primary">{totalChats}</p>
              </div>
            </div>
            <div className="card text-center flex flex-col items-center gap-2">
              <div className="w-10 h-10 rounded-full bg-red-50 flex items-center justify-center text-red-500">
                <ShieldAlert size={20} />
              </div>
              <div>
                <p className="section-label text-[10px]">Crisis Detected</p>
                <p className="font-display font-semibold text-3xl text-red-500">{totalCrisis}</p>
              </div>
            </div>
            <div className="card text-center flex flex-col items-center gap-2">
              <div className="w-10 h-10 rounded-full bg-amber-50 flex items-center justify-center text-amber-500">
                <Zap size={20} fill="currentColor" />
              </div>
              <div>
                <p className="section-label text-[10px]">Detection Rate</p>
                <p className="font-display font-semibold text-3xl text-amber-500">{detectionRate}%</p>
              </div>
            </div>
          </div>

          <div className="card">
            <p className="section-label mb-4">Chat Volume & Crisis Trend (Weekly)</p>
            <ResponsiveContainer width="100%" height={220}>
              <AreaChart data={chartData}>
                <defs>
                  <linearGradient id="cg" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#7C9C84" stopOpacity={0.15} />
                    <stop offset="95%" stopColor="#7C9C84" stopOpacity={0} />
                  </linearGradient>
                  <linearGradient id="cr" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#ef4444" stopOpacity={0.15} />
                    <stop offset="95%" stopColor="#ef4444" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#EEEDE9" />
                <XAxis dataKey="day" tick={{ fontFamily: 'Outfit', fontSize: 11, fill: '#aaa' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontFamily: 'Outfit', fontSize: 11, fill: '#aaa' }} axisLine={false} tickLine={false} />
                <Tooltip contentStyle={{ fontFamily: 'Outfit', borderRadius: '12px', border: '1px solid #EEEDE9', fontSize: 12 }} />
                <Area type="monotone" dataKey="chats" stroke="#7C9C84" strokeWidth={2.5} fill="url(#cg)" name="Chats" />
                <Area type="monotone" dataKey="crisis" stroke="#ef4444" strokeWidth={2} fill="url(#cr)" name="Crisis" />
              </AreaChart>
            </ResponsiveContainer>
          </div>

          <div className="card border border-red-100">
            <div className="flex items-center gap-2 mb-4">
              <AlertTriangle size={16} className="text-red-400" />
              <p className="section-label text-red-500" style={{ color: '#ef4444' }}>Live Crisis Keyword Log</p>
            </div>
            <div className="flex flex-col gap-3">
              {crisisSessions.length === 0 ? (
                <p className="text-center py-6 font-body text-charcoal-muted text-sm italic">No active crisis alerts. Everything is calm 🌿</p>
              ) : (
                crisisSessions.slice(0, 5).map((s, i) => (
                  <div key={s.id || i} className="flex items-center justify-between bg-cream rounded-2xl px-4 py-3 border border-red-50">
                    <div>
                      <p className="font-body font-semibold text-sm text-charcoal">{s.userName || 'Anonymous User'}</p>
                      <p className="font-body text-xs text-charcoal-muted mt-0.5">
                        Trigger Keyword: <span className="font-bold text-red-500">"{s.crisisKeyword || 'Self-Harm Risk'}"</span>
                      </p>
                    </div>
                    <div className="flex items-center gap-3">
                      <span className={s.status === 'Escalated' ? 'badge-red' : 'badge-amber'}>
                        {s.status === 'Escalated' ? 'Escalated' : 'Action Required'}
                      </span>
                      <span className="font-body text-[10px] text-charcoal-subtle uppercase font-bold tracking-tighter">
                        {s.createdAt?.toDate ? s.createdAt.toDate().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : 'Recent'}
                      </span>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
