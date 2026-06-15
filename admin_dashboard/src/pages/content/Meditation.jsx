import { useState, useRef, useEffect } from 'react';
import { doc, deleteDoc, addDoc, updateDoc, collection, serverTimestamp } from 'firebase/firestore';
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import { db, storage } from '../../firebase';
import { useMeditationGuides } from '../../hooks/useFirestore';
import { Plus, Search, Pencil, Trash2, Music, X, Archive, Save, Send, Image as ImageIcon, Clock, PlayCircle, Upload, Loader2, Tag, FileText } from 'lucide-react';
import { customAlert, customConfirm } from '../../utils/dialogUtils';
import Skeleton from '../../components/Skeleton.jsx';

const C = {
  primary: '#7C9C84',
  primaryDark: '#6A8671',
  cream: '#F6F5F2',
  creamDarker: '#E5E4E0',
  sage100: '#E5EDE8',
  charcoal: '#333',
  charcoalMuted: '#666',
  muted: '#888',
  white: '#ffffff',
  error: '#f87171'
};

const card = { background: 'white', borderRadius: '20px', boxShadow: '0 2px 16px rgba(0,0,0,0.06)', padding: '20px' };
const sLabel = { fontFamily: 'Outfit', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.08em', color: C.muted };
const badge = (type) => ({ display: 'inline-flex', padding: '3px 10px', borderRadius: '999px', fontSize: '11px', fontWeight: 700, fontFamily: 'Outfit', background: type === 'green' ? C.sage100 : type === 'gray' ? C.creamDarker : '#fffbeb', color: type === 'green' ? C.primary : type === 'gray' ? C.muted : '#d97706' });

export default function Meditation() {
  const { data: guides, loading } = useMeditationGuides();
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [deleting, setDeleting] = useState(null);
  const [viewingGuide, setViewingGuide] = useState(null);
  const [preloading, setPreloading] = useState(null);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 6;

  const viewWithPreload = (m) => {
    if (preloading) return;
    if (!m.imageUrl) return setViewingGuide(m);
    
    setPreloading(m.id);
    const img = new Image();
    img.src = m.imageUrl;
    img.onload = () => {
      setPreloading(null);
      setViewingGuide(m);
    };
    img.onerror = () => {
      setPreloading(null);
      setViewingGuide(m);
    };
  };
  const [uploadProgress, setUploadProgress] = useState({ imageUrl: 0, audioUrl: 0 });
  const [isUploading, setIsUploading] = useState({ imageUrl: false, audioUrl: false });

  const fileInputRef = useRef(null);
  const audioInputRef = useRef(null);

  const handleFileUpload = (e, targetField) => {
    const file = e.target.files[0];
    if (!file) return;

    if (targetField === 'audioUrl') {
      const audio = new Audio();
      audio.src = URL.createObjectURL(file);
      audio.onloadedmetadata = () => {
        const minutes = Math.ceil(audio.duration / 60);
        setFormData(prev => ({ ...prev, duration: `${minutes} min` }));
        URL.revokeObjectURL(audio.src);
      };
    }

    setIsUploading(prev => ({ ...prev, [targetField]: true }));
    const storageRef = ref(storage, `meditations/${targetField}/${Date.now()}_${file.name}`);
    const uploadTask = uploadBytesResumable(storageRef, file);

    uploadTask.on('state_changed', 
      (snapshot) => {
        const progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        setUploadProgress(prev => ({ ...prev, [targetField]: progress }));
      }, 
      (err) => {
        console.error("Upload error:", err);
        setIsUploading(prev => ({ ...prev, [targetField]: false }));
        customAlert("Upload failed. Verify that you have enabled Firebase Storage and rules.", "Upload Error");
      }, 
      () => {
        getDownloadURL(uploadTask.snapshot.ref).then((downloadURL) => {
          setFormData(prev => ({ ...prev, [targetField]: downloadURL }));
          setIsUploading(prev => ({ ...prev, [targetField]: false }));
          setUploadProgress(prev => ({ ...prev, [targetField]: 0 }));
        });
      }
    );
  };
  const [isEditorOpen, setIsEditorOpen] = useState(false);
  const [editingGuide, setEditingGuide] = useState(null);

  // Form State
  const [formData, setFormData] = useState({
    title: '',
    subtitle: '',
    category: '',
    duration: '',
    imageUrl: '',
    audioUrl: '',
    status: 'draft'
  });

  const filtered = (guides || []).filter(m => {
    const matchesSearch = (m.title || '').toLowerCase().includes(search.toLowerCase()) || 
                          (m.category || '').toLowerCase().includes(search.toLowerCase());
    const matchesCategory = categoryFilter === 'all' || (m.category || '').toLowerCase() === categoryFilter.toLowerCase();
    const matchesStatus = statusFilter === 'all' || (m.status || 'draft').toLowerCase() === statusFilter.toLowerCase();
    
    return matchesSearch && matchesCategory && matchesStatus;
  });

  const totalPages = Math.ceil(filtered.length / itemsPerPage);
  const paginatedItems = filtered.slice(
    (currentPage - 1) * itemsPerPage,
    currentPage * itemsPerPage
  );

  const handleOpenEditor = (guide = null) => {
    if (guide) {
      setEditingGuide(guide);
      setFormData({
        title: guide.title || '',
        subtitle: guide.subtitle || '',
        category: guide.category || '',
        duration: guide.duration || '',
        imageUrl: guide.imageUrl || '',
        audioUrl: guide.audioUrl || '',
        status: guide.status || 'draft'
      });
    } else {
      setEditingGuide(null);
      const savedDraft = localStorage.getItem('meditation_draft');
      if (savedDraft) {
        try {
          setFormData(JSON.parse(savedDraft));
        } catch (e) {
          setFormData({ title: '', subtitle: '', category: '', duration: '', imageUrl: '', audioUrl: '', status: 'draft' });
        }
      } else {
        setFormData({
          title: '', subtitle: '', category: '', duration: '', imageUrl: '', audioUrl: '', status: 'draft'
        });
      }
    }
    setIsEditorOpen(true);
  };

  useEffect(() => {
    if (isEditorOpen && !editingGuide) {
      localStorage.setItem('meditation_draft', JSON.stringify(formData));
    }
  }, [formData, isEditorOpen, editingGuide]);

  const handleCloseEditor = () => {
    setIsEditorOpen(false);
    setEditingGuide(null);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();

    // Form Validation
    if (!formData.title.trim() || !formData.category.trim() || !formData.imageUrl.trim() || !formData.audioUrl.trim() || !formData.duration.trim()) {
      await customAlert("Please fill in all required fields (Title, Category, Duration, Cover Image, and Audio Track).", "Missing Details");
      return;
    }

    // Duration Formatting & Validation
    let finalDuration = formData.duration.toString().trim();
    if (/^\d+$/.test(finalDuration)) {
      finalDuration += ' min';
    } else if (/^\d+\s*m(in)?(s)?$/i.test(finalDuration)) {
      finalDuration = finalDuration.replace(/\s*m(in)?(s)?$/i, ' min');
    }

    if (!/^\d+\s*min$/.test(finalDuration)) {
      await customAlert("Duration must be a number (e.g., '10').", "Invalid Duration");
      return;
    }

    const submissionData = { ...formData, duration: finalDuration };

    // URL Validation
    if (submissionData.imageUrl && !/^https?:\/\//.test(submissionData.imageUrl) && !submissionData.imageUrl.startsWith('blob:') && !submissionData.imageUrl.startsWith('/')) {
        await customAlert("Please provide a valid URL for the Cover Image.", "Invalid URL");
        return;
    }
    if (formData.audioUrl && !/^https?:\/\//.test(formData.audioUrl) && !formData.audioUrl.startsWith('blob:') && !formData.audioUrl.startsWith('/')) {
        await customAlert("Please provide a valid URL for the Audio Track.", "Invalid URL");
        return;
    }

    try {
      if (editingGuide) {
        // Update existing guide
        const docRef = doc(db, 'meditation_guides', editingGuide.id);
        await updateDoc(docRef, {
          ...submissionData,
          updatedAt: serverTimestamp()
        });
      } else {
        // Add new guide
        await addDoc(collection(db, 'meditation_guides'), {
          ...submissionData,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
          clicks: 0,
          plays: 0
        });
        localStorage.removeItem('meditation_draft');
      }
      handleCloseEditor();
      await customAlert("Meditation guide saved successfully!", "Success");
    } catch (error) {
      console.error("Error saving meditation guide: ", error);
      await customAlert("Failed to save guide. View console for details.", "Error");
    }
  };

  const handleDelete = async (id) => {
    const confirmed = await customConfirm('Delete this meditation guide?', 'Confirm Delete');
    if (!confirmed) return;
    setDeleting(id);
    try {
      await deleteDoc(doc(db, 'meditation_guides', id));
    } catch (error) {
      console.error("Error deleting meditation guide: ", error);
    }
    setDeleting(null);
  };

  const handleArchive = async (id, currentStatus) => {
    const isArchiving = currentStatus !== 'archived';
    const confirmed = await customConfirm(
      `Are you sure you want to ${isArchiving ? 'archive' : 'unarchive'} this guide?`, 
      isArchiving ? 'Confirm Archive' : 'Confirm Unarchive'
    );
    if (!confirmed) return;

    const newStatus = isArchiving ? 'archived' : 'draft';
    try {
      await updateDoc(doc(db, 'meditation_guides', id), {
        status: newStatus,
        updatedAt: serverTimestamp()
      });
      await customAlert(`Guide successfully ${isArchiving ? 'archived' : 'unarchived'}.`, 'Success');
    } catch (error) {
      console.error("Error archiving meditation guide: ", error);
      await customAlert(`Failed to update status: ${error.message || error}`, "Error");
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px', position: 'relative' }}>
      <style>
        {`
          @keyframes slideIn {
            from { transform: translateX(100%); }
            to { transform: translateX(0); }
          }
          .form-group { margin-bottom: 20px; }
          .form-label { display: flex; align-items: center; gap: 6px; font-family: 'Outfit', sans-serif; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; color: ${C.muted}; margin-bottom: 8px; }
          .form-input { width: 100%; background: ${C.cream}; border: 1px solid ${C.creamDarker}; border-radius: 12px; padding: 10px 14px; height: 42px; font-family: 'Outfit', sans-serif; font-size: 14px; color: ${C.charcoal}; outline: none; box-sizing: border-box; transition: all 0.2s ease; }
          .form-input:hover { border-color: ${C.primaryLight}; }
          .form-input:focus { border-color: ${C.primary}; box-shadow: 0 0 0 3px ${C.sage100}; background: white; }
          select.form-input { cursor: pointer; appearance: none; background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%234F796B' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'%3E%3C/polyline%3E%3C/svg%3E"); background-repeat: no-repeat; background-position: right 14px center; padding-right: 40px; }
          
          .custom-dropdown {
            padding: 10px 32px 10px 14px;
            border-radius: 12px;
            border: 1px solid ${C.creamDarker};
            background-color: ${C.cream};
            font-family: 'Outfit', sans-serif;
            font-size: 13px;
            color: ${C.charcoal};
            cursor: pointer;
            appearance: none;
            background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%234F796B' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'%3E%3C/polyline%3E%3C/svg%3E");
            background-repeat: no-repeat;
            background-position: right 12px center;
            min-width: 140px;
            transition: all 0.2s ease;
            outline: none;
          }
          .custom-dropdown:hover {
            background-color: #f8faf9;
            border-color: ${C.primaryLight};
          }
          .custom-dropdown:focus {
            background-color: white;
            border-color: ${C.primary};
            box-shadow: 0 0 0 3px ${C.sage100};
          }
          .editor-header { padding: 24px; border-bottom: 1px solid ${C.creamDarker}; display: flex; align-items: center; justify-content: space-between; }
          .editor-content { flex: 1; overflow-y: auto; padding: 24px; }
          .editor-footer { padding: 20px 24px; border-top: 1px solid ${C.creamDarker}; display: flex; justify-content: flex-end; gap: 12px; }
        `}
      </style>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <span style={{ ...sLabel, display: 'block', marginBottom: '4px' }}>Content Management</span>
          <h2 style={{ fontFamily: '"Playfair Display", serif', fontWeight: 600, fontSize: '24px', color: C.charcoal, margin: 0 }}>Meditation Guide</h2>
        </div>
        <button
          onClick={() => handleOpenEditor()}
          style={{ display: 'flex', alignItems: 'center', gap: '6px', background: C.primary, color: 'white', border: 'none', borderRadius: '14px', padding: '10px 18px', fontFamily: 'Outfit', fontWeight: 600, fontSize: '14px', cursor: 'pointer', transition: 'background 0.2s' }}
          onMouseOver={(e) => e.target.style.background = C.primaryDark}
          onMouseOut={(e) => e.target.style.background = C.primary}
        >
          <Plus size={15} /> Upload Guide
        </button>
      </div>

      <div style={card}>
        <div style={{ display: 'flex', gap: '12px', marginBottom: '20px', flexWrap: 'wrap' }}>
          <div style={{ position: 'relative', flex: '1', minWidth: '220px' }}>
            <Search size={14} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: C.muted }} />
            <input
              style={{ width: '100%', background: C.cream, border: `1px solid ${C.creamDarker}`, borderRadius: '12px', padding: '10px 12px 10px 36px', fontFamily: 'Outfit', fontSize: '13px', color: C.charcoal, outline: 'none', boxSizing: 'border-box' }}
              placeholder="Search by title or category…"
              value={search}
              onChange={e => setSearch(e.target.value)}
            />
          </div>
          <select 
            className="custom-dropdown"
            value={categoryFilter}
            onChange={e => setCategoryFilter(e.target.value)}
          >
            <option value="all">All Categories</option>
            <option value="Stress">Stress</option>
            <option value="Sleep">Sleep</option>
            <option value="Focus">Focus</option>
            <option value="Breathing">Breathing</option>
            <option value="Mindfulness">Mindfulness</option>
            <option value="Guided">Guided</option>
          </select>
          <select 
            className="custom-dropdown"
            value={statusFilter}
            onChange={e => setStatusFilter(e.target.value)}
          >
            <option value="all">All Status</option>
            <option value="published">Published</option>
            <option value="draft">Draft</option>
            <option value="archived">Archived</option>
          </select>
        </div>

        {loading ? (
          <div className="flex flex-col gap-3 mt-4">
            {[1, 2, 3, 4].map((i) => (
              <div key={i} className="flex items-center gap-4 py-3 border-b border-cream-darker last:border-none">
                <Skeleton type="rectangle" className="w-9 h-9 shrink-0" />
                <div className="flex flex-col gap-2 flex-1">
                  <Skeleton type="title" className="w-1/3 h-5" />
                </div>
                <Skeleton type="text" className="w-16 h-5" />
                <Skeleton type="text" className="w-16 h-5" />
                <Skeleton type="text" className="w-16 h-5" />
                <Skeleton type="text" className="w-24 h-5" />
                <div className="flex gap-2">
                  <Skeleton type="rectangle" className="w-7 h-7" />
                  <Skeleton type="rectangle" className="w-7 h-7" />
                </div>
              </div>
            ))}
          </div>
        ) : filtered.length === 0 ? (
          <p style={{ fontFamily: 'Outfit', fontSize: '13px', color: C.muted }}>No guides found.</p>
        ) : (
          <>
            <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontFamily: 'Outfit', fontSize: '13px' }}>
              <thead>
                <tr style={{ borderBottom: `1px solid ${C.creamDarker}` }}>
                  {['Title', 'Category', 'Duration', 'Status', 'Metrics', 'Actions'].map(h => (
                    <th key={h} style={{ textAlign: 'left', paddingBottom: '10px', fontWeight: 700, fontSize: '10px', textTransform: 'uppercase', letterSpacing: '0.06em', color: C.muted }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {paginatedItems.map((m, i) => (
                  <tr 
                    key={m.id} 
                    onClick={() => viewWithPreload(m)}
                    style={{ borderBottom: i < paginatedItems.length - 1 ? `1px solid ${C.creamDarker}` : 'none', cursor: 'pointer' }} 
                    className="hover:bg-cream transition-colors group"
                  >
                    <td style={{ padding: '12px 0', color: C.charcoal }} className="group-hover:text-primary transition-colors">
                      <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                        <div style={{ 
                          width: '36px', height: '36px', borderRadius: '10px', backgroundColor: C.sage100, 
                          display: 'flex', alignItems: 'center', justifyContent: 'center', 
                          overflow: 'hidden', border: `1px solid ${C.creamDarker}`, flexShrink: 0
                        }}>
                          {m.imageUrl ? (
                            <img src={m.imageUrl} alt="" style={{ width: '100%', height: '100%', objectCover: 'cover' }} />
                          ) : (
                            <span style={{ fontSize: '12px', fontWeight: 800, color: C.primary }}>
                              {(m.title || '?').charAt(0).toUpperCase()}
                            </span>
                          )}
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
                          <span style={{ fontWeight: 600, maxWidth: '240px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {m.title || 'Untitled'}
                          </span>
                          {preloading === m.id && (
                            <div style={{ display: 'flex', alignItems: 'center', gap: '4px', fontSize: '10px', color: C.primary }}>
                              <Loader2 size={10} className="animate-spin" /> <span>Preloading Content...</span>
                            </div>
                          )}
                        </div>
                      </div>
                    </td>
                    <td style={{ padding: '12px 0' }}>
                      <span style={badge('green')}>{m.category || 'Focus'}</span>
                    </td>
                    <td style={{ padding: '12px 0', color: C.charcoalMuted, fontWeight: 500 }}>{m.duration}</td>
                    <td style={{ padding: '12px 0' }}>
                      <span style={badge((m.status || '').toLowerCase() === 'published' ? 'green' : (m.status || '').toLowerCase() === 'archived' ? 'gray' : 'amber')}>
                        {m.status ? m.status.charAt(0).toUpperCase() + m.status.slice(1) : 'Draft'}
                      </span>
                    </td>
                    <td style={{ padding: '12px 0' }}>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '1px' }}>
                        <span style={{ fontSize: '11px', color: C.charcoalMuted, fontWeight: 600 }}>{(m.plays || 0).toLocaleString()} <span style={{ color: C.muted, fontWeight: 400 }}>plays</span></span>
                        <span style={{ fontSize: '11px', color: '#eab308' }}>★ {m.rating?.toFixed(1) || '0.0'}</span>
                      </div>
                    </td>
                    <td style={{ padding: '12px 0' }}>
                      <div style={{ display: 'flex', gap: '4px' }} onClick={e => e.stopPropagation()}>
                        <button 
                          onClick={() => handleOpenEditor(m)}
                          style={{ padding: '6px', border: 'none', background: C.cream, borderRadius: '8px', cursor: 'pointer', color: C.muted }}
                        >
                          <Pencil size={14} />
                        </button>
                        <button 
                          onClick={() => handleArchive(m.id, m.status)}
                          style={{ padding: '6px', border: 'none', background: C.cream, borderRadius: '8px', cursor: 'pointer', color: m.status === 'archived' ? C.primary : C.muted }}
                          title={m.status === 'archived' ? "Unarchive" : "Archive"}
                        >
                          <Archive size={14} />
                        </button>
                        <button
                          onClick={() => handleDelete(m.id)}
                          disabled={deleting === m.id}
                          style={{ padding: '6px', border: 'none', background: '#fef2f2', borderRadius: '8px', cursor: 'pointer', color: '#f87171' }}
                        >
                          {deleting === m.id ? <Loader2 size={14} className="animate-spin" /> : <Trash2 size={14} />}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Pagination UI */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: '24px', padding: '0 4px' }}>
            <p style={{ fontFamily: 'Outfit', fontSize: '12px', color: C.muted, fontWeight: 500 }}>
              Showing {paginatedItems.length} of {filtered.length} guides
            </p>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <button 
                disabled={currentPage === 1}
                onClick={() => setCurrentPage(prev => prev - 1)}
                style={{ padding: '6px 14px', borderRadius: '10px', border: `1px solid ${C.creamDarker}`, background: 'white', fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.charcoal, cursor: currentPage === 1 ? 'default' : 'pointer', opacity: currentPage === 1 ? 0.4 : 1 }}
              >
                Previous
              </button>
              {[...Array(totalPages)].map((_, i) => (
                <button 
                  key={i}
                  onClick={() => setCurrentPage(i + 1)}
                  style={{ width: '32px', height: '32px', borderRadius: '10px', border: currentPage === i + 1 ? `1px solid ${C.primary}` : `1px solid ${C.creamDarker}`, background: currentPage === i + 1 ? C.primary : 'white', fontFamily: 'Outfit', fontSize: '12px', fontWeight: 700, color: currentPage === i + 1 ? 'white' : C.charcoal, cursor: 'pointer' }}
                >
                  {i + 1}
                </button>
              ))}
              <button 
                disabled={currentPage === totalPages || totalPages === 0}
                onClick={() => setCurrentPage(prev => prev + 1)}
                style={{ padding: '6px 14px', borderRadius: '10px', border: `1px solid ${C.creamDarker}`, background: 'white', fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.charcoal, cursor: (currentPage === totalPages || totalPages === 0) ? 'default' : 'pointer', opacity: (currentPage === totalPages || totalPages === 0) ? 0.4 : 1 }}
              >
                Next
              </button>
            </div>
          </div>
          </>
        )}
      </div>

      {/* Meditation Preview Modal */}
      {viewingGuide && (
        <div 
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)', backdropFilter: 'blur(8px)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px' }}
          onClick={() => setViewingGuide(null)}
        >
          <div 
            style={{ width: '100%', maxWidth: '600px', background: 'white', borderRadius: '32px', overflow: 'hidden', boxShadow: '0 30px 60px rgba(0,0,0,0.15)' }}
            onClick={e => e.stopPropagation()}
          >
            <div style={{ padding: '0', position: 'relative' }}>
               {viewingGuide.imageUrl && (
                 <img src={viewingGuide.imageUrl} style={{ width: '100%', height: '300px', objectFit: 'cover' }} alt="Cover" />
               )}
               <button onClick={() => setViewingGuide(null)} style={{ position: 'absolute', top: '20px', right: '20px', padding: '10px', background: 'rgba(255,255,255,0.8)', border: 'none', borderRadius: '50%', cursor: 'pointer', backdropFilter: 'blur(4px)' }}>
                 <X size={20} />
               </button>
            </div>
            
            <div style={{ padding: '32px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '24px' }}>
                <div style={{ flex: 1 }}>
                  <span style={badge('green')}>{viewingGuide.category}</span>
                  <h3 style={{ fontFamily: 'Playfair Display', fontSize: '28px', margin: '12px 0 8px 0' }}>{viewingGuide.title}</h3>
                  <p style={{ margin: 0, color: C.charcoalMuted, fontSize: '15px' }}>{viewingGuide.subtitle}</p>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '12px', marginBottom: '32px' }}>
                  <div style={{ background: C.cream, padding: '16px', borderRadius: '20px', textAlign: 'center' }}>
                    <p style={{ margin: 0, fontSize: '10px', fontWeight: 700, color: C.muted, textTransform: 'uppercase' }}>Duration</p>
                    <p style={{ margin: '4px 0 0 0', fontSize: '15px', fontWeight: 600 }}>{viewingGuide.duration}</p>
                  </div>
                  <div style={{ background: C.cream, padding: '16px', borderRadius: '20px', textAlign: 'center' }}>
                    <p style={{ margin: 0, fontSize: '10px', fontWeight: 700, color: C.muted, textTransform: 'uppercase' }}>Plays</p>
                    <p style={{ margin: '4px 0 0 0', fontSize: '15px', fontWeight: 600 }}>{viewingGuide.plays || 0}</p>
                  </div>
                  <div style={{ background: C.cream, padding: '16px', borderRadius: '20px', textAlign: 'center' }}>
                    <p style={{ margin: 0, fontSize: '10px', fontWeight: 700, color: C.muted, textTransform: 'uppercase' }}>Rating</p>
                    <p style={{ margin: '4px 0 0 0', fontSize: '15px', fontWeight: 600 }}>{viewingGuide.rating?.toFixed(1) || '0.0'}</p>
                  </div>
              </div>

              <div style={{ display: 'flex', gap: '12px' }}>
                 <button onClick={() => { setViewingGuide(null); handleOpenEditor(viewingGuide); }} style={{ flex: 1, padding: '16px', background: C.primary, color: 'white', border: 'none', borderRadius: '16px', fontWeight: 600, cursor: 'pointer' }}>Edit Guide</button>
                 <button onClick={() => setViewingGuide(null)} style={{ padding: '16px 24px', background: C.cream, color: C.charcoal, border: 'none', borderRadius: '16px', fontWeight: 600, cursor: 'pointer' }}>Close</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Slide-over Editor Modal */}
      {isEditorOpen && (
        <div style={{
          position: 'fixed',
          top: 0,
          right: 0,
          bottom: 0,
          left: 0,
          zIndex: 100,
          display: 'flex',
          justifyContent: 'flex-end',
          background: 'rgba(0,0,0,0.3)',
          backdropFilter: 'blur(2px)'
        }}>
          <div
            style={{
              width: '100%',
              maxWidth: '500px',
              background: 'white',
              height: '100%',
              display: 'flex',
              flexDirection: 'column',
              boxShadow: '-4px 0 24px rgba(0,0,0,0.1)',
              animation: 'slideIn 0.3s ease-out'
            }}
          >
            <div className="editor-header">
              <div>
                <span style={sLabel}>{editingGuide ? 'Editing Guide' : 'Creation'}</span>
                <h3 style={{ margin: 0, fontFamily: 'Playfair Display', fontSize: '20px', fontWeight: 600 }}>{editingGuide ? 'Edit Guide' : 'Upload Guide'}</h3>
              </div>
              <button
                onClick={handleCloseEditor}
                style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '8px', color: C.muted }}
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="editor-content">
              <div className="form-group">
                <label className="form-label"><FileText size={12} /> Guide Title</label>
                <input
                  className="form-input"
                  value={formData.title}
                  onChange={e => setFormData({ ...formData, title: e.target.value })}
                  onBlur={e => {
                    const toTitleCase = (str) => str.replace(/\w\S*/g, (txt) => txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase());
                    setFormData({ ...formData, title: toTitleCase(e.target.value) });
                  }}
                  placeholder="e.g., Forest Breathing"
                  required
                />
              </div>

              <div className="form-group">
                <label className="form-label"><FileText size={12} /> Subtitle / Description</label>
                <input
                  className="form-input"
                  value={formData.subtitle}
                  onChange={e => setFormData({ ...formData, subtitle: e.target.value })}
                  placeholder="e.g., Deep focus and calm..."
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div className="form-group">
                  <label className="form-label"><Tag size={12} /> Category</label>
                  <select
                    className="form-input"
                    value={formData.category}
                    onChange={e => setFormData({ ...formData, category: e.target.value })}
                    required
                  >
                    <option value="" disabled>Select a category</option>
                    <option value="Stress">Stress</option>
                    <option value="Sleep">Sleep</option>
                    <option value="Focus">Focus</option>
                    <option value="Breathing">Breathing</option>
                    <option value="Mindfulness">Mindfulness</option>
                    <option value="Guided">Guided</option>
                  </select>
                </div>
                <div className="form-group">
                  <label className="form-label"><Clock size={12} /> Duration</label>
                  <input
                    className="form-input"
                    value={formData.duration}
                    onChange={e => setFormData({ ...formData, duration: e.target.value })}
                    placeholder="e.g., 6 min"
                    required
                  />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label"><ImageIcon size={12} /> Cover Image <span style={{color: 'red'}}>*</span></label>
                <input 
                  type="file" 
                  hidden 
                  ref={fileInputRef} 
                  accept="image/*"
                  onChange={(e) => handleFileUpload(e, 'imageUrl')} 
                />
                <div 
                  onClick={() => !isUploading.imageUrl && fileInputRef.current.click()}
                  onDragOver={(e) => { e.preventDefault(); e.currentTarget.style.borderColor = C.primary; }}
                  onDragLeave={(e) => { e.preventDefault(); e.currentTarget.style.borderColor = formData.imageUrl ? 'none' : `2px dashed ${C.primaryLight}`; }}
                  onDrop={(e) => {
                    e.preventDefault();
                    e.currentTarget.style.borderColor = formData.imageUrl ? 'none' : `2px dashed ${C.primaryLight}`;
                    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
                      handleFileUpload({ target: { files: e.dataTransfer.files } }, 'imageUrl');
                    }
                  }}
                  style={{
                    width: '100%',
                    height: '200px',
                    borderRadius: '16px',
                    border: formData.imageUrl ? 'none' : `2px dashed ${C.primaryLight}`,
                    background: formData.imageUrl ? 'transparent' : '#f8faf9',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                    cursor: isUploading.imageUrl ? 'not-allowed' : 'pointer',
                    transition: 'all 0.2s ease',
                    position: 'relative',
                    overflow: 'hidden',
                    boxShadow: formData.imageUrl ? '0 4px 12px rgba(0,0,0,0.05)' : 'none'
                  }}
                >
                  {isUploading.imageUrl ? (
                     <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px' }}>
                       <Loader2 size={24} className="animate-spin" style={{ color: C.primary }} />
                       <span style={{ fontSize: '12px', fontFamily: 'Outfit', color: C.primary, fontWeight: 600 }}>Uploading... {Math.round(uploadProgress.imageUrl || 0)}%</span>
                     </div>
                  ) : formData.imageUrl ? (
                     <>
                       <img src={formData.imageUrl} alt="Cover" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                       <div 
                         style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', opacity: 0, transition: 'opacity 0.2s' }} 
                         onMouseOver={e => e.currentTarget.style.opacity = 1} 
                         onMouseOut={e => e.currentTarget.style.opacity = 0}
                       >
                         <div style={{ background: 'white', padding: '8px 16px', borderRadius: '20px', display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px', fontWeight: 600, color: C.charcoal }}>
                           <Upload size={14} /> Change Image
                         </div>
                       </div>
                     </>
                  ) : (
                     <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px', color: C.muted }}>
                       <div style={{ width: '48px', height: '48px', borderRadius: '50%', background: C.sage100, display: 'flex', alignItems: 'center', justifyContent: 'center', color: C.primary }}>
                         <Upload size={20} />
                       </div>
                       <div style={{ textAlign: 'center' }}>
                         <p style={{ margin: 0, fontSize: '14px', fontWeight: 600, color: C.charcoal }}>Click to upload cover image</p>
                         <p style={{ margin: '4px 0 0 0', fontSize: '12px' }}>PNG, JPG or GIF (max. 5MB)</p>
                       </div>
                     </div>
                  )}
                </div>
              </div>

              <div className="form-group">
                <label className="form-label"><PlayCircle size={12} /> Audio Track</label>
                <div 
                  style={{ display: 'flex', gap: '8px', padding: '10px', border: `2px dashed ${isUploading.audioUrl ? 'transparent' : C.primaryLight}`, borderRadius: '12px', background: isUploading.audioUrl ? 'transparent' : '#f8faf9', transition: 'all 0.2s', position: 'relative' }}
                  onDragOver={(e) => { e.preventDefault(); e.currentTarget.style.borderColor = C.primary; }}
                  onDragLeave={(e) => { e.preventDefault(); e.currentTarget.style.borderColor = `2px dashed ${C.primaryLight}`; }}
                  onDrop={(e) => {
                    e.preventDefault();
                    e.currentTarget.style.borderColor = `2px dashed ${C.primaryLight}`;
                    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
                      handleFileUpload({ target: { files: e.dataTransfer.files } }, 'audioUrl');
                    }
                  }}
                >
                  <input
                    className="form-input"
                    value={formData.audioUrl}
                    onChange={e => setFormData({ ...formData, audioUrl: e.target.value })}
                    placeholder="Enter audio URL or drop file here..."
                    style={{ flex: 1, border: 'none', background: 'transparent', padding: '0 4px', height: 'auto' }}
                  />
                  <input 
                    type="file" 
                    hidden 
                    ref={audioInputRef} 
                    accept="audio/*"
                    onChange={(e) => handleFileUpload(e, 'audioUrl')} 
                  />
                  <button 
                    type="button"
                    onClick={() => audioInputRef.current.click()}
                    disabled={isUploading.audioUrl}
                    style={{ padding: '8px 16px', borderRadius: '8px', border: `1px solid ${C.creamDarker}`, background: 'white', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '6px', fontWeight: 600, color: C.charcoal }}
                  >
                    {isUploading.audioUrl ? <Loader2 size={16} className="animate-spin" /> : <Upload size={16} />} Upload
                  </button>
                </div>
                {uploadProgress.audioUrl > 0 && <div style={{ height: '4px', background: C.sage100, borderRadius: '2px', marginTop: '4px' }}><div style={{ height: '100%', width: `${uploadProgress.audioUrl}%`, background: C.primary, borderRadius: '2px', transition: 'width 0.3s' }}></div></div>}
                
                {formData.audioUrl && !isUploading.audioUrl && (
                  <audio controls src={formData.audioUrl} style={{ width: '100%', marginTop: '12px', height: '40px', outline: 'none' }} />
                )}
              </div>

              <div className="form-group">
                <label className="form-label"><Send size={12} /> Status</label>
                <select
                  className="form-input"
                  value={formData.status}
                  onChange={e => setFormData({ ...formData, status: e.target.value })}
                >
                  <option value="draft">Draft (Hidden from App)</option>
                  <option value="published">Published (Live in App)</option>
                  <option value="archived">Archived (Hidden from App)</option>
                </select>
              </div>
            </form>

            <div className="editor-footer">
              <button
                onClick={handleCloseEditor}
                style={{ padding: '10px 20px', background: 'transparent', border: `1px solid ${C.creamDarker}`, borderRadius: '12px', fontFamily: 'Outfit', fontWeight: 600, color: C.charcoalMuted, cursor: 'pointer' }}
              >
                Cancel
              </button>
              <button
                onClick={handleSubmit}
                style={{ 
                  display: 'flex', 
                  alignItems: 'center', 
                  gap: '8px', 
                  padding: '10px 24px', 
                  background: C.primary, 
                  color: 'white', 
                  border: 'none', 
                  borderRadius: '12px', 
                  fontFamily: 'Outfit', 
                  fontWeight: 600, 
                  cursor: 'pointer', 
                  boxShadow: '0 4px 12px rgba(124, 156, 132, 0.3)',
                  transition: 'all 0.2s ease'
                }}
                onMouseOver={(e) => {
                  e.currentTarget.style.background = C.primaryDark;
                  e.currentTarget.style.transform = 'translateY(-1px)';
                  e.currentTarget.style.boxShadow = '0 6px 16px rgba(124, 156, 132, 0.4)';
                }}
                onMouseOut={(e) => {
                  e.currentTarget.style.background = C.primary;
                  e.currentTarget.style.transform = 'translateY(0)';
                  e.currentTarget.style.boxShadow = '0 4px 12px rgba(124, 156, 132, 0.3)';
                }}
              >
                {editingGuide ? <><Save size={16} /> Update Guide</> : <><Send size={16} /> Upload Guide</>}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Styles for animation */}
      <style>{`
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
        .animate-spin {
          animation: spin 1s linear infinite;
        }
      `}</style>
    </div>
  );
}
