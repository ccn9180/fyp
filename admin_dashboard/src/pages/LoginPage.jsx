import { useState, useEffect } from 'react';
import { signInWithEmailAndPassword, signInWithPopup, sendPasswordResetEmail } from 'firebase/auth';
import { auth, googleProvider } from '../firebase';
import { Eye, EyeOff, Lock, Mail } from 'lucide-react';
import logo from '../assets/leaf.png';
import googleIcon from '../assets/google_logo.svg';

const C = { bgCard: '#FFFFFF' };

const keyframes = `
  @keyframes floatSlow {
    0% { transform: translate(0px, 0px) scale(1); }
    33% { transform: translate(40px, -40px) scale(1.05); }
    66% { transform: translate(-20px, 30px) scale(0.95); }
    100% { transform: translate(0px, 0px) scale(1); }
  }
  @keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
`;

const s = {
  wrap: {
    minHeight: '100vh',
    width: '100%',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: '#F9F6F0', // Creamy color
    padding: '24px',
    position: 'relative',
    overflow: 'hidden',
  },

  orb1: {
    position: 'absolute', top: '-10%', left: '-5%',
    width: '40vw', height: '40vw',
    background: 'radial-gradient(circle, rgba(124,156,132,0.12) 0%, rgba(249,246,240,0) 70%)',
    borderRadius: '50%', filter: 'blur(80px)', zIndex: 0,
    animation: 'floatSlow 20s ease-in-out infinite'
  },

  orb2: {
    position: 'absolute', bottom: '-20%', right: '-10%',
    width: '50vw', height: '50vw',
    background: 'radial-gradient(circle, rgba(163,187,169,0.12) 0%, rgba(249,246,240,0) 70%)',
    borderRadius: '50%', filter: 'blur(80px)', zIndex: 0,
    animation: 'floatSlow 25s ease-in-out infinite reverse'
  },

  card: {
    width: '100%',
    maxWidth: '960px',
    minHeight: '420px',
    background: C.bgCard,
    borderRadius: '24px',
    boxShadow: '0 24px 64px rgba(124,156,132,0.15)', // Soft green shadow
    display: 'flex',
    overflow: 'hidden',
    zIndex: 1,
  },

  // Left Panel
  leftPanel: {
    flex: '1',
    background: 'linear-gradient(135deg, #7C9C84 0%, #5d7e65 100%)',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    padding: '40px',
    color: 'white',
    position: 'relative',
  },
  logoIcon: {
    width: '130px', height: '130px', borderRadius: '50%',
    background: C.bgCard, display: 'flex', alignItems: 'center',
    justifyContent: 'center', marginBottom: '20px',
    boxShadow: '0 20px 50px rgba(0,0,0,0.15)',
    zIndex: 2
  },
  logoTitle: {
    fontFamily: '"Playfair Display", serif', fontWeight: 700,
    fontSize: '36px', color: 'white', marginBottom: '6px', zIndex: 2
  },
  logoSub: {
    fontFamily: 'Outfit, sans-serif', fontSize: '14px', color: '#E5EDE8',
    textAlign: 'center', letterSpacing: '0.05em', zIndex: 2, fontWeight: 300
  },
  decorativePattern: {
    position: 'absolute',
    top: 0, left: 0, right: 0, bottom: 0,
    backgroundImage: 'radial-gradient(circle at 2px 2px, rgba(255,255,255,0.12) 1px, transparent 0)',
    backgroundSize: '24px 24px',
    opacity: 0.8,
  },

  // Right Panel
  rightPanel: {
    flex: '1',
    background: C.bgCard,
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'center',
    padding: '36px 100px',
  },

  cardTitle: { fontFamily: '"Playfair Display", serif', fontWeight: 600, fontSize: '30px', color: '#2c3630', marginBottom: '6px', textAlign: 'center' },
  cardSub: { fontFamily: 'Outfit, sans-serif', fontSize: '13px', color: '#6a7870', marginBottom: '24px', lineHeight: '1.5', textAlign: 'center' },

  // Form Elements
  form: { display: 'flex', flexDirection: 'column', gap: '16px' },
  label: { display: 'block', fontFamily: 'Outfit, sans-serif', fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.08em', color: '#4a5750', marginBottom: '6px' },
  inputWrap: { position: 'relative' },
  inputIcon: { position: 'absolute', left: '16px', top: '50%', transform: 'translateY(-50%)', color: '#A3BBA9', pointerEvents: 'none' },
  input: {
    width: '100%', background: '#Fbfbfb', border: '1px solid #E5E4E0',
    borderRadius: '12px', padding: '12px 16px 12px 44px', fontFamily: 'Outfit, sans-serif',
    fontSize: '13px', color: '#2c3630', outline: 'none', boxSizing: 'border-box',
    transition: 'all 0.2s ease',
  },
  eyeBtn: { position: 'absolute', right: '16px', top: '50%', transform: 'translateY(-50%)', border: 'none', background: 'transparent', cursor: 'pointer', color: '#A3BBA9', padding: '2px' },

  // Actions
  forgotBtnWrap: { display: 'flex', justifyContent: 'flex-end', marginTop: '2px' },
  forgotBtn: { background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'Outfit, sans-serif', fontSize: '11px', color: '#7C9C84', fontWeight: 600 },
  error: { fontFamily: 'Outfit, sans-serif', fontSize: '12px', color: '#ef4444', background: '#fef2f2', borderRadius: '10px', padding: '10px 12px', border: '1px solid #fee2e2' },
  success: { fontFamily: 'Outfit, sans-serif', fontSize: '12px', color: '#059669', background: '#d1fae5', borderRadius: '10px', padding: '10px 12px', border: '1px solid #a7f3d0' },

  submitBtn: (loading) => ({
    width: '100%', background: loading ? '#A3BBA9' : '#7C9C84', color: 'white',
    fontFamily: 'Outfit, sans-serif', fontWeight: 600, fontSize: '14px',
    padding: '12px', borderRadius: '12px', border: 'none', cursor: loading ? 'not-allowed' : 'pointer',
    marginTop: '4px', transition: 'all 0.2s ease',
  }),

  divider: { display: 'flex', alignItems: 'center', gap: '16px', margin: '20px 0' },
  dividerLine: { flex: 1, height: '1px', background: '#E5EDE8' },
  dividerText: { fontFamily: 'Outfit, sans-serif', fontSize: '11px', color: '#88928b' },

  googleBtn: {
    width: '100%', background: C.bgCard, border: '1px solid #E5EDE8', color: '#4a5750',
    fontFamily: 'Outfit, sans-serif', fontWeight: 600, fontSize: '13px', padding: '12px',
    borderRadius: '12px', cursor: 'pointer', display: 'flex', alignItems: 'center',
    justifyContent: 'center', gap: '12px', transition: 'all 0.2s ease'
  },

  footer: { textAlign: 'center', fontFamily: 'Outfit, sans-serif', fontSize: '11px', color: '#88928b', marginTop: '24px' },
};

const FIREBASE_ERRORS = {
  'auth/user-not-found': 'No admin account found with this email.',
  'auth/wrong-password': 'Incorrect password. Please try again.',
  'auth/invalid-email': 'Please enter a valid email address.',
  'auth/invalid-credential': 'Invalid credentials. Please try again.',
  'auth/too-many-requests': 'Too many failed attempts. Please try again later.',
  'auth/popup-blocked': 'The sign-in popup was blocked by your browser. Please allow popups for this site.',
};

export default function LoginPage({ externalError }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPw, setShowPw] = useState(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);

  useEffect(() => {
    if (externalError) {
      setError(externalError);
      setLoading(false);
      setGoogleLoading(false);
    }
  }, [externalError]);

  const handleForgotPassword = async () => {
    setError('');
    setMessage('');
    if (!email) {
      setError('Please enter your email address above to reset your password.');
      return;
    }
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      setError('Please enter a valid email format.');
      return;
    }
    setLoading(true);
    try {
      await sendPasswordResetEmail(auth, email);
      setMessage('Password reset email sent! Check your inbox.');
    } catch (err) {
      setError(FIREBASE_ERRORS[err.code] || 'Failed to send reset email.');
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleLogin = async () => {
    setError('');
    setGoogleLoading(true);
    try {
      await signInWithPopup(auth, googleProvider);
    } catch (err) {
      if (err?.code !== 'auth/popup-closed-by-user' && err?.code !== 'auth/cancelled-popup-request') {
        setError((err?.code && FIREBASE_ERRORS[err.code]) || 'Google login failed.');
      }
    } finally {
      setGoogleLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setMessage('');

    if (!email || !password) {
      setError('Please fill in all fields.');
      return;
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      setError('Please enter a valid email format.');
      return;
    }

    if (password.length < 8) {
      setError('Password must be at least 8 characters long.');
      return;
    }

    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch (err) {
      setError(FIREBASE_ERRORS[err.code] || 'Login failed. Please try again.');
      setLoading(false);
    }
  };

  return (
    <div style={s.wrap}>
      <style>{keyframes}</style>

      {/* Static/Slow Floating Orbs */}
      <div id="background-orb" style={s.orb1} />
      <div id="background-orb" style={s.orb2} />

      <div id="login-card" style={s.card}>

        {/* Left Panel - Branding */}
        <div style={s.leftPanel}>
          <div style={s.decorativePattern} />
          <div style={s.logoIcon}>
            <img src={logo} alt="Eunoia Logo" style={{ width: '80px', height: '80px', objectFit: 'contain' }} />
          </div>
          <div style={s.logoTitle}>Eunoia</div>
          <div style={s.logoSub}>System Administration Portal</div>
        </div>

        {/* Right Panel - Login Form */}
        <div style={s.rightPanel}>
          <div style={s.cardTitle}>Welcome back</div>
          <div style={s.cardSub}>Sign in to oversee and manage the platform.</div>

          <form onSubmit={handleSubmit} style={s.form}>
            <div>
              <label style={s.label}>Email Address</label>
              <div style={s.inputWrap}>
                <span style={s.inputIcon}><Mail size={16} /></span>
                <input
                  id="admin-email"
                  type="email"
                  style={s.input}
                  placeholder="admin@eunoia.com"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  autoComplete="email"
                  onFocus={e => { e.target.style.borderColor = '#7C9C84'; e.target.style.boxShadow = '0 0 0 4px rgba(124,156,132,0.1)'; e.target.style.background = 'white'; }}
                  onBlur={e => { e.target.style.borderColor = '#E5E4E0'; e.target.style.boxShadow = 'none'; e.target.style.background = '#Fbfbfb'; }}
                />
              </div>
            </div>

            <div>
              <label style={s.label}>Password</label>
              <div style={s.inputWrap}>
                <span style={s.inputIcon}><Lock size={16} /></span>
                <input
                  id="admin-password"
                  type={showPw ? 'text' : 'password'}
                  style={{ ...s.input, paddingRight: '48px' }}
                  placeholder="••••••••"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  autoComplete="current-password"
                  onFocus={e => { e.target.style.borderColor = '#7C9C84'; e.target.style.boxShadow = '0 0 0 4px rgba(124,156,132,0.1)'; e.target.style.background = 'white'; }}
                  onBlur={e => { e.target.style.borderColor = '#E5E4E0'; e.target.style.boxShadow = 'none'; e.target.style.background = '#Fbfbfb'; }}
                />
                <button type="button" style={s.eyeBtn} onClick={() => setShowPw(p => !p)}>
                  {showPw ? <EyeOff size={16} /> : <Eye size={16} />}
                </button>
              </div>
              <div style={s.forgotBtnWrap}>
                <button type="button" style={s.forgotBtn} onClick={handleForgotPassword}>Forgot password?</button>
              </div>
            </div>

            {error && <div style={s.error}>{error}</div>}
            {message && <div style={s.success}>{message}</div>}

            <button
              id="login-btn"
              type="submit"
              disabled={loading || googleLoading}
              style={s.submitBtn(loading)}
              onMouseEnter={e => { if (!loading && !googleLoading) { e.currentTarget.style.background = '#6a8a71'; e.currentTarget.style.transform = 'translateY(-1px)'; } }}
              onMouseLeave={e => { if (!loading && !googleLoading) { e.currentTarget.style.background = '#7C9C84'; e.currentTarget.style.transform = 'none'; } }}
            >
              {loading ? (
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
                  <div style={{
                    width: '16px', height: '16px',
                    border: '2px solid rgba(255, 255, 255, 0.3)',
                    borderTop: '2px solid white',
                    borderRadius: '50%',
                    animation: 'spin 0.8s linear infinite'
                  }} />
                  Authenticating…
                </div>
              ) : 'Sign In'}
            </button>
          </form>

          <div style={s.divider}>
            <div style={s.dividerLine} />
            <span style={s.dividerText}>or continue with</span>
            <div style={s.dividerLine} />
          </div>

          <button
            onClick={handleGoogleLogin}
            disabled={loading || googleLoading}
            style={{
              ...s.googleBtn,
              background: (loading || googleLoading) ? '#F5F5F5' : 'white',
              cursor: (loading || googleLoading) ? 'not-allowed' : 'pointer'
            }}
            onMouseEnter={e => { if (!(loading || googleLoading)) { e.currentTarget.style.background = '#Fbfbfb'; e.currentTarget.style.borderColor = '#A3BBA9'; } }}
            onMouseLeave={e => { if (!(loading || googleLoading)) { e.currentTarget.style.background = 'white'; e.currentTarget.style.borderColor = '#E5EDE8'; } }}
          >
            {googleLoading ? (
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
                <div style={{
                  width: '16px', height: '16px',
                  border: '2px solid rgba(124, 156, 132, 0.2)',
                  borderTop: '2px solid #7C9C84',
                  borderRadius: '50%',
                  animation: 'spin 0.8s linear infinite'
                }} />
                Authenticating with Google…
              </div>
            ) : (
              <>
                <img src={googleIcon} alt="G" style={{ width: '20px', height: '20px' }} />
                Sign in with Google
              </>
            )}
          </button>

          <p style={s.footer}>Eunoia © {new Date().getFullYear()} · Secure System Administration</p>
        </div>
      </div>

    </div>
  );
}
