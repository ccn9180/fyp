import { useState, useEffect } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from '../firebase';
import { Eye, EyeOff, Lock, Mail } from 'lucide-react';
import logo from '../assets/logo.svg';

const s = {
  wrap: { minHeight: '100vh', background: '#F6F5F2', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '16px' },
  box: { width: '100%', maxWidth: '380px' },
  logoWrap: { display: 'flex', flexDirection: 'column', alignItems: 'center', marginBottom: '32px' },
  logoIcon: { width: '80px', height: '80px', borderRadius: '50%', background: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '16px', boxShadow: '0 10px 30px rgba(124,156,132,0.15)' },
  logoTitle: { fontFamily: '"Playfair Display", serif', fontWeight: 600, fontSize: '24px', color: '#333' },
  logoSub: { fontFamily: 'Outfit, sans-serif', fontSize: '13px', color: '#888', marginTop: '2px' },
  card: { background: 'white', borderRadius: '24px', boxShadow: '0 2px 16px rgba(0,0,0,0.06)', padding: '28px' },
  cardTitle: { fontFamily: '"Playfair Display", serif', fontWeight: 600, fontSize: '18px', color: '#333', marginBottom: '4px' },
  cardSub: { fontFamily: 'Outfit, sans-serif', fontSize: '13px', color: '#888', marginBottom: '24px' },
  label: { display: 'block', fontFamily: 'Outfit, sans-serif', fontSize: '11px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.08em', color: '#888', marginBottom: '6px' },
  inputWrap: { position: 'relative' },
  inputIcon: { position: 'absolute', left: '14px', top: '50%', transform: 'translateY(-50%)', color: '#AAAAAA', pointerEvents: 'none' },
  input: { width: '100%', background: '#F6F5F2', border: '1px solid #E5E4E0', borderRadius: '14px', padding: '12px 14px 12px 42px', fontFamily: 'Outfit, sans-serif', fontSize: '14px', color: '#333', outline: 'none', boxSizing: 'border-box', transition: 'border-color 0.2s' },
  eyeBtn: { position: 'absolute', right: '14px', top: '50%', transform: 'translateY(-50%)', border: 'none', background: 'transparent', cursor: 'pointer', color: '#AAAAAA', padding: '2px' },
  forgotBtn: { background: 'none', border: 'none', cursor: 'pointer', fontFamily: 'Outfit, sans-serif', fontSize: '12px', color: '#7C9C84' },
  error: { fontFamily: 'Outfit, sans-serif', fontSize: '12px', color: '#ef4444', background: '#fef2f2', borderRadius: '12px', padding: '10px 14px' },
  submitBtn: (loading) => ({ width: '100%', background: loading ? '#A3BBA9' : '#7C9C84', color: 'white', fontFamily: 'Outfit, sans-serif', fontWeight: 600, fontSize: '15px', padding: '14px', borderRadius: '14px', border: 'none', cursor: loading ? 'not-allowed' : 'pointer', marginTop: '4px', transition: 'background 0.2s' }),
  footer: { textAlign: 'center', fontFamily: 'Outfit, sans-serif', fontSize: '11px', color: '#AAAAAA', marginTop: '20px' },
};

const FIREBASE_ERRORS = {
  'auth/user-not-found': 'No admin account found with this email.',
  'auth/wrong-password': 'Incorrect password. Please try again.',
  'auth/invalid-email': 'Please enter a valid email address.',
  'auth/invalid-credential': 'Invalid credentials. Please try again.',
  'auth/too-many-requests': 'Too many failed attempts. Please try again later.',
};

export default function LoginPage({ externalError }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPw, setShowPw] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (externalError) {
      setError(externalError);
      setLoading(false);
    }
  }, [externalError]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    if (!email || !password) { setError('Please fill in all fields.'); return; }
    setLoading(true);
    try {
      await signInWithEmailAndPassword(auth, email, password);
      // Auth state change in App.jsx will handle redirect automatically
    } catch (err) {
      setError(FIREBASE_ERRORS[err.code] || 'Login failed. Please try again.');
      setLoading(false);
    }
  };

  return (
    <div style={s.wrap}>
      <div style={s.box}>
        <div style={s.logoWrap}>
          <div style={s.logoIcon}>
            <img src={logo} alt="Eunoia Logo" style={{ width: '48px', height: '48px' }} />
          </div>
          <div style={s.logoTitle}>Eunoia</div>
          <div style={s.logoSub}>Admin Portal</div>
        </div>

        <div style={s.card}>
          <div style={s.cardTitle}>Welcome back</div>
          <div style={s.cardSub}>Sign in to your admin account</div>

          <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div>
              <label style={s.label}>Email</label>
              <div style={s.inputWrap}>
                <span style={s.inputIcon}><Mail size={15} /></span>
                <input
                  id="admin-email"
                  type="email"
                  style={s.input}
                  placeholder="admin@eunoia.com"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  autoComplete="email"
                />
              </div>
            </div>

            <div>
              <label style={s.label}>Password</label>
              <div style={s.inputWrap}>
                <span style={s.inputIcon}><Lock size={15} /></span>
                <input
                  id="admin-password"
                  type={showPw ? 'text' : 'password'}
                  style={{ ...s.input, paddingRight: '42px' }}
                  placeholder="••••••••"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  autoComplete="current-password"
                />
                <button type="button" style={s.eyeBtn} onClick={() => setShowPw(p => !p)}>
                  {showPw ? <EyeOff size={15} /> : <Eye size={15} />}
                </button>
              </div>
            </div>

            <div style={{ textAlign: 'right' }}>
              <button type="button" style={s.forgotBtn}>Forgot password?</button>
            </div>

            {error && <div style={s.error}>{error}</div>}

            <button id="login-btn" type="submit" disabled={loading} style={s.submitBtn(loading)}>
              {loading ? 'Signing in…' : 'Sign In'}
            </button>
          </form>
        </div>

        <p style={s.footer}>Eunoia © {new Date().getFullYear()} · Admin Access Only</p>
      </div>
    </div>
  );
}
