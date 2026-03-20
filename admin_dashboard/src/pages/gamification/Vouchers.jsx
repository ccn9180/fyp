import { useState } from 'react';
import { doc, deleteDoc, addDoc, collection, serverTimestamp } from 'firebase/firestore';
import { db } from '../../firebase';
import { useVouchers } from '../../hooks/useFirestore';
import { Plus, Trash2, Copy, X, Send, Ticket } from 'lucide-react';

export default function Vouchers() {
  const { data: vouchers, loading } = useVouchers();
  const [isEditorOpen, setIsEditorOpen] = useState(false);
  const [deleting, setDeleting] = useState(null);

  // Form State
  const [formData, setFormData] = useState({
    code: '',
    discount: '',
    total: 50,
    used: 0,
    expires: '',
    status: 'Active'
  });

  const handleOpenEditor = () => {
    setFormData({
      code: '',
      discount: '',
      total: 50,
      used: 0,
      expires: '',
      status: 'Active'
    });
    setIsEditorOpen(true);
  };

  const handleCloseEditor = () => setIsEditorOpen(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      await addDoc(collection(db, 'vouchers'), {
        ...formData,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp()
      });
      handleCloseEditor();
    } catch (error) {
      console.error("Error creating voucher: ", error);
      alert("Failed to create voucher.");
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this voucher code?')) return;
    setDeleting(id);
    try {
      await deleteDoc(doc(db, 'vouchers', id));
    } catch (error) {
      console.error("Error deleting voucher: ", error);
    }
    setDeleting(null);
  };

  const copyToClipboard = (text) => {
    navigator.clipboard.writeText(text);
    alert('Code copied to clipboard!');
  };

  return (
    <div className="flex flex-col gap-6 relative">
      <div className="flex items-center justify-between">
        <div>
          <p className="section-label mb-1">Gamification & Rewards</p>
          <h2 className="font-display font-semibold text-2xl text-charcoal">Voucher Codes</h2>
        </div>
        <button 
          onClick={handleOpenEditor}
          className="btn-primary flex items-center gap-2 text-sm"
        >
          <Plus size={15} /> Create Voucher
        </button>
      </div>

      {loading ? (
        <p className="font-body text-sm text-charcoal-muted">Loading vouchers…</p>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="card text-center">
              <p className="section-label mb-2">Total Vouchers</p>
              <p className="font-display font-semibold text-3xl text-charcoal">{vouchers.length}</p>
            </div>
            <div className="card text-center">
              <p className="section-label mb-2">Active</p>
              <p className="font-display font-semibold text-3xl text-primary">
                {vouchers.filter(v => v.status === 'Active').length}
              </p>
            </div>
            <div className="card text-center">
              <p className="section-label mb-2">Total Uses</p>
              <p className="font-display font-semibold text-3xl text-charcoal">
                {vouchers.reduce((s, v) => s + (v.used || 0), 0)}
              </p>
            </div>
          </div>

          <div className="card">
            <div className="overflow-x-auto">
              <table className="w-full font-body text-sm">
                <thead>
                  <tr className="text-left text-charcoal-muted text-xs uppercase tracking-wide border-b border-cream-darker">
                    <th className="pb-2 font-semibold">Code</th>
                    <th className="pb-2 font-semibold">Discount</th>
                    <th className="pb-2 font-semibold">Used / Total</th>
                    <th className="pb-2 font-semibold">Expires</th>
                    <th className="pb-2 font-semibold">Status</th>
                    <th className="pb-2 font-semibold">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {vouchers.map((v) => {
                    const used = v.used || 0;
                    const total = v.total || 1;
                    const percent = (used / total) * 100;
                    const isExhausted = used >= total;
                    
                    return (
                      <tr key={v.id} className="border-b border-cream-darker last:border-0 hover:bg-cream transition">
                        <td className="py-3 pr-4">
                          <span className="font-mono font-bold text-primary bg-sage-100 rounded-xl px-2.5 py-1 text-xs">{v.code}</span>
                        </td>
                        <td className="py-3 font-semibold text-charcoal">{v.discount}</td>
                        <td className="py-3 text-charcoal-muted pr-4">
                          <div className="flex items-center gap-2">
                            <span className="shrink-0">{used}/{total}</span>
                            <div className="w-full max-w-[80px] h-1.5 rounded-full bg-cream-darker overflow-hidden">
                              <div className="h-full bg-primary rounded-full transition-all" style={{ width: `${percent}%` }} />
                            </div>
                          </div>
                        </td>
                        <td className="py-3 text-charcoal-muted">{v.expires || 'No expiry'}</td>
                        <td className="py-3">
                          <span className={isExhausted ? 'badge-amber' : v.status === 'Active' ? 'badge-green' : 'badge-amber'}>
                            {isExhausted ? 'Exhausted' : v.status || 'Active'}
                          </span>
                        </td>
                        <td className="py-3">
                          <div className="flex items-center gap-2">
                            <button 
                              onClick={() => copyToClipboard(v.code)}
                              className="p-1.5 rounded-xl hover:bg-sage-100 text-charcoal-muted hover:text-primary transition"
                            >
                              <Copy size={14} />
                            </button>
                            <button 
                              disabled={deleting === v.id}
                              onClick={() => handleDelete(v.id)}
                              className="p-1.5 rounded-xl hover:bg-red-50 text-charcoal-muted hover:text-red-400 transition"
                            >
                              <Trash2 size={14} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                  {vouchers.length === 0 && (
                    <tr>
                      <td colSpan="6" className="py-8 text-center text-charcoal-muted opacity-60 italic">No vouchers created yet.</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </>
      )}

      {/* Slide-over creation modal */}
      {isEditorOpen && (
        <div className="fixed inset-0 z-50 flex justify-end bg-black/30 backdrop-blur-[2px]">
          <div className="w-full max-w-md bg-white h-full flex flex-col shadow-2xl animate-in slide-in-from-right duration-300">
            <div className="p-6 border-b border-cream-darker flex items-center justify-between">
              <div>
                <p className="section-label mb-1">New Voucher</p>
                <h3 className="font-display font-semibold text-xl">Create Promo Code</h3>
              </div>
              <button onClick={handleCloseEditor} className="p-2 hover:bg-cream rounded-full transition text-charcoal-muted">
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto p-6 space-y-5">
              <div className="space-y-2">
                <label className="section-label flex items-center gap-1.5"><Ticket size={12} /> Voucher Code</label>
                <input 
                  className="input-field font-mono uppercase" 
                  value={formData.code} 
                  onChange={e => setFormData({...formData, code: e.target.value.toUpperCase()})} 
                  placeholder="e.g. MIND20"
                  required
                />
              </div>

              <div className="space-y-2">
                <label className="section-label">Discount (e.g. 20%)</label>
                <input 
                  className="input-field" 
                  value={formData.discount} 
                  onChange={e => setFormData({...formData, discount: e.target.value})} 
                  placeholder="e.g. 20% OFF"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <label className="section-label">Total Uses</label>
                  <input 
                    type="number"
                    className="input-field" 
                    value={formData.total} 
                    onChange={e => setFormData({...formData, total: parseInt(e.target.value)})} 
                  />
                </div>
                <div className="space-y-2">
                  <label className="section-label">Initial Uses</label>
                  <input 
                    type="number"
                    className="input-field" 
                    value={formData.used} 
                    onChange={e => setFormData({...formData, used: parseInt(e.target.value)})} 
                  />
                </div>
              </div>

              <div className="space-y-2">
                <label className="section-label">Expiry Date</label>
                <input 
                  type="date"
                  className="input-field" 
                  value={formData.expires} 
                  onChange={e => setFormData({...formData, expires: e.target.value})} 
                />
              </div>
            </form>

            <div className="p-6 border-t border-cream-darker flex justify-end gap-3">
              <button type="button" onClick={handleCloseEditor} className="btn-ghost text-sm py-2 px-6">Cancel</button>
              <button 
                onClick={handleSubmit}
                className="btn-primary text-sm py-2 px-6 flex items-center gap-2"
              >
                <Send size={16} /> Create
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
