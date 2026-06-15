import React, { useState, useEffect } from 'react';
import { collection, query, where, getDocs, doc, getDoc, addDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { Clock, Users, Star, Calendar, Activity, ChevronRight, Database, X, CheckCircle2, DollarSign } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

let dashboardCache = null;

export default function Dashboard() {
  const [stats, setStats] = useState(dashboardCache ? dashboardCache.stats : { todayCount: 0, patientCount: 0, rating: 4.9, upcomingCount: 0, earnings: 0, latestReview: null, weeklyData: [], performanceText: 'Calculating...' });
  const [upcomingSessions, setUpcomingSessions] = useState(dashboardCache ? dashboardCache.upcomingSessions : []);
  const [loading, setLoading] = useState(dashboardCache ? false : true);
  const [flashMessage, setFlashMessage] = useState(null);
  const [counsellorName, setCounsellorName] = useState('Counsellor');
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
    const fetchDashboardData = async (user) => {
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
        let totalEarnings = 0;
        let upcomingTotalCount = 0;

        let realName = user.displayName || 'Counsellor';
        try {
          const userDocRef = doc(db, 'users', user.uid);
          const userDocSnap = await getDoc(userDocRef);
          if (userDocSnap.exists()) {
            const uData = userDocSnap.data();
            realName = uData.name || uData.fullName || realName;
          }
        } catch (e) {
          console.error("Error fetching counsellor name:", e);
        }
        setCounsellorName(realName);

        const now = new Date();
        const thisWeekStart = new Date(now);
        thisWeekStart.setDate(now.getDate() - 7);
        const lastWeekStart = new Date(now);
        lastWeekStart.setDate(now.getDate() - 14);

        let thisWeekCount = 0;
        let lastWeekCount = 0;

        // Track completed sessions by day for the last 7 days
        const last7Days = [];
        for (let i = 6; i >= 0; i--) {
          const d = new Date(now);
          d.setDate(d.getDate() - i);
          d.setHours(0,0,0,0);
          last7Days.push({
            dateObj: d,
            day: d.toLocaleDateString('en-US', { weekday: 'short' }),
            count: 0
          });
        }

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

          const statusUpper = data.status?.toUpperCase() || '';
          if (statusUpper === 'COMPLETED' && data.price) {
            totalEarnings += Number(data.price);
          }
          if (statusUpper === 'CONFIRMED' || statusUpper === 'PENDING' || statusUpper === 'RESCHEDULED' || statusUpper === 'UPCOMING') {
            upcomingTotalCount++;
          }
          
          if (statusUpper === 'COMPLETED' && apptDate) {
            const t = apptDate.getTime();
            if (t >= thisWeekStart.getTime() && t <= now.getTime()) {
              thisWeekCount++;
            } else if (t >= lastWeekStart.getTime() && t < thisWeekStart.getTime()) {
              lastWeekCount++;
            }
            
            const aptDateOnly = new Date(apptDate);
            aptDateOnly.setHours(0,0,0,0);
            const targetDay = last7Days.find(d => d.dateObj.getTime() === aptDateOnly.getTime());
            if (targetDay) {
              targetDay.count++;
            }
          }
        });

        // Compute max for weekly engagement graph
        let maxCount = 0;
        last7Days.forEach(d => {
          if (d.count > maxCount) maxCount = d.count;
        });
        const weeklyData = last7Days.map(d => ({
          day: d.day,
          val: maxCount === 0 ? 0 : (d.count / maxCount) * 100,
          rawCount: d.count
        }));

        let performanceDelta = 0;
        if (lastWeekCount > 0) {
          performanceDelta = Math.round(((thisWeekCount - lastWeekCount) / lastWeekCount) * 100);
        } else if (thisWeekCount > 0) {
          performanceDelta = 100;
        }

        const performanceText = performanceDelta >= 0 
          ? `You performed ${performanceDelta}% better this week compared to last week.`
          : `Your completed sessions are down by ${Math.abs(performanceDelta)}% this week.`;

        // Filter for upcoming (CONFIRMED, PENDING, RESCHEDULED, UPCOMING) sessions
        const upcomingFiltered = bookingsList
          .filter(a => {
            const stat = a.status?.toUpperCase() || '';
            if (stat !== 'CONFIRMED' && stat !== 'PENDING' && stat !== 'RESCHEDULED' && stat !== 'UPCOMING') return false;
            // Exclude sessions that have already passed
            if (a.resolvedDate && a.resolvedDate < now) return false;
            return true;
          })
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

        // Fetch dynamic rating from counsellor_reviews
        let averageRating = 0;
        let latestReview = null;
        try {
          const qReviews = query(
            collection(db, 'counsellor_reviews'),
            where('counsellorId', '==', user.uid)
          );
          const reviewsSnap = await getDocs(qReviews);
          let totalScore = 0;
          let count = 0;
          let reviewsList = [];
          reviewsSnap.forEach((docSnap) => {
            const data = docSnap.data();
            totalScore += (data.rating || 5);
            count++;
            reviewsList.push(data);
          });
          if (count > 0) {
            averageRating = (totalScore / count).toFixed(1);
            latestReview = reviewsList[reviewsList.length - 1];
          }
        } catch (e) {
          console.error("Error fetching dynamic rating:", e);
        }

        const newStats = {
          todayCount: todaySessionsCount,
          patientCount: uniquePatients.size,
          rating: averageRating > 0 ? averageRating : 0,
          upcomingCount: upcomingTotalCount,
          earnings: totalEarnings,
          latestReview: latestReview,
          weeklyData: weeklyData,
          performanceText: performanceText
        };
        
        setStats(newStats);
        setUpcomingSessions(resolvedSessions);
        
        dashboardCache = {
          stats: newStats,
          upcomingSessions: resolvedSessions
        };

      } catch (err) {
        console.error("Error loading dashboard data:", err);
      } finally {
        setLoading(false);
      }
    };

    const unsubscribe = auth.onAuthStateChanged(user => {
      if (user) {
        fetchDashboardData(user);
      } else {
        if (typeof setLoading === 'function') setLoading(false);
      }
    });
    return () => unsubscribe();
  }, []);

  const formatDate = (dateObj) => {
    if (!dateObj) return 'TBD';
    return dateObj.toLocaleDateString('en-US', { weekday: 'short', month: 'short', day: 'numeric' });
  };


  return (
    <div>
      <header className="page-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h1 className="page-title">Welcome back, {counsellorName}</h1>
          <p className="page-subtitle">Here is your Eunoia support center dashboard overview.</p>
        </div>
      </header>



      {/* KPI Stats Cards */}
      <div className="grid-3" style={{ marginBottom: '32px' }}>
        <div className="card stat-card" onClick={() => navigate('/patients')} style={{ cursor: 'pointer', transition: 'transform 0.2s', ':hover': { transform: 'translateY(-2px)' } }}>
          <div>
            <p className="stat-title">Total Users</p>
            <p className="stat-value">{stats.patientCount}</p>
          </div>
          <div className="stat-icon-wrapper">
            <Users size={24} />
          </div>
        </div>

        <div className="card stat-card" onClick={() => navigate('/sessions')} style={{ cursor: 'pointer', transition: 'transform 0.2s', ':hover': { transform: 'translateY(-2px)' } }}>
          <div>
            <p className="stat-title">Upcoming Sessions</p>
            <p className="stat-value">{stats.upcomingCount}</p>
          </div>
          <div className="stat-icon-wrapper">
            <Clock size={24} />
          </div>
        </div>

        <div className="card stat-card" onClick={() => navigate('/wallet')} style={{ cursor: 'pointer', transition: 'transform 0.2s', ':hover': { transform: 'translateY(-2px)' } }}>
          <div>
            <p className="stat-title">Total Earnings</p>
            <p className="stat-value">${stats.earnings.toFixed(2)}</p>
          </div>
          <div className="stat-icon-wrapper">
            <DollarSign size={24} />
          </div>
        </div>
      </div>

      {/* Main Layout (2/3 and 1/3) */}
      <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '24px', alignItems: 'start' }}>
        
        {/* Left Column (2/3) */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          
          {/* Upcoming Appointments */}
          <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div className="flex-between">
            <div>
              <h2 style={{ fontSize: '20px', fontWeight: 700, color: 'var(--text-darker)' }}>Upcoming Appointments</h2>
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
                <div 
                  key={session.id} 
                  className="session-item card" 
                  onClick={() => navigate('/sessions')}
                  style={{ 
                    cursor: 'pointer', 
                    display: 'flex', 
                    justifyContent: 'space-between',
                    padding: '16px',
                    marginBottom: '8px',
                    transition: 'all 0.2s ease',
                    border: '1px solid var(--border-color)',
                    boxShadow: '0 2px 8px rgba(0,0,0,0.02)'
                  }}
                  onMouseOver={(e) => {
                    e.currentTarget.style.transform = 'translateY(-2px)';
                    e.currentTarget.style.borderColor = 'var(--primary-color)';
                  }}
                  onMouseOut={(e) => {
                    e.currentTarget.style.transform = 'translateY(0)';
                    e.currentTarget.style.borderColor = 'var(--border-color)';
                  }}
                >
                  <div style={{ display: 'flex', gap: '16px', alignItems: 'center' }}>
                    <div className="session-avatar" style={{ width: '44px', height: '44px', borderRadius: '50%', backgroundColor: '#EAF2ED', color: 'var(--primary-color)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: '16px' }}>
                      {session.patientName.charAt(0)}
                    </div>
                    <div>
                      <h4 style={{ fontSize: '16px', fontWeight: '700', color: 'var(--text-darker)', marginBottom: '4px' }}>
                        {session.patientName}
                      </h4>
                      <p style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '6px' }}>
                        <Calendar size={12} /> {session.resolvedDate ? formatToDDMMMYYYY(session.resolvedDate) : session.date} 
                        <span style={{ margin: '0 4px' }}>•</span>
                        <Clock size={12} /> {session.timeRange || session.time || 'TBD'}
                      </p>
                    </div>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                    <span className="session-status status-scheduled" style={{ textTransform: 'capitalize', fontSize: '12px', padding: '6px 10px', borderRadius: '8px', fontWeight: 600, backgroundColor: '#FFF9E6', color: '#D99E00' }}>
                      {session.status?.toLowerCase()}
                    </span>
                    <ChevronRight size={18} style={{ color: 'var(--text-muted)' }} />
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Column 2: Weekly Metrics & Copy */}
        <div 
          className="card" 
          onClick={() => navigate('/performance')}
          style={{ cursor: 'pointer', display: 'flex', flexDirection: 'column', gap: '20px', transition: 'all 0.2s ease' }}
          onMouseOver={(e) => { e.currentTarget.style.transform = 'translateY(-2px)'; e.currentTarget.style.boxShadow = '0 12px 24px rgba(0,0,0,0.06)'; }}
          onMouseOut={(e) => { e.currentTarget.style.transform = 'translateY(0)'; e.currentTarget.style.boxShadow = '0 8px 24px rgba(124, 156, 132, 0.03)'; }}
        >
          <div>
            <h2 style={{ fontSize: '20px', fontWeight: 700, color: 'var(--text-darker)' }}>Weekly Engagement</h2>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Completed sessions over the last 7 days</p>
          </div>

          {/* Styled CSS Bar Chart */}
          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', height: '160px', padding: '10px 20px 0 20px', borderBottom: '1px solid var(--border-color)', margin: '10px 0' }}>
            {(stats.weeklyData || []).map((d, i) => (
              <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flex: 1, gap: '8px' }}>
                <div style={{ position: 'relative', width: '32px', height: '120px', display: 'flex', alignItems: 'flex-end' }}>
                  <div 
                    style={{ 
                      width: '100%', 
                      height: `${Math.max(d.val, 2)}%`, 
                      background: 'linear-gradient(to top, #7C9C84, #a3bba9)', 
                      borderRadius: '6px 6px 0 0',
                      transition: 'all 0.6s cubic-bezier(0.4, 0, 0.2, 1)',
                      opacity: d.val === 0 ? 0.3 : 1
                    }} 
                    title={`${d.rawCount} Sessions`}
                  />
                </div>
                <span style={{ fontSize: '11px', color: 'var(--text-muted)', fontWeight: 500 }}>{d.day}</span>
              </div>
            ))}
          </div>
          </div>
        </div>

        {/* Right Column (1/3) */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          
          {/* Quick Actions (Vertical) */}
          <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            <h2 style={{ fontSize: '20px', fontWeight: 700, color: 'var(--text-darker)', marginBottom: '4px' }}>Quick Actions</h2>
            
            <div onClick={() => navigate('/availability')} style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '12px', backgroundColor: 'var(--bg-secondary)', borderRadius: '12px', cursor: 'pointer', transition: 'all 0.2s' }} onMouseOver={e=>e.currentTarget.style.backgroundColor='var(--border-color)'} onMouseOut={e=>e.currentTarget.style.backgroundColor='var(--bg-secondary)'}>
              <div style={{ width: '36px', height: '36px', borderRadius: '10px', backgroundColor: 'var(--bg-card)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--primary-color)' }}>
                <Clock size={18} />
              </div>
              <span style={{ fontSize: '13px', fontWeight: 500, color: 'var(--text-darker)' }}>Set Availability</span>
              <ChevronRight size={16} style={{ marginLeft: 'auto', color: 'var(--text-muted)' }} />
            </div>

            <div onClick={() => navigate('/patients')} style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '12px', backgroundColor: 'var(--bg-secondary)', borderRadius: '12px', cursor: 'pointer', transition: 'all 0.2s' }} onMouseOver={e=>e.currentTarget.style.backgroundColor='var(--border-color)'} onMouseOut={e=>e.currentTarget.style.backgroundColor='var(--bg-secondary)'}>
              <div style={{ width: '36px', height: '36px', borderRadius: '10px', backgroundColor: 'var(--bg-card)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--primary-color)' }}>
                <Users size={18} />
              </div>
              <span style={{ fontSize: '13px', fontWeight: 500, color: 'var(--text-darker)' }}>View Patients</span>
              <ChevronRight size={16} style={{ marginLeft: 'auto', color: 'var(--text-muted)' }} />
            </div>

            <div onClick={() => navigate('/wallet')} style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '12px', backgroundColor: 'var(--bg-secondary)', borderRadius: '12px', cursor: 'pointer', transition: 'all 0.2s' }} onMouseOver={e=>e.currentTarget.style.backgroundColor='var(--border-color)'} onMouseOut={e=>e.currentTarget.style.backgroundColor='var(--bg-secondary)'}>
              <div style={{ width: '36px', height: '36px', borderRadius: '10px', backgroundColor: 'var(--bg-card)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--primary-color)' }}>
                <DollarSign size={18} />
              </div>
              <span style={{ fontSize: '13px', fontWeight: 500, color: 'var(--text-darker)' }}>Withdraw Earnings</span>
              <ChevronRight size={16} style={{ marginLeft: 'auto', color: 'var(--text-muted)' }} />
            </div>
          </div>

          <div 
            className="card" 
            onClick={() => navigate('/performance')}
            style={{ cursor: 'pointer', display: 'flex', flexDirection: 'column', gap: '20px', transition: 'all 0.2s ease' }}
            onMouseOver={(e) => { e.currentTarget.style.transform = 'translateY(-2px)'; e.currentTarget.style.boxShadow = '0 12px 24px rgba(0,0,0,0.06)'; }}
            onMouseOut={(e) => { e.currentTarget.style.transform = 'translateY(0)'; e.currentTarget.style.boxShadow = '0 8px 24px rgba(124, 156, 132, 0.03)'; }}
          >
            <div>
              <h2 style={{ fontSize: '20px', fontWeight: 700, color: 'var(--text-darker)' }}>Performance Insights</h2>
              <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Your stats and patient feedback</p>
            </div>
            
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', backgroundColor: 'var(--bg-secondary)', padding: '14px', borderRadius: '16px' }}>
            <div style={{ color: 'var(--primary-color)', backgroundColor: 'var(--bg-card)', padding: '8px', borderRadius: '10px', display: 'flex', alignItems: 'center' }}>
              <Activity size={18} />
            </div>
            <div>
              <p style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-darker)' }}>Active Counseling Performance</p>
              <p style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{stats.performanceText}</p>
            </div>
          </div>

          {/* Recent Reviews & Ratings */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', backgroundColor: 'var(--bg-secondary)', padding: '16px', borderRadius: '16px', marginTop: '2px' }}>
            <div className="flex-between">
              <h3 style={{ fontSize: '14px', fontWeight: 600, color: 'var(--text-darker)' }}>Overall Rating</h3>
              <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                <Star size={16} style={{ color: '#f59e0b', fill: '#f59e0b' }} />
                <span style={{ fontSize: '14px', fontWeight: 600 }}>{stats.rating}</span>
              </div>
            </div>
            {stats.latestReview ? (
              <div style={{ padding: '12px', backgroundColor: 'var(--bg-card)', borderRadius: '12px' }}>
                <p style={{ fontSize: '12px', color: 'var(--text-darker)', fontStyle: 'italic' }}>"{stats.latestReview.comment || 'Great session, highly recommended!'}"</p>
                <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '8px', textAlign: 'right' }}>- {stats.latestReview.patientName || 'Anonymous'}</p>
              </div>
            ) : (
              <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>No recent reviews available.</p>
            )}
          </div>
        </div>
      </div>
    </div>

      {/* Flash Message Toast */}
      {flashMessage && (
        <div style={{ 
          position: 'fixed', 
          bottom: '32px', 
          right: '32px', 
          zIndex: 1100,
          padding: '16px 24px', 
          backgroundColor: flashMessage.type === 'error' ? '#fee2e2' : 'var(--bg-card)', 
          color: flashMessage.type === 'error' ? '#dc2626' : 'var(--primary-color)', 
          borderRadius: '12px', 
          display: 'flex', 
          alignItems: 'center', 
          gap: '12px', 
          fontWeight: 600, 
          border: flashMessage.type === 'error' ? '1px solid #fca5a5' : '1px solid var(--primary-light)',
          boxShadow: '0 10px 25px rgba(0, 0, 0, 0.1)',
          animation: 'slideUp 0.3s cubic-bezier(0.16, 1, 0.3, 1)'
        }}>
          {flashMessage.type === 'error' ? <X size={20} /> : <CheckCircle2 size={24} />} 
          {flashMessage.text}
        </div>
      )}
    </div>
  );
}
