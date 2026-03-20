import { useState, useEffect } from 'react';
import { User, Lock, Save, Loader2, ShieldCheck, Mail } from 'lucide-react';
import { auth, db } from '../../firebase';
import { doc, getDoc, collection, query, where, getDocs, limit } from 'firebase/firestore';

export default function AccountSettings() {
  const [activeTab, setActiveTab] = useState('profile');
  const [loading, setLoading] = useState(true);
  const [profile, setProfile] = useState({ name: 'Loading...', email: '...', role: 'Admin' });
  const [passwords, setPasswords] = useState({ current: '', newPw: '', confirm: '' });
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    const fetchAdminData = async () => {
      const u = auth.currentUser;
      if (!u) return;

      try {
        setLoading(true);
        // Standard check
        const docRef = doc(db, 'users', u.uid);
        const docSnap = await getDoc(docRef);
        let userData = docSnap.exists() ? docSnap.data() : null;

        // Fallback search
        if (!userData) {
          const q = query(collection(db, 'users'), where('uid', '==', u.uid), limit(1));
          const querySnap = await getDocs(q);
          if (!querySnap.empty) userData = querySnap.docs[0].data();
        }

        if (userData) {
          setProfile({
            name: userData.name || userData.fullName || 'Admin User',
            email: userData.email || u.email,
            role: userData.role === 'admin' ? 'System Administrator' : userData.role
          });
        }
      } catch (err) {
        console.error("Account fetch error:", err);
      } finally {
        setLoading(false);
      }
    };

    fetchAdminData();
  }, []);

  const handleUpdatePassword = () => {
    // Note: Firebase Auth password update requires recent login
    alert("Functionality to update password via Firebase Auth is ready to be linked. This usually requires a 're-authenticate' step for security.");
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  return (
    <div className="flex flex-col gap-6 max-w-2xl">
      <div>
        <p className="section-label mb-1">System Settings</p>
        <h2 className="font-display font-semibold text-2xl text-charcoal">Account Settings</h2>
      </div>

      {/* Tabs */}
      <div className="flex gap-2 bg-cream rounded-2xl p-1 w-fit">
        {[{ id: 'profile', icon: User, label: 'Profile' }, { id: 'password', icon: Lock, label: 'Security' }].map(t => (
          <button
            key={t.id}
            onClick={() => setActiveTab(t.id)}
            className={`flex items-center gap-2 px-5 py-2.5 rounded-xl font-body text-sm font-medium transition-all ${activeTab === t.id ? 'bg-white text-primary shadow-card' : 'text-charcoal-muted hover:text-charcoal'}`}
          >
            <t.icon size={15} /> {t.label}
          </button>
        ))}
      </div>

      {activeTab === 'profile' && (
        <div className="card flex flex-col gap-6">
          {loading ? (
            <div className="py-10 flex flex-col items-center gap-3">
              <Loader2 className="animate-spin text-primary" size={32} />
              <p className="font-body text-sm text-charcoal-muted">Retrieving profile...</p>
            </div>
          ) : (
            <>
              {/* Avatar */}
              <div className="flex items-center gap-5">
                <div className="w-20 h-20 rounded-2xl bg-sage-200 border-2 border-white shadow-sm flex items-center justify-center text-primary font-display font-semibold text-3xl">
                  {profile.name.charAt(0)}
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <p className="font-body font-bold text-lg text-charcoal">{profile.name}</p>
                    <ShieldCheck size={16} className="text-primary" />
                  </div>
                  <p className="font-body text-sm text-charcoal-muted flex items-center gap-1.5 mt-0.5">
                    <Mail size={12} /> {profile.email}
                  </p>
                  <p className="font-body text-[11px] font-bold text-primary uppercase tracking-widest mt-2 px-2 py-0.5 bg-sage-100 rounded-md w-fit">
                    {profile.role}
                  </p>
                </div>
              </div>

              <div className="w-full h-px bg-cream-darker" />

              <div className="grid grid-cols-1 gap-5">
                <div className="opacity-70">
                  <label className="font-body text-xs font-semibold text-charcoal-muted uppercase tracking-wider mb-2 block">Full Name</label>
                  <div className="input-field bg-cream-darker flex items-center gap-2 text-charcoal-muted">
                    <User size={14} />
                    {profile.name}
                  </div>
                  <p className="text-[10px] text-muted mt-1.5 italic">* Mandatory field managed by directory</p>
                </div>
                
                <div className="opacity-70">
                  <label className="font-body text-xs font-semibold text-charcoal-muted uppercase tracking-wider mb-2 block">Email Address</label>
                  <div className="input-field bg-cream-darker flex items-center gap-2 text-charcoal-muted">
                    <Mail size={14} />
                    {profile.email}
                  </div>
                  <p className="text-[10px] text-muted mt-1.5 italic">* Primary authentication email (Read-only)</p>
                </div>

                <div>
                  <label className="font-body text-xs font-semibold text-charcoal-muted uppercase tracking-wider mb-2 block">Permissions Level</label>
                  <input className="input-field bg-cream-darker text-charcoal-muted cursor-not-allowed" value={profile.role} disabled />
                </div>
              </div>

              <div className="p-4 bg-amber-50 rounded-2xl border border-amber-100">
                <p className="font-body text-xs text-amber-700 leading-relaxed">
                  <strong>Notice:</strong> Your personal information is retrieved directly from the platform's core identity database. To request changes to your name or primary email, please contact the system owner or HR department.
                </p>
              </div>
            </>
          )}
        </div>
      )}

      {activeTab === 'password' && (
        <div className="card flex flex-col gap-5">
            <h4 className="font-display font-semibold text-lg text-charcoal mb-2">Update Credentials</h4>
          <div>
            <label className="font-body text-xs font-semibold text-charcoal-muted uppercase tracking-wider mb-1.5 block">Current Password</label>
            <input className="input-field" type="password" placeholder="••••••••" value={passwords.current} onChange={e => setPasswords(p => ({ ...p, current: e.target.value }))} />
          </div>
          <div>
            <label className="font-body text-xs font-semibold text-charcoal-muted uppercase tracking-wider mb-1.5 block">New Password</label>
            <input className="input-field" type="password" placeholder="••••••••" value={passwords.newPw} onChange={e => setPasswords(p => ({ ...p, newPw: e.target.value }))} />
          </div>
          <div>
            <label className="font-body text-xs font-semibold text-charcoal-muted uppercase tracking-wider mb-1.5 block">Confirm New Password</label>
            <input className="input-field" type="password" placeholder="••••••••" value={passwords.confirm} onChange={e => setPasswords(p => ({ ...p, confirm: e.target.value }))} />
          </div>
          {passwords.newPw && passwords.confirm && passwords.newPw !== passwords.confirm && (
            <p className="font-body text-xs text-red-500 bg-red-50 rounded-xl px-3 py-2">Passwords do not match</p>
          )}
          <button onClick={handleUpdatePassword} className="btn-primary flex items-center justify-center gap-2 w-fit mt-4"
            disabled={!passwords.current || !passwords.newPw || passwords.newPw !== passwords.confirm}>
            <Save size={15} /> {saved ? 'Updated!' : 'Update Password'}
          </button>
        </div>
      )}
    </div>
  );
}
