import React, { useState, useEffect } from 'react';
import { collection, query, where, getDocs, doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { Clock, Users, Star, Calendar, Activity, ChevronRight } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

export default function Dashboard() {
  const [stats, setStats] = useState({ todayCount: 0, patientCount: 0, rating: 4.9 });
  const [upcomingSessions, setUpcomingSessions] = useState([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  // Helper to format Date to "dd MMM yyyy" to match mobile app DateFormat
  const formatToDDMMMYYYY = (dateObj) => {
    const day = String(dateObj.getDate()).padStart(2, '0');
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const month = months[dateObj.getMonth()];
    const year = dateObj.getFullYear();
    return `${day} ${month} ${year}`;
  };

  useEffect(() => {
    const fetchDashboardData = async () => {
      const user = auth.currentUser;
      if (!user) return;

      try {
        // Query counsellor_bookings for current counsellor
        const qBookings = query(
          collection(db, 'counsellor_bookings'),
          where('counsellorId', '==', user.uid)
        );
        const snapshot = await getDocs(qBookings);
        const bookingsList = [];
        const uniquePatients = new Set();
        
        const todayStr = formatToDDMMMYYYY(new Date());
        let todaySessionsCount = 0;

        snapshot.forEach((docSnap) => {
          const data = docSnap.data();
          const bookingId = docSnap.id;
          let apptDate = null;
          
          if (data.startTime) {
            apptDate = data.startTime.seconds ? new Date(data.startTime.seconds * 1000) : new Date(data.startTime);
          } else if (data.date) {
            apptDate = new Date(data.date);
          }

          const resolvedPatientId = data.patientId || data.userId || '';

          bookingsList.push({
            id: bookingId,
            ...data,
            resolvedPatientId,
            resolvedDate: apptDate
          });

          if (resolvedPatientId) {
            uniquePatients.add(resolvedPatientId);
          }

          // Count today's sessions based on string date matching the mobile format
          if (data.date === todayStr) {
            todaySessionsCount++;
          }
        });

        // Filter for upcoming (CONFIRMED, PENDING, RESCHEDULED) sessions
        const upcomingFiltered = bookingsList
          .filter(a => a.status === 'CONFIRMED' || a.status === 'PENDING' || a.status === 'RESCHEDULED')
          .sort((a, b) => (a.resolvedDate || 0) - (b.resolvedDate || 0))
          .slice(0, 3);

        // Resolve patient names if needed, fall back to userName/patientName in document
        const resolvedSessions = await Promise.all(
          upcomingFiltered.map(async (booking) => {
            let patientName = booking.patientName || booking.userName || 'Valued Client';
            if (booking.resolvedPatientId && (!booking.patientName && !booking.userName)) {
              try {
                const userDocRef = doc(db, 'users', booking.resolvedPatientId);
                const userDocSnap = await getDoc(userDocRef);
                if (userDocSnap.exists()) {
                  const uData = userDocSnap.data();
                  patientName = uData.name || uData.fullName || uData.email || 'Valued Client';
                }
              } catch (e) {
                console.error("Error resolving patient name:", e);
              }
            }
            return {
              ...booking,
              patientName
            };
          })
        );

        // Fetch rating from user profile
        let rating = 4.9;
        try {
          const profileRef = doc(db, 'users', user.uid);
          const profileSnap = await getDoc(profileRef);
          if (profileSnap.exists()) {
            rating = profileSnap.data().rating || 4.9;
          }
        } catch (e) {
          console.error("Error fetching counsellor rating:", e);
        }

        setStats({
          todayCount: todaySessionsCount,
          patientCount: uniquePatients.size || 0,
          rating: rating
        });
        setUpcomingSessions(resolvedSessions);

      } catch (err) {
        console.error("Error loading dashboard data:", err);
      } finally {
        setLoading(false);
      }
    };

    fetchDashboardData();
  }, []);

  const formatDate = (dateObj) => {
    if (!dateObj) return 'TBD';
    return dateObj.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
  };

  return (
    <div>
      <header className="page-header">
        <h1 className="page-title">Welcome back, Counsellor</h1>
        <p className="page-subtitle">Here is your Eunoia support center dashboard overview.</p>
      </header>

      {/* KPI Stats Cards */}
      <div className="grid-3" style={{ marginBottom: '32px' }}>
        <div className="card stat-card">
          <div>
            <p className="stat-title">Today's Sessions</p>
            <p className="stat-value">{stats.todayCount}</p>
          </div>
          <div className="stat-icon-wrapper">
            <Clock size={24} />
          </div>
        </div>

        <div className="card stat-card">
          <div>
            <p className="stat-title">Total Active Patients</p>
            <p className="stat-value">{stats.patientCount}</p>
          </div>
          <div className="stat-icon-wrapper">
            <Users size={24} />
          </div>
        </div>

        <div className="card stat-card">
          <div>
            <p className="stat-title">Average Rating</p>
            <p className="stat-value">{stats.rating} <span style={{ fontSize: '16px', color: '#f59e0b', fontWeight: 'normal' }}>★</span></p>
          </div>
          <div className="stat-icon-wrapper">
            <Star size={24} />
          </div>
        </div>
      </div>

      {/* Main Split Layout */}
      <div className="grid-2">
        
        {/* Column 1: Upcoming Appointments */}
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div className="flex-between">
            <div>
              <h2 style={{ fontSize: '18px', fontWeight: 700, color: 'var(--text-darker)' }}>Upcoming Appointments</h2>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Your next scheduled consultations</p>
            </div>
            <button onClick={() => navigate('/sessions')} className="btn btn-secondary" style={{ padding: '8px 14px', fontSize: '12px' }}>
              View Schedule
            </button>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '4px' }}>
            {loading ? (
              <div style={{ padding: '30px', textAlign: 'center', color: 'var(--text-muted)' }}>Loading sessions…</div>
            ) : upcomingSessions.length === 0 ? (
              <div style={{ padding: '40px 20px', textAlign: 'center', border: '1px dashed var(--border-color)', borderRadius: '18px', backgroundColor: 'var(--bg-secondary)' }}>
                <Calendar size={32} style={{ color: 'var(--text-muted)', marginBottom: '8px', opacity: 0.6 }} />
                <p style={{ fontSize: '14px', fontWeight: 500, color: 'var(--text-darker)' }}>No Upcoming Sessions</p>
                <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginTop: '2px' }}>New booking requests will appear here.</p>
              </div>
            ) : (
              upcomingSessions.map((session) => (
                <div key={session.id} className="session-item">
                  <div style={{ display: 'flex', gap: '14px', alignItems: 'center' }}>
                    <div className="session-avatar">
                      {session.patientName.charAt(0)}
                    </div>
                    <div>
                      <h4 style={{ fontSize: '15px', fontWeight: '600', color: 'var(--text-darker)', marginBottom: '2px' }}>
                        {session.patientName}
                      </h4>
                      <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                        {session.date} · {session.timeRange || session.time || 'TBD'}
                      </p>
                    </div>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <span className="session-status status-scheduled" style={{ textTransform: 'capitalize' }}>
                      {session.status?.toLowerCase()}
                    </span>
                    <ChevronRight size={16} style={{ color: 'var(--text-muted)' }} />
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Column 2: Weekly Metrics & Copy */}
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div>
            <h2 style={{ fontSize: '18px', fontWeight: 700, color: 'var(--text-darker)' }}>Weekly Engagement</h2>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Completed sessions over the last 7 days</p>
          </div>

          {/* Styled CSS Bar Chart */}
          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', height: '140px', padding: '10px 10px 0 10px', borderBottom: '1px solid var(--border-color)', margin: '10px 0' }}>
            {[
              { day: 'Mon', val: 30 },
              { day: 'Tue', val: 65 },
              { day: 'Wed', val: 45 },
              { day: 'Thu', val: 80 },
              { day: 'Fri', val: 95 },
              { day: 'Sat', val: 20 },
              { day: 'Sun', val: 10 }
            ].map((d, i) => (
              <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flex: 1, gap: '8px' }}>
                <div style={{ position: 'relative', width: '20px', height: '100px', display: 'flex', alignItems: 'flex-end' }}>
                  <div 
                    style={{ 
                      width: '100%', 
                      height: `${d.val}%`, 
                      background: 'linear-gradient(to top, #7C9C84, #a3bba9)', 
                      borderRadius: '4px 4px 0 0',
                      transition: 'all 0.6s cubic-bezier(0.4, 0, 0.2, 1)',
                    }} 
                    title={`${d.val}% Capacity`}
                  />
                </div>
                <span style={{ fontSize: '11px', color: 'var(--text-muted)', fontWeight: 500 }}>{d.day}</span>
              </div>
            ))}
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '12px', backgroundColor: 'var(--bg-secondary)', padding: '14px', borderRadius: '16px' }}>
            <div style={{ color: 'var(--primary-color)', backgroundColor: 'white', padding: '8px', borderRadius: '10px', display: 'flex', alignItems: 'center' }}>
              <Activity size={18} />
            </div>
            <div>
              <p style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-darker)' }}>Active Counseling Performance</p>
              <p style={{ fontSize: '11px', color: 'var(--text-muted)' }}>You performed 18% better this week compared to last week.</p>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
}
