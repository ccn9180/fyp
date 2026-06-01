import React, { useState, useEffect } from 'react';
import { collection, query, where, getDocs, updateDoc, doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { Calendar as CalIcon, Clock, CheckCircle2 } from 'lucide-react';

export default function Sessions() {
  const [appointments, setAppointments] = useState([]);
  const [activeTab, setActiveTab] = useState('upcoming');
  const [loading, setLoading] = useState(true);
  const [updatingId, setUpdatingId] = useState(null);

  const fetchAppointments = async () => {
    const user = auth.currentUser;
    if (!user) return;
    setLoading(true);

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
    } catch (e) {
      console.error("Error fetching appointments:", e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAppointments();
  }, []);

  const handleCompleteSession = async (apptId) => {
    if (!window.confirm("Are you sure you want to mark this consultation session as completed?")) return;

    setUpdatingId(apptId);
    try {
      const apptRef = doc(db, 'counsellor_bookings', apptId);
      await updateDoc(apptRef, {
        status: 'COMPLETED'
      });
      // Refresh list
      await fetchAppointments();
    } catch (err) {
      console.error("Error updating appointment status:", err);
    } finally {
      setUpdatingId(null);
    }
  };

  const filteredAppts = appointments.filter(a => {
    const statusUpper = a.status?.toUpperCase() || '';
    if (activeTab === 'upcoming') {
      return statusUpper === 'CONFIRMED' || statusUpper === 'PENDING' || statusUpper === 'RESCHEDULED';
    } else {
      return statusUpper === 'COMPLETED';
    }
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

      {/* Session Cards Grid */}
      {loading ? (
        <div className="card" style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
          Loading schedule…
        </div>
      ) : filteredAppts.length === 0 ? (
        <div className="card" style={{ padding: '60px 20px', textAlign: 'center', border: '1px dashed var(--border-color)', backgroundColor: 'var(--bg-card)' }}>
          <CalIcon size={40} style={{ color: 'var(--text-muted)', marginBottom: '12px', opacity: 0.6 }} />
          <h3 style={{ fontSize: '18px', fontWeight: 600, color: 'var(--text-darker)' }}>
            No {activeTab} sessions found
          </h3>
          <p style={{ fontSize: '14px', color: 'var(--text-muted)', marginTop: '4px' }}>
            {activeTab === 'upcoming' 
              ? 'All booked sessions have been completed or cancelled.' 
              : 'Completed session history will display here.'}
          </p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {filteredAppts.map((appt) => (
            <div key={appt.id} className="card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '24px' }}>
              <div style={{ display: 'flex', gap: '20px', alignItems: 'center' }}>
                <div style={{ 
                  width: '56px', 
                  height: '56px', 
                  borderRadius: '50%', 
                  backgroundColor: activeTab === 'upcoming' ? '#FFF9E6' : '#E6F7F0', 
                  display: 'flex', 
                  alignItems: 'center', 
                  justifyContent: 'center',
                  color: activeTab === 'upcoming' ? '#D99E00' : '#00A666',
                  fontWeight: 700,
                  fontSize: '18px',
                  border: '1px solid rgba(0,0,0,0.03)'
                }}>
                  {appt.patientName?.charAt(0) || 'P'}
                </div>
                <div>
                  <h3 style={{ fontSize: '18px', fontWeight: 700, color: 'var(--text-darker)', marginBottom: '4px' }}>
                    {appt.patientName}
                  </h3>
                  <div style={{ display: 'flex', gap: '16px', flexWrap: 'wrap' }}>
                    <span style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <CalIcon size={14} /> {appt.date || 'TBD'}
                    </span>
                    <span style={{ fontSize: '13px', color: 'var(--text-muted)', display: 'flex', alignItems: 'center', gap: '6px' }}>
                      <Clock size={14} /> {appt.timeRange || appt.time || 'TBD'}
                    </span>
                  </div>
                </div>
              </div>

              <div>
                {activeTab === 'upcoming' ? (
                  <button 
                    onClick={() => handleCompleteSession(appt.id)}
                    disabled={updatingId === appt.id}
                    className="btn btn-primary"
                    style={{ padding: '10px 18px', fontSize: '13px' }}
                  >
                    {updatingId === appt.id ? 'Updating…' : (
                      <>
                        <CheckCircle2 size={16} /> Complete Session
                      </>
                    )}
                  </button>
                ) : (
                  <span className="session-status status-completed" style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px' }}>
                    <CheckCircle2 size={14} /> Completed
                  </span>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
