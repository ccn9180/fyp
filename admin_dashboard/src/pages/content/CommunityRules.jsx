import React, { useState, useEffect } from 'react';
import { ShieldCheck, Plus, Pencil, Trash2, Check, X, Loader2, GripVertical } from 'lucide-react';
import { customConfirm } from '../../utils/dialogUtils';
import { db } from '../../firebase';
import { collection, getDocs, doc, addDoc, updateDoc, deleteDoc, query, orderBy } from 'firebase/firestore';

const C = {
  primary: '#7C9C84',
  cream: '#F6F5F2',
  creamDarker: '#E5E4E0',
  charcoal: '#333',
  charcoalMuted: '#666',
  muted: '#888',
  red: '#f87171',
  sage100: '#E5EDE8',
};

export default function CommunityRules() {
  const [rules, setRules] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editingId, setEditingId] = useState(null);
  const [editTitle, setEditTitle] = useState('');
  const [editDesc, setEditDesc] = useState('');
  const [isAdding, setIsAdding] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newDesc, setNewDesc] = useState('');
  const [processing, setProcessing] = useState(false);

  useEffect(() => {
    fetchRules();
  }, []);

  const fetchRules = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, 'community_rules'), orderBy('order', 'asc'));
      const snapshot = await getDocs(q);
      const fetchedRules = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setRules(fetchedRules);
    } catch (error) {
      console.error('Error fetching rules:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleAddRule = async () => {
    if (!newTitle.trim() || !newDesc.trim()) return;
    setProcessing(true);
    try {
      const newOrder = rules.length > 0 ? rules[rules.length - 1].order + 1 : 1;
      const docRef = await addDoc(collection(db, 'community_rules'), {
        title: newTitle,
        description: newDesc,
        order: newOrder,
        createdAt: new Date()
      });
      setRules([...rules, { id: docRef.id, title: newTitle, description: newDesc, order: newOrder }]);
      setNewTitle('');
      setNewDesc('');
      setIsAdding(false);
    } catch (error) {
      console.error('Error adding rule:', error);
    } finally {
      setProcessing(false);
    }
  };

  const startEditing = (rule) => {
    setEditingId(rule.id);
    setEditTitle(rule.title);
    setEditDesc(rule.description);
  };

  const handleSaveEdit = async () => {
    if (!editTitle.trim() || !editDesc.trim()) return;
    setProcessing(true);
    try {
      const ruleRef = doc(db, 'community_rules', editingId);
      await updateDoc(ruleRef, {
        title: editTitle,
        description: editDesc,
        updatedAt: new Date()
      });
      setRules(rules.map(r => r.id === editingId ? { ...r, title: editTitle, description: editDesc } : r));
      setEditingId(null);
    } catch (error) {
      console.error('Error updating rule:', error);
    } finally {
      setProcessing(false);
    }
  };

  const handleDelete = async (id) => {
    const confirmed = await customConfirm('Are you sure you want to delete this rule?', 'Confirm Delete');
    if (!confirmed) return;
    setProcessing(true);
    try {
      await deleteDoc(doc(db, 'community_rules', id));
      setRules(rules.filter(r => r.id !== id));
    } catch (error) {
      console.error('Error deleting rule:', error);
    } finally {
      setProcessing(false);
    }
  };

  if (loading) {
    return (
      <div className="flex flex-col items-center justify-center h-64 gap-4">
        <Loader2 size={32} className="animate-spin text-primary" />
        <p className="text-charcoal-muted font-body">Loading Community Rules...</p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex justify-between items-end">
        <div>
          <h2 className="font-display font-semibold text-2xl text-charcoal">Community Rules</h2>
          <p className="font-body text-sm text-charcoal-muted mt-1">Manage the guidelines for the Eunoia Community Pulse.</p>
        </div>
        <button
          onClick={() => setIsAdding(true)}
          disabled={isAdding}
          className="flex items-center gap-2 px-4 py-2 bg-primary text-white rounded-xl font-bold text-sm shadow-sm transition hover:bg-opacity-90 disabled:opacity-50"
        >
          <Plus size={16} /> Add New Rule
        </button>
      </div>

      <div className="bg-white rounded-2xl border border-creamDarker shadow-sm overflow-hidden">
        <div className="p-6 border-b border-creamDarker bg-cream/30">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-sage-100 flex items-center justify-center text-primary">
              <ShieldCheck size={20} />
            </div>
            <div>
              <h3 className="font-display font-bold text-lg text-charcoal">Official Guidelines</h3>
              <p className="font-body text-xs text-charcoal-muted">Rules displayed to all users before posting.</p>
            </div>
          </div>
        </div>

        <div className="p-6 flex flex-col gap-4">
          {isAdding && (
            <div className="bg-cream/50 p-5 rounded-2xl border border-creamDarker flex flex-col gap-3 animate-in fade-in slide-in-from-top-2">
              <input
                type="text"
                placeholder="Rule Title (e.g., Be Respectful)"
                value={newTitle}
                onChange={(e) => setNewTitle(e.target.value)}
                className="w-full px-4 py-2.5 rounded-xl border border-creamDarker focus:outline-none focus:border-primary font-display font-semibold text-charcoal"
              />
              <textarea
                placeholder="Rule Description..."
                value={newDesc}
                onChange={(e) => setNewDesc(e.target.value)}
                rows={2}
                className="w-full px-4 py-2.5 rounded-xl border border-creamDarker focus:outline-none focus:border-primary font-body text-sm text-charcoal resize-none"
              />
              <div className="flex justify-end gap-2 mt-2">
                <button
                  onClick={() => setIsAdding(false)}
                  disabled={processing}
                  className="px-4 py-2 rounded-xl text-charcoal-muted hover:bg-cream border border-transparent font-bold text-sm transition"
                >
                  Cancel
                </button>
                <button
                  onClick={handleAddRule}
                  disabled={processing || !newTitle.trim() || !newDesc.trim()}
                  className="px-4 py-2 rounded-xl bg-primary text-white font-bold text-sm transition hover:bg-opacity-90 disabled:opacity-50 flex items-center gap-2"
                >
                  {processing ? <Loader2 size={14} className="animate-spin" /> : 'Save Rule'}
                </button>
              </div>
            </div>
          )}

          {rules.length === 0 && !isAdding ? (
            <div className="text-center py-10 opacity-60">
              <ShieldCheck size={32} className="mx-auto text-muted mb-3" />
              <p className="font-body text-sm text-charcoal-muted">No rules defined yet.</p>
            </div>
          ) : (
            rules.map((rule, index) => (
              <div key={rule.id} className="flex gap-4 p-4 rounded-2xl border border-creamDarker bg-white hover:border-primary/30 transition group relative">
                <div className="flex-shrink-0 mt-1 cursor-grab text-creamDarker hover:text-charcoal-muted">
                  <GripVertical size={20} />
                </div>
                <div className="w-8 h-8 rounded-full bg-sage-100 text-primary flex items-center justify-center font-bold text-sm flex-shrink-0">
                  {index + 1}
                </div>
                
                {editingId === rule.id ? (
                  <div className="flex-1 flex flex-col gap-3">
                    <input
                      type="text"
                      value={editTitle}
                      onChange={(e) => setEditTitle(e.target.value)}
                      className="w-full px-3 py-2 rounded-lg border border-creamDarker focus:outline-none focus:border-primary font-display font-semibold"
                    />
                    <textarea
                      value={editDesc}
                      onChange={(e) => setEditDesc(e.target.value)}
                      rows={2}
                      className="w-full px-3 py-2 rounded-lg border border-creamDarker focus:outline-none focus:border-primary font-body text-sm resize-none"
                    />
                    <div className="flex justify-end gap-2">
                      <button onClick={() => setEditingId(null)} disabled={processing} className="p-2 text-muted hover:bg-cream rounded-lg">
                        <X size={16} />
                      </button>
                      <button onClick={handleSaveEdit} disabled={processing} className="p-2 text-primary hover:bg-sage-100 rounded-lg">
                        {processing ? <Loader2 size={16} className="animate-spin" /> : <Check size={16} />}
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="flex-1 flex justify-between items-start">
                    <div>
                      <h4 className="font-display font-semibold text-charcoal text-base">{rule.title}</h4>
                      <p className="font-body text-charcoal-muted text-sm mt-1 leading-relaxed">{rule.description}</p>
                    </div>
                    <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition">
                      <button
                        onClick={() => startEditing(rule)}
                        className="p-2 text-primary hover:bg-sage-100 rounded-lg transition"
                      >
                        <Pencil size={16} />
                      </button>
                      <button
                        onClick={() => handleDelete(rule.id)}
                        className="p-2 text-red-400 hover:bg-red-50 rounded-lg transition"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </div>
                )}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}
