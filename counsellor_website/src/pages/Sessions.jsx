import React, { useState, useEffect } from 'react';
import { collection, query, where, getDocs, updateDoc, doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { Calendar as CalIcon, Clock, CheckCircle2, Video, X, FileText, AlertTriangle } from 'lucide-react';

let sessionsCache = null;

export default function Sessions() {
  const [appointments, setAppointments] = useState(sessionsCache ? sessionsCache.appointments : []);
  const [activeTab, setActiveTab] = useState('upcoming');
  const [loading, setLoading] = useState(sessionsCache ? false : true);
  const [updatingId, setUpdatingId] = useState(null);
  const [missedConfirmId, setMissedConfirmId] = useState(null);
  const [missedReason, setMissedReason] = useState('');
  const [flashMessage, setFlashMessage] = useState(null);

  const [selectedDate, setSelectedDate] = useState(new Date());

  const getFormatStr = (d) => {
    if (!d) return null;
    const day = String(d.getDate()).padStart(2, '0');
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return `${day} ${months[d.getMonth()]} ${d.getFullYear()}`;
  };

  const selectedDateStr = getFormatStr(selectedDate);

  const handlePrevDay = () => {
    if (!selectedDate) {
      setSelectedDate(new Date());
    } else {
      const d = new Date(selectedDate);
      d.setDate(d.getDate() - 1);
      setSelectedDate(d);
    }
  };

  const handleNextDay = () => {
    if (!selectedDate) {
      setSelectedDate(new Date());
    } else {
      const d = new Date(selectedDate);
      d.setDate(d.getDate() + 1);
      setSelectedDate(d);
    }
  };

  const [isCalendarOpen, setIsCalendarOpen] = useState(false);
  const [calendarViewDate, setCalendarViewDate] = useState(new Date());

  const getDaysInMonth = (year, month) => new Date(year, month + 1, 0).getDate();
  const getFirstDayOfMonth = (year, month) => new Date(year, month, 1).getDay();

  const renderCalendar = () => {
    const year = calendarViewDate.getFullYear();
    const month = calendarViewDate.getMonth();
    const daysInMonth = getDaysInMonth(year, month);
    const firstDay = getFirstDayOfMonth(year, month);
    const prevMonthDays = getDaysInMonth(year, month - 1);

    const days = [];
    for (let i = firstDay - 1; i >= 0; i--) {
      days.push({ day: prevMonthDays - i, isCurrentMonth: false, date: new Date(year, month - 1, prevMonthDays - i) });
    }
    for (let i = 1; i <= daysInMonth; i++) {
      days.push({ day: i, isCurrentMonth: true, date: new Date(year, month, i) });
    }
    const remainingCells = 42 - days.length;
    for (let i = 1; i <= remainingCells; i++) {
      days.push({ day: i, isCurrentMonth: false, date: new Date(year, month + 1, i) });
    }

    const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    const weekDays = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];

    return (
      <div style={{ position: 'absolute', top: '100%', left: 0, marginTop: '8px', backgroundColor: 'var(--bg-card)', borderRadius: '12px', boxShadow: '0 4px 20px rgba(0,0,0,0.15)', border: '1px solid var(--border-color)', padding: '16px', zIndex: 100, width: '280px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
          <div style={{ fontWeight: 700, fontSize: '15px', color: 'var(--text-darker)' }}>
            {monthNames[month]} {year}
          </div>
          <div style={{ display: 'flex', gap: '4px' }}>
            <button 
              onClick={() => setCalendarViewDate(new Date(year, month - 1, 1))}
              style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: '4px', color: 'var(--text-muted)' }}
            >
              ↑
            </button>
            <button 
              onClick={() => setCalendarViewDate(new Date(year, month + 1, 1))}
              style={{ background: 'transparent', border: 'none', cursor: 'pointer', padding: '4px', color: 'var(--text-muted)' }}
            >
              ↓
            </button>
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: '4px', marginBottom: '8px' }}>
          {weekDays.map(wd => (
            <div key={wd} style={{ textAlign: 'center', fontSize: '12px', fontWeight: 600, color: 'var(--text-muted)' }}>{wd}</div>
          ))}
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: '4px' }}>
          {days.map((d, i) => {
            const isSelected = selectedDate && d.date.toDateString() === selectedDate.toDateString();
            const isToday = new Date().toDateString() === d.date.toDateString();
            return (
              <button
                key={i}
                onClick={() => {
                  setSelectedDate(d.date);
                  setIsCalendarOpen(false);
                }}
                style={{
                  background: isSelected ? 'var(--primary-color)' : 'transparent',
                  color: isSelected ? 'white' : (d.isCurrentMonth ? 'var(--text-darker)' : 'var(--text-muted)'),
                  border: isToday && !isSelected ? '1px solid var(--primary-color)' : 'none',
                  borderRadius: '6px',
                  padding: '6px 0',
                  fontSize: '13px',
                  fontWeight: isSelected ? 700 : 500,
                  cursor: 'pointer',
                  textAlign: 'center'
                }}
              >
                {d.day}
              </button>
            );
          })}
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '16px', paddingTop: '12px', borderTop: '1px solid var(--border-color)' }}>
          <button 
            onClick={() => { setSelectedDate(null); setIsCalendarOpen(false); }}
            style={{ background: 'transparent', border: 'none', color: 'var(--primary-color)', fontSize: '13px', fontWeight: 600, cursor: 'pointer' }}
          >
            Clear
          </button>
          <button 
            onClick={() => { setSelectedDate(new Date()); setCalendarViewDate(new Date()); setIsCalendarOpen(false); }}
            style={{ background: 'transparent', border: 'none', color: 'var(--primary-color)', fontSize: '13px', fontWeight: 600, cursor: 'pointer' }}
          >
            Today
          </button>
        </div>
      </div>
    );
  };
  const [showDetailsModal, setShowDetailsModal] = useState(false);
  const [selectedSession, setSelectedSession] = useState(null);

  const [showNotesModal, setShowNotesModal] = useState(false);
  const [activeNotesSession, setActiveNotesSession] = useState(null);
  const [clinicalNotes, setClinicalNotes] = useState('');

  const fetchAppointments = async (user) => {
    if (!sessionsCache) setLoading(true);

    try {
      const qBookings = query(
        collection(db, 'counsellor_bookings'),
        where('counsellorId', '==', user.uid)
      );
      const snap = await getDocs(qBookings);
      const apptsList = [];

      snap.forEach((docSnap) => {
        const data = docSnap.data();
        let apptDate = null;
        if (data.startTime) {
          apptDate = data.startTime.seconds ? new Date(data.startTime.seconds * 1000) : new Date(data.startTime);
        } else if (data.date) {
          apptDate = new Date(data.date);
        }

        const resolvedPatientId = data.patientId || data.userId || '';

        apptsList.push({
          id: docSnap.id,
          ...data,
          resolvedPatientId,
          resolvedDate: apptDate,
          patientName: data.patientName || data.userName || 'Valued Client'
        });
      });

      // Sort by date (nearest first)
      apptsList.sort((a, b) => (a.resolvedDate || 0) - (b.resolvedDate || 0));

      // Resolve usernames if placeholder and id exists
      const resolvedList = await Promise.all(
        apptsList.map(async (appt) => {
          if (appt.patientName !== 'Valued Client') return appt;
          if (!appt.resolvedPatientId) return appt;
          try {
            const userDocRef = doc(db, 'users', appt.resolvedPatientId);
            const userDocSnap = await getDoc(userDocRef);
            if (userDocSnap.exists()) {
              const uData = userDocSnap.data();
              return {
                ...appt,
                patientName: uData.name || uData.fullName || uData.email || 'Valued Client'
              };
            }
          } catch (e) {
            console.error("Error resolving patient name:", e);
          }
          return appt;
        })
      );

      setAppointments(resolvedList);
      sessionsCache = { appointments: resolvedList };
    } catch (e) {
      console.error("Error fetching appointments:", e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const unsubscribe = auth.onAuthStateChanged(user => {
      if (user) {
        fetchAppointments(user);
      } else {
        if (typeof setLoading === 'function') setLoading(false);
      }
    });
    return () => unsubscribe();
  }, []);

  const handleViewDetails = (appt) => {
    setSelectedSession(appt);
    setShowDetailsModal(true);
  };

  const handleCompleteSession = (apptId) => {
    setShowDetailsModal(false);
    setActiveNotesSession(apptId);
    setClinicalNotes('');
    setShowNotesModal(true);
  };

  const submitSessionComplete = async () => {
    if (!activeNotesSession) return;
    
    setUpdatingId(activeNotesSession);
    try {
      const apptRef = doc(db, 'counsellor_bookings', activeNotesSession);
      await updateDoc(apptRef, {
        status: 'COMPLETED',
        notes: clinicalNotes.trim(),
        sessionSummary: clinicalNotes.trim(),
        completedAt: new Date()
      });
      // Refresh list
      setShowNotesModal(false);
      setActiveNotesSession(null);
      await fetchAppointments();
    } catch (err) {
      console.error("Error updating appointment status:", err);
      setFlashMessage({ type: 'error', text: "Failed to complete session." });
      setTimeout(() => setFlashMessage(null), 3000);
    } finally {
      setUpdatingId(null);
    }
  };

  const handleMissedSession = (apptId) => {
    setMissedConfirmId(apptId);
    setMissedReason('');
  };

  const confirmMissedSession = async () => {
    if (!missedConfirmId) return;
    setUpdatingId(missedConfirmId);
    try {
      const apptRef = doc(db, 'counsellor_bookings', missedConfirmId);
      await updateDoc(apptRef, { 
        status: 'MISSED', 
        reason: missedReason.trim(),
        completedAt: new Date() 
      });
      setMissedConfirmId(null);
      await fetchAppointments();
    } catch (err) {
      console.error("Error marking session as missed:", err);
      setFlashMessage({ type: 'error', text: "Failed to update session." });
      setTimeout(() => setFlashMessage(null), 3000);
    } finally {
      setUpdatingId(null);
    }
  };
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const now = new Date();

  const filteredAppts = appointments.filter(a => {
    const statusUpper = a.status?.toUpperCase() || '';
    // Match mobile logic: only move to history tab if explicitly marked completed, missed, or cancelled.
    if (activeTab === 'upcoming') {
      return statusUpper !== 'COMPLETED' && statusUpper !== 'MISSED' && statusUpper !== 'CANCELLED';
    } else {
      return statusUpper === 'COMPLETED' || statusUpper === 'MISSED' || statusUpper === 'CANCELLED';
    }
  });

  const dateFilteredAppts = selectedDateStr 
    ? filteredAppts.filter(a => a.date === selectedDateStr)
    : filteredAppts;

  // Group by date or time
  const groupedAppts = dateFilteredAppts.reduce((acc, appt) => {
    let groupKey = appt.date || 'TBD';
    
    if (selectedDateStr) {
      if (appt.timeRange) groupKey = appt.timeRange.split('-')[0].trim();
      else if (appt.time) groupKey = appt.time;
      else groupKey = 'TBD';
    }

    if (!acc[groupKey]) acc[groupKey] = [];
    
    let isPassedTime = false;
    if (activeTab === 'upcoming' && appt.resolvedDate) {
      if (appt.resolvedDate < now) {
        isPassedTime = true;
      }
    }
    
    acc[groupKey].push({ ...appt, isPassedTime });
    return acc;
  }, {});

  // Sort groups: upcoming time first, passed time last
  Object.keys(groupedAppts).forEach(key => {
    groupedAppts[key].sort((a, b) => {
      if (a.isPassedTime === b.isPassedTime) {
        if (activeTab === 'completed') {
          return (b.resolvedDate || 0) - (a.resolvedDate || 0);
        }
        return (a.resolvedDate || 0) - (b.resolvedDate || 0);
      }
      return a.isPassedTime ? 1 : -1;
    });
  });

  return (
    <div>
      <header className="page-header">
        <h1 className="page-title">Appointment Schedule</h1>
        <p className="page-subtitle">Track, monitor, and mark client consultations as completed.</p>
      </header>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: '12px', borderBottom: '1px solid var(--border-color)', marginBottom: '28px', paddingBottom: '12px' }}>
        <button 
          onClick={() => setActiveTab('upcoming')}
          className={`btn ${activeTab === 'upcoming' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ padding: '10px 20px', borderRadius: '12px' }}
        >
          Upcoming Sessions
        </button>
        <button 
          onClick={() => setActiveTab('completed')}
          className={`btn ${activeTab === 'completed' ? 'btn-primary' : 'btn-secondary'}`}
          style={{ padding: '10px 20px', borderRadius: '12px' }}
        >
          Completed History
        </button>
      </div>

      {/* Date Filter Bar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '16px', marginBottom: '24px', flexWrap: 'wrap', backgroundColor: 'var(--bg-card)', padding: '16px', borderRadius: '16px', border: '1px solid var(--border-color)', boxShadow: '0 2px 8px rgba(0,0,0,0.02)' }}>
        
        <div>
          <label style={{ display: 'block', fontSize: '12px', fontWeight: 600, color: 'var(--text-muted)', marginBottom: '8px' }}>SELECT DATE</label>
          <div style={{ position: 'relative' }}>
            <button 
              onClick={() => {
                setCalendarViewDate(selectedDate || new Date());
                setIsCalendarOpen(!isCalendarOpen);
              }}
              style={{ 
                padding: '10px 14px', 
                borderRadius: '10px', 
                border: '1px solid var(--border-color)', 
                backgroundColor: 'var(--bg-primary)', 
                fontSize: '15px', 
                fontWeight: 600, 
                color: 'var(--text-darker)',
                cursor: 'pointer',
                minWidth: '180px',
                textAlign: 'left',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center'
              }}
            >
              {selectedDate ? getFormatStr(selectedDate) : 'Select a date'}
              <CalIcon size={18} style={{ color: 'var(--text-muted)' }} />
            </button>
            {isCalendarOpen && renderCalendar()}
          </div>
        </div>

        <div style={{ display: 'flex', gap: '8px', alignSelf: 'flex-end' }}>
          <button 
            onClick={() => setSelectedDate(new Date())}
            className="btn"
            style={{ 
              padding: '10px 16px', 
              fontSize: '14px', 
              borderRadius: '10px', 
              fontWeight: 600, 
              transition: 'all 0.2s',
              backgroundColor: 'var(--bg-card)',
              border: '1px solid var(--border-color)',
              color: 'var(--text-darker)',
              cursor: 'pointer'
            }}
            onMouseEnter={e => {
              e.currentTarget.style.backgroundColor = 'var(--primary-light)';
              e.currentTarget.style.color = 'var(--primary-dark)';
              e.currentTarget.style.borderColor = 'var(--primary-color)';
            }}
            onMouseLeave={e => {
              e.currentTarget.style.backgroundColor = 'var(--bg-card)';
              e.currentTarget.style.color = 'var(--text-darker)';
              e.currentTarget.style.borderColor = 'var(--border-color)';
            }}
          >
            Jump to Today
          </button>
          
          <button 
            onClick={() => setSelectedDate(null)}
            className="btn"
            style={{ 
              padding: '10px 16px', 
              fontSize: '14px', 
              borderRadius: '10px', 
              fontWeight: 600,
              background: !selectedDate ? 'var(--primary-light)' : 'var(--bg-card)', 
              color: !selectedDate ? 'var(--primary-dark)' : 'var(--text-darker)',
              border: !selectedDate ? '1px solid var(--primary-color)' : '1px solid var(--border-color)',
              cursor: 'pointer',
              transition: 'all 0.2s'
            }}
            onMouseEnter={e => {
              if (selectedDate) {
                e.currentTarget.style.backgroundColor = 'var(--primary-light)';
                e.currentTarget.style.color = 'var(--primary-dark)';
                e.currentTarget.style.borderColor = 'var(--primary-color)';
              }
            }}
            onMouseLeave={e => {
              if (selectedDate) {
                e.currentTarget.style.backgroundColor = 'var(--bg-card)';
                e.currentTarget.style.color = 'var(--text-darker)';
                e.currentTarget.style.borderColor = 'var(--border-color)';
              }
            }}
          >
            Show All Sessions
          </button>
        </div>
      </div>

      {/* Session Cards Timeline */}
      {loading ? (
        <div className="card" style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
          Loading schedule…
        </div>
      ) : dateFilteredAppts.length === 0 ? (
        <div className="card" style={{ padding: '60px 20px', textAlign: 'center', border: '1px dashed var(--border-color)', backgroundColor: 'var(--bg-card)' }}>
          <CalIcon size={40} style={{ color: 'var(--text-muted)', marginBottom: '12px', opacity: 0.6 }} />
          <h3 style={{ fontSize: '18px', fontWeight: 600, color: 'var(--text-darker)' }}>
            No {activeTab} sessions found {selectedDateStr && 'for this date'}
          </h3>
          <p style={{ fontSize: '14px', color: 'var(--text-muted)', marginTop: '4px' }}>
            {activeTab === 'upcoming' 
              ? 'All booked sessions have been completed or cancelled.' 
              : 'Completed session history will display here.'}
          </p>
        </div>
      ) : (
        <div style={{ position: 'relative', paddingLeft: '32px', marginTop: '16px' }}>
          {/* Vertical Timeline Line */}
          <div style={{ position: 'absolute', left: '8px', top: '10px', bottom: '20px', width: '2px', backgroundColor: 'var(--border-color)', borderRadius: '2px' }} />

          {Object.entries(groupedAppts)
            .sort(([, apptsA], [, apptsB]) => {
              const dateA = apptsA[0]?.resolvedDate || 0;
              const dateB = apptsB[0]?.resolvedDate || 0;
              return activeTab === 'completed' ? dateB - dateA : dateA - dateB;
            })
            .map(([groupKey, appts]) => (
            <div key={groupKey} style={{ marginBottom: '32px', position: 'relative' }}>
              {/* Timeline Date Dot */}
              <div style={{ 
                position: 'absolute', 
                left: '-29px', 
                top: '4px', 
                width: '14px', 
                height: '14px', 
                borderRadius: '50%', 
                backgroundColor: 'var(--bg-card)',
                border: `3px solid ${activeTab === 'upcoming' ? 'var(--primary-color)' : '#8A968F'}`,
                zIndex: 1
              }} />
              
              <h3 style={{ fontSize: '16px', fontWeight: 700, color: 'var(--text-darker)', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                {groupKey}
              </h3>
              
              <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                {appts.map((appt) => {
                  const startTime = appt.resolvedDate || new Date();
                  const endTime = new Date(startTime.getTime() + 60 * 60 * 1000);
                  const fifteenMinsLateTime = new Date(startTime.getTime() + 15 * 60 * 1000);
                  
                  const isSessionPassed = now > endTime;
                  const isFifteenMinsLate = now > fifteenMinsLateTime;
                  const statusUpper = appt.status?.toUpperCase() || '';
                  const isMissed = statusUpper === 'MISSED';
                  const isCompleted = statusUpper === 'COMPLETED';
                  const isCancelled = statusUpper === 'CANCELLED';

                  return (
                    <div 
                      key={appt.id} 
                      className="card" 
                      onClick={() => handleViewDetails(appt)}
                      style={{ 
                        display: 'flex', 
                        justifyContent: 'space-between', 
                        alignItems: 'center', 
                        padding: '24px',
                        cursor: 'pointer',
                        transition: 'all 0.2s ease',
                        borderLeft: (isSessionPassed && activeTab === 'upcoming') ? '4px solid #f59e0b' : isMissed ? '4px solid #ef4444' : '1px solid var(--border-color)'
                      }}
                      onMouseEnter={(e) => {
                        e.currentTarget.style.transform = 'translateY(-2px)';
                        e.currentTarget.style.boxShadow = '0 12px 24px rgba(0,0,0,0.05)';
                      }}
                      onMouseLeave={(e) => {
                        e.currentTarget.style.transform = 'none';
                        e.currentTarget.style.boxShadow = '0 8px 24px rgba(124, 156, 132, 0.03)';
                      }}
                    >
                      <div style={{ display: 'flex', gap: '20px', alignItems: 'center' }}>
                        <div style={{ 
                          width: '56px', 
                          height: '56px', 
                          borderRadius: '50%', 
                          backgroundColor: activeTab === 'upcoming' ? (isSessionPassed ? '#fef3c7' : '#E6F7F0') : (isMissed ? '#fee2e2' : '#f3f4f6'), 
                          display: 'flex', 
                          alignItems: 'center', 
                          justifyContent: 'center',
                          color: activeTab === 'upcoming' ? (isSessionPassed ? '#d97706' : '#00A666') : (isMissed ? '#ef4444' : '#6b7280'),
                          fontWeight: 700,
                          fontSize: '18px',
                          border: '1px solid rgba(0,0,0,0.03)'
                        }}>
                          {appt.patientName?.charAt(0) || 'P'}
                        </div>
                        <div>
                          <h3 style={{ fontSize: '18px', fontWeight: 700, color: 'var(--text-darker)', marginBottom: '4px' }}>
                            {appt.patientName}
                            {(isSessionPassed && activeTab === 'upcoming') && (
                              <span style={{ 
                                marginLeft: '10px', 
                                fontSize: '10px', 
                                padding: '3px 8px', 
                                backgroundColor: '#fef3c7', 
                                color: '#b45309', 
                                borderRadius: '6px',
                                verticalAlign: 'middle',
                                fontWeight: 700
                              }}>
                                PASSED
                              </span>
                            )}
                            {isMissed && (
                              <span style={{ 
                                marginLeft: '10px', 
                                fontSize: '10px', 
                                padding: '3px 8px', 
                                backgroundColor: '#fee2e2', 
                                color: '#ef4444', 
                                borderRadius: '6px',
                                verticalAlign: 'middle',
                                fontWeight: 700
                              }}>
                                MISSED
                              </span>
                            )}
                          </h3>
                          <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
                            <span style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '6px' }}>
                              <Clock size={14} /> {appt.timeRange || appt.time || 'TBD'}
                            </span>
                          </div>
                        </div>
                      </div>

                      <div style={{ display: 'flex', gap: '8px' }} onClick={(e) => e.stopPropagation()}>
                        {activeTab === 'upcoming' ? (
                          <>
                            {!isSessionPassed && (
                              <button 
                                onClick={async () => {
                                  try {
                                    window.open(`https://meet.jit.si/eunoia_${appt.id}`, '_blank');
                                    const apptRef = doc(db, 'counsellor_bookings', appt.id);
                                    await updateDoc(apptRef, { status: 'ongoing' });
                                  } catch (error) {
                                    console.error('Error starting video session:', error);
                                    setFlashMessage({ type: 'error', text: 'Failed to start video session.' });
                                    setTimeout(() => setFlashMessage(null), 3000);
                                  }
                                }}
                                className="btn"
                                style={{ padding: '10px 18px', fontSize: '13px', backgroundColor: '#eef2ff', color: '#4f46e5', fontWeight: 600 }}
                              >
                                <Video size={16} /> Join Call
                              </button>
                            )}
                            
                            {isFifteenMinsLate && !isSessionPassed && (
                              <button 
                                onClick={() => handleMissedSession(appt.id)}
                                disabled={updatingId === appt.id}
                                className="btn"
                                style={{ padding: '10px 18px', fontSize: '13px', backgroundColor: '#fee2e2', color: '#dc2626', fontWeight: 600 }}
                              >
                                {updatingId === appt.id ? 'Updating...' : 'Mark Missed'}
                              </button>
                            )}

                            {isSessionPassed && (
                              <div style={{ display: 'flex', gap: '8px' }}>
                                <button 
                                  onClick={() => handleMissedSession(appt.id)}
                                  disabled={updatingId === appt.id}
                                  className="btn"
                                  style={{ padding: '10px 18px', fontSize: '13px', backgroundColor: '#fee2e2', color: '#dc2626', fontWeight: 600 }}
                                >
                                  {updatingId === appt.id ? 'Updating...' : 'Mark Missed'}
                                </button>
                                <button 
                                  onClick={() => handleCompleteSession(appt.id)}
                                  disabled={updatingId === appt.id}
                                  className="btn btn-primary"
                                  style={{ padding: '10px 18px', fontSize: '13px' }}
                                >
                                  {updatingId === appt.id ? 'Updating…' : 'Mark Completed'}
                                </button>
                              </div>
                            )}
                          </>
                        ) : (
                          <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                            {isMissed ? (
                              <span className="session-status" style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', backgroundColor: '#f3f4f6', color: '#4b5563', padding: '6px 12px', borderRadius: '20px', fontWeight: 600 }}>
                                <X size={14} /> Missed
                              </span>
                            ) : appt.status?.toUpperCase() === 'CANCELLED' ? (
                              <span className="session-status" style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', backgroundColor: '#fee2e2', color: '#dc2626', padding: '6px 12px', borderRadius: '20px', fontWeight: 600 }}>
                                <X size={14} /> Cancelled
                              </span>
                            ) : appt.status?.toUpperCase() === 'COMPLETED' ? (
                              <>
                                <button 
                                  onClick={() => handleViewDetails(appt)}
                                  className="btn"
                                  style={{ padding: '6px 12px', fontSize: '12px', backgroundColor: '#e5e7eb', color: '#374151', fontWeight: 600 }}
                                >
                                  View Notes
                                </button>
                                <span className="session-status status-completed" style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px' }}>
                                  <CheckCircle2 size={14} /> Completed
                                </span>
                              </>
                            ) : (
                              <span className="session-status" style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', backgroundColor: '#fef3c7', color: '#92400e', padding: '6px 12px', borderRadius: '20px', fontWeight: 600 }}>
                                <AlertTriangle size={14} /> Passed
                              </span>
                            )}
                          </div>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Session Details Modal */}
      {showDetailsModal && selectedSession && (
        <div style={{
          position: 'fixed', top: 0, left: 0, width: '100%', height: '100%',
          backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1000,
          display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px'
        }}>
          <div className="card" style={{ width: '100%', maxWidth: '500px', padding: '32px', position: 'relative' }}>
            <button 
              onClick={() => setShowDetailsModal(false)}
              style={{ position: 'absolute', top: '24px', right: '24px', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}
            >
              <X size={24} />
            </button>
            <h3 style={{ fontSize: '22px', fontWeight: 700, color: 'var(--text-darker)', marginBottom: '20px' }}>Session Details</h3>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid var(--border-color)' }}>
                <span style={{ color: 'var(--text-muted)', fontSize: '14px' }}>Client</span>
                <span style={{ fontWeight: 600, color: 'var(--text-darker)', fontSize: '15px' }}>{selectedSession.patientName}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid var(--border-color)' }}>
                <span style={{ color: 'var(--text-muted)', fontSize: '14px' }}>Date</span>
                <span style={{ fontWeight: 600, color: 'var(--text-darker)', fontSize: '15px' }}>{selectedSession.date || selectedSession.resolvedDate?.toLocaleDateString() || 'TBD'}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid var(--border-color)' }}>
                <span style={{ color: 'var(--text-muted)', fontSize: '14px' }}>Time</span>
                <span style={{ fontWeight: 600, color: 'var(--text-darker)', fontSize: '15px' }}>{selectedSession.timeRange || selectedSession.time || 'TBD'}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid var(--border-color)' }}>
                <span style={{ color: 'var(--text-muted)', fontSize: '14px' }}>Status</span>
                <span style={{ 
                  fontWeight: 600, 
                  fontSize: '13px', 
                  padding: '4px 10px', 
                  borderRadius: '20px', 
                  backgroundColor: selectedSession.status?.toUpperCase() === 'COMPLETED' ? '#dcfce7' : (selectedSession.status?.toUpperCase() === 'CANCELLED' || selectedSession.status?.toUpperCase() === 'MISSED') ? '#fee2e2' : '#fef3c7',
                  color: selectedSession.status?.toUpperCase() === 'COMPLETED' ? '#166534' : (selectedSession.status?.toUpperCase() === 'CANCELLED' || selectedSession.status?.toUpperCase() === 'MISSED') ? '#dc2626' : '#92400e'
                }}>
                  {selectedSession.status?.toUpperCase() === 'COMPLETED' ? 'COMPLETED' :
                   selectedSession.status?.toUpperCase() === 'CANCELLED' ? 'CANCELLED' :
                   selectedSession.status?.toUpperCase() === 'MISSED' ? 'MISSED' :
                   (selectedSession.resolvedDate && selectedSession.resolvedDate < new Date()) ? 'PASSED' : 
                   (selectedSession.status?.toUpperCase() || 'UNKNOWN')}
                </span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid var(--border-color)' }}>
                <span style={{ color: 'var(--text-muted)', fontSize: '14px' }}>Payment Reference</span>
                <span style={{ fontWeight: 600, color: 'var(--text-darker)', fontSize: '14px', fontFamily: 'monospace' }}>{selectedSession.paymentIntentId || 'N/A'}</span>
              </div>
              
              {(selectedSession.notes || selectedSession.sessionSummary || selectedSession.reason || selectedSession.cancelReason) && (
                <div style={{ padding: '16px', backgroundColor: 'var(--bg-secondary)', borderRadius: '12px', marginTop: '8px' }}>
                  <h4 style={{ fontSize: '13px', fontWeight: 700, color: 'var(--text-muted)', marginBottom: '8px', textTransform: 'uppercase' }}>
                    {selectedSession.status?.toUpperCase() === 'COMPLETED' ? 'Clinical Notes' : 'Summary / Reason'}
                  </h4>
                  <p style={{ fontSize: '14px', color: 'var(--text-dark)', margin: 0, whiteSpace: 'pre-wrap' }}>
                    {selectedSession.sessionSummary || selectedSession.notes || selectedSession.reason || selectedSession.cancelReason}
                  </p>
                </div>
              )}
            </div>

            {activeTab === 'upcoming' && (
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '32px' }}>
                <button 
                  onClick={() => handleCompleteSession(selectedSession.id)}
                  className="btn btn-primary"
                  style={{ padding: '12px 24px' }}
                >
                  <CheckCircle2 size={16} /> Complete Session
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Clinical Notes Modal */}
      {showNotesModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, width: '100%', height: '100%',
          backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1000,
          display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px'
        }}>
          <div className="card" style={{ width: '100%', maxWidth: '600px', padding: '32px', position: 'relative' }}>
            <button 
              onClick={() => setShowNotesModal(false)}
              style={{ position: 'absolute', top: '24px', right: '24px', background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-muted)' }}
            >
              <X size={24} />
            </button>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '24px' }}>
              <div style={{ width: '48px', height: '48px', borderRadius: '12px', backgroundColor: 'var(--primary-light)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--primary-color)' }}>
                <FileText size={24} />
              </div>
              <div>
                <h3 style={{ fontSize: '20px', fontWeight: 700, color: 'var(--text-darker)' }}>Complete Session</h3>
                <p style={{ fontSize: '14px', color: 'var(--text-muted)' }}>Write private clinical remarks before closing.</p>
              </div>
            </div>
            
            <div className="form-group">
              <label className="form-label">Clinical Notes (Private)</label>
              <textarea 
                className="form-control"
                rows="6"
                placeholder="Write your session summary, diagnosis, or progress notes here..."
                value={clinicalNotes}
                onChange={e => setClinicalNotes(e.target.value)}
                style={{ resize: 'vertical' }}
              />
            </div>
            
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '12px', marginTop: '24px' }}>
              <button 
                onClick={() => setShowNotesModal(false)}
                className="btn btn-secondary"
                style={{ padding: '12px 24px', display: 'flex', justifyContent: 'center', alignItems: 'center' }}
              >
                Cancel
              </button>
              <button 
                onClick={submitSessionComplete}
                disabled={updatingId !== null}
                className="btn btn-primary"
                style={{ padding: '12px 24px', display: 'flex', justifyContent: 'center', alignItems: 'center' }}
              >
                {updatingId !== null ? 'Saving...' : 'Save & Complete'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Confirm Missed Modal */}
      {missedConfirmId && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ backgroundColor: 'var(--bg-card)', borderRadius: '24px', width: '100%', maxWidth: '420px', padding: '32px', position: 'relative', boxShadow: '0 20px 40px rgba(0,0,0,0.15)', animation: 'fadeIn 0.2s ease-out' }}>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', marginBottom: '32px' }}>
              <div style={{ padding: '16px', backgroundColor: 'rgba(239, 68, 68, 0.1)', borderRadius: '50%', color: '#ef4444', marginBottom: '16px' }}>
                <AlertTriangle size={32} />
              </div>
              <h2 style={{ fontSize: '24px', fontWeight: 700, color: 'var(--text-darker)', margin: 0, marginBottom: '12px' }}>Mark as Missed?</h2>
              <p style={{ fontSize: '15px', color: 'var(--text-muted)', lineHeight: '1.6', margin: 0 }}>
                This action cannot be undone. Are you sure you want to mark this session as Missed/No Show?
              </p>
            </div>

            <div className="form-group" style={{ marginBottom: '24px' }}>
              <label className="form-label" style={{ fontSize: '14px', fontWeight: 600 }}>Reason for Missed Session</label>
              <textarea 
                className="form-control"
                rows="3"
                placeholder="E.g., Client did not join within 15 minutes..."
                value={missedReason}
                onChange={e => setMissedReason(e.target.value)}
                style={{ resize: 'vertical', width: '100%', padding: '12px', borderRadius: '10px', border: '1px solid var(--border-color)' }}
              />
            </div>
            
            <div style={{ display: 'flex', gap: '16px' }}>
              <button 
                onClick={() => setMissedConfirmId(null)} 
                className="btn btn-secondary" 
                style={{ flex: 1, padding: '14px', fontSize: '15px', fontWeight: 600, textAlign: 'center', display: 'flex', justifyContent: 'center' }}
              >
                Cancel
              </button>
              <button 
                onClick={confirmMissedSession}
                disabled={updatingId !== null}
                className="btn" 
                style={{ flex: 1, padding: '14px', fontSize: '15px', fontWeight: 600, backgroundColor: '#ef4444', color: 'white', border: 'none', textAlign: 'center', display: 'flex', justifyContent: 'center' }}
              >
                {updatingId !== null ? 'Updating...' : 'Mark Missed'}
              </button>
            </div>
          </div>
        </div>
      )}

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
