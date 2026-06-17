import { useState, useEffect } from 'react';
import { User, Lock, Loader2, Mail, Info, Activity, ShieldCheck, Key, HelpCircle, Eye, EyeOff } from 'lucide-react';
import { auth, db } from '../../firebase';
import { doc, getDoc, collection, query, where, getDocs, limit } from 'firebase/firestore';
import { EmailAuthProvider, reauthenticateWithCredential, updatePassword } from 'firebase/auth';

export default function AccountSettings() {
   const [activeTab, setActiveTab] = useState('profile'); // 'profile' or 'password'
   const [loading, setLoading] = useState(true);
   const [profile, setProfile] = useState({ name: 'Loading...', email: '...', role: 'Admin' });
   
   // Password visibility states
   const [showOld, setShowOld] = useState(false);
   const [showNew, setShowNew] = useState(false);
   const [showConfirm, setShowConfirm] = useState(false);
   
   // Password values
   const [oldPassword, setOldPassword] = useState('');
   const [newPassword, setNewPassword] = useState('');
   const [confirmPassword, setConfirmPassword] = useState('');
   
   // Password update status
   const [updateStatus, setUpdateStatus] = useState({ type: '', message: '' });
   const [isUpdating, setIsUpdating] = useState(false);

   useEffect(() => {
      const fetchAdminData = async () => {
         const u = auth.currentUser;
         if (!u) return;

         try {
            setLoading(true);
            const docRef = doc(db, 'users', u.uid);
            const docSnap = await getDoc(docRef);
            let userData = docSnap.exists() ? docSnap.data() : null;

            if (!userData) {
               const q = query(collection(db, 'users'), where('uid', '==', u.uid), limit(1));
               const querySnap = await getDocs(q);
               if (!querySnap.empty) userData = querySnap.docs[0].data();
            }

            if (!userData && u.email) {
               const qEmail = query(collection(db, 'users'), where('email', '==', u.email), limit(1));
               const querySnapEmail = await getDocs(qEmail);
               if (!querySnapEmail.empty) {
                 userData = querySnapEmail.docs[0].data();
               }
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

   const handleUpdatePassword = async () => {
      setUpdateStatus({ type: '', message: '' });
      if (!oldPassword || !newPassword || !confirmPassword) {
         setUpdateStatus({ type: 'error', message: 'Please fill in all fields.' });
         return;
      }
      if (newPassword !== confirmPassword) {
         setUpdateStatus({ type: 'error', message: 'New passwords do not match.' });
         return;
      }
      
      const u = auth.currentUser;
      if (!u || !u.email) {
         setUpdateStatus({ type: 'error', message: 'No active user found.' });
         return;
      }

      setIsUpdating(true);
      try {
         const credential = EmailAuthProvider.credential(u.email, oldPassword);
         await reauthenticateWithCredential(u, credential);
         await updatePassword(u, newPassword);
         
         setUpdateStatus({ type: 'success', message: 'Password updated successfully!' });
         setOldPassword('');
         setNewPassword('');
         setConfirmPassword('');
      } catch (err) {
         console.error('Password update error:', err);
         if (err.code === 'auth/wrong-password' || err.code === 'auth/invalid-credential') {
            setUpdateStatus({ type: 'error', message: 'Incorrect old password.' });
         } else if (err.code === 'auth/weak-password') {
            setUpdateStatus({ type: 'error', message: 'New password is too weak.' });
         } else {
            setUpdateStatus({ type: 'error', message: 'Failed to update password. Please try again.' });
         }
      } finally {
         setIsUpdating(false);
      }
   };

   return (
      <div className="flex flex-col gap-8 w-full">
         {/* HEADER */}
         <div className="flex flex-row items-center justify-between gap-4">
            <div>
               <p className="section-label mb-0.5 whitespace-nowrap">Administrative Hub / Account Node</p>
               <h2 className="font-display font-semibold text-2xl text-charcoal">Profile</h2>
            </div>
         </div>

         {loading ? (
            <div className="flex flex-col items-center justify-center py-40 gap-4">
               <Loader2 className="animate-spin text-[#7C9C84]" size={32} />
               <p className="font-body text-xs text-charcoal-muted uppercase tracking-[0.2em] font-black">Syncing Hub...</p>
            </div>
         ) : (
            <>
                  {/* PROFILE VIEW (IDENTITY + INFO) */}
                  <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 items-stretch w-full animate-in fade-in duration-300">
                     
                     {/* COLUMN 1 (LEFT): IDENTITY BOX */}
                     <div className="card p-10 flex flex-col bg-white shadow-sm border border-cream-darker/30 min-h-[500px]">
                        <div className="flex-1 flex flex-col items-center justify-center py-6">
                           <div className="relative mb-8">
                              <div className="w-40 h-40 rounded-full overflow-hidden border-4 border-[#F6F5F2] shadow-xl">
                                 <div className="w-full h-full bg-[#E5EDE8] flex items-center justify-center text-[#7C9C84] font-display text-5xl font-black">
                                    {profile.name.charAt(0)}
                                 </div>
                              </div>
                              <div className="absolute bottom-2 right-2 p-2.5 bg-white rounded-full shadow-lg border border-cream-darker/20 transition-all hover:scale-110">
                                 <ShieldCheck size={18} className="text-[#7C9C84]" />
                              </div>
                           </div>

                           <div className="text-center mb-8">
                              <h3 className="font-display text-2xl text-charcoal font-black tracking-tight mb-2 underline underline-offset-8 decoration-cream-darker/40">{profile.name}</h3>
                              <p className="font-body text-xs text-charcoal-muted opacity-80 italic truncate max-w-[240px] tracking-wide">{profile.email}</p>
                           </div>

                           <div className="bg-[#E5EDE8] px-10 py-3 rounded-full border border-[#7C9C84]/10 shadow-sm transition-all hover:bg-[#DDE9E1]">
                              <p className="text-[11px] font-black text-[#7C9C84] uppercase tracking-[0.25em]">{profile.role}</p>
                           </div>
                        </div>

                     </div>

                     {/* COLUMN 2 (RIGHT): PERSONAL PROFILE BOX */}
                     <div className="card p-10 bg-white shadow-sm border border-cream-darker/30 flex flex-col h-full">
                        <div className="flex items-center gap-4 mb-10 pb-6 border-b border-cream/50">
                           <div className="w-10 h-10 rounded-xl bg-[#E5EDE8] flex items-center justify-center text-[#7C9C84]">
                              <User size={18} />
                           </div>
                           <h4 className="font-display text-lg text-charcoal font-bold">Personal Profile</h4>
                        </div>

                        <div className="space-y-6">
                           {[
                              { label: "Admin Name", value: profile.name },
                              { label: "Admin Email", value: profile.email },
                              { label: "Admin Role", value: profile.role }
                           ].map((f, i) => (
                              <div key={i} className="space-y-2 group">
                                 <label className="text-[9px] font-black text-[#7C9C84] uppercase tracking-[0.3em] ml-1">{f.label}</label>
                                 <div className="w-full h-[54px] bg-[#f8f7f5] border border-cream-darker/40 rounded-xl px-5 flex items-center justify-between shadow-inner group">
                                    <p className="text-[15px] font-body text-charcoal-muted font-medium tracking-tight truncate max-w-[90%]">
                                       {f.value}
                                    </p>
                                    <div className="text-charcoal/20 shrink-0">
                                       <Lock size={12} />
                                    </div>
                                 </div>
                              </div>
                           ))}
                        </div>
                        
                        {/* HR REDIRECTION NOTICE */}
                        <div className="mt-auto pt-10 border-t border-cream/20">
                           <div className="p-5 bg-cream/30 rounded-2xl border border-cream-darker/40 flex items-start gap-4">
                              <div className="w-10 h-10 rounded-xl bg-white flex items-center justify-center text-[#7C9C84] shrink-0 border border-cream-darker/20 shadow-sm">
                                 <HelpCircle size={18} />
                              </div>
                              <div className="space-y-0.5">
                                 <p className="text-[9px] font-black text-[#7C9C84] uppercase tracking-widest mb-1">Administrative Modification</p>
                                 <p className="text-[11px] text-charcoal-muted leading-relaxed font-medium">
                                    To update profile records, please contact the <span className="text-[#7C9C84] font-bold">HR Department</span> for system audit approval.
                                 </p>
                              </div>
                           </div>
                        </div>
                     </div>
                  </div>
            </>
         )}
      </div>
   );
}
