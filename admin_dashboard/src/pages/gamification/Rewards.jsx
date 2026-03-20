import { useState } from 'react';

const BADGES = [
  { name: 'Beginner Meditator', xp: 100, icon: '🌱' },
  { name: 'Mindful Week', xp: 250, icon: '🍃' },
  { name: 'Streak Master', xp: 500, icon: '🔥' },
  { name: 'Wellness Sage', xp: 1000, icon: '🧘' },
  { name: 'Eunoia Champion', xp: 2000, icon: '🏆' },
];

const XP_ACTIONS = [
  { action: 'Complete a Meditation Session', xp: 20 },
  { action: 'Write a Diary Entry', xp: 15 },
  { action: 'Read an Article', xp: 10 },
  { action: 'Daily Login Streak', xp: 5 },
  { action: 'Complete a Chat Session', xp: 25 },
];

export default function Rewards() {
  const [badges, setBadges] = useState(BADGES);
  const [actions, setActions] = useState(XP_ACTIONS);

  const updateBadgeXP = (i, val) => {
    setBadges(prev => prev.map((b, idx) => idx === i ? { ...b, xp: Number(val) } : b));
  };
  const updateActionXP = (i, val) => {
    setActions(prev => prev.map((a, idx) => idx === i ? { ...a, xp: Number(val) } : a));
  };

  return (
    <div className="flex flex-col gap-6">
      <div>
        <p className="section-label mb-1">Gamification & Rewards</p>
        <h2 className="font-display font-semibold text-2xl text-charcoal">Reward System</h2>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        {/* Badges */}
        <div className="card">
          <p className="section-label mb-1">Badge Thresholds</p>
          <h3 className="font-body font-semibold text-charcoal mb-4">Adjust XP to unlock each badge</h3>
          <div className="flex flex-col gap-4">
            {badges.map((b, i) => (
              <div key={i} className="flex items-center gap-3">
                <span className="text-2xl shrink-0">{b.icon}</span>
                <div className="flex-1">
                  <p className="font-body text-sm font-medium text-charcoal">{b.name}</p>
                  <input
                    type="range"
                    min={50}
                    max={5000}
                    step={50}
                    value={b.xp}
                    onChange={e => updateBadgeXP(i, e.target.value)}
                    className="w-full accent-primary mt-1"
                  />
                </div>
                <span className="font-body text-sm font-semibold text-primary w-16 text-right">{b.xp} XP</span>
              </div>
            ))}
          </div>
          <button className="btn-primary w-full mt-5 text-sm">Save Badge Settings</button>
        </div>

        {/* XP per action */}
        <div className="card">
          <p className="section-label mb-1">XP per Action</p>
          <h3 className="font-body font-semibold text-charcoal mb-4">Configure XP earned per user action</h3>
          <div className="flex flex-col gap-4">
            {actions.map((a, i) => (
              <div key={i} className="flex items-center gap-3 bg-cream rounded-2xl px-4 py-3">
                <p className="flex-1 font-body text-sm text-charcoal">{a.action}</p>
                <div className="flex items-center gap-2">
                  <input
                    type="number"
                    min={1}
                    max={100}
                    value={a.xp}
                    onChange={e => updateActionXP(i, e.target.value)}
                    className="w-16 input-field text-center py-1.5 text-sm"
                  />
                  <span className="font-body text-xs text-charcoal-muted">XP</span>
                </div>
              </div>
            ))}
          </div>
          <button className="btn-primary w-full mt-5 text-sm">Save XP Settings</button>
        </div>
      </div>
    </div>
  );
}
