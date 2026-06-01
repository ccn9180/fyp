import React, { useState, useEffect } from 'react';
import { doc, getDoc, updateDoc, addDoc, collection, serverTimestamp } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { User, Mail, Phone, MapPin, Edit, Save, X, Briefcase, FileText, ShieldAlert, CheckCircle2, Award, Languages, DollarSign } from 'lucide-react';

export default function Profile() {
  const [profile, setProfile] = useState({
    name: 'Counsellor',
    specializations: ['Mental Health Specialist'],
    bio: '',
    experience: '3-5 Years',
    languages: ['English'],
    email: '',
    phone: '',
    location: '',
    licenseNumber: '',
    price: 'Free',
    photo: null
  });

  const [editMode, setEditMode] = useState(false);
  const [formData, setFormData] = useState({ ...profile });
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  // Deactivation state
  const [showDeactivation, setShowDeactivation] = useState(false);
  const [deactivateReason, setDeactivateReason] = useState('Temporary Break');
  const [deactivateDetails, setDeactivateDetails] = useState('');
  const [deactivating, setDeactivating] = useState(false);
  const [deactivateSuccess, setDeactivateSuccess] = useState(false);

  const experienceOptions = ['1-2 Years', '3-5 Years', '5-10 Years', '10+ Years', '15+ Years'];
  const specializationOptions = [
    'Anxiety & Stress', 'Depression', 'Relationship Issues', 
    'Trauma & PTSD', 'Career Counseling', 'Addiction Recovery',
    'OCD', 'Grief & Loss', 'Eating Disorders'
  ];
  const languageOptions = ['English', 'Malay', 'Mandarin', 'Cantonese', 'Tamil', 'Hokkien'];
  const commonDeactivateReasons = [
    'Career Change',
    'Personal / Health Reasons',
    'Retirement',
    'Moving to Private Practice',
    'Temporary Break',
    'Other',
  ];

  const fetchProfile = async () => {
    const user = auth.currentUser;
    if (!user) return;
    setLoading(true);

    try {
      const docRef = doc(db, 'users', user.uid);
      const snap = await getDoc(docRef);
      if (snap.exists()) {
        const data = snap.data();
        const specs = data.specializations || ['Mental Health Specialist'];
        const langs = data.languages || ['English'];
        const license = data.licenseNumber || `E-SAGE-${user.uid.substring(0, 8).toUpperCase()}`;

        const pData = {
          name: data.fullName || data.name || user.displayName || 'Counsellor',
          specializations: Array.isArray(specs) ? specs : [specs],
          bio: data.bio || '',
          experience: data.experience || '3-5 Years',
          languages: Array.isArray(langs) ? langs : [langs],
          email: data.email || user.email || '',
          phone: data.phone || '',
          location: data.location || 'Eunoia Health Center, Clinical District',
          licenseNumber: license,
          price: data.price?.toString() || 'Free',
          photo: data.counsellorImageUrl || data.profileImageUrl || data.photoUrl || user.photoURL || null
        };
        setProfile(pData);
        setFormData(pData);
      }
    } catch (e) {
      console.error("Error loading counsellor profile:", e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchProfile();
  }, []);

  const handleSave = async (e) => {
    e.preventDefault();
    setError('');
    setMessage('');
    setSaving(true);

    const user = auth.currentUser;
    if (!user) return;

    try {
      const docRef = doc(db, 'users', user.uid);
      const updatePayload = {
        fullName: formData.name,
        name: formData.name,
        phone: formData.phone,
        location: formData.location,
        price: formData.price || 'Free',
        bio: formData.bio,
        experience: formData.experience,
        specializations: formData.specializations,
        languages: formData.languages,
        updatedAt: serverTimestamp()
      };
      
      await updateDoc(docRef, updatePayload);

      setProfile({ ...formData });
      setMessage('Professional profile updated successfully!');
      setEditMode(false);
    } catch (err) {
      console.error("Error saving profile:", err);
      setError('Failed to save profile changes. Please try again.');
    } finally {
      setSaving(false);
    }
  };

  const handleDeactivate = async (e) => {
    e.preventDefault();
    if (!deactivateDetails.trim()) {
      alert("Please provide detailed explanation for deactivation.");
      return;
    }

    const user = auth.currentUser;
    if (!user) return;

    setDeactivating(true);
    try {
      // Add record matching mobile app deactivation schema
      await addDoc(collection(db, 'deactivation_requests'), {
        counsellorId: user.uid,
        counsellorName: profile.name,
        reason: deactivateReason,
        details: deactivateDetails,
        status: 'Pending',
        requestedAt: serverTimestamp()
      });

      setDeactivateSuccess(true);
      setDeactivateDetails('');
    } catch (err) {
      console.error("Error submitting deactivation request:", err);
      alert("Failed to submit request. Please try again later.");
    } finally {
      setDeactivating(false);
    }
  };

  const toggleSpecialization = (spec) => {
    const current = [...formData.specializations];
    const index = current.indexOf(spec);
    if (index > -1) {
      if (current.length > 1) current.splice(index, 1);
    } else {
      current.push(spec);
    }
    setFormData({ ...formData, specializations: current });
  };

  const toggleLanguage = (lang) => {
    const current = [...formData.languages];
    const index = current.indexOf(lang);
    if (index > -1) {
      if (current.length > 1) current.splice(index, 1);
    } else {
      current.push(lang);
    }
    setFormData({ ...formData, languages: current });
  };

  if (loading) {
    return (
      <div className="card" style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
        Loading profile details…
      </div>
    );
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '28px' }}>
      <header className="page-header">
        <h1 className="page-title">Counsellor Profile</h1>
        <p className="page-subtitle">Oversee and update your clinical registration, credentials, and therapist details.</p>
      </header>

      <div className="card" style={{ maxWidth: '800px' }}>
        {/* Header Block */}
        <div className="flex-between" style={{ marginBottom: '32px', borderBottom: '1px solid var(--border-color)', paddingBottom: '24px' }}>
          <div style={{ display: 'flex', gap: '24px', alignItems: 'center' }}>
            <div style={{ 
              width: '90px', 
              height: '90px', 
              borderRadius: '50%', 
              backgroundColor: 'var(--primary-light)', 
              display: 'flex', 
              alignItems: 'center', 
              justifyContent: 'center', 
              color: 'var(--primary-color)',
              fontWeight: 700,
              fontSize: '24px',
              border: '1px solid rgba(124, 156, 132, 0.15)',
              overflow: 'hidden'
            }}>
              {profile.photo ? (
                <img src={profile.photo} alt="P" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
              ) : (
                <span style={{ fontSize: '32px' }}>{profile.name.charAt(0)}</span>
              )}
            </div>
            <div>
              <h2 style={{ fontSize: '24px', fontWeight: 700, color: 'var(--text-darker)', marginBottom: '4px' }}>
                {profile.name}
              </h2>
              <p style={{ color: 'var(--primary-color)', fontWeight: 600, fontSize: '13px', display: 'flex', alignItems: 'center', gap: '6px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>
                <Briefcase size={14} /> {profile.specializations[0] || 'Therapist'}
              </p>
            </div>
          </div>
          
          {!editMode ? (
            <button 
              onClick={() => { setFormData({ ...profile }); setEditMode(true); }}
              className="btn btn-secondary" 
              style={{ padding: '10px 18px', fontSize: '13px' }}
            >
              <Edit size={16} /> Edit Professional Profile
            </button>
          ) : (
            <div style={{ display: 'flex', gap: '8px' }}>
              <button 
                onClick={() => setEditMode(false)}
                className="btn btn-secondary" 
                style={{ padding: '10px 18px', fontSize: '13px' }}
              >
                <X size={16} /> Cancel
              </button>
            </div>
          )}
        </div>

        {message && <div style={{ backgroundColor: '#d1fae5', color: '#059669', border: '1px solid #a7f3d0', borderRadius: '12px', padding: '12px', marginBottom: '20px', fontSize: '13px', fontFamily: 'var(--font-main)' }}>{message}</div>}
        {error && <div style={{ backgroundColor: '#fef2f2', color: '#ef4444', border: '1px solid #fee2e2', borderRadius: '12px', padding: '12px', marginBottom: '20px', fontSize: '13px', fontFamily: 'var(--font-main)' }}>{error}</div>}

        {/* Info Grid */}
        {!editMode ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
            
            {/* Identity Info Grid */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
              
              <div style={{ padding: '18px', backgroundColor: 'var(--bg-secondary)', borderRadius: '16px', border: '1px solid var(--border-color)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px', color: 'var(--text-muted)' }}>
                  <Mail size={16} />
                  <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.5px' }}>Email Address</span>
                </div>
                <p style={{ fontWeight: '600', color: 'var(--text-darker)', fontSize: '14px' }}>{profile.email}</p>
              </div>

              <div style={{ padding: '18px', backgroundColor: 'var(--bg-secondary)', borderRadius: '16px', border: '1px solid var(--border-color)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px', color: 'var(--text-muted)' }}>
                  <Phone size={16} />
                  <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.5px' }}>Phone Contact</span>
                </div>
                <p style={{ fontWeight: '600', color: 'var(--text-darker)', fontSize: '14px' }}>{profile.phone || 'Not Configured'}</p>
              </div>

              <div style={{ padding: '18px', backgroundColor: 'var(--bg-secondary)', borderRadius: '16px', border: '1px solid var(--border-color)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px', color: 'var(--text-muted)' }}>
                  <Award size={16} />
                  <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.5px' }}>Clinical License ID</span>
                </div>
                <p style={{ fontWeight: '600', color: 'var(--text-darker)', fontSize: '14px' }}>{profile.licenseNumber}</p>
              </div>

              <div style={{ padding: '18px', backgroundColor: 'var(--bg-secondary)', borderRadius: '16px', border: '1px solid var(--border-color)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px', color: 'var(--text-muted)' }}>
                  <Briefcase size={16} />
                  <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.5px' }}>Experience Rank</span>
                </div>
                <p style={{ fontWeight: '600', color: 'var(--text-darker)', fontSize: '14px' }}>{profile.experience}</p>
              </div>

              <div style={{ padding: '18px', backgroundColor: 'var(--bg-secondary)', borderRadius: '16px', border: '1px solid var(--border-color)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px', color: 'var(--text-muted)' }}>
                  <MapPin size={16} />
                  <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.5px' }}>Clinic Location</span>
                </div>
                <p style={{ fontWeight: '600', color: 'var(--text-darker)', fontSize: '14px' }}>{profile.location || 'Not Configured'}</p>
              </div>

              <div style={{ padding: '18px', backgroundColor: 'var(--bg-secondary)', borderRadius: '16px', border: '1px solid var(--border-color)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px', color: 'var(--text-muted)' }}>
                  <DollarSign size={16} />
                  <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.5px' }}>Session Price ($/hr)</span>
                </div>
                <p style={{ fontWeight: '600', color: 'var(--text-darker)', fontSize: '14px' }}>{profile.price || 'Free'}</p>
              </div>

            </div>

            {/* Specialization List */}
            <div>
              <h3 style={{ fontSize: '15px', fontWeight: 700, color: 'var(--text-darker)', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Award size={16} style={{ color: 'var(--primary-color)' }} /> Clinical Specializations
              </h3>
              <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                {profile.specializations.map((spec, i) => (
                  <span key={i} style={{ padding: '6px 12px', fontSize: '12px', fontWeight: 500, backgroundColor: 'var(--bg-secondary)', border: '1px solid var(--border-color)', borderRadius: '8px', color: 'var(--text-dark)' }}>
                    {spec}
                  </span>
                ))}
              </div>
            </div>

            {/* Spoken Languages */}
            <div>
              <h3 style={{ fontSize: '15px', fontWeight: 700, color: 'var(--text-darker)', marginBottom: '10px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <Languages size={16} style={{ color: 'var(--primary-color)' }} /> Proficiency in Languages
              </h3>
              <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                {profile.languages.map((lang, i) => (
                  <span key={i} style={{ padding: '6px 12px', fontSize: '12px', fontWeight: 500, backgroundColor: 'var(--bg-secondary)', border: '1px solid var(--border-color)', borderRadius: '8px', color: 'var(--text-dark)' }}>
                    {lang}
                  </span>
                ))}
              </div>
            </div>

            {/* Bio section */}
            <div>
              <h3 style={{ fontSize: '15px', fontWeight: 700, color: 'var(--text-darker)', marginBottom: '12px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                <FileText size={16} style={{ color: 'var(--primary-color)' }} /> Therapeutic Bio
              </h3>
              <p style={{ color: 'var(--text-dark)', lineHeight: '1.6', fontSize: '14px', whiteSpace: 'pre-line' }}>
                {profile.bio || 'No professional bio recorded yet. Click Edit to set up your bio.'}
              </p>
            </div>

          </div>
        ) : (
          <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
              <div className="form-group">
                <label className="form-label">Full Name</label>
                <input 
                  type="text" 
                  className="form-control" 
                  value={formData.name} 
                  onChange={e => setFormData({ ...formData, name: e.target.value })} 
                  required
                />
              </div>

              <div className="form-group">
                <label className="form-label">Experience Rank</label>
                <select 
                  className="form-control" 
                  value={formData.experience}
                  onChange={e => setFormData({ ...formData, experience: e.target.value })}
                >
                  {experienceOptions.map(opt => (
                    <option key={opt} value={opt}>{opt}</option>
                  ))}
                </select>
              </div>

              <div className="form-group">
                <label className="form-label">Phone Contact</label>
                <input 
                  type="text" 
                  className="form-control" 
                  value={formData.phone} 
                  onChange={e => setFormData({ ...formData, phone: e.target.value })} 
                />
              </div>

              <div className="form-group">
                <label className="form-label">Clinic Location</label>
                <input 
                  type="text" 
                  className="form-control" 
                  value={formData.location} 
                  onChange={e => setFormData({ ...formData, location: e.target.value })} 
                />
              </div>

              <div className="form-group" style={{ gridColumn: 'span 2' }}>
                <label className="form-label" style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', marginBottom: '8px' }}>
                  <input
                    type="checkbox"
                    checked={formData.price === 'Free' || formData.price === '0'}
                    onChange={e => {
                      setFormData({
                        ...formData,
                        price: e.target.checked ? 'Free' : '100'
                      });
                    }}
                    style={{ width: '16px', height: '16px', accentColor: 'var(--primary-color)' }}
                  />
                  <span style={{ fontWeight: 600, color: 'var(--text-darker)' }}>Offer Free Sessions</span>
                </label>
                {(formData.price !== 'Free' && formData.price !== '0') && (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginTop: '8px' }}>
                    <span style={{ color: 'var(--text-muted)', fontWeight: 600 }}>RM</span>
                    <input 
                      type="number" 
                      className="form-control" 
                      min="0"
                      step="5"
                      style={{ maxWidth: '150px' }}
                      value={isNaN(parseInt(formData.price)) ? 100 : parseInt(formData.price)} 
                      onChange={e => {
                        const val = e.target.value;
                        setFormData({ ...formData, price: val ? val.toString() : '0' });
                      }} 
                    />
                    <span style={{ color: 'var(--text-muted)' }}>per hour</span>
                  </div>
                )}
              </div>

              {/* Specializations selection */}
              <div className="form-group" style={{ gridColumn: 'span 2' }}>
                <label className="form-label">Clinical Specializations (Select to Toggle)</label>
                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginTop: '6px' }}>
                  {specializationOptions.map(spec => {
                    const isSelected = formData.specializations.includes(spec);
                    return (
                      <button
                        key={spec}
                        type="button"
                        onClick={() => toggleSpecialization(spec)}
                        style={{
                          padding: '6px 12px',
                          borderRadius: '8px',
                          border: isSelected ? '1px solid var(--primary-color)' : '1px solid var(--border-color)',
                          backgroundColor: isSelected ? 'var(--primary-color)' : 'white',
                          color: isSelected ? 'white' : 'var(--text-dark)',
                          fontSize: '12px',
                          fontWeight: 500,
                          cursor: 'pointer',
                          transition: 'all 0.15s'
                        }}
                      >
                        {spec}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Languages selection */}
              <div className="form-group" style={{ gridColumn: 'span 2' }}>
                <label className="form-label">Languages Spoken (Select to Toggle)</label>
                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginTop: '6px' }}>
                  {languageOptions.map(lang => {
                    const isSelected = formData.languages.includes(lang);
                    return (
                      <button
                        key={lang}
                        type="button"
                        onClick={() => toggleLanguage(lang)}
                        style={{
                          padding: '6px 12px',
                          borderRadius: '8px',
                          border: isSelected ? '1px solid var(--primary-color)' : '1px solid var(--border-color)',
                          backgroundColor: isSelected ? 'var(--primary-color)' : 'white',
                          color: isSelected ? 'white' : 'var(--text-dark)',
                          fontSize: '12px',
                          fontWeight: 500,
                          cursor: 'pointer',
                          transition: 'all 0.15s'
                        }}
                      >
                        {lang}
                      </button>
                    );
                  })}
                </div>
              </div>

              <div className="form-group" style={{ gridColumn: 'span 2' }}>
                <label className="form-label">Therapeutic Bio</label>
                <textarea 
                  className="form-control" 
                  rows="5" 
                  style={{ resize: 'vertical' }}
                  value={formData.bio} 
                  onChange={e => setFormData({ ...formData, bio: e.target.value })} 
                  required
                />
              </div>
            </div>

            <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '10px' }}>
              <button 
                type="submit" 
                disabled={saving}
                className="btn btn-primary"
                style={{ padding: '12px 24px' }}
              >
                {saving ? 'Saving changes…' : (
                  <>
                    <Save size={16} /> Save Professional Records
                  </>
                )}
              </button>
            </div>
          </form>
        )}

      </div>

      {/* Account Deactivation Request block */}
      <div className="card" style={{ maxWidth: '800px', borderColor: '#fee2e2' }}>
        <div className="flex-between">
          <div>
            <h3 style={{ fontSize: '16px', fontWeight: 700, color: '#ef4444', display: 'flex', alignItems: 'center', gap: '8px' }}>
              <ShieldAlert size={18} /> Retire / Deactivate Profile
            </h3>
            <p style={{ fontSize: '13px', color: 'var(--text-muted)', marginTop: '4px' }}>
              Send formal retirement request to the Eunoia Sage administrative board for review.
            </p>
          </div>
          <button 
            onClick={() => { setShowDeactivation(!showDeactivation); setDeactivateSuccess(false); }}
            className="btn" 
            style={{ 
              backgroundColor: '#fee2e2', 
              color: '#ef4444', 
              padding: '10px 18px', 
              fontSize: '13px',
              fontWeight: 600
            }}
          >
            {showDeactivation ? 'Close' : 'Request Retirement'}
          </button>
        </div>

        {showDeactivation && (
          <div style={{ marginTop: '20px', borderTop: '1px solid #fee2e2', paddingTop: '20px' }}>
            {deactivateSuccess ? (
              <div style={{ display: 'flex', alignItems: 'center', gap: '10px', backgroundColor: '#ecfdf5', color: '#047857', padding: '14px', borderRadius: '12px', border: '1px solid #a7f3d0' }}>
                <CheckCircle2 size={18} />
                <p style={{ fontSize: '13px', fontWeight: 500 }}>Retirement request submitted. Eunoia administrators will review it shortly.</p>
              </div>
            ) : (
              <form onSubmit={handleDeactivate} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
                <div className="form-group">
                  <label className="form-label" style={{ color: '#ef4444' }}>Primary Reason</label>
                  <select
                    className="form-control"
                    style={{ borderColor: '#fca5a5' }}
                    value={deactivateReason}
                    onChange={e => setDeactivateReason(e.target.value)}
                  >
                    {commonDeactivateReasons.map(r => (
                      <option key={r} value={r}>{r}</option>
                    ))}
                  </select>
                </div>
                
                <div className="form-group">
                  <label className="form-label" style={{ color: '#ef4444' }}>Detailed Explanation</label>
                  <textarea 
                    className="form-control"
                    rows="4"
                    style={{ borderColor: '#fca5a5', resize: 'vertical' }}
                    placeholder="Please describe your reason for retirement and any handover requirements..."
                    value={deactivateDetails}
                    onChange={e => setDeactivateDetails(e.target.value)}
                    required
                  />
                </div>
                <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                  <button 
                    type="submit"
                    disabled={deactivating}
                    className="btn"
                    style={{ backgroundColor: '#ef4444', color: 'white', padding: '10px 20px', fontSize: '13px' }}
                  >
                    {deactivating ? 'Submitting request…' : 'Submit Retirement Request'}
                  </button>
                </div>
              </form>
            )}
          </div>
        )}
      </div>

    </div>
  );
}
