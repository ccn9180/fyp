import React, { useState, useEffect } from 'react';
import { doc, getDoc, updateDoc, addDoc, collection, serverTimestamp } from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { auth, db, storage } from '../firebase';
import { User, Mail, Phone, MapPin, Edit, Save, X, Briefcase, FileText, ShieldAlert, CheckCircle2, Award, Languages, DollarSign, Camera, AlertCircle, ChevronDown } from 'lucide-react';

let cachedProfile = null;

export default function Profile() {
  const [profile, setProfile] = useState(cachedProfile || {
    name: 'Counsellor',
    specializations: [],
    bio: '',
    experience: '3-5 Years',
    languages: [],
    email: '',
    phone: '',
    location: '',
    licenseNumber: '',
    price: 'Free',
    photo: null
  });

  const [editMode, setEditMode] = useState(false);
  const [formData, setFormData] = useState({ ...profile });
  const [loading, setLoading] = useState(!cachedProfile);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');
  const [uploadingImage, setUploadingImage] = useState(false);
  const fileInputRef = React.useRef(null);

  // Deactivation state
  const [showDeactivation, setShowDeactivation] = useState(false);
  const [deactivateReason, setDeactivateReason] = useState('Temporary Break');
  const [showReasonDropdown, setShowReasonDropdown] = useState(false);
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

  const fetchProfile = async (user) => {
    if (!cachedProfile) setLoading(true);

    try {
      const docRef = doc(db, 'users', user.uid);
      const snap = await getDoc(docRef);
      if (snap.exists()) {
        const data = snap.data();
        const specs = data.specializations || [];
        const langs = data.languages || [];
        const license = data.licenseNumber || `E-SAGE-${user.uid.substring(0, 8).toUpperCase()}`;

        const pData = {
          name: data.fullName || data.name || user.displayName || 'Counsellor',
          specializations: Array.isArray(specs) ? specs : [specs],
          bio: data.counsellorBio || data.bio || data.motivation || data.applicationMotivation || '',
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
        cachedProfile = pData;
      } else {
        setFormData({ ...profile });
      }
    } catch (e) {
      console.error("Error loading counsellor profile:", e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const unsubscribe = auth.onAuthStateChanged(user => {
      if (user) {
        fetchProfile(user);
      } else {
        if (typeof setLoading === 'function') setLoading(false);
      }
    });
    return () => unsubscribe();
  }, []);

  const handleSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    setError('');
    setMessage('');

    if (!formData.phone || formData.phone.length < 11) { // +60 plus at least 8 digits
      setError('Please enter a valid phone number (e.g. 123456789).');
      setSaving(false);
      setTimeout(() => setError(''), 4000);
      return;
    }
    if (!formData.bio || formData.bio.trim().length < 10) {
      setError('Therapeutic bio must be at least 10 characters long.');
      setSaving(false);
      setTimeout(() => setError(''), 4000);
      return;
    }
    if (formData.specializations.length === 0) {
      setError('Please select at least one clinical specialization.');
      setSaving(false);
      setTimeout(() => setError(''), 4000);
      return;
    }
    if (formData.languages.length === 0) {
      setError('Please select at least one spoken language.');
      setSaving(false);
      setTimeout(() => setError(''), 4000);
      return;
    }

    const user = auth.currentUser;
    if (!user) return;

    try {
      const docRef = doc(db, 'users', user.uid);
      const updatePayload = {
        fullName: formData.name,
        name: formData.name,
        phone: formData.phone,
        price: formData.price || 'Free',
        counsellorBio: formData.bio,
        experience: formData.experience,
        specializations: formData.specializations,
        languages: formData.languages,
        updatedAt: serverTimestamp()
      };
      
      await updateDoc(docRef, updatePayload);

      const updatedProfile = { ...formData };
      setProfile(updatedProfile);
      cachedProfile = updatedProfile;
      setMessage('Professional profile updated successfully!');
      setTimeout(() => setMessage(''), 4000);
      setEditMode(false);
    } catch (err) {
      console.error("Error saving profile:", err);
      setError('Failed to save profile changes. Please try again.');
      setTimeout(() => setError(''), 4000);
    } finally {
      setSaving(false);
    }
  };

  const handleImageChange = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    
    try {
      setUploadingImage(true);
      setError('');
      const user = auth.currentUser;
      const fileRef = ref(storage, `counsellor_profiles/${user.uid}_${Date.now()}`);
      await uploadBytes(fileRef, file);
      const url = await getDownloadURL(fileRef);
      
      setFormData(prev => ({ ...prev, photo: url }));
      setProfile(prev => ({ ...prev, photo: url }));
      
      await updateDoc(doc(db, 'users', user.uid), {
        counsellorImageUrl: url
      });
      
      setMessage('Profile image updated successfully!');
      setTimeout(() => setMessage(''), 4000);
    } catch (e) {
      console.error(e);
      setError('Failed to upload image. Please try again.');
      setTimeout(() => setError(''), 4000);
    } finally {
      setUploadingImage(false);
    }
  };

  const handleDeactivate = async (e) => {
    e.preventDefault();
    if (!deactivateDetails.trim()) {
      setError("Please provide detailed explanation for deactivation.");
      setTimeout(() => setError(''), 4000);
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
      setError("Failed to submit request. Please try again later.");
      setTimeout(() => setError(''), 4000);
    } finally {
      setDeactivating(false);
    }
  };

  const toggleSpecialization = (spec) => {
    const current = [...formData.specializations];
    const index = current.indexOf(spec);
    if (index > -1) {
      current.splice(index, 1);
    } else {
      current.push(spec);
    }
    setFormData({ ...formData, specializations: current });
  };

  const toggleLanguage = (lang) => {
    const current = [...formData.languages];
    const index = current.indexOf(lang);
    if (index > -1) {
      current.splice(index, 1);
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
    <div>
      <header className="page-header">
        <h1 className="page-title">Counsellor Profile</h1>
        <p className="page-subtitle">Oversee and update your clinical registration, credentials, and therapist details.</p>
      </header>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.6fr', gap: '32px', alignItems: 'stretch', width: '100%', maxWidth: '1400px' }}>
        
        {/* COLUMN 1 (LEFT) WRAPPER */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '32px' }}>
          {/* COLUMN 1 (LEFT): IDENTITY BOX */}
          <div className="card" style={{ display: 'flex', flexDirection: 'column', padding: '40px', flex: 1 }}>
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '24px 0' }}>
            <div style={{ position: 'relative', marginBottom: '32px' }}>
              <div style={{ 
                width: '160px', height: '160px', borderRadius: '50%', overflow: 'hidden', 
                border: '4px solid #F6F5F2', boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)',
                backgroundColor: 'var(--primary-light)', display: 'flex', alignItems: 'center', justifyContent: 'center',
                color: 'var(--primary-color)', fontSize: '5rem', fontWeight: 900
              }}>
                {uploadingImage ? (
                  <div style={{ width: '40px', height: '40px', border: '3px solid #f3f4f6', borderTop: '3px solid var(--primary-color)', borderRadius: '50%', animation: 'spin 1s linear infinite' }} />
                ) : profile.photo ? (
                  <img src={profile.photo} alt="P" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                ) : (
                  <span>{profile.name.charAt(0)}</span>
                )}
              </div>
              
              <input 
                type="file" 
                accept="image/*" 
                ref={fileInputRef} 
                style={{ display: 'none' }} 
                onChange={handleImageChange} 
              />
              {editMode && (
                <button 
                  onClick={() => fileInputRef.current?.click()}
                  disabled={uploadingImage}
                  style={{ 
                    position: 'absolute', bottom: '8px', right: '8px', 
                    backgroundColor: 'var(--bg-card)', borderRadius: '50%', 
                    padding: '8px', border: '1px solid var(--border-color)', 
                    cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center',
                    transition: 'all 0.2s', zIndex: 2
                  }}
                  onMouseEnter={e => e.currentTarget.style.transform = 'scale(1.1)'}
                  onMouseLeave={e => e.currentTarget.style.transform = 'scale(1)'}
                >
                  <Camera size={20} style={{ color: 'var(--primary-color)' }} />
                </button>
              )}
            </div>

            <div style={{ textAlign: 'center', marginBottom: '32px' }}>
              <h3 style={{ fontFamily: 'var(--font-serif)', fontSize: '28px', color: 'var(--text-darker)', fontWeight: 900, marginBottom: '8px', textDecoration: 'underline', textDecorationColor: 'rgba(229, 228, 224, 0.4)', textUnderlineOffset: '8px' }}>
                {profile.name}
              </h3>
              <p style={{ fontSize: '14px', color: 'var(--text-muted)', fontStyle: 'italic', letterSpacing: '0.5px' }}>
                {profile.email}
              </p>
            </div>

            <div style={{ backgroundColor: 'var(--primary-light)', padding: '12px 40px', borderRadius: '999px', border: '1px solid rgba(124, 156, 132, 0.1)' }}>
              <p style={{ fontSize: '11px', fontWeight: 900, color: 'var(--primary-color)', textTransform: 'uppercase', letterSpacing: '4px', margin: 0 }}>
                {profile.specializations[0] || 'Therapist'}
              </p>
            </div>
          </div>
        </div>

        {/* Account Deactivation Request block (Moved to left column) */}
          <div 
            className="card" 
            onClick={() => { setShowDeactivation(true); setDeactivateSuccess(false); }}
            style={{ 
              width: '100%', borderColor: 'rgba(239,68,68,0.35)', backgroundColor: 'rgba(239,68,68,0.06)', 
              cursor: 'pointer', transition: 'all 0.2s cubic-bezier(0.4, 0, 0.2, 1)',
              display: 'flex', flexDirection: 'column'
            }}
            onMouseEnter={e => { e.currentTarget.style.transform = 'translateY(-2px)'; e.currentTarget.style.boxShadow = '0 10px 25px -5px rgba(239, 68, 68, 0.1)'; }}
            onMouseLeave={e => { e.currentTarget.style.transform = 'translateY(0)'; e.currentTarget.style.boxShadow = '0 1px 3px rgba(0,0,0,0.05)'; }}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '12px' }}>
              <div>
                <h3 style={{ fontSize: '18px', fontWeight: 800, color: '#ef4444', display: 'flex', alignItems: 'center', gap: '8px', letterSpacing: '0.5px' }}>
                  <ShieldAlert size={18} /> Retire Profile
                </h3>
                <p style={{ fontSize: '12px', color: '#f87171', marginTop: '6px', lineHeight: 1.4 }}>
                  Send formal retirement request to the board for review.
                </p>
              </div>
              <button 
                className="btn" 
                style={{ 
                  backgroundColor: 'rgba(239,68,68,0.15)', 
                  color: '#ef4444', 
                  padding: '8px 12px', 
                  fontSize: '12px',
                  fontWeight: 600,
                  pointerEvents: 'none',
                  whiteSpace: 'nowrap',
                  border: '1px solid rgba(239,68,68,0.25)'
                }}
              >
                Request
              </button>
            </div>
          </div>
        </div>

        {/* COLUMN 2 (RIGHT): PROFESSIONAL DETAILS / EDIT FORM */}
        <div className="card" style={{ display: 'flex', flexDirection: 'column', padding: '40px' }}>
          
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '32px', paddingBottom: '24px', borderBottom: '1px solid rgba(229, 228, 224, 0.5)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
              <div style={{ width: '40px', height: '40px', borderRadius: '12px', backgroundColor: 'var(--primary-light)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--primary-color)' }}>
                <User size={20} />
              </div>
              <h4 style={{ fontFamily: 'var(--font-serif)', fontSize: '20px', color: 'var(--text-darker)', fontWeight: 700, margin: 0 }}>
                Professional Profile
              </h4>
            </div>
            
            {!editMode ? (
              <button 
                onClick={() => { setFormData({ ...profile }); setEditMode(true); }}
                className="btn btn-secondary" 
                style={{ padding: '10px 18px', fontSize: '13px', backgroundColor: 'var(--bg-card)' }}
              >
                <Edit size={16} /> Edit Profile
              </button>
            ) : (
              <button 
                onClick={() => setEditMode(false)}
                className="btn btn-secondary" 
                style={{ padding: '10px 18px', fontSize: '13px', backgroundColor: 'var(--bg-card)' }}
              >
                <X size={16} /> Cancel
              </button>
            )}
          </div>

        {/* Toast Notification for Success/Error */}
        {(message || error) && (
          <div 
            style={{ 
              position: 'fixed', bottom: '40px', right: '40px', zIndex: 9999, 
              backgroundColor: message ? '#ecfdf5' : '#fef2f2', 
              color: message ? '#047857' : '#b91c1c', 
              padding: '16px 24px', borderRadius: '12px', 
              boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1), 0 10px 10px -5px rgba(0,0,0,0.04)', 
              border: message ? '1px solid #a7f3d0' : '1px solid #fca5a5',
              display: 'flex', alignItems: 'center', gap: '16px',
              animation: 'slideUp 0.4s cubic-bezier(0.16, 1, 0.3, 1)' 
            }}
          >
            {message ? <CheckCircle2 size={28} /> : <AlertCircle size={28} />}
            <div>
              <p style={{ margin: 0, fontWeight: 700, fontSize: '15px' }}>{message ? 'Success' : 'Action Required'}</p>
              <p style={{ margin: 0, fontSize: '14px', marginTop: '2px', opacity: 0.9 }}>{message || error}</p>
            </div>
          </div>
        )}
        {/* Info Grid */}
        {!editMode ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
            
            {/* Identity Info Grid */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
              
              <div style={{ padding: '18px', backgroundColor: 'var(--bg-card)', borderRadius: '16px', border: '1px solid var(--border-color)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px', color: 'var(--text-muted)' }}>
                  <Mail size={16} />
                  <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.5px' }}>Email Address</span>
                </div>
                <p style={{ fontWeight: '600', color: 'var(--text-darker)', fontSize: '14px' }}>{profile.email}</p>
              </div>

              <div style={{ padding: '18px', backgroundColor: 'var(--bg-card)', borderRadius: '16px', border: '1px solid var(--border-color)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px', color: 'var(--text-muted)' }}>
                  <Phone size={16} />
                  <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.5px' }}>Phone Contact</span>
                </div>
                <p style={{ fontWeight: '600', color: 'var(--text-darker)', fontSize: '14px' }}>{profile.phone || 'Not Configured'}</p>
              </div>

              <div style={{ padding: '18px', backgroundColor: 'var(--bg-card)', borderRadius: '16px', border: '1px solid var(--border-color)' }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '8px', color: 'var(--text-muted)' }}>
                  <Briefcase size={16} />
                  <span style={{ fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.5px' }}>Experience Rank</span>
                </div>
                <p style={{ fontWeight: '600', color: 'var(--text-darker)', fontSize: '14px' }}>{profile.experience}</p>
              </div>

              <div style={{ padding: '18px', backgroundColor: 'var(--bg-card)', borderRadius: '16px', border: '1px solid var(--border-color)' }}>
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
                  <span key={i} style={{ padding: '6px 12px', fontSize: '12px', fontWeight: 500, backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', borderRadius: '8px', color: 'var(--text-dark)' }}>
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
                  <span key={i} style={{ padding: '6px 12px', fontSize: '12px', fontWeight: 500, backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', borderRadius: '8px', color: 'var(--text-dark)' }}>
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
                  readOnly
                  disabled
                  style={{ backgroundColor: 'var(--bg-main)', cursor: 'not-allowed', color: 'var(--text-muted)' }}
                />
              </div>

              <div className="form-group">
                <label className="form-label">Phone Contact</label>
                <div style={{ display: 'flex', alignItems: 'center', border: '1px solid var(--border-color)', borderRadius: '8px', overflow: 'hidden', backgroundColor: 'var(--bg-card)' }}>
                  <div style={{ padding: '10px 14px', backgroundColor: 'var(--bg-main)', color: 'var(--text-dark)', fontWeight: 600, borderRight: '1px solid var(--border-color)' }}>
                    +60
                  </div>
                  <input 
                    type="text" 
                    className="form-control" 
                    style={{ border: 'none', borderRadius: 0, padding: '10px', backgroundColor: 'var(--bg-main)', cursor: 'not-allowed', color: 'var(--text-muted)' }}
                    value={(formData.phone || '').replace(/^\+?60/, '')} 
                    readOnly
                    disabled
                    placeholder="123456789"
                  />
                </div>
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
                <label className="form-label">Session Pricing</label>
                <div style={{ display: 'flex', alignItems: 'center', gap: '20px', flexWrap: 'nowrap', minHeight: '42px' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', margin: 0, whiteSpace: 'nowrap' }}>
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
                    <span style={{ fontWeight: 600, color: 'var(--text-darker)', fontSize: '13px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Free Sessions</span>
                  </label>
                  
                  {(formData.price !== 'Free' && formData.price !== '0') && (
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', borderLeft: '1px solid var(--border-color)', paddingLeft: '20px', whiteSpace: 'nowrap' }}>
                      <span style={{ color: 'var(--text-muted)', fontWeight: 600 }}>RM</span>
                      <input 
                        type="number" 
                        className="form-control" 
                        min="15"
                        step="5"
                        style={{ width: '80px', padding: '8px 12px' }}
                        value={isNaN(parseInt(formData.price)) ? 100 : parseInt(formData.price)} 
                        onChange={e => {
                          const val = e.target.value;
                          setFormData({ ...formData, price: val ? val.toString() : '0' });
                        }}
                        onInvalid={e => {
                          e.target.setCustomValidity("Session pricing must be at least RM 15, and in multiples of RM 5 (e.g. 15, 20, 25).");
                        }}
                        onInput={e => {
                          e.target.setCustomValidity("");
                        }}
                      />
                      <span style={{ color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>/ hr</span>
                    </div>
                  )}
                </div>
              </div>

              {/* Specializations selection */}
              <div className="form-group" style={{ gridColumn: 'span 2' }}>
                <label className="form-label">Clinical Specializations (Select to Toggle)</label>
                <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginTop: '6px' }}>
                  {Array.from(new Set([...specializationOptions, ...profile.specializations])).map(spec => {
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
                          backgroundColor: isSelected ? 'var(--primary-color)' : 'var(--bg-card)',
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
                  {Array.from(new Set([...languageOptions, ...profile.languages])).map(lang => {
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
                          backgroundColor: isSelected ? 'var(--primary-color)' : 'var(--bg-card)',
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
      </div>


      {/* Deactivation Modal */}
      {showDeactivation && (
        <div style={{ position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, backgroundColor: 'rgba(0,0,0,0.5)', zIndex: 9999, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <div style={{ backgroundColor: 'var(--bg-card)', borderRadius: '24px', width: '100%', maxWidth: '420px', padding: '32px', position: 'relative', boxShadow: '0 20px 40px rgba(0,0,0,0.15)', animation: 'fadeIn 0.2s ease-out' }}>
            
            {deactivateSuccess ? (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
                <div style={{ padding: '16px', backgroundColor: 'rgba(16, 185, 129, 0.1)', borderRadius: '50%', color: '#10b981', marginBottom: '16px' }}>
                  <CheckCircle2 size={32} />
                </div>
                <h2 style={{ fontSize: '24px', fontWeight: 700, color: 'var(--text-darker)', margin: 0, marginBottom: '12px' }}>Request Submitted</h2>
                <p style={{ fontSize: '15px', color: 'var(--text-muted)', lineHeight: '1.6', margin: 0, marginBottom: '32px' }}>
                  Eunoia administrators will review your retirement request shortly. You will be contacted via email regarding the handover process.
                </p>
                <button 
                  onClick={() => setShowDeactivation(false)} 
                  className="btn btn-secondary" 
                  style={{ width: '100%', padding: '14px', fontSize: '15px', fontWeight: 600, textAlign: 'center', display: 'flex', justifyContent: 'center' }}
                >
                  Close Window
                </button>
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column' }}>
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', marginBottom: '24px' }}>
                  <div style={{ padding: '16px', backgroundColor: 'rgba(239, 68, 68, 0.1)', borderRadius: '50%', color: '#ef4444', marginBottom: '16px' }}>
                    <ShieldAlert size={32} />
                  </div>
                  <h2 style={{ fontSize: '24px', fontWeight: 700, color: 'var(--text-darker)', margin: 0, marginBottom: '12px' }}>Request Retirement?</h2>
                  <p style={{ fontSize: '15px', color: 'var(--text-muted)', lineHeight: '1.6', margin: 0 }}>
                    Please provide the reason for your retirement. This will notify administrators to begin the handover process.
                  </p>
                </div>
                
                <form onSubmit={handleDeactivate} style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                  
                  <div className="form-group" style={{ position: 'relative', marginBottom: '0' }}>
                    <label className="form-label" style={{ color: '#dc2626', fontWeight: 700, letterSpacing: '0.5px', textTransform: 'uppercase', fontSize: '11px' }}>Primary Reason</label>
                    <div 
                      onClick={() => setShowReasonDropdown(!showReasonDropdown)}
                      style={{ 
                        border: showReasonDropdown ? '2px solid #ef4444' : '1px solid #fca5a5', 
                        backgroundColor: '#fff5f5', 
                        padding: '12px 16px', 
                        borderRadius: '12px', 
                        display: 'flex', 
                        justifyContent: 'space-between', 
                        alignItems: 'center', 
                        cursor: 'pointer',
                        transition: 'all 0.2s',
                        color: 'var(--text-darker)',
                        fontWeight: 500
                      }}
                    >
                      <span>{deactivateReason}</span>
                      <ChevronDown size={18} style={{ color: '#ef4444', transform: showReasonDropdown ? 'rotate(180deg)' : 'rotate(0deg)', transition: 'transform 0.2s' }} />
                    </div>
                    
                    {showReasonDropdown && (
                      <div style={{ 
                        position: 'absolute', top: 'calc(100% + 8px)', left: 0, right: 0, 
                        backgroundColor: 'var(--bg-card)', border: '1px solid var(--border-color)', borderRadius: '12px', 
                        boxShadow: '0 10px 25px -5px rgba(0,0,0,0.1), 0 8px 10px -6px rgba(0,0,0,0.1)', 
                        zIndex: 10, overflow: 'hidden', animation: 'slideUp 0.2s ease-out' 
                      }}>
                        {commonDeactivateReasons.map((r, i) => (
                          <div 
                            key={r} 
                            onClick={() => {
                              setDeactivateReason(r);
                              setShowReasonDropdown(false);
                            }}
                            onMouseEnter={e => { e.currentTarget.style.backgroundColor = '#fef2f2'; e.currentTarget.style.color = '#ef4444'; }}
                            onMouseLeave={e => {
                              if (r !== deactivateReason) {
                                e.currentTarget.style.backgroundColor = 'transparent';
                                e.currentTarget.style.color = 'var(--text-darker)';
                              }
                            }}
                            style={{ 
                              padding: '12px 16px', cursor: 'pointer', fontSize: '14px', fontWeight: 500,
                              backgroundColor: r === deactivateReason ? '#ef4444' : 'transparent',
                              color: r === deactivateReason ? 'white' : 'var(--text-darker)',
                              borderBottom: i < commonDeactivateReasons.length - 1 ? '1px solid #f3f4f6' : 'none',
                              transition: 'all 0.15s'
                            }}
                          >
                            {r}
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                  
                  <div className="form-group" style={{ marginBottom: '8px' }}>
                    <label className="form-label" style={{ color: '#ef4444', fontWeight: 600 }}>Detailed Explanation</label>
                    <textarea 
                      className="form-control"
                      rows="3"
                      style={{ borderColor: '#fca5a5', backgroundColor: '#fff5f5', resize: 'vertical' }}
                      placeholder="Describe your reason and handover requirements..."
                      value={deactivateDetails}
                      onChange={e => setDeactivateDetails(e.target.value)}
                      required
                    />
                  </div>
                  
                  <div style={{ display: 'flex', gap: '16px' }}>
                    <button 
                      type="button" 
                      onClick={() => setShowDeactivation(false)} 
                      className="btn btn-secondary" 
                      style={{ flex: 1, padding: '14px', fontSize: '15px', fontWeight: 600, textAlign: 'center', display: 'flex', justifyContent: 'center' }}
                    >
                      Cancel
                    </button>
                    <button 
                      type="submit"
                      disabled={deactivating}
                      className="btn" 
                      style={{ flex: 1, padding: '14px', fontSize: '15px', fontWeight: 600, backgroundColor: '#ef4444', color: 'white', border: 'none', textAlign: 'center', display: 'flex', justifyContent: 'center' }}
                    >
                      {deactivating ? 'Submitting...' : 'Submit'}
                    </button>
                  </div>
                </form>
              </div>
            )}
          </div>
        </div>
      )}

    </div>
  );
}
