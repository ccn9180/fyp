import React, { useState, useEffect, useRef } from 'react';
import { collection, query, where, getDocs, addDoc, updateDoc, deleteDoc, doc, Timestamp, serverTimestamp } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { Calendar as CalIcon, Clock, Plus, Trash2, Edit2, ChevronLeft, ChevronRight, AlertCircle, CheckCircle2, X, Save } from 'lucide-react';

const CustomSelect = ({ value, options, onChange }) => {
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef(null);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  return (
    <div ref={dropdownRef} style={{ position: 'relative', width: '100%' }}>
      <div 
        onClick={() => setIsOpen(!isOpen)}
        style={{ 
          width: '100%', padding: '10px 14px', borderRadius: '10px',
          border: isOpen ? '1px solid var(--primary-color)' : '1px solid var(--border-color)',
          backgroundColor: isOpen ? 'var(--bg-card)' : 'var(--bg-secondary)',
          fontFamily: 'var(--font-main)', fontSize: '13.5px', color: 'var(--text-darker)',
          cursor: 'pointer', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          boxShadow: isOpen ? '0 0 0 3px rgba(124, 156, 132, 0.08)' : 'none',
          transition: 'all 0.2s ease'
        }}
      >
        <span>{value}</span>
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" 
             stroke={isOpen ? "var(--primary-color)" : "#6b7280"} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" 
             style={{ transition: 'transform 0.2s', transform: isOpen ? 'rotate(180deg)' : 'rotate(0)' }}>
          <polyline points="6 9 12 15 18 9"></polyline>
        </svg>
      </div>
      
      {isOpen && (
        <div style={{
          position: 'absolute', top: 'calc(100% + 6px)', left: 0, right: 0, zIndex: 100,
          backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', borderRadius: '12px',
          boxShadow: '0 10px 25px rgba(0,0,0,0.1)', maxHeight: '220px', overflowY: 'auto',
          padding: '6px 0', animation: 'fadeIn 0.2s ease-out'
        }}>
          {options.map(opt => (
            <div 
              key={opt}
              onClick={() => { onChange(opt); setIsOpen(false); }}
              style={{
                padding: '10px 16px', fontSize: '13.5px', cursor: 'pointer',
                backgroundColor: value === opt ? 'var(--primary-light)' : 'transparent',
                color: value === opt ? 'var(--primary-color)' : 'var(--text-darker)',
                fontWeight: value === opt ? 600 : 400,
                transition: 'background-color 0.15s'
              }}
              onMouseEnter={(e) => { if (value !== opt) e.currentTarget.style.backgroundColor = '#f9fafb'; }}
              onMouseLeave={(e) => { if (value !== opt) e.currentTarget.style.backgroundColor = 'transparent'; }}
            >
              {opt}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default function Availability() {
  const [slots, setSlots] = useState([]);
  const [loading, setLoading] = useState(true);
  
  // Date states
  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [selectedDate, setSelectedDate] = useState(new Date());

  // Form states
  const [hour, setHour] = useState('09');
  const [minute, setMinute] = useState('00');
  const [ampm, setAmpm] = useState('AM');
  
  const [adding, setAdding] = useState(false);
  const [editingSlot, setEditingSlot] = useState(null); // holds the slot being edited
  const [slotToDelete, setSlotToDelete] = useState(null);
  const [validationError, setValidationError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');

  // Helpers for time options
  const hoursList = ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'];
  const minutesList = ['00', '15', '30', '45'];

  // Helper to format Date to "dd MMM yyyy"
  const formatDateToDDMMMYYYY = (dateObj) => {
    const day = String(dateObj.getDate()).padStart(2, '0');
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const month = months[dateObj.getMonth()];
    const year = dateObj.getFullYear();
    return `${day} ${month} ${year}`;
  };

  const fetchAvailability = async (user) => {
    setLoading(true);

    try {
      const q = query(
        collection(db, 'counsellor_availability'),
        where('counsellorId', '==', user.uid)
      );
      const snap = await getDocs(q);
      const slotsList = [];

      snap.forEach((docSnap) => {
        slotsList.push({
          id: docSnap.id,
          ...docSnap.data()
        });
      });

      setSlots(slotsList);
    } catch (e) {
      console.error("Error loading availability slots:", e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const unsubscribe = auth.onAuthStateChanged(user => {
      if (user) {
        fetchAvailability(user);
      } else {
        if (typeof setLoading === 'function') setLoading(false);
      }
    });
    return () => unsubscribe();
  }, []);

  useEffect(() => {
    if (successMessage) {
      const timer = setTimeout(() => setSuccessMessage(''), 3000);
      return () => clearTimeout(timer);
    }
  }, [successMessage]);

  // Calendar builder helper
  const getDaysInMonth = (date) => {
    const year = date.getFullYear();
    const month = date.getMonth();
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    
    // Offset Sunday to index 6 so calendar starts on Monday
    let startOffset = firstDay.getDay() - 1;
    if (startOffset < 0) startOffset = 6; 
    
    const days = [];
    
    // Prev month days
    const prevMonthLastDay = new Date(year, month, 0).getDate();
    for (let i = startOffset - 1; i >= 0; i--) {
      days.push({
        date: new Date(year, month - 1, prevMonthLastDay - i),
        isCurrentMonth: false
      });
    }
    
    // Current month days
    for (let i = 1; i <= lastDay.getDate(); i++) {
      days.push({
        date: new Date(year, month, i),
        isCurrentMonth: true
      });
    }
    
    // Next month days to pad end of week
    const remaining = 7 - (days.length % 7);
    if (remaining < 7) {
      for (let i = 1; i <= remaining; i++) {
        days.push({
          date: new Date(year, month + 1, i),
          isCurrentMonth: false
        });
      }
    }
    
    return days;
  };

  const changeMonth = (offset) => {
    const newMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + offset, 1);
    setCurrentMonth(newMonth);
    // Align selected date to first day of that month unless it's current month
    const today = new Date();
    if (newMonth.getMonth() === today.getMonth() && newMonth.getFullYear() === today.getFullYear()) {
      setSelectedDate(today);
    } else {
      setSelectedDate(newMonth);
    }
    cancelEdit();
  };

  const cancelEdit = () => {
    setEditingSlot(null);
    setHour('09');
    setMinute('00');
    setAmpm('AM');
    setValidationError('');
  };

  const startEditing = (slot) => {
    setEditingSlot(slot);
    setValidationError('');
    setSuccessMessage('');

    // Parse timeRange e.g., "09:00 AM"
    try {
      const [time, period] = slot.timeRange.split(' ');
      const [h, m] = time.split(':');
      setHour(h);
      setMinute(m);
      setAmpm(period);
    } catch (e) {
      console.error("Error parsing slot time range:", e);
    }
  };

  const handleAddOrEditSlot = async (e) => {
    e.preventDefault();
    setValidationError('');
    setSuccessMessage('');

    const user = auth.currentUser;
    if (!user) return;

    // Build selected time string
    const timeStr = `${hour}:${minute} ${ampm}`;
    const dateStr = formatDateToDDMMMYYYY(selectedDate);
    
    // Parse to JS Date object to check against current time
    let selectedHour = parseInt(hour, 10);
    if (ampm === 'PM' && selectedHour < 12) selectedHour += 12;
    if (ampm === 'AM' && selectedHour === 12) selectedHour = 0;
    
    const slotDateTime = new Date(
      selectedDate.getFullYear(),
      selectedDate.getMonth(),
      selectedDate.getDate(),
      selectedHour,
      parseInt(minute, 10)
    );

    const now = new Date();
    
    // 1. Validation: Future time check (1 hour in advance)
    if (slotDateTime <= now) {
      setValidationError("Cannot select a past time.");
      return;
    }

    const minAdvanceTime = new Date(now.getTime() + 1 * 60 * 60 * 1000);
    if (slotDateTime < minAdvanceTime) {
      setValidationError("Slots must be set at least 1 hour in advance.");
      return;
    }

    // Filter slots for the selected date, excluding the one currently being edited
    const slotsForSelectedDate = slots.filter(s => s.date === dateStr && (!editingSlot || s.id !== editingSlot.id));

    // 2. Validation: Duplicate slot
    const duplicate = slotsForSelectedDate.find(s => s.timeRange === timeStr);
    if (duplicate) {
      setValidationError("Slot already exists for this time.");
      return;
    }

    // 3. Validation: 3-hour gap
    let gapViolation = false;
    slotsForSelectedDate.forEach(s => {
      try {
        const [t, period] = s.timeRange.split(' ');
        let [sh, sm] = t.split(':').map(Number);
        if (period === 'PM' && sh < 12) sh += 12;
        if (period === 'AM' && sh === 12) sh = 0;
        
        const existingDT = new Date(
          selectedDate.getFullYear(),
          selectedDate.getMonth(),
          selectedDate.getDate(),
          sh,
          sm
        );
        
        const diffInHours = Math.abs(slotDateTime - existingDT) / (1000 * 60 * 60);
        if (diffInHours < 3) {
          gapViolation = true;
        }
      } catch (err) {
        console.error("Error parsing existing slot time:", err);
      }
    });

    if (gapViolation) {
      setValidationError("Must have at least a 3-hour gap between slots.");
      return;
    }

    setAdding(true);
    try {
      if (editingSlot) {
        // Edit existing slot
        const docRef = doc(db, 'counsellor_availability', editingSlot.id);
        await updateDoc(docRef, {
          timeRange: timeStr,
          updatedAt: serverTimestamp()
        });
        setSuccessMessage("Availability slot updated successfully!");
        setEditingSlot(null);
      } else {
        // Add new slot
        const sortDate = new Date(selectedDate.getFullYear(), selectedDate.getMonth(), selectedDate.getDate());
        const dayStr = selectedDate.toLocaleDateString('en-US', { weekday: 'long' });

        const data = {
          counsellorId: user.uid,
          day: dayStr,
          date: dateStr,
          timeRange: timeStr,
          sortTimestamp: Timestamp.fromDate(sortDate),
          createdAt: serverTimestamp()
        };

        await addDoc(collection(db, 'counsellor_availability'), data);
        setSuccessMessage("Availability slot added successfully!");
      }
      
      // Reset time select pickers to default
      setHour('09');
      setMinute('00');
      setAmpm('AM');
      await fetchAvailability();
    } catch (err) {
      console.error("Error saving availability slot:", err);
      setValidationError("Failed to save slot in Firebase. Please try again.");
    } finally {
      setAdding(false);
    }
  };

  const promptDeleteSlot = (slot) => {
    setSlotToDelete(slot);
  };

  const confirmDeleteSlot = async () => {
    if (!slotToDelete) return;
    const slotId = slotToDelete.id;
    try {
      await deleteDoc(doc(db, 'counsellor_availability', slotId));
      setSlots(slots.filter(s => s.id !== slotId));
      setSuccessMessage("Availability slot removed.");
      if (editingSlot && editingSlot.id === slotId) {
        cancelEdit();
      }
    } catch (err) {
      console.error("Error deleting slot:", err);
    } finally {
      setSlotToDelete(null);
    }
  };

  const formattedSelectedDate = formatDateToDDMMMYYYY(selectedDate);
  const slotsForSelectedDate = slots
    .filter(s => s.date === formattedSelectedDate)
    .sort((a, b) => {
      const parseTime = (tStr) => {
        const [time, period] = tStr.split(' ');
        let [h, m] = time.split(':').map(Number);
        if (period === 'PM' && h < 12) h += 12;
        if (period === 'AM' && h === 12) h = 0;
        return h * 60 + m;
      };
      return parseTime(a.timeRange) - parseTime(b.timeRange);
    });

  const calendarDays = getDaysInMonth(currentMonth);
  const todayDateStr = formatDateToDDMMMYYYY(new Date());

  // Find all dates with active slots to show marker dot
  const datesWithSlots = new Set(slots.map(s => s.date));

  return (
    <div>
      <header className="page-header">
        <h1 className="page-title">Availability Management</h1>
        <p className="page-subtitle">Configure your specific consulting calendar dates and hours so patients can book sessions.</p>
      </header>

      {successMessage && (
        <div style={{ 
          position: 'fixed', bottom: '24px', right: '24px', zIndex: 1000,
          backgroundColor: '#ecfdf5', color: '#047857', border: '1px solid #a7f3d0', 
          borderRadius: '12px', padding: '14px 20px', fontSize: '14px', fontWeight: 600,
          display: 'flex', alignItems: 'center', gap: '10px',
          boxShadow: '0 10px 25px rgba(0,0,0,0.1)'
        }}>
          <CheckCircle2 size={18} />
          <span>{successMessage}</span>
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: '440px 1fr', gap: '32px', alignItems: 'start' }}>
        
        {/* Left Column - Custom Calendar Grid */}
        <div className="card" style={{ padding: '24px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
            <h2 style={{ fontSize: '24px', fontWeight: 700, color: 'var(--text-darker)' }}>Select Date</h2>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <button onClick={() => changeMonth(-1)} className="btn btn-secondary" style={{ padding: '6px', borderRadius: '50%' }}>
                <ChevronLeft size={18} />
              </button>
              <span style={{ fontSize: '14px', fontWeight: 700, color: 'var(--primary-color)', minWidth: '110px', textAlign: 'center' }}>
                {currentMonth.toLocaleDateString('en-US', { month: 'long', year: 'numeric' })}
              </span>
              <button onClick={() => changeMonth(1)} className="btn btn-secondary" style={{ padding: '6px', borderRadius: '50%' }}>
                <ChevronRight size={18} />
              </button>
            </div>
          </div>

          {/* Weekday headers */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', textAlign: 'center', marginBottom: '12px' }}>
            {['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map(day => (
              <span key={day} style={{ fontSize: '11px', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase' }}>
                {day}
              </span>
            ))}
          </div>

          {/* Calendar Days */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: '8px', rowGap: '12px' }}>
            {calendarDays.map((dayItem, idx) => {
              const dayStr = formatDateToDDMMMYYYY(dayItem.date);
              const isSelected = formatDateToDDMMMYYYY(selectedDate) === dayStr;
              const hasSlots = datesWithSlots.has(dayStr);
              const isToday = todayDateStr === dayStr;
              const isPast = dayItem.date < new Date(new Date().setHours(0,0,0,0));

              return (
                <div 
                  key={idx}
                  onClick={() => {
                    if (!isPast && dayItem.isCurrentMonth) {
                      setSelectedDate(dayItem.date);
                      cancelEdit();
                    }
                  }}
                  style={{
                    position: 'relative',
                    aspectRatio: '1',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                    borderRadius: '50%',
                    cursor: (isPast || !dayItem.isCurrentMonth) ? 'default' : 'pointer',
                    backgroundColor: isSelected ? 'var(--primary-color)' : (hasSlots && dayItem.isCurrentMonth && !isPast ? 'var(--primary-light)' : 'transparent'),
                    color: isSelected 
                      ? 'white' 
                      : (!dayItem.isCurrentMonth ? '#d1d5db' : (isPast ? '#9ca3af' : 'var(--text-darker)')),
                    fontWeight: isSelected || isToday ? '700' : '500',
                    fontSize: '14px',
                    opacity: dayItem.isCurrentMonth ? 1 : 0.35,
                    border: isToday && !isSelected ? '1.5px solid var(--primary-color)' : 'none',
                    transition: 'all 0.15s ease'
                  }}
                >
                  {dayItem.date.getDate()}
                  
                  {/* Active slot dot */}
                  {hasSlots && dayItem.isCurrentMonth && !isPast && (
                    <span style={{ 
                      position: 'absolute', 
                      bottom: '4px', 
                      width: '4px', 
                      height: '4px', 
                      borderRadius: '50%', 
                      backgroundColor: isSelected ? 'white' : 'var(--primary-color)' 
                    }} />
                  )}
                </div>
              );
            })}
          </div>
        </div>

        {/* Right Column - Slots for Selected Date & Add/Edit Slot Panel */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          
          {/* Slots List Card */}
          <div className="card">
            <h2 style={{ fontSize: '18px', fontWeight: 700, color: 'var(--text-darker)', marginBottom: '4px' }}>
              Slots for {selectedDate.toLocaleDateString('en-US', { weekday: 'short', day: 'numeric', month: 'short', year: 'numeric' })}
            </h2>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '20px' }}>Active consulting hours on this day</p>

            {loading ? (
              <div style={{ padding: '20px 0', textAlign: 'center', color: 'var(--text-muted)', fontSize: '13px' }}>Loading availability…</div>
            ) : slotsForSelectedDate.length === 0 ? (
              <div style={{ padding: '30px 20px', textAlign: 'center', border: '1px dashed var(--border-color)', borderRadius: '16px', backgroundColor: 'var(--bg-secondary)' }}>
                <Clock size={28} style={{ color: 'var(--text-muted)', marginBottom: '8px', opacity: 0.5 }} />
                <p style={{ fontSize: '13px', fontWeight: 500, color: 'var(--text-darker)' }}>No slots set for this date</p>
              </div>
            ) : (
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '12px' }}>
                {slotsForSelectedDate.map((slot) => {
                  const isCurrentEditing = editingSlot && editingSlot.id === slot.id;
                  return (
                    <div 
                      key={slot.id} 
                      style={{ 
                        padding: '12px 14px', 
                        borderRadius: '12px', 
                        backgroundColor: isCurrentEditing ? 'var(--primary-light)' : 'var(--bg-card)', 
                        border: isCurrentEditing ? '1px solid var(--primary-color)' : '1px solid var(--border-color)',
                        display: 'flex', 
                        alignItems: 'center', 
                        justifyContent: 'space-between',
                        gap: '24px',
                        width: 'fit-content',
                        fontSize: '13px',
                        fontWeight: 600,
                        color: 'var(--text-darker)'
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                        <Clock size={14} style={{ color: 'var(--primary-color)' }} />
                        <span>{slot.timeRange}</span>
                      </div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                        <button 
                          onClick={() => startEditing(slot)}
                          style={{ 
                            background: 'none', 
                            border: 'none', 
                            color: '#9ca3af', 
                            cursor: 'pointer', 
                            display: 'flex',
                            alignItems: 'center',
                            padding: '4px',
                            borderRadius: '50%',
                            transition: 'all 0.2s'
                          }}
                          onMouseEnter={e => { e.currentTarget.style.backgroundColor = 'var(--bg-secondary)'; e.currentTarget.style.color = 'var(--primary-color)'; }}
                          onMouseLeave={e => { e.currentTarget.style.backgroundColor = 'transparent'; e.currentTarget.style.color = '#9ca3af'; }}
                          title="Edit Slot"
                        >
                          <Edit2 size={13} />
                        </button>
                        <button 
                          onClick={() => promptDeleteSlot(slot)}
                          style={{ 
                            background: 'none', 
                            border: 'none', 
                            color: '#9ca3af', 
                            cursor: 'pointer', 
                            display: 'flex',
                            alignItems: 'center',
                            padding: '4px',
                            borderRadius: '50%',
                            transition: 'all 0.2s'
                          }}
                          onMouseEnter={e => { e.currentTarget.style.backgroundColor = '#fee2e2'; e.currentTarget.style.color = '#ef4444'; }}
                          onMouseLeave={e => { e.currentTarget.style.backgroundColor = 'transparent'; e.currentTarget.style.color = '#9ca3af'; }}
                          title="Delete Slot"
                        >
                          <Trash2 size={13} />
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>

          {/* Add / Edit Slot Card */}
          <div className="card">
            <h2 style={{ fontSize: '18px', fontWeight: 700, color: 'var(--text-darker)', marginBottom: '4px' }}>
              {editingSlot ? 'Edit Availability Slot' : 'Configure Availability'}
            </h2>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)', marginBottom: '20px' }}>
              {editingSlot ? 'Modify selected consulting time slot' : 'Setup active consultation hours'}
            </p>

            {validationError && (
              <div style={{ backgroundColor: '#fef2f2', color: '#ef4444', border: '1px solid #fee2e2', borderRadius: '12px', padding: '12px', marginBottom: '16px', fontSize: '12.5px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <AlertCircle size={16} />
                <span>{validationError}</span>
              </div>
            )}

            <form onSubmit={handleAddOrEditSlot} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
                <div className="form-group" style={{ flex: 1 }}>
                  <label className="form-label">Hour</label>
                  <CustomSelect 
                    value={hour} 
                    options={hoursList} 
                    onChange={setHour} 
                  />
                </div>

                <div className="form-group" style={{ flex: 1 }}>
                  <label className="form-label">Minute</label>
                  <CustomSelect 
                    value={minute} 
                    options={minutesList} 
                    onChange={setMinute} 
                  />
                </div>

                <div className="form-group" style={{ flex: 1 }}>
                  <label className="form-label">Period</label>
                  <CustomSelect 
                    value={ampm} 
                    options={['AM', 'PM']} 
                    onChange={setAmpm} 
                  />
                </div>
              </div>

              <div style={{ fontSize: '11px', color: 'var(--text-muted)', lineHeight: '1.4' }}>
                * System enforces a 1-hour lead time and 3-hour gap from other sessions on this date to prevent overlaps.
              </div>

              <div style={{ display: 'flex', gap: '10px' }}>
                {editingSlot && (
                  <button 
                    type="button" 
                    onClick={cancelEdit}
                    className="btn btn-secondary"
                    style={{ flex: 1, padding: '12px' }}
                  >
                    Cancel Edit
                  </button>
                )}
                <button 
                  type="submit" 
                  disabled={adding}
                  className="btn btn-primary"
                  style={{ flex: 2, padding: '12px' }}
                >
                  {adding ? 'Saving…' : (
                    editingSlot ? (
                      <>
                        <Save size={16} /> Save Changes
                      </>
                    ) : (
                      <>
                        <Plus size={16} /> Confirm Availability
                      </>
                    )
                  )}
                </button>
              </div>
            </form>
          </div>

        </div>

      </div>

      {/* Delete Confirmation Modal */}
      {slotToDelete && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ backgroundColor: 'var(--bg-card)', borderRadius: '24px', width: '100%', maxWidth: '420px', padding: '32px', position: 'relative', boxShadow: '0 20px 40px rgba(0,0,0,0.15)', animation: 'fadeIn 0.2s ease-out' }}>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', marginBottom: '32px' }}>
              <div style={{ padding: '16px', backgroundColor: 'rgba(239, 68, 68, 0.1)', borderRadius: '50%', color: '#ef4444', marginBottom: '16px' }}>
                <Clock size={32} />
              </div>
              <h2 style={{ fontSize: '24px', fontWeight: 700, color: 'var(--text-darker)', margin: 0, marginBottom: '12px' }}>Remove Availability?</h2>
              <p style={{ fontSize: '15px', color: 'var(--text-muted)', lineHeight: '1.6', margin: 0, marginBottom: '20px' }}>
                Are you sure you want to delete this availability slot? Patients will not be able to book this slot anymore.
              </p>
              
              <div style={{ padding: '12px 24px', backgroundColor: '#fef2f2', borderRadius: '12px', display: 'inline-flex', flexDirection: 'column', alignItems: 'center', border: '1px solid #fee2e2' }}>
                <div style={{ fontSize: '18px', fontWeight: 700, color: '#ef4444' }}>{slotToDelete.timeRange}</div>
                <div style={{ fontSize: '14px', color: '#ef4444', opacity: 0.8 }}>{slotToDelete.date}</div>
              </div>
            </div>
            
            <div style={{ display: 'flex', gap: '16px' }}>
              <button 
                onClick={() => setSlotToDelete(null)} 
                className="btn btn-secondary" 
                style={{ flex: 1, padding: '14px', fontSize: '15px', fontWeight: 600, textAlign: 'center', display: 'flex', justifyContent: 'center' }}
              >
                Cancel
              </button>
              <button 
                onClick={confirmDeleteSlot}
                className="btn" 
                style={{ flex: 1, padding: '14px', fontSize: '15px', fontWeight: 600, backgroundColor: '#ef4444', color: 'white', border: 'none', textAlign: 'center', display: 'flex', justifyContent: 'center' }}
              >
                Remove Slot
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
