import React from 'react';
import { Award, Heart, ShieldAlert, Star } from 'lucide-react';

export default function Performance() {
  const feedbackList = [
    {
      name: "Clara Tan",
      rating: 5,
      date: "May 18, 2026",
      text: "The guidance and mindfulness exercises suggested by the therapist changed my morning routines completely. Very supportive."
    },
    {
      name: "Marcus Aurelius",
      rating: 5,
      date: "May 14, 2026",
      text: "Excellent session. The anxiety breathing patterns we practiced during our session have been a lifesaver during exams."
    },
    {
      name: "Sarah Jenkins",
      rating: 4.8,
      date: "May 10, 2026",
      text: "Highly recommended clinical approach. It feels like a safe, non-judgmental space every single time."
    }
  ];

  return (
    <div>
      <header className="page-header">
        <h1 className="page-title">Performance Analytics</h1>
        <p className="page-subtitle">Track your counseling metrics, feedback ratings, and session performance.</p>
      </header>

      {/* KPI Cards */}
      <div className="grid-3" style={{ marginBottom: '32px' }}>
        <div className="card stat-card">
          <div>
            <p className="stat-title">Client Satisfaction</p>
            <p className="stat-value">98.4%</p>
          </div>
          <div className="stat-icon-wrapper" style={{ backgroundColor: '#E6F7F0', color: '#00A666' }}>
            <Heart size={24} />
          </div>
        </div>

        <div className="card stat-card">
          <div>
            <p className="stat-title">Total Hours Logged</p>
            <p className="stat-value">148h</p>
          </div>
          <div className="stat-icon-wrapper" style={{ backgroundColor: 'var(--primary-light)', color: 'var(--primary-color)' }}>
            <Award size={24} />
          </div>
        </div>

        <div className="card stat-card">
          <div>
            <p className="stat-title">Cancel Rate</p>
            <p className="stat-value">1.8%</p>
          </div>
          <div className="stat-icon-wrapper" style={{ backgroundColor: '#FFF0F0', color: '#F56565' }}>
            <ShieldAlert size={24} />
          </div>
        </div>
      </div>

      {/* Analytics Content */}
      <div className="grid-2">
        {/* Session Stats (CSS Bar Chart) */}
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div>
            <h2 style={{ fontSize: '18px', fontWeight: 700, color: 'var(--text-darker)' }}>Monthly Session Volume</h2>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Completed sessions per month</p>
          </div>

          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', height: '220px', padding: '10px 10px 0 10px', borderBottom: '1px solid var(--border-color)', margin: '10px 0' }}>
            {[
              { label: 'Jan', val: 40 },
              { label: 'Feb', val: 55 },
              { label: 'Mar', val: 70 },
              { label: 'Apr', val: 90 },
              { label: 'May', val: 120 },
              { label: 'Jun', val: 110 }
            ].map((m, i) => (
              <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', flex: 1, gap: '8px' }}>
                <div style={{ position: 'relative', width: '28px', height: '180px', display: 'flex', alignItems: 'flex-end' }}>
                  <div 
                    style={{ 
                      width: '100%', 
                      height: `${(m.val / 120) * 100}%`, 
                      background: 'linear-gradient(to top, #7C9C84, #a3bba9)', 
                      borderRadius: '6px 6px 0 0',
                      transition: 'all 0.6s cubic-bezier(0.4, 0, 0.2, 1)',
                    }}
                    title={`${m.val} sessions`}
                  />
                </div>
                <span style={{ fontSize: '12px', color: 'var(--text-muted)', fontWeight: 500 }}>{m.label}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Feedback List */}
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
          <div>
            <h2 style={{ fontSize: '18px', fontWeight: 700, color: 'var(--text-darker)' }}>Recent Client Feedback</h2>
            <p style={{ fontSize: '12px', color: 'var(--text-muted)' }}>Latest reviews and session comments</p>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', overflowY: 'auto', maxHeight: '250px', paddingRight: '4px' }}>
            {feedbackList.map((feedback, index) => (
              <div key={index} style={{ padding: '16px', border: '1px solid var(--border-color)', borderRadius: '16px', backgroundColor: 'var(--bg-secondary)', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <div className="flex-between">
                  <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                    <div style={{ width: '32px', height: '32px', borderRadius: '50%', backgroundColor: 'white', border: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', color: 'var(--primary-color)', fontSize: '12px' }}>
                      {feedback.name.charAt(0)}
                    </div>
                    <div>
                      <h4 style={{ fontSize: '13px', fontWeight: 600, color: 'var(--text-darker)' }}>{feedback.name}</h4>
                      <p style={{ fontSize: '10px', color: 'var(--text-muted)' }}>{feedback.date}</p>
                    </div>
                  </div>
                  <span style={{ fontSize: '12px', color: '#f59e0b', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '2px' }}>
                    <Star size={12} fill="#f59e0b" /> {feedback.rating}
                  </span>
                </div>
                <p style={{ fontSize: '12px', color: 'var(--text-dark)', lineHeight: '1.5', fontStyle: 'italic' }}>
                  "{feedback.text}"
                </p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
