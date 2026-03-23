import { useState, useEffect } from 'react';
import { User, Lock, Loader2, Mail, Info, Activity, ShieldCheck, Key, HelpCircle, Eye, EyeOff } from 'lucide-react';
import { auth, db } from '../../firebase';
import { doc, getDoc, collection, query, where, getDocs, limit } from 'firebase/firestore';

export default function AccountSettings() {
   const [activeTab, setActiveTab] = useState('profile'); // 'profile' or 'password'
   const [loading, setLoading] = useState(true);
   const [profile, setProfile] = useState({ name: 'Loading...', email: '...', role: 'Admin' });
   
   // Password visibility states
   const [showOld, setShowOld] = useState(false);
   const [showNew, setShowNew] = useState(false);
   const [showConfirm, setShowConfirm] = useState(false);

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
      alert("Password rotation requires a re-authentication step.");
   };

   return (
      <div className="flex flex-col gap-8 w-full">
         {/* HEADER: Profile and Password Tab-Buttons */}
         <div className="flex flex-row items-center justify-between gap-4">
            <div>
               <p className="section-label mb-0.5 whitespace-nowrap">Administrative Hub / Account Node</p>
               <h2 className="font-display font-semibold text-2xl text-charcoal">Account Settings</h2>
            </div>
            <div className="flex items-center gap-2 bg-cream-darker/20 p-1.5 rounded-2xl border border-cream-darker/40 shadow-inner">
               <button 
                  onClick={() => setActiveTab('profile')}
                  className={`px-6 py-2 rounded-xl font-body text-xs font-bold transition-all uppercase tracking-widest flex items-center gap-2 ${activeTab === 'profile' ? 'bg-[#7C9C84] text-white shadow-md' : 'text-charcoal-muted hover:bg-cream/50'}`}
               >
                  <User size={13} /> Profile
               </button>
               <button 
                  onClick={() => setActiveTab('password')}
                  className={`px-6 py-2 rounded-xl font-body text-xs font-bold transition-all uppercase tracking-widest flex items-center gap-2 ${activeTab === 'password' ? 'bg-[#7C9C84] text-white shadow-md' : 'text-charcoal-muted hover:bg-cream/50'}`}
               >
                  <Lock size={13} /> Password
               </button>
            </div>
         </div>

         {loading ? (
            <div className="flex flex-col items-center justify-center py-40 gap-4">
               <Loader2 className="animate-spin text-[#7C9C84]" size={32} />
               <p className="font-body text-xs text-charcoal-muted uppercase tracking-[0.2em] font-black">Syncing Hub...</p>
            </div>
         ) : (
            <>
               {activeTab === 'profile' ? (
                  /* TAB 1: PROFILE VIEW (IDENTITY + INFO) */
                  <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 items-stretch w-full animate-in fade-in duration-300">
                     
                     {/* COLUMN 1 (LEFT): IDENTITY BOX */}
                     <div className="card p-10 flex flex-col bg-white shadow-sm border border-cream-darker/30 min-h-[500px]">
                        <div className="flex-1 flex flex-col items-center justify-center py-6">
                           <div className="relative mb-8">
                              <div className="w-40 h-40 rounded-full overflow-hidden border-4 border-[#F6F5F2] shadow-xl">
                                 <div className="w-full h-full bg-[#E5EDE8] flex items-center justify-center text-[#7C9C84] font-display text-8xl font-black">
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

                        {/* Summary Footer */}
                        <div className="w-full space-y-4 pt-10 border-t border-cream-darker/30 mt-auto">
                           <div className="flex justify-between items-center text-[10px]">
                              <p className="font-black text-muted uppercase tracking-widest opacity-40">System Access Node</p>
                              <p className="font-bold text-charcoal tracking-tight">GLOBAL-A1</p>
                           </div>
                           <div className="flex justify-between items-center text-[10px]">
                              <p className="font-black text-muted uppercase tracking-widest opacity-40">Account Pulse</p>
                              <p className="font-bold text-[#7C9C84] tracking-tight uppercase">VERIFIED STATUS</p>
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
               ) : (
                  /* TAB 2: PASSWORD VIEW (UPDATED BUTTON SIZE) */
                  <div className="w-full animate-in slide-in-from-bottom-2 duration-400">
                     <div className="card p-10 bg-white shadow-sm border border-cream-darker/30 flex flex-col max-w-2xl px-6 lg:px-12 pb-14">
                        <div className="flex items-center gap-5 mb-8 pb-6 border-b border-cream/40">
                           <div className="w-12 h-12 rounded-2xl bg-sage-50 flex items-center justify-center text-[#7C9C84]">
                              <Lock size={24} />
                           </div>
                           <div>
                              <h4 className="font-display text-xl text-charcoal font-bold">Update Password</h4>
                              <p className="text-[9px] text-charcoal-muted font-bold uppercase tracking-widest opacity-50">Change account security</p>
                           </div>
                        </div>

                        <div className="space-y-6 max-w-xl">
                           {[
                              { label: 'Old Password', visible: showOld, setter: setShowOld },
                              { label: 'New Password', visible: showNew, setter: setShowNew },
                              { label: 'Confirm Password', visible: showConfirm, setter: setShowConfirm }
                           ].map((f, i) => (
                              <div key={i} className="space-y-2 group">
                                 <label className="text-[9px] font-black text-[#7C9C84] uppercase tracking-widest ml-1">{f.label}</label>
                                 <div className="w-full bg-[#f8f7f5] border border-cream-darker/40 rounded-xl px-5 py-4 flex items-center transition-all focus-within:border-[#7C9C84] focus-within:bg-white shadow-inner relative">
                                    <input 
                                       type={f.visible ? "text" : "password"}
                                       placeholder="••••••••••••"
                                       className="w-full bg-transparent font-body text-xl tracking-[0.45em] outline-none placeholder:text-cream-darker placeholder:tracking-normal h-6 pr-10"
                                    />
                                    <button 
                                       type="button"
                                       onClick={() => f.setter(!f.visible)}
                                       className="absolute right-5 top-1/2 -translate-y-1/2 text-charcoal-muted hover:text-[#7C9C84] transition-colors p-1"
                                    >
                                       {f.visible ? <EyeOff size={18} /> : <Eye size={18} />}
                                    </button>
                                 </div>
                              </div>
                           ))}

                           <div className="pt-8">
                              <button 
                                 onClick={handleUpdatePassword}
                                 className="px-10 py-4.5 bg-[#7C9C84] text-white rounded-[18px] font-body text-sm font-bold uppercase tracking-widest shadow-lg shadow-[#7C9C84]/20 hover:scale-[1.02] active:scale-95 transition-all w-full lg:w-auto"
                                 style={{ padding: '16px 40px' }} // Explicitly matching the high-action size
                              >
                                 Update Password
                              </button>
                           </div>
                        </div>
                     </div>
                  </div>
               )}
            </>
         )}
      </div>
   );
}
