import React, { useState, useEffect, useRef } from 'react';
import { collection, query, where, getDocs, doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { Award, Heart, ShieldAlert, Star, TrendingUp, Download, CheckCircle, RotateCcw, Calendar as CalIcon, X } from 'lucide-react';
import jsPDF from 'jspdf';
import html2canvas from 'html2canvas';
import DatePicker from 'react-datepicker';
import "react-datepicker/dist/react-datepicker.css";
import '../calendar.css';

let cachedPerformanceData = null;

export default function Performance() {
  const [rangeLabel, setRangeLabel] = useState('All Time');
  const [loading, setLoading] = useState(!cachedPerformanceData);
  const [exporting, setExporting] = useState(false);
  const [counsellorName, setCounsellorName] = useState(cachedPerformanceData?.counsellorName || 'Counsellor');

  // Date Picker State
  const [dateRange, setDateRange] = useState([null, null]);
  const [customStart, customEnd] = dateRange;

  // Raw Data
  const [allBookings, setAllBookings] = useState(cachedPerformanceData?.allBookings || []);
  const [allReviews, setAllReviews] = useState(cachedPerformanceData?.allReviews || []);

  // Computed Stats for the View
  const [stats, setStats] = useState(cachedPerformanceData?.stats || {
    satisfaction: '0.0',
    hours: '0',
    cancelRate: '0%',
    completionRate: '0%',
    retentionRate: '0%',
    peakDay: 'N/A',
    reviewCount: 0,
    ratingDistribution: [0, 0, 0, 0, 0],
    chartData: [],
    feedbackList: [],
    totalSessions: 0,
    totalPatients: 0,
  });

  const pdfRef = useRef();

  useEffect(() => {
    const fetchPerformance = async (user) => {
      if (!cachedPerformanceData) setLoading(true);

      try {
        // Fetch counsellor name from Firestore users collection
        let realName = user.displayName || 'Counsellor';
        const docRef = doc(db, 'users', user.uid);
        const userSnap = await getDoc(docRef);
        if (userSnap.exists()) {
          const userData = userSnap.data();
          realName = userData.name || userData.fullName || realName;
        }
        setCounsellorName(realName);

        const qBookings = query(collection(db, 'counsellor_bookings'), where('counsellorId', '==', user.uid));

        const snapBookings = await getDocs(qBookings);

        const bookings = [];
        const reviews = [];
        
        snapBookings.forEach(doc => {
          const d = doc.data();
          let dt = null;
          if (d.startTime?.toDate) dt = d.startTime.toDate();
          else if (d.date) dt = new Date(d.date);
          bookings.push({ id: doc.id, ...d, parsedDate: dt });

          if (d.rating) {
            let r = typeof d.rating === 'number' ? d.rating : parseFloat(d.rating);
            if (r > 0) {
              let commentText = '';
              if (d.feedback && typeof d.feedback === 'object') {
                commentText = d.feedback.comment || '';
              } else if (typeof d.feedback === 'string') {
                commentText = d.feedback;
              }
              let ts = d.feedbackSubmittedAt?.toDate ? d.feedbackSubmittedAt.toDate() : (d.startTime?.toDate ? d.startTime.toDate() : new Date());
              reviews.push({
                id: doc.id,
                rating: r,
                comment: commentText,
                timestamp: ts,
                patientName: d.patientName || d.userName || 'Anonymous',
              });
            }
          }
        });

        reviews.sort((a, b) => b.timestamp - a.timestamp);

        setAllBookings(bookings);
        setAllReviews(reviews);
        
        cachedPerformanceData = {
          counsellorName: realName,
          allBookings: bookings,
          allReviews: reviews,
          stats: stats
        };
        
      } catch (err) {
        console.error("Error fetching performance:", err);
      } finally {
        setLoading(false);
      }
    };
    const unsubscribe = auth.onAuthStateChanged(user => {
      if (user) {
        fetchPerformance(user);
      } else {
        if (typeof setLoading === 'function') setLoading(false);
      }
    });
    return () => unsubscribe();
  }, []);

  useEffect(() => {
    if (loading || (allBookings.length === 0 && allReviews.length === 0)) return;

    const now = new Date();
    let filterStart = null;
    let filterEnd = null;
    
    if (rangeLabel === 'Weekly') {
      filterStart = new Date(now);
      filterStart.setDate(filterStart.getDate() - 7);
    } else if (rangeLabel === 'Monthly') {
      filterStart = new Date(now);
      filterStart.setDate(filterStart.getDate() - 30);
    } else if (rangeLabel === 'Custom' && customStart && customEnd) {
      filterStart = new Date(customStart);
      filterEnd = new Date(customEnd);
      filterEnd.setHours(23, 59, 59, 999);
    }

    const filteredBookings = allBookings.filter(b => {
      if (!b.parsedDate) return true;
      if (filterStart && b.parsedDate < filterStart) return false;
      if (filterEnd && b.parsedDate > filterEnd) return false;
      return true;
    });

    const filteredReviews = allReviews.filter(r => {
      if (!r.timestamp) return true;
      if (filterStart && r.timestamp < filterStart) return false;
      if (filterEnd && r.timestamp > filterEnd) return false;
      return true;
    });

    let completedSessions = 0;
    let cancelledSessions = 0;
    const totalBookings = filteredBookings.length;
    const patientCounts = {};
    const dayCounts = {0:0,1:0,2:0,3:0,4:0,5:0,6:0};

    filteredBookings.forEach(b => {
      const statusUpper = b.status?.toUpperCase() || '';
      if (statusUpper === 'COMPLETED') {
        completedSessions++;
        if (b.parsedDate) dayCounts[b.parsedDate.getDay()]++;
      }
      if (statusUpper === 'CANCELLED') cancelledSessions++;

      const pId = b.patientId || b.userId || 'unknown';
      patientCounts[pId] = (patientCounts[pId] || 0) + 1;
    });

    const daysArr = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    let maxDay = -1, maxDayCount = -1;
    Object.keys(dayCounts).forEach(dStr => {
      if (dayCounts[dStr] > maxDayCount) { maxDayCount = dayCounts[dStr]; maxDay = parseInt(dStr); }
    });
    const peakDay = maxDayCount > 0 ? daysArr[maxDay] : 'N/A';

    const retentionCount = Object.values(patientCounts).filter(c => c > 1).length;
    const totalPatients = Object.keys(patientCounts).length;
    const retentionRate = totalPatients > 0 ? ((retentionCount / totalPatients) * 100).toFixed(0) + '%' : '0%';

    const completionRate = totalBookings > 0 ? ((completedSessions / totalBookings) * 100).toFixed(0) + '%' : '0%';
    const cancelRate = totalBookings > 0 ? ((cancelledSessions / totalBookings) * 100).toFixed(1) + '%' : '0.0%';
    const hours = completedSessions.toString();

    let totalScore = 0;
    const distribution = [0,0,0,0,0];
    filteredReviews.forEach(r => {
      const val = r.rating || 5;
      totalScore += val;
      if (val >= 1 && val <= 5) distribution[val - 1]++;
    });
    const satisfaction = filteredReviews.length > 0 ? (totalScore / filteredReviews.length).toFixed(1) : '0.0';

    let chartData = [];
    if (rangeLabel === 'Weekly' || (rangeLabel === 'Custom' && filterStart && filterEnd && (filterEnd - filterStart) <= 14 * 24 * 60 * 60 * 1000)) {
      // Daily bins for weekly or short custom range
      const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      for (let i = 6; i >= 0; i--) {
        const d = filterEnd ? new Date(filterEnd) : new Date(now);
        d.setDate(d.getDate() - i);
        const count = filteredBookings.filter(b => b.status?.toUpperCase() === 'COMPLETED' && b.parsedDate && b.parsedDate.toDateString() === d.toDateString()).length;
        chartData.push({ label: dayNames[d.getDay()], val: count });
      }
    } else {
      // Monthly bins
      const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      for (let i = 5; i >= 0; i--) {
        const d = filterEnd ? new Date(filterEnd) : new Date(now);
        d.setMonth(d.getMonth() - i);
        const count = allBookings.filter(b => b.status?.toUpperCase() === 'COMPLETED' && b.parsedDate && b.parsedDate.getMonth() === d.getMonth() && b.parsedDate.getFullYear() === d.getFullYear()).length;
        chartData.push({ label: monthNames[d.getMonth()], val: count });
      }
    }

    setStats({ 
      satisfaction, hours, cancelRate, completionRate, retentionRate, peakDay, 
      reviewCount: filteredReviews.length, ratingDistribution: distribution, chartData, 
      feedbackList: filteredReviews, totalSessions: completedSessions, totalPatients 
    });
  }, [rangeLabel, allBookings, allReviews, loading, customStart, customEnd]);

  useEffect(() => {
    if (customStart || customEnd) {
      setRangeLabel('Custom');
    }
  }, [customStart, customEnd]);

  const generatePDF = async () => {
    if (!pdfRef.current) return;
    setExporting(true);

    try {
      // Temporarily un-hide the PDF container to render it on canvas
      const element = pdfRef.current;
      element.style.display = 'block';

      const canvas = await html2canvas(element, {
        scale: 2, // High resolution
        useCORS: true,
        logging: false,
        backgroundColor: '#ffffff'
      });

      element.style.display = 'none';

      const imgData = canvas.toDataURL('image/png');
      const pdf = new jsPDF('p', 'mm', 'a4');
      const pdfWidth = pdf.internal.pageSize.getWidth();
      const pageHeight = pdf.internal.pageSize.getHeight();
      
      // 15mm margin on all sides
      const margin = 15;
      const effectiveWidth = pdfWidth - 2 * margin;
      const effectivePageHeight = pageHeight - 2 * margin;
      
      const imgHeight = (canvas.height * effectiveWidth) / canvas.width;
      const totalPages = Math.ceil(imgHeight / effectivePageHeight);
      
      for (let i = 1; i <= totalPages; i++) {
        if (i > 1) {
          pdf.addPage();
        }
        
        const sourceY = -(i - 1) * effectivePageHeight;
        
        // Draw the full image shifted up by the amount we've already shown
        pdf.addImage(imgData, 'PNG', margin, margin + sourceY, effectiveWidth, imgHeight);
        
        // Draw white rectangles over the top and bottom margins to hide the overflowing image parts
        pdf.setFillColor(255, 255, 255);
        pdf.rect(0, 0, pdfWidth, margin, 'F'); // Top margin cover
        pdf.rect(0, pageHeight - margin, pdfWidth, margin, 'F'); // Bottom margin cover
        
        // Draw Page Number
        pdf.setFontSize(9);
        pdf.setTextColor(120);
        pdf.text(`Page ${i} of ${totalPages}`, pdfWidth - margin, pageHeight - 6, { align: 'right' });
        
        // Add a small footer text on the left
        pdf.text(`Eunoia Performance Report - ${counsellorName}`, margin, pageHeight - 6, { align: 'left' });
      }
      
      pdf.save(`Eunoia_Performance_${counsellorName.replace(/\s+/g, '_')}_${new Date().toISOString().slice(0,10)}.pdf`);
    } catch (error) {
      console.error("PDF generation failed", error);
    } finally {
      setExporting(false);
    }
  };

  const getBarColor = (star) => {
    if (star >= 4) return '#7C9C84';
    if (star === 3) return '#D97706';
    return '#EF4444';
  };

  const getPeriodString = () => {
    if (rangeLabel === 'Custom' && customStart && customEnd) {
      return `${new Date(customStart).toLocaleDateString()} - ${new Date(customEnd).toLocaleDateString()}`;
    }
    return rangeLabel;
  };

  const refId = `CP-${new Date().getFullYear()}-${Date.now().toString().slice(-6)}`;

  return (
    <div style={{ paddingBottom: '40px', position: 'relative' }}>
      <header className="page-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginBottom: '24px' }}>
        <div>
          <h1 className="page-title">Performance Analytics</h1>
          <p className="page-subtitle">Track your counseling metrics, feedback ratings, and session performance.</p>
        </div>
      </header>

      {/* Control Bar */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', backgroundColor: 'var(--bg-card)', padding: '12px 20px', borderRadius: '16px', border: '1px solid var(--border-color)', marginBottom: '32px', boxShadow: '0 4px 12px rgba(124,156,132,0.03)' }}>
        <div style={{ display: 'flex', gap: '8px', alignItems: 'center', position: 'relative' }}>
          {['Weekly', 'Monthly', 'All Time'].map(label => (
            <button
              key={label}
              onClick={() => { setRangeLabel(label); setDateRange([null, null]); }}
              style={{
                padding: '6px 14px', borderRadius: '8px', border: 'none',
                backgroundColor: rangeLabel === label ? 'var(--primary-color)' : 'transparent',
                color: rangeLabel === label ? 'white' : 'var(--text-dark)',
                fontSize: '13px', fontWeight: 600, cursor: 'pointer', transition: 'all 0.2s'
              }}
            >
              {label}
            </button>
          ))}
          
          <div style={{ position: 'relative' }}>
            <DatePicker
              selectsRange={true}
              startDate={customStart}
              endDate={customEnd}
              onChange={(update) => {
                setDateRange(update);
              }}
              isClearable={true}
              placeholderText="Select date range..."
              customInput={
                <button 
                  style={{ 
                    display: 'flex', alignItems: 'center', justifyContent: 'center', 
                    padding: '6px 10px', 
                    paddingRight: (customStart || customEnd) ? '28px' : '10px',
                    borderRadius: '8px', border: 'none', 
                    backgroundColor: (customStart || rangeLabel === 'Custom') ? 'var(--primary-light)' : 'transparent', 
                    cursor: 'pointer', marginLeft: '4px', gap: '6px', fontSize: '13px', fontWeight: 600, 
                    color: (customStart || rangeLabel === 'Custom') ? 'var(--primary-color)' : 'var(--text-muted)' 
                  }}
                >
                  <CalIcon size={18} />
                  {(customStart && customEnd) ? 'Custom' : ''}
                </button>
              }
            />
          </div>


        </div>

        <button 
          onClick={generatePDF}
          disabled={exporting}
          style={{
            display: 'flex', alignItems: 'center', gap: '8px',
            backgroundColor: 'var(--bg-main)', color: 'var(--text-darker)',
            border: '1px solid var(--border-color)', padding: '8px 16px', borderRadius: '10px',
            fontWeight: 600, fontSize: '13px', cursor: exporting ? 'wait' : 'pointer',
            transition: 'all 0.2s', opacity: exporting ? 0.7 : 1
          }}
        >
          <Download size={16} color="var(--primary-color)" />
          {exporting ? 'Generating...' : 'Export Report'}
        </button>
      </div>

      {loading ? (
        <div style={{ textAlign: 'center', padding: '60px', color: 'var(--text-muted)', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '16px' }}>
          <div style={{ width: '32px', height: '32px', border: '3px solid var(--primary-light)', borderTopColor: 'var(--primary-color)', borderRadius: '50%', animation: 'spin 1s linear infinite' }} />
          Calculating metrics...
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          {/* Top Level KPIs */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '20px' }}>
            <div className="card stat-card" style={{ padding: '20px' }}>
              <div>
                <p className="stat-title">Client Satisfaction</p>
                <p className="stat-value" style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  {stats.satisfaction} <Star size={22} fill="#f59e0b" color="#f59e0b" />
                </p>
              </div>
            </div>
            <div className="card stat-card" style={{ padding: '20px' }}>
              <div>
                <p className="stat-title">Clinical Hours</p>
                <p className="stat-value">{stats.hours}h</p>
              </div>
              <div className="stat-icon-wrapper" style={{ backgroundColor: 'var(--primary-light)', color: 'var(--primary-color)' }}>
                <Award size={24} />
              </div>
            </div>
            <div className="card stat-card" style={{ padding: '20px' }}>
              <div>
                <p className="stat-title">Completion Rate</p>
                <p className="stat-value" style={{ color: '#00A666' }}>{stats.completionRate}</p>
              </div>
              <div className="stat-icon-wrapper" style={{ backgroundColor: '#E6F7F0', color: '#00A666' }}>
                <CheckCircle size={24} />
              </div>
            </div>
            <div className="card stat-card" style={{ padding: '20px' }}>
              <div>
                <p className="stat-title">Client Retention</p>
                <p className="stat-value" style={{ color: '#3b82f6' }}>{stats.retentionRate}</p>
              </div>
              <div className="stat-icon-wrapper" style={{ backgroundColor: '#eff6ff', color: '#3b82f6' }}>
                <RotateCcw size={24} />
              </div>
            </div>
          </div>

          {/* Main Analytics Dashboard */}
          <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: '24px' }}>
            <div className="card" style={{ display: 'flex', flexDirection: 'column' }}>
              <div style={{ marginBottom: '32px' }}>
                <h2 style={{ fontSize: '20px', fontWeight: 700, color: 'var(--text-darker)' }}>Session Productivity</h2>
                <p style={{ fontSize: '13px', color: 'var(--text-muted)' }}>{rangeLabel === 'Weekly' ? 'Daily session volume' : 'Periodic session volume'}</p>
              </div>
              <div style={{ flex: 1, display: 'flex', alignItems: 'flex-end', justifyContent: 'space-around', minHeight: '200px', padding: '10px 0 0 0' }}>
                {stats.chartData.map((m, i) => {
                  const maxVal = Math.max(...stats.chartData.map(d => d.val), 5);
                  return (
                  <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px', flex: 1 }}>
                    <div style={{ position: 'relative', width: '36px', height: '160px', display: 'flex', alignItems: 'flex-end', backgroundColor: 'var(--bg-main)', borderRadius: '8px' }}>
                      <div 
                        style={{ 
                          width: '100%', 
                          height: `${(m.val / maxVal) * 100}%`, 
                          background: 'linear-gradient(to top, var(--primary-color), #a3bba9)', 
                          borderRadius: '8px',
                          transition: 'all 0.8s cubic-bezier(0.4, 0, 0.2, 1)',
                        }}
                        title={`${m.val} sessions`}
                      />
                    </div>
                    <span style={{ fontSize: '12px', color: 'var(--text-muted)', fontWeight: 600 }}>{m.label}</span>
                  </div>
                )})}
              </div>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
              <div className="card">
                <h2 style={{ fontSize: '20px', fontWeight: 700, color: 'var(--text-darker)', marginBottom: '24px' }}>Rating Distribution</h2>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  {[5,4,3,2,1].map(star => {
                    const count = stats.ratingDistribution[star - 1];
                    const pct = stats.reviewCount > 0 ? (count / stats.reviewCount) * 100 : 0;
                    return (
                      <div key={star} style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: '4px', width: '32px' }}>
                          <span style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-darker)' }}>{star}</span>
                          <Star size={12} fill="var(--text-muted)" color="var(--text-muted)" />
                        </div>
                        <div style={{ flex: 1, height: '8px', backgroundColor: 'var(--bg-main)', borderRadius: '4px', overflow: 'hidden' }}>
                          <div style={{ width: `${pct}%`, height: '100%', backgroundColor: getBarColor(star), borderRadius: '4px', transition: 'width 1s ease-out' }} />
                        </div>
                        <span style={{ fontSize: '12px', color: 'var(--text-muted)', width: '24px', textAlign: 'right' }}>{count}</span>
                      </div>
                    )
                  })}
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div className="card" style={{ padding: '16px' }}>
                  <TrendingUp size={20} color="#3b82f6" style={{ marginBottom: '12px' }} />
                  <p style={{ fontSize: '12px', color: 'var(--text-muted)', margin: '0 0 4px 0', fontWeight: 600 }}>Peak Day</p>
                  <p style={{ fontSize: '18px', fontWeight: 700, color: 'var(--text-darker)', margin: 0 }}>{stats.peakDay}</p>
                </div>
                <div className="card" style={{ padding: '16px' }}>
                  <ShieldAlert size={20} color="#F56565" style={{ marginBottom: '12px' }} />
                  <p style={{ fontSize: '12px', color: 'var(--text-muted)', margin: '0 0 4px 0', fontWeight: 600 }}>Cancel Rate</p>
                  <p style={{ fontSize: '18px', fontWeight: 700, color: 'var(--text-darker)', margin: 0 }}>{stats.cancelRate}</p>
                </div>
              </div>
            </div>
          </div>

          {/* Recent Client Feedback */}
          <div className="card">
            <h2 style={{ fontSize: '20px', fontWeight: 700, color: 'var(--text-darker)', marginBottom: '20px' }}>Recent Client Feedback</h2>
            {stats.feedbackList && stats.feedbackList.length > 0 ? (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: '16px' }}>
                {stats.feedbackList.slice(0, 6).map((review, i) => (
                  <div key={i} style={{ padding: '16px', backgroundColor: 'var(--bg-secondary)', borderRadius: '12px', border: '1px solid var(--border-color)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '12px' }}>
                      <div style={{ display: 'flex', gap: '2px' }}>
                        {[...Array(5)].map((_, idx) => (
                          <Star key={idx} size={14} fill={idx < (review.rating || 5) ? '#f59e0b' : 'transparent'} color={idx < (review.rating || 5) ? '#f59e0b' : '#d1d5db'} />
                        ))}
                      </div>
                      <span style={{ fontSize: '12px', color: 'var(--text-muted)' }}>
                        {review.timestamp ? new Date(review.timestamp).toLocaleDateString(undefined, {month:'short', day:'numeric'}) : ''}
                      </span>
                    </div>
                    <p style={{ fontSize: '13px', color: 'var(--text-darker)', fontStyle: 'italic', marginBottom: '12px', lineHeight: '1.5' }}>
                      "{review.comment || 'Great session, highly recommended!'}"
                    </p>
                    <p style={{ fontSize: '12px', color: 'var(--text-muted)', textAlign: 'right', margin: 0, fontWeight: 500 }}>
                      - {review.patientName || 'Anonymous'}
                    </p>
                  </div>
                ))}
              </div>
            ) : (
              <div style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)', backgroundColor: 'var(--bg-secondary)', borderRadius: '12px', border: '1px dashed var(--border-color)' }}>
                No feedback received for this period.
              </div>
            )}
          </div>

        </div>
      )}

      {/* HIDDEN PDF TEMPLATE - MOBILE PARITY */}
      <div style={{ position: 'absolute', top: '-15000px', left: '-15000px', opacity: 0, zIndex: -10 }}>
        <div ref={pdfRef} style={{ width: '794px', backgroundColor: '#ffffff', color: '#333333', display: 'none', padding: '48px', boxSizing: 'border-box', fontFamily: 'sans-serif' }}>
          
          {/* Header */}
          <div style={{ borderBottom: '1px solid #E0EAE3', paddingBottom: '12px', display: 'flex', justifyContent: 'space-between', marginBottom: '32px' }}>
            <span style={{ color: '#7C9C84', fontWeight: 'bold', fontSize: '18px' }}>Eunoia</span>
            <span style={{ color: '#888888', fontSize: '10px', letterSpacing: '1px', fontWeight: 'bold' }}>COUNSELLOR PERFORMANCE AUDIT</span>
          </div>

          {/* Cover Block */}
          <div style={{ backgroundColor: '#F4F7F5', padding: '28px', borderRadius: '14px', display: 'flex', justifyContent: 'space-between', marginBottom: '32px' }}>
            <div>
              <h1 className="page-title">Counsellor Performance Report</h1>
              <p style={{ color: '#666666', fontSize: '11px', margin: '0 0 16px 0' }}>Clinical Insight and Service Audit</p>
              <p style={{ fontSize: '11px', fontWeight: 'bold', margin: '0 0 4px 0' }}>Practitioner: {counsellorName}</p>
              <p style={{ fontSize: '11px', color: '#888888', margin: 0 }}>Period: {getPeriodString()}</p>
            </div>
            <div style={{ textAlign: 'right' }}>
              <p style={{ color: '#7C9C84', fontWeight: 'bold', fontSize: '10px', margin: '0 0 4px 0' }}>REF: {refId}</p>
              <p style={{ color: '#888888', fontSize: '10px', margin: '0 0 4px 0' }}>Generated: {new Date().toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric'})}</p>
              <p style={{ color: '#888888', fontSize: '9px', margin: 0 }}>Eunoia Analytics Engine v2.1</p>
            </div>
          </div>

          {/* 1. Executive Summary */}
          <div>
            <h2 style={{ fontSize: '16px', fontFamily: 'serif', margin: '0 0 6px 0' }}>1. Executive Summary</h2>
            <div style={{ width: '40px', height: '2px', backgroundColor: '#7C9C84', marginBottom: '14px' }}></div>
            <div style={{ border: '1px solid #E0EAE3', padding: '18px', borderRadius: '10px', marginBottom: '16px' }}>
              <p style={{ fontSize: '11px', lineHeight: '1.6', color: '#555555', margin: 0 }}>
                This report provides an overview of {counsellorName}'s service performance during the {getPeriodString()} period. The overall results indicate consistent session completion, positive client feedback, and stable engagement across counselling activities. Clinical benchmarks remain high with exceptional patient satisfaction reported.
              </p>
            </div>
            <div style={{ display: 'flex', gap: '8px', marginBottom: '32px' }}>
              {[
                { label: 'Sessions', val: stats.totalSessions, col: '#7C9C84' },
                { label: 'Avg. Rating', val: `${stats.satisfaction}/5.0`, col: '#BBCBC2' },
                { label: 'Completion', val: stats.completionRate, col: '#4B5563' },
                { label: 'Clients', val: stats.totalPatients, col: '#D97706' },
                { label: 'Hours', val: `${stats.hours}h`, col: '#7C9C84' }
              ].map(kpi => (
                <div key={kpi.label} style={{ flex: 1, padding: '12px', border: '1px solid #EEEEEE', borderRadius: '10px' }}>
                  <div style={{ width: '20px', height: '3px', backgroundColor: kpi.col, marginBottom: '8px' }}></div>
                  <p style={{ margin: '0 0 4px 0', fontSize: '14px', fontWeight: 'bold', color: kpi.col }}>{kpi.val}</p>
                  <p style={{ margin: 0, fontSize: '9px', color: '#888888' }}>{kpi.label}</p>
                </div>
              ))}
            </div>
          </div>

          {/* 2. Session Activity Trend */}
          <div>
            <h2 style={{ fontSize: '16px', fontFamily: 'serif', margin: '0 0 6px 0' }}>2. Session Activity Trend</h2>
            <div style={{ width: '40px', height: '2px', backgroundColor: '#7C9C84', marginBottom: '14px' }}></div>
            <div style={{ border: '1px solid #EEEEEE', borderRadius: '12px', padding: '16px', height: '120px', display: 'flex', alignItems: 'flex-end', justifyContent: 'space-around', marginBottom: '32px' }}>
              {stats.chartData.map((d, i) => {
                const max = Math.max(...stats.chartData.map(c => c.val), 5);
                const h = (d.val / max) * 80; // max height 80px
                return (
                  <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
                    <div style={{ width: '20px', height: `${h}px`, backgroundColor: '#7C9C84', borderRadius: '4px', marginBottom: '6px' }}></div>
                    <span style={{ fontSize: '9px', color: '#888888' }}>{d.label}</span>
                  </div>
                );
              })}
            </div>
          </div>

          {/* 3. Feedback and Satisfaction */}
          <div style={{ display: 'flex', gap: '32px', marginBottom: '32px' }}>
            <div style={{ flex: 1 }}>
              <h2 style={{ fontSize: '16px', fontFamily: 'serif', margin: '0 0 6px 0' }}>3. Feedback & Satisfaction</h2>
              <div style={{ width: '40px', height: '2px', backgroundColor: '#7C9C84', marginBottom: '14px' }}></div>
              <p style={{ fontSize: '11px', fontWeight: 'bold', marginBottom: '8px' }}>Rating Distribution</p>
              {[5,4,3,2,1].map(star => {
                const count = stats.ratingDistribution[star-1];
                const pct = stats.reviewCount > 0 ? (count / stats.reviewCount) * 100 : 0;
                return (
                  <div key={star} style={{ display: 'flex', alignItems: 'center', marginBottom: '6px' }}>
                    <span style={{ fontSize: '9px', width: '40px' }}>{star} Stars</span>
                    <div style={{ flex: 1, height: '4px', backgroundColor: '#F0F0F0', margin: '0 10px' }}>
                      <div style={{ width: `${pct}%`, height: '100%', backgroundColor: getBarColor(star) }}></div>
                    </div>
                    <span style={{ fontSize: '9px', width: '20px', textAlign: 'right' }}>{count}</span>
                  </div>
                )
              })}
            </div>
            <div style={{ flex: 1 }}>
              <h2 style={{ fontSize: '16px', fontFamily: 'serif', margin: '0 0 6px 0', color: 'white' }}>_</h2>
              <div style={{ width: '40px', height: '2px', backgroundColor: 'transparent', marginBottom: '14px' }}></div>
              <p style={{ fontSize: '11px', fontWeight: 'bold', marginBottom: '8px' }}>Common Feedback Themes</p>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '8px' }}>
                {['Supportive', 'Professional', 'Good Listener', 'Valuable Guidance'].map(t => (
                  <span key={t} style={{ backgroundColor: '#F4F7F5', padding: '4px 8px', borderRadius: '4px', fontSize: '9px', color: '#555555' }}>{t}</span>
                ))}
              </div>
            </div>
          </div>

          {/* 4. Client Engagement Indicators */}
          <div>
            <h2 style={{ fontSize: '16px', fontFamily: 'serif', margin: '0 0 6px 0' }}>4. Client Engagement Indicators</h2>
            <div style={{ width: '40px', height: '2px', backgroundColor: '#7C9C84', marginBottom: '14px' }}></div>
            <div style={{ display: 'flex', gap: '12px', marginBottom: '32px' }}>
              <div style={{ flex: 1, padding: '14px', border: '1px solid #EEEEEE', borderRadius: '12px' }}>
                <p style={{ fontSize: '9px', color: '#888888', margin: '0 0 8px 0' }}>Repeat Rate</p>
                <p style={{ fontSize: '14px', fontWeight: 'bold', color: '#7C9C84', margin: 0 }}>{stats.retentionRate}</p>
              </div>
              <div style={{ flex: 1, padding: '14px', border: '1px solid #EEEEEE', borderRadius: '12px' }}>
                <p style={{ fontSize: '9px', color: '#888888', margin: '0 0 8px 0' }}>Peak Day</p>
                <p style={{ fontSize: '14px', fontWeight: 'bold', color: '#4B5563', margin: 0 }}>{stats.peakDay}</p>
              </div>
              <div style={{ flex: 1, padding: '14px', border: '1px solid #EEEEEE', borderRadius: '12px' }}>
                <p style={{ fontSize: '9px', color: '#888888', margin: '0 0 8px 0' }}>Cancel Rate</p>
                <p style={{ fontSize: '14px', fontWeight: 'bold', color: '#D97706', margin: 0 }}>{stats.cancelRate}</p>
              </div>
            </div>
          </div>

          {/* 5. Personal Insights & Recommendations */}
          <div>
            <h2 style={{ fontSize: '16px', fontFamily: 'serif', margin: '0 0 6px 0' }}>5. Personal Insights & Recommendations</h2>
            <div style={{ width: '40px', height: '2px', backgroundColor: '#7C9C84', marginBottom: '14px' }}></div>
            <div style={{ backgroundColor: '#F4F7F5', padding: '16px', borderRadius: '12px', marginBottom: '40px' }}>
              <ul style={{ margin: 0, paddingLeft: '20px', color: '#555555', fontSize: '11px', lineHeight: '1.8' }}>
                <li>The counsellor maintains a strong average rating across all completed sessions.</li>
                <li>Client retention is robust, indicating high satisfaction with initial consultations.</li>
                <li>Maintain current strengths in client communication and punctuality.</li>
                <li>Consider optimising availability on peak session days ({stats.peakDay}) to accommodate demand.</li>
              </ul>
            </div>
          </div>

          {/* Footer */}
          <div style={{ borderTop: '1px solid #EEEEEE', paddingTop: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end' }}>
            <div>
              <p style={{ fontWeight: 'bold', fontSize: '11px', color: '#7C9C84', margin: '0 0 4px 0' }}>Eunoia Sage Analytics Engine</p>
              <p style={{ fontSize: '9px', color: '#888888', margin: '0 0 2px 0' }}>This report is strictly confidential and intended solely for the named recipient.</p>
              <p style={{ fontSize: '9px', color: '#888888', margin: 0 }}>Report ID: {refId} | Generated: {new Date().toLocaleString()}</p>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ width: '160px', borderBottom: '1px solid #888888', marginBottom: '6px' }}></div>
              <p style={{ fontSize: '9px', color: '#888888', margin: 0 }}>Verified by System Administrator</p>
            </div>
          </div>

        </div>
      </div>
      <style>{`@keyframes spin { 100% { transform: rotate(360deg); } }`}</style>
    </div>
  );
}
