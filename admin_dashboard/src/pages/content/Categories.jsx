import { useState } from 'react';
import { doc, deleteDoc, addDoc, updateDoc, collection, serverTimestamp } from 'firebase/firestore';
import { db } from '../../firebase';
import { useCategories, useArticles, useMeditationGuides } from '../../hooks/useFirestore';
import { Plus, Pencil, Trash2, X, Save, Send, Tag } from 'lucide-react';

const COLOR_PRESETS = [
  { name: 'Blue', color: 'bg-blue-100 text-blue-500' },
  { name: 'Sage', color: 'bg-sage-100 text-primary' },
  { name: 'Purple', color: 'bg-purple-100 text-purple-500' },
  { name: 'Indigo', color: 'bg-indigo-100 text-indigo-500' },
  { name: 'Rose', color: 'bg-rose-100 text-rose-500' },
  { name: 'Amber', color: 'bg-amber-100 text-amber-600' },
];

export default function Categories() {
  const { data: categories, loading: catLoading } = useCategories();
  const { data: articles } = useArticles();
  const { data: guides } = useMeditationGuides();
  
  const [isEditorOpen, setIsEditorOpen] = useState(false);
  const [editingCategory, setEditingCategory] = useState(null);
  const [deleting, setDeleting] = useState(null);

  // Form State
  const [formData, setFormData] = useState({
    name: '',
    color: 'bg-sage-100 text-primary'
  });

  const getArticleCount = (catName) => {
    return articles.filter(a => (a.tag || a.category) === catName).length;
  };

  const getGuideCount = (catName) => {
    return guides.filter(g => g.category === catName).length;
  };

  const handleOpenEditor = (cat = null) => {
    if (cat) {
      setEditingCategory(cat);
      setFormData({
        name: cat.name || '',
        color: cat.color || 'bg-sage-100 text-primary'
      });
    } else {
      setEditingCategory(null);
      setFormData({
        name: '',
        color: 'bg-sage-100 text-primary'
      });
    }
    setIsEditorOpen(true);
  };

  const handleCloseEditor = () => {
    setIsEditorOpen(false);
    setEditingCategory(null);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingCategory) {
        const docRef = doc(db, 'categories', editingCategory.id);
        await updateDoc(docRef, {
          ...formData,
          updatedAt: serverTimestamp()
        });
      } else {
        await addDoc(collection(db, 'categories'), {
          ...formData,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp()
        });
      }
      handleCloseEditor();
    } catch (error) {
      console.error("Error saving category: ", error);
      alert("Failed to save category.");
    }
  };

  const handleDelete = async (id) => {
    if (!window.confirm('Delete this category? Articles and guides using this category will not be deleted but will appear as Uncategorized.')) return;
    setDeleting(id);
    try {
      await deleteDoc(doc(db, 'categories', id));
    } catch (error) {
      console.error("Error deleting category: ", error);
    }
    setDeleting(null);
  };

  return (
    <div className="flex flex-col gap-6 relative">
      <div className="flex items-center justify-between">
        <div>
          <p className="section-label mb-1">Content Management</p>
          <h2 className="font-display font-semibold text-2xl text-charcoal">Categories</h2>
        </div>
        <button 
          onClick={() => handleOpenEditor()}
          className="btn-primary flex items-center gap-2 text-sm"
        >
          <Plus size={15} /> Add Category
        </button>
      </div>

      {catLoading ? (
        <p className="font-body text-sm text-charcoal-muted">Loading categories…</p>
      ) : categories.length === 0 ? (
        <p className="font-body text-sm text-charcoal-muted">No categories found.</p>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {categories.map(c => (
            <div key={c.id} className="card flex flex-col gap-4 hover:shadow-card-hover transition-shadow">
              <div className={`inline-flex items-center px-3 py-1.5 rounded-xl text-xs font-semibold w-fit ${c.color || 'bg-sage-100 text-primary'}`}>
                {c.name}
              </div>
              <div className="flex gap-4">
                <div>
                  <p className="font-display font-semibold text-xl text-charcoal">{getArticleCount(c.name)}</p>
                  <p className="font-body text-xs text-charcoal-muted">Articles</p>
                </div>
                <div className="w-px bg-cream-darker" />
                <div>
                  <p className="font-display font-semibold text-xl text-charcoal">{getGuideCount(c.name)}</p>
                  <p className="font-body text-xs text-charcoal-muted">Guides</p>
                </div>
              </div>
              <div className="flex gap-2 pt-2 border-t border-cream-darker">
                <button 
                  onClick={() => handleOpenEditor(c)}
                  className="flex-1 btn-ghost text-xs py-1.5 flex items-center justify-center gap-1"
                >
                  <Pencil size={12} /> Edit
                </button>
                <button 
                  onClick={() => handleDelete(c.id)}
                  disabled={deleting === c.id}
                  className="p-1.5 rounded-xl hover:bg-red-50 text-charcoal-muted hover:text-red-400 transition"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Slide-over Editor Modal */}
      {isEditorOpen && (
        <div className="fixed inset-0 z-50 flex justify-end bg-black/30 backdrop-blur-[2px]">
          <div className="w-full max-w-md bg-white h-full flex flex-col shadow-2xl animate-in slide-in-from-right duration-300">
            <div className="p-6 border-b border-cream-darker flex items-center justify-between">
              <div>
                <p className="section-label mb-1">{editingCategory ? 'Modify Category' : 'Creation'}</p>
                <h3 className="font-display font-semibold text-xl">{editingCategory ? 'Edit Category' : 'New Category'}</h3>
              </div>
              <button 
                onClick={handleCloseEditor}
                className="p-2 hover:bg-cream rounded-full transition text-charcoal-muted"
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto p-6 space-y-6">
              <div className="space-y-2">
                <label className="section-label flex items-center gap-1.5"><Tag size={12} /> Category Name</label>
                <input 
                  className="input-field" 
                  value={formData.name} 
                  onChange={e => setFormData({...formData, name: e.target.value})} 
                  placeholder="e.g., Mindfulness"
                  required
                />
              </div>

              <div className="space-y-3">
                <label className="section-label">Color Theme</label>
                <div className="grid grid-cols-2 gap-2">
                  {COLOR_PRESETS.map(preset => (
                    <button
                      key={preset.name}
                      type="button"
                      onClick={() => setFormData({...formData, color: preset.color})}
                      className={`flex items-center gap-2 p-2 rounded-xl border-2 transition-all ${
                        formData.color === preset.color ? 'border-primary bg-sage-50' : 'border-transparent bg-cream hover:border-cream-darker'
                      }`}
                    >
                      <div className={`w-4 h-4 rounded-full ${preset.color}`} />
                      <span className="font-body text-xs font-medium">{preset.name}</span>
                    </button>
                  ))}
                </div>
              </div>

              {editingCategory && (
                <div className="p-4 bg-sage-50 rounded-2xl border border-sage-100">
                  <p className="font-body text-xs text-primary font-medium">Stats for {editingCategory.name}</p>
                  <p className="font-body text-xs text-charcoal-muted mt-1">
                    Currently linked to {getArticleCount(editingCategory.name)} articles and {getGuideCount(editingCategory.name)} meditation guides.
                  </p>
                </div>
              )}
            </form>

            <div className="p-6 border-t border-cream-darker flex justify-end gap-3">
              <button 
                type="button"
                onClick={handleCloseEditor}
                className="btn-ghost text-sm py-2 px-6"
              >
                Cancel
              </button>
              <button 
                onClick={handleSubmit}
                className="btn-primary text-sm py-2 px-6 flex items-center gap-2"
              >
                {editingCategory ? <><Save size={16} /> Update</> : <><Send size={16} /> Create</>}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
