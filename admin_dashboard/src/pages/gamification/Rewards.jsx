import { useState, useEffect } from 'react';
import { doc, updateDoc, collection, addDoc } from 'firebase/firestore';
import { db } from '../../firebase';
import { useBadges, useXPRules } from '../../hooks/useFirestore';
import { customAlert } from '../../utils/dialogUtils';

const DEFAULT_XP_ACTIONS = [
  { action: 'Complete a Meditation Session', xp: 20 },
  { action: 'Write a Diary Entry', xp: 15 },
  { action: 'Read an Article', xp: 10 },
  { action: 'Daily Login Streak', xp: 5 },
  { action: 'Complete a Chat Session', xp: 25 },
];

const getBadgeEmoji = (iconName) => {
  switch (iconName?.toLowerCase()) {
    case 'directions_walk':
    case 'directions_walk_rounded':
      return '🚶';
    case 'calendar_month':
    case 'calendar_month_rounded':
      return '📅';
    case 'local_fire_department':
    case 'local_fire_department_rounded':
      return '🔥';
    case 'psychology':
    case 'psychology_rounded':
      return '🧠';
    default:
      return '🌱';
  }
};

export default function Rewards() {
  const { data: dbBadges, loading: badgesLoading } = useBadges();
  const { data: dbActions, loading: actionsLoading } = useXPRules();

  const [badges, setBadges] = useState([]);
  const [actions, setActions] = useState([]);
  const [savingBadges, setSavingBadges] = useState(false);
  const [savingActions, setSavingActions] = useState(false);
  const [seeding, setSeeding] = useState(false);

  useEffect(() => {
    if (dbBadges && dbBadges.length > 0) {
      setBadges(dbBadges);
    }
  }, [dbBadges]);

  useEffect(() => {
    if (dbActions && dbActions.length > 0) {
      setActions(dbActions);
    }
  }, [dbActions]);

  // Auto seed xp_rules if empty
  useEffect(() => {
    const autoSeed = async () => {
      if (dbActions && dbActions.length === 0 && !actionsLoading && !seeding) {
        setSeeding(true);
        try {
          for (const item of DEFAULT_XP_ACTIONS) {
            await addDoc(collection(db, 'xp_rules'), item);
          }
        } catch (error) {
          console.error("Error seeding xp_rules: ", error);
        } finally {
          setSeeding(false);
        }
      }
    };
    autoSeed();
  }, [dbActions, actionsLoading]);

  const updateBadgeValue = (i, val) => {
    setBadges(prev => prev.map((b, idx) => idx === i ? { ...b, condition_value: Number(val) } : b));
  };

  const updateActionXP = (i, val) => {
    setActions(prev => prev.map((a, idx) => idx === i ? { ...a, xp: Number(val) } : a));
  };

  const handleSaveBadges = async () => {
    setSavingBadges(true);
    try {
      for (const badge of badges) {
        if (badge.id) {
          const badgeRef = doc(db, 'badges', badge.id);
          await updateDoc(badgeRef, {
            condition_value: Number(badge.condition_value)
          });
        }
      }
      await customAlert('Badge thresholds updated successfully in the database!', 'Success');
    } catch (error) {
      console.error("Error saving badges: ", error);
      await customAlert('Failed to save badge thresholds.', 'Error');
    } finally {
      setSavingBadges(false);
    }
  };

  const handleSaveActions = async () => {
    setSavingActions(true);
    try {
      for (const action of actions) {
        if (action.id) {
          const actionRef = doc(db, 'xp_rules', action.id);
          await updateDoc(actionRef, {
            xp: Number(action.xp)
          });
        }
      }
      await customAlert('XP action rules updated successfully in the database!', 'Success');
    } catch (error) {
      console.error("Error saving actions: ", error);
      await customAlert('Failed to save XP action rules.', 'Error');
    } finally {
      setSavingActions(false);
    }
  };

  const loading = badgesLoading || actionsLoading || seeding;

  return (
    <div className="flex flex-col gap-6">
      <div>
        <p className="section-label mb-1">Gamification & Rewards</p>
        <h2 className="font-display font-semibold text-2xl text-charcoal">Reward System Settings</h2>
      </div>

      {loading ? (
        <div className="card text-center py-8">
          <p className="font-body text-sm text-charcoal-muted">Loading settings from database…</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {/* Badges Thresholds */}
          <div className="card">
            <p className="section-label mb-1">Badge Thresholds</p>
            <h3 className="font-body font-semibold text-charcoal mb-4">Adjust conditions to unlock each achievement badge</h3>
            <div className="flex flex-col gap-4">
              {badges.map((b, i) => {
                const isLevel = b.condition_type === 'level';
                const isStreak = b.condition_type === 'streak';
                const label = isLevel ? 'Level' : isStreak ? 'Streak Days' : 'XP';
                const min = 1;
                const max = isLevel ? 20 : isStreak ? 30 : 5000;
                const step = isLevel || isStreak ? 1 : 50;

                return (
                  <div key={b.id || i} className="flex items-center gap-3">
                    <span className="text-2xl shrink-0">{getBadgeEmoji(b.icon)}</span>
                    <div className="flex-1">
                      <p className="font-body text-sm font-medium text-charcoal">{b.name} <span className="text-xs text-charcoal-muted">({b.tier})</span></p>
                      <input
                        type="range"
                        min={min}
                        max={max}
                        step={step}
                        value={b.condition_value || 1}
                        onChange={e => updateBadgeValue(i, e.target.value)}
                        className="w-full accent-primary mt-1"
                      />
                    </div>
                    <span className="font-body text-sm font-semibold text-primary w-24 text-right">
                      {b.condition_value || 1} {label}
                    </span>
                  </div>
                );
              })}
              {badges.length === 0 && (
                <p className="text-sm italic text-charcoal-muted text-center py-4">No badges found. Setup badges in Gamification Management.</p>
              )}
            </div>
            {badges.length > 0 && (
              <button 
                onClick={handleSaveBadges} 
                disabled={savingBadges}
                className="btn-primary w-full mt-5 text-sm"
              >
                {savingBadges ? 'Saving Badges…' : 'Save Badge Settings'}
              </button>
            )}
          </div>

          {/* XP per action */}
          <div className="card">
            <p className="section-label mb-1">XP per Action</p>
            <h3 className="font-body font-semibold text-charcoal mb-4">Configure XP earned per user action</h3>
            <div className="flex flex-col gap-4">
              {actions.map((a, i) => (
                <div key={a.id || i} className="flex items-center gap-3 bg-cream rounded-2xl px-4 py-3">
                  <p className="flex-1 font-body text-sm text-charcoal">{a.action}</p>
                  <div className="flex items-center gap-2">
                    <input
                      type="number"
                      min={1}
                      max={200}
                      value={a.xp || 1}
                      onChange={e => updateActionXP(i, e.target.value)}
                      className="w-16 input-field text-center py-1.5 text-sm"
                    />
                    <span className="font-body text-xs text-charcoal-muted">XP</span>
                  </div>
                </div>
              ))}
              {actions.length === 0 && (
                <p className="text-sm italic text-charcoal-muted text-center py-4">No action rules found.</p>
              )}
            </div>
            {actions.length > 0 && (
              <button 
                onClick={handleSaveActions} 
                disabled={savingActions}
                className="btn-primary w-full mt-5 text-sm"
              >
                {savingActions ? 'Saving Actions…' : 'Save XP Settings'}
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
