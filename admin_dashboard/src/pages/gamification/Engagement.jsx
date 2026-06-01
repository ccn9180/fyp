import { useState, useEffect } from 'react';
import {
  Zap, Award, Gift, Plus, Trash2, Pencil, X, Search,
  TrendingUp, Star, Music, BookOpen,
  MessageSquare, Edit3, Loader2, Sparkles, ChevronDown, Check, AlertCircle
} from 'lucide-react';
import { customAlert, customConfirm } from '../../utils/dialogUtils';
import { db, storage } from '../../firebase';
import {
  collection,
  onSnapshot,
  doc,
  addDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp
} from 'firebase/firestore';
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';



// Default Seed Data
const DEFAULT_TASKS = [
  { title: "Daily Mood Check-In", description: "Log your emotional state on the Home screen", xp_reward: 10, coin_reward: 5, task_type: "mood", frequency: "daily", icon: "mood" },
  { title: "Mindful Chatbot Session", description: "Have a chat session with Eunoia AI", xp_reward: 15, coin_reward: 8, task_type: "chat", frequency: "daily", icon: "chat" },
  { title: "Write a Diary Entry", description: "Reflect and write your thoughts in your private journal", xp_reward: 20, coin_reward: 10, task_type: "journal", frequency: "daily", icon: "journal" },
  { title: "Grounding Breathing Quest", description: "Complete a grounding or breathing exercise", xp_reward: 25, coin_reward: 12, task_type: "meditation", frequency: "daily", icon: "breathing" },
  { title: "Weekly Reflection Master", description: "Write at least 3 diary entries this week", xp_reward: 100, coin_reward: 50, task_type: "journal", frequency: "weekly", icon: "journal" },
  { title: "Consistent Connection", description: "Chat with Eunoia AI on 5 different days", xp_reward: 150, coin_reward: 75, task_type: "chat", frequency: "weekly", icon: "chat" }
];

const DEFAULT_BADGES = [
  { name: "First Step", description: "Earned on leveling up to Level 2", icon: "directions_walk_rounded", tier: "Novice", condition_type: "level", condition_value: 2 },
  { name: "Mindful Traveler", description: "Reach Level 5 to unlock traveler status", icon: "calendar_month_rounded", tier: "Adept", condition_type: "level", condition_value: 5 },
  { name: "Calm Keeper", description: "Maintain a 3-day wellness streak", icon: "local_fire_department_rounded", tier: "Adept", condition_type: "streak", condition_value: 3 },
  { name: "Streak Master", description: "Maintain a 7-day wellness streak", icon: "local_fire_department_rounded", tier: "Master", condition_type: "streak", condition_value: 7 },
  { name: "Balanced Bloomer", description: "Reach Level 10 to bloom", icon: "psychology_rounded", tier: "Legendary", condition_type: "level", condition_value: 10 }
];

const DEFAULT_REWARDS = [
  { name: "10% Session Discount", description: "Redeem for 10% off your next counselor session", coin_cost: 200, category: "Voucher", icon: "voucher", active: true },
  { name: "Mindful Forest Theme", description: "A custom soothing green theme for your user profile", coin_cost: 500, category: "Theme", icon: "theme", active: true },
  { name: "Lotus Profile Seal", description: "Unlock a special lotus badge icon for your profile", coin_cost: 1000, category: "Avatar", icon: "profile", active: true },
  { name: "Premium Meditation Guide", description: "Access the extended library of breathing exercises", coin_cost: 1500, category: "Feature", icon: "extension", active: true }
];

export default function Engagement() {
  const [activeTab, setActiveTab] = useState('tasks');
  const [tasks, setTasks] = useState([]);
  const [badges, setBadges] = useState([]);
  const [rewards, setRewards] = useState([]);
  
  const [loading, setLoading] = useState({ tasks: true, badges: true, rewards: true });
  const [processing, setProcessing] = useState(false);
  const [isModalOpen, setIsModalOpen] = useState(null); // 'tasks' | 'badges' | 'rewards' | null
  const [editingItem, setEditingItem] = useState(null); // Doc object to edit

  // Form states
  const [taskForm, setTaskForm] = useState({ title: '', description: '', xp_reward: 10, coin_reward: 5, task_type: 'mood', frequency: 'daily', icon: 'mood' });
  const [badgeForm, setBadgeForm] = useState({ name: '', description: '', icon: 'directions_walk_rounded', tier: 'Novice', condition_type: 'level', condition_value: 2 });
  const [rewardForm, setRewardForm] = useState({ name: '', description: '', coin_cost: 100, category: 'Voucher', icon: 'voucher', active: true });
  const [uploadingIcon, setUploadingIcon] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');

  const filteredTasks = tasks.filter(t => (t.title || '').toLowerCase().includes(searchQuery.toLowerCase()) || (t.description || '').toLowerCase().includes(searchQuery.toLowerCase()));
  const filteredBadges = badges.filter(b => (b.name || '').toLowerCase().includes(searchQuery.toLowerCase()) || (b.description || '').toLowerCase().includes(searchQuery.toLowerCase()));
  const filteredRewards = rewards.filter(r => (r.name || '').toLowerCase().includes(searchQuery.toLowerCase()) || (r.description || '').toLowerCase().includes(searchQuery.toLowerCase()));

  const handleImageUpload = async (e, formSetter) => {
    const file = e.target.files[0];
    if (!file) return;
    setUploadingIcon(true);
    try {
      const fileRef = ref(storage, `gamification_icons/${Date.now()}_${file.name}`);
      const uploadTask = uploadBytesResumable(fileRef, file);
      
      uploadTask.on(
        'state_changed',
        null,
        (error) => {
          console.error("Upload error:", error);
          customAlert("Failed to upload image.", "Error");
          setUploadingIcon(false);
        },
        async () => {
          const downloadURL = await getDownloadURL(uploadTask.snapshot.ref);
          formSetter(prev => ({ ...prev, icon: downloadURL }));
          setUploadingIcon(false);
        }
      );
    } catch (error) {
      console.error(error);
      setUploadingIcon(false);
    }
  };

  // Listen to Firestore
  useEffect(() => {
    const unsubTasks = onSnapshot(collection(db, 'tasks'), (snap) => {
      setTasks(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(l => ({ ...l, tasks: false }));
    });
    const unsubBadges = onSnapshot(collection(db, 'badges'), (snap) => {
      setBadges(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(l => ({ ...l, badges: false }));
    });
    const unsubRewards = onSnapshot(collection(db, 'rewards'), (snap) => {
      setRewards(snap.docs.map(d => ({ id: d.id, ...d.data() })));
      setLoading(l => ({ ...l, rewards: false }));
    });

    return () => {
      unsubTasks();
      unsubBadges();
      unsubRewards();
    };
  }, []);

  const handleSeedData = async () => {
    const confirmed = await customConfirm('Populate Firestore with standard Eunoia gamification assets?', 'Confirm Data Seed');
    if (!confirmed) return;
    setProcessing(true);
    try {
      if (tasks.length === 0) {
        for (const item of DEFAULT_TASKS) {
          await addDoc(collection(db, 'tasks'), item);
        }
      }
      if (badges.length === 0) {
        for (const item of DEFAULT_BADGES) {
          await addDoc(collection(db, 'badges'), item);
        }
      }
      if (rewards.length === 0) {
        for (const item of DEFAULT_REWARDS) {
          await addDoc(collection(db, 'rewards'), item);
        }
      }
      await customAlert('Data seeded successfully!', 'Success');
    } catch (e) {
      console.error(e);
      await customAlert('Failed to seed data.', 'Error');
    } finally {
      setProcessing(false);
    }
  };

  const handleSaveTask = async (e) => {
    e.preventDefault();
    setProcessing(true);
    try {
      if (editingItem) {
        await updateDoc(doc(db, 'tasks', editingItem.id), taskForm);
      } else {
        await addDoc(collection(db, 'tasks'), taskForm);
      }
      setIsModalOpen(null);
      setEditingItem(null);
    } catch (e) {
      console.error(e);
    } finally {
      setProcessing(false);
    }
  };

  const handleSaveBadge = async (e) => {
    e.preventDefault();
    setProcessing(true);
    try {
      if (editingItem) {
        await updateDoc(doc(db, 'badges', editingItem.id), badgeForm);
      } else {
        await addDoc(collection(db, 'badges'), badgeForm);
      }
      setIsModalOpen(null);
      setEditingItem(null);
    } catch (e) {
      console.error(e);
    } finally {
      setProcessing(false);
    }
  };

  const handleSaveReward = async (e) => {
    e.preventDefault();
    setProcessing(true);
    try {
      if (editingItem) {
        await updateDoc(doc(db, 'rewards', editingItem.id), rewardForm);
      } else {
        await addDoc(collection(db, 'rewards'), rewardForm);
      }
      setIsModalOpen(null);
      setEditingItem(null);
    } catch (e) {
      console.error(e);
    } finally {
      setProcessing(false);
    }
  };

  const openEdit = (type, item) => {
    setEditingItem(item);
    if (type === 'tasks') {
      setTaskForm({
        title: item.title || '',
        description: item.description || '',
        xp_reward: item.xp_reward || 10,
        coin_reward: item.coin_reward || 5,
        task_type: item.task_type || 'mood',
        frequency: item.frequency || 'daily',
        icon: item.icon || 'mood'
      });
      setIsModalOpen('tasks');
    } else if (type === 'badges') {
      setBadgeForm({
        name: item.name || '',
        description: item.description || '',
        icon: item.icon || 'directions_walk_rounded',
        tier: item.tier || 'Novice',
        condition_type: item.condition_type || 'level',
        condition_value: item.condition_value || 2
      });
      setIsModalOpen('badges');
    } else if (type === 'rewards') {
      setRewardForm({
        name: item.name || '',
        description: item.description || '',
        coin_cost: item.coin_cost || 100,
        category: item.category || 'Voucher',
        icon: item.icon || 'voucher',
        active: item.active !== false
      });
      setIsModalOpen('rewards');
    }
  };

  const handleDelete = async (coll, id) => {
    const confirmed = await customConfirm("Are you sure you want to permanently delete this item?", "Confirm Delete");
    if (!confirmed) return;
    try {
      await deleteDoc(doc(db, coll, id));
      await customAlert("Item successfully deleted.", "Success");
    } catch (e) {
      console.error(e);
      await customAlert("Failed to delete item.", "Error");
    }
  };

  return (
    <div className="flex flex-col gap-5">
      <div className="flex items-center justify-between">
        <div>
          <span className="font-body text-[10px] font-bold uppercase tracking-[0.08em] text-muted">Gamification Center</span>
          <h2 className="font-outfit font-semibold text-2xl text-charcoal m-0">Gamification Management</h2>
        </div>

        <div className="flex gap-4 items-center">
          <div className="relative">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-charcoal-muted" />
            <input
              type="text"
              placeholder="Search..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              className="pl-9 pr-10 py-2 bg-white border border-cream-darker rounded-xl text-sm font-body outline-none focus:border-primary transition w-48 shadow-sm"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-primary p-0.5 rounded-full hover:bg-sage-50 transition"
              >
                <X size={14} />
              </button>
            )}
          </div>
          <div className="flex gap-2 bg-cream p-1 rounded-[14px] border border-cream-darker">
            {[
            { id: 'tasks', label: 'Quests & Tasks' },
            { id: 'badges', label: 'Badges' },
            { id: 'rewards', label: 'Treasury Rewards' }
          ].map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`px-4 py-2 rounded-xl border-none font-outfit font-semibold text-[13px] cursor-pointer transition-all ${activeTab === tab.id ? 'bg-primary text-white shadow-[0_4px_12px_rgba(124,156,132,0.2)]' : 'bg-transparent text-charcoal-muted'}`}
            >
              {tab.label}
            </button>
          ))}
          </div>
        </div>
      </div>

      <div>
        {activeTab === 'tasks' && (
          <div className="bg-white rounded-[20px] shadow-[0_2px_16px_rgba(0,0,0,0.06)] p-6">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h3 className="font-outfit text-lg font-semibold text-charcoal m-0">Wellness Quests</h3>
                <p className="text-xs text-muted font-outfit mt-1">Daily and weekly user challenges for XP & Coins</p>
              </div>
              <button
                onClick={() => { setEditingItem(null); setTaskForm({ title: '', description: '', xp_reward: 10, coin_reward: 5, task_type: 'mood', frequency: 'daily', icon: 'mood' }); setIsModalOpen('tasks'); }}
                className="flex items-center gap-1.5 bg-primary text-white border-none rounded-xl px-5 py-2.5 font-outfit font-semibold text-[13px] cursor-pointer transition-all hover:bg-primary-dark"
              >
                <Plus size={14} /> New Quest
              </button>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full border-collapse font-outfit text-[13px]">
                <thead>
                  <tr className="border-b border-cream-darker text-left">
                    {['Quest / Description', 'Type', 'Frequency', 'Rewards', 'Actions'].map(h => (
                      <th key={h} className="px-3 pb-3 text-[10px] font-bold uppercase tracking-[0.08em] text-muted">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {filteredTasks.map((task, idx) => (
                    <tr key={task.id} className={`${idx === filteredTasks.length - 1 ? 'border-none' : 'border-b border-cream-darker'}`}>
                      <td className="p-4 px-3">
                        <div className="flex items-center gap-3">
                          <span className="text-xl">
                            {task.icon?.startsWith('http') ? <img src={task.icon} alt="" className="w-8 h-8 object-contain rounded" /> : task.icon === 'mood' ? '🎭' : task.icon === 'chat' ? '💬' : task.icon === 'journal' ? '📓' : '🧘'}
                          </span>
                          <div className="flex flex-col">
                            <span className="font-semibold text-[14px] text-charcoal">{task.title}</span>
                            <span className="text-[11px] text-muted">{task.description}</span>
                          </div>
                        </div>
                      </td>
                      <td className="p-4 px-3 capitalize font-semibold">{task.task_type}</td>
                      <td className="p-4 px-3">
                        <span className={`px-2 py-1 rounded-md text-[11px] font-bold ${task.frequency === 'weekly' ? 'bg-blue-50 text-blue-600' : 'bg-gray-100 text-charcoal-muted'}`}>
                          {task.frequency?.toUpperCase()}
                        </span>
                      </td>
                      <td className="p-4 px-3 font-bold text-primary">
                        +{task.xp_reward} XP / +{task.coin_reward} Coins
                      </td>
                      <td className="p-4 px-3">
                        <div className="flex gap-2">
                          <button onClick={() => openEdit('tasks', task)} className="p-1.5 border-none bg-transparent text-muted cursor-pointer hover:text-primary"><Pencil size={14} /></button>
                          <button onClick={() => handleDelete('tasks', task.id)} className="p-1.5 border-none bg-transparent text-red-400 cursor-pointer hover:text-red-500"><Trash2 size={14} /></button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {tasks.length === 0 && !loading.tasks && (
              <div className="text-center border-2 border-dashed border-cream-darker rounded-[20px] p-10">
                <p className="text-sm text-muted mb-5">No wellness tasks configured.</p>
                <button onClick={handleSeedData} className="px-5 py-2.5 bg-primary text-white border-none rounded-xl font-semibold cursor-pointer">Initialize Default Quests</button>
              </div>
            )}
          </div>
        )}

        {activeTab === 'badges' && (
          <div className="bg-white rounded-[20px] shadow-[0_2px_16px_rgba(0,0,0,0.06)] p-6">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h3 className="font-outfit text-lg font-semibold text-charcoal m-0">Achievements & Badges</h3>
                <p className="text-xs text-muted font-outfit mt-1">User milestone definitions and criteria</p>
              </div>
              <button
                onClick={() => { setEditingItem(null); setBadgeForm({ name: '', description: '', icon: 'directions_walk_rounded', tier: 'Novice', condition_type: 'level', condition_value: 2 }); setIsModalOpen('badges'); }}
                className="flex items-center gap-1.5 bg-primary text-white border-none rounded-xl px-5 py-2.5 font-outfit font-semibold text-[13px] cursor-pointer transition-all hover:bg-primary-dark"
              >
                <Plus size={14} /> New Badge
              </button>
            </div>

            <div className="grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-5">
              {filteredBadges.map(b => (
                <div key={b.id} className="border border-cream-darker rounded-[20px] p-5 flex flex-col gap-3 relative">
                  <div className="flex justify-between items-start">
                    <div className="w-12 h-12 rounded-full bg-cream flex items-center justify-center text-[22px] border border-cream-darker overflow-hidden">
                      {b.icon?.startsWith('http') ? <img src={b.icon} alt="" className="w-full h-full object-cover" /> : b.icon === 'directions_walk_rounded' ? '🚶' : b.icon === 'calendar_month_rounded' ? '📅' : b.icon === 'local_fire_department_rounded' ? '🔥' : '🌸'}
                    </div>
                    <div className="flex gap-1">
                      <button onClick={() => openEdit('badges', b)} className="p-1.5 border-none bg-transparent text-muted cursor-pointer hover:text-primary"><Pencil size={14} /></button>
                      <button onClick={() => handleDelete('badges', b.id)} className="p-1.5 border-none bg-transparent text-red-400 cursor-pointer hover:text-red-500"><Trash2 size={14} /></button>
                    </div>
                  </div>
                  <div>
                    <h4 className="m-0 text-base font-bold text-charcoal">{b.name}</h4>
                    <p className="mt-1 mb-0 text-[11px] text-muted">{b.description}</p>
                  </div>
                  <div className="mt-auto pt-3 border-t border-cream-darker flex justify-between items-center">
                    <span className="text-[10px] font-bold px-2 py-1 rounded-md bg-sage-100 text-primary">{b.tier}</span>
                    <span className="text-[11px] font-semibold text-charcoal">
                      Req: {b.condition_value} {b.condition_type}
                    </span>
                  </div>
                </div>
              ))}
            </div>

            {badges.length === 0 && !loading.badges && (
              <div className="text-center border-2 border-dashed border-cream-darker rounded-[20px] p-10">
                <p className="text-sm text-muted mb-5">No milestone badges mapped.</p>
                <button onClick={handleSeedData} className="px-5 py-2.5 bg-primary text-white border-none rounded-xl font-semibold cursor-pointer">Initialize Default Badges</button>
              </div>
            )}
          </div>
        )}

        {activeTab === 'rewards' && (
          <div className="bg-white rounded-[20px] shadow-[0_2px_16px_rgba(0,0,0,0.06)] p-6">
            <div className="flex items-center justify-between mb-6">
              <div>
                <h3 className="font-outfit text-lg font-semibold text-charcoal m-0">Treasury Rewards</h3>
                <p className="text-xs text-muted font-outfit mt-1">Redeemable items in the user reward store</p>
              </div>
              <button
                onClick={() => { setEditingItem(null); setRewardForm({ name: '', description: '', coin_cost: 100, category: 'Voucher', icon: 'voucher', active: true }); setIsModalOpen('rewards'); }}
                className="flex items-center gap-1.5 bg-primary text-white border-none rounded-xl px-5 py-2.5 font-outfit font-semibold text-[13px] cursor-pointer transition-all hover:bg-primary-dark"
              >
                <Plus size={14} /> New Reward
              </button>
            </div>

            <div className="grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-5">
              {filteredRewards.map(r => (
                <div key={r.id} className="border border-cream-darker rounded-[20px] p-5 flex flex-col gap-3 relative">
                  <div className="flex justify-between items-start">
                    <span className="text-2xl">
                      {r.icon?.startsWith('http') ? <img src={r.icon} alt="" className="w-10 h-10 object-contain rounded-md" /> : r.icon === 'voucher' ? '🎫' : r.icon === 'theme' ? '🎨' : r.icon === 'profile' ? '💮' : '🧩'}
                    </span>
                    <div className="flex gap-1">
                      <button onClick={() => openEdit('rewards', r)} className="p-1.5 border-none bg-transparent text-muted cursor-pointer hover:text-primary"><Pencil size={14} /></button>
                      <button onClick={() => handleDelete('rewards', r.id)} className="p-1.5 border-none bg-transparent text-red-400 cursor-pointer hover:text-red-500"><Trash2 size={14} /></button>
                    </div>
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <h4 className="m-0 text-base font-bold text-charcoal">{r.name}</h4>
                      <span className={`text-[9px] font-bold px-1.5 py-0.5 rounded ${r.active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-charcoal-muted'}`}>
                        {r.active ? 'ACTIVE' : 'INACTIVE'}
                      </span>
                    </div>
                    <p className="mt-1 mb-0 text-[11px] text-muted">{r.description}</p>
                  </div>
                  <div className="mt-auto pt-3 border-t border-cream-darker flex justify-between items-center">
                    <span className="text-[10px] font-bold px-2 py-1 rounded-md bg-cream text-charcoal">{r.category}</span>
                    <span className="text-[13px] font-bold text-primary">{r.coin_cost} Coins</span>
                  </div>
                </div>
              ))}
            </div>

            {rewards.length === 0 && !loading.rewards && (
              <div className="text-center border-2 border-dashed border-cream-darker rounded-[20px] p-10">
                <p className="text-sm text-muted mb-5">No rewards mapped in the treasury store.</p>
                <button onClick={handleSeedData} className="px-5 py-2.5 bg-primary text-white border-none rounded-xl font-semibold cursor-pointer">Initialize Default Rewards</button>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Popups */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-black/50 z-[1000] flex items-center justify-center p-5">
          <div className="w-full max-w-[500px] bg-white rounded-[24px] overflow-hidden flex flex-col shadow-[0_20px_40px_rgba(0,0,0,0.1)]">
            <div className="p-6 border-b border-cream-darker flex justify-between items-center">
              <h3 className="m-0 font-outfit text-xl font-semibold">
                {editingItem ? 'Edit' : 'New'} {isModalOpen === 'tasks' ? 'Quest' : isModalOpen === 'badges' ? 'Badge' : 'Reward'}
              </h3>
              <button onClick={() => setIsModalOpen(null)} className="p-2 bg-cream border-none rounded-full cursor-pointer hover:bg-cream-darker"><X size={16} /></button>
            </div>

            <form
              onSubmit={isModalOpen === 'tasks' ? handleSaveTask : isModalOpen === 'badges' ? handleSaveBadge : handleSaveReward}
              className="p-6 flex flex-col gap-4 max-h-[70vh] overflow-y-auto"
            >
              {isModalOpen === 'tasks' && (
                <>
                  <div>
                    <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Quest Title</label>
                    <input className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary" value={taskForm.title} onChange={e => setTaskForm({ ...taskForm, title: e.target.value })} required />
                  </div>
                  <div>
                    <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Description</label>
                    <input className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary" value={taskForm.description} onChange={e => setTaskForm({ ...taskForm, description: e.target.value })} />
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">XP Reward</label>
                      <input type="number" className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary" value={taskForm.xp_reward} onChange={e => setTaskForm({ ...taskForm, xp_reward: parseInt(e.target.value) })} />
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Coin Reward</label>
                      <input type="number" className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary" value={taskForm.coin_reward} onChange={e => setTaskForm({ ...taskForm, coin_reward: parseInt(e.target.value) })} />
                    </div>
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Frequency</label>
                      <select className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary bg-white" value={taskForm.frequency} onChange={e => setTaskForm({ ...taskForm, frequency: e.target.value })}>
                        <option value="daily">Daily</option>
                        <option value="weekly">Weekly</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Task Type</label>
                      <select 
                        className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary bg-white" 
                        value={['mood', 'chat', 'journal', 'meditation'].includes(taskForm.task_type) ? taskForm.task_type : 'custom'} 
                        onChange={e => {
                          if (e.target.value === 'custom') {
                            setTaskForm({ ...taskForm, task_type: '' });
                          } else {
                            setTaskForm({ ...taskForm, task_type: e.target.value });
                          }
                        }}
                      >
                        <option value="mood">Mood Check-In</option>
                        <option value="chat">Chatbot Session</option>
                        <option value="journal">Diary Journal</option>
                        <option value="meditation">Meditation/Breathing</option>
                        <option value="custom">Other (Custom)...</option>
                      </select>
                      {!['mood', 'chat', 'journal', 'meditation'].includes(taskForm.task_type) && (
                        <input 
                          type="text"
                          className="w-full mt-2 px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary bg-white animate-in slide-in-from-top-1 fade-in duration-200" 
                          placeholder="Type custom task type..."
                          value={taskForm.task_type}
                          onChange={e => setTaskForm({ ...taskForm, task_type: e.target.value })}
                          required
                        />
                      )}
                    </div>
                  </div>
                  <div>
                    <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Icon Identifier</label>
                    <div className="flex flex-col gap-2">
                      <select className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary bg-white" value={taskForm.icon} onChange={e => setTaskForm({ ...taskForm, icon: e.target.value })}>
                        <option value="mood">Mood Icon</option>
                        <option value="chat">Chat Icon</option>
                        <option value="journal">Journal Icon</option>
                        <option value="breathing">Breathing Icon</option>
                        {taskForm.icon?.startsWith('http') && <option value={taskForm.icon}>Custom Uploaded Icon</option>}
                      </select>
                      <div className="flex items-center gap-3">
                        <label className="flex-1 cursor-pointer bg-cream hover:bg-cream-darker text-charcoal-muted text-[11px] font-bold py-2 px-3 rounded-lg text-center transition-colors">
                          Upload Custom Icon
                          <input type="file" accept="image/*" onChange={(e) => handleImageUpload(e, setTaskForm)} className="hidden" disabled={uploadingIcon} />
                        </label>
                        {taskForm.icon?.startsWith('http') && <img src={taskForm.icon} alt="Preview" className="w-8 h-8 rounded object-cover border border-cream-darker" />}
                      </div>
                    </div>
                  </div>
                </>
              )}

              {isModalOpen === 'badges' && (
                <>
                  <div>
                    <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Badge Name</label>
                    <input className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary" value={badgeForm.name} onChange={e => setBadgeForm({ ...badgeForm, name: e.target.value })} required />
                  </div>
                  <div>
                    <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Description</label>
                    <input className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary" value={badgeForm.description} onChange={e => setBadgeForm({ ...badgeForm, description: e.target.value })} />
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Icon</label>
                      <div className="flex flex-col gap-2">
                        <select className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary bg-white" value={badgeForm.icon} onChange={e => setBadgeForm({ ...badgeForm, icon: e.target.value })}>
                          <option value="directions_walk_rounded">Walking Icon</option>
                          <option value="calendar_month_rounded">Calendar Icon</option>
                          <option value="local_fire_department_rounded">Fire Icon</option>
                          <option value="psychology_rounded">Psychology Icon</option>
                          {badgeForm.icon?.startsWith('http') && <option value={badgeForm.icon}>Custom Uploaded Icon</option>}
                        </select>
                        <div className="flex items-center gap-3">
                          <label className="flex-1 cursor-pointer bg-cream hover:bg-cream-darker text-charcoal-muted text-[11px] font-bold py-2 px-3 rounded-lg text-center transition-colors">
                            Upload Custom Icon
                            <input type="file" accept="image/*" onChange={(e) => handleImageUpload(e, setBadgeForm)} className="hidden" disabled={uploadingIcon} />
                          </label>
                          {badgeForm.icon?.startsWith('http') && <img src={badgeForm.icon} alt="Preview" className="w-8 h-8 rounded object-cover border border-cream-darker" />}
                        </div>
                      </div>
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Tier</label>
                      <select className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary bg-white" value={badgeForm.tier} onChange={e => setBadgeForm({ ...badgeForm, tier: e.target.value })}>
                        <option value="Novice">Novice</option>
                        <option value="Adept">Adept</option>
                        <option value="Master">Master</option>
                        <option value="Legendary">Legendary</option>
                      </select>
                    </div>
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Condition Type</label>
                      <select className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary bg-white" value={badgeForm.condition_type} onChange={e => setBadgeForm({ ...badgeForm, condition_type: e.target.value })}>
                        <option value="level">Level</option>
                        <option value="streak">Streak Days</option>
                        <option value="xp_total">Total Lifetime XP</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Threshold Value</label>
                      <input type="number" className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary" value={badgeForm.condition_value} onChange={e => setBadgeForm({ ...badgeForm, condition_value: parseInt(e.target.value) })} />
                    </div>
                  </div>
                </>
              )}

              {isModalOpen === 'rewards' && (
                <>
                  <div>
                    <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Reward Name</label>
                    <input className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary" value={rewardForm.name} onChange={e => setRewardForm({ ...rewardForm, name: e.target.value })} required />
                  </div>
                  <div>
                    <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Description</label>
                    <input className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary" value={rewardForm.description} onChange={e => setRewardForm({ ...rewardForm, description: e.target.value })} />
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Coin Cost</label>
                      <input type="number" className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary" value={rewardForm.coin_cost} onChange={e => setRewardForm({ ...rewardForm, coin_cost: parseInt(e.target.value) })} />
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Category</label>
                      <select className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary bg-white" value={rewardForm.category} onChange={e => setRewardForm({ ...rewardForm, category: e.target.value })}>
                        <option value="Voucher">Voucher</option>
                        <option value="Theme">Theme</option>
                        <option value="Avatar">Avatar</option>
                        <option value="Feature">Feature</option>
                      </select>
                    </div>
                  </div>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Icon</label>
                      <div className="flex flex-col gap-2">
                        <select className="w-full px-3.5 py-2.5 border border-cream-darker rounded-xl text-[13px] outline-none focus:border-primary bg-white" value={rewardForm.icon} onChange={e => setRewardForm({ ...rewardForm, icon: e.target.value })}>
                          <option value="voucher">Voucher Icon</option>
                          <option value="theme">Theme Icon</option>
                          <option value="profile">Profile Icon</option>
                          <option value="extension">Extension Icon</option>
                          {rewardForm.icon?.startsWith('http') && <option value={rewardForm.icon}>Custom Uploaded Icon</option>}
                        </select>
                        <div className="flex items-center gap-3">
                          <label className="flex-1 cursor-pointer bg-cream hover:bg-cream-darker text-charcoal-muted text-[11px] font-bold py-2 px-3 rounded-lg text-center transition-colors">
                            Upload Custom Icon
                            <input type="file" accept="image/*" onChange={(e) => handleImageUpload(e, setRewardForm)} className="hidden" disabled={uploadingIcon} />
                          </label>
                          {rewardForm.icon?.startsWith('http') && <img src={rewardForm.icon} alt="Preview" className="w-8 h-8 rounded object-cover border border-cream-darker" />}
                        </div>
                      </div>
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-muted uppercase mb-1.5">Status</label>
                      <div className="flex items-center h-10 gap-2">
                        <input type="checkbox" checked={rewardForm.active} onChange={e => setRewardForm({ ...rewardForm, active: e.target.checked })} />
                        <span className="text-[13px] font-semibold">Active in store</span>
                      </div>
                    </div>
                  </div>
                </>
              )}

              <button
                type="submit"
                disabled={processing}
                className="mt-3 p-3.5 bg-primary text-white border-none rounded-xl font-semibold cursor-pointer transition-colors hover:bg-primary-dark flex items-center justify-center gap-2"
              >
                {processing ? <Loader2 size={16} className="animate-spin" /> : 'Save Changes'}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
