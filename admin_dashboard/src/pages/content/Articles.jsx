import { useState, useRef } from 'react';
import { doc, deleteDoc, addDoc, updateDoc, collection, serverTimestamp } from 'firebase/firestore';
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import { db, storage } from '../../firebase';
import { useArticles } from '../../hooks/useFirestore';
import { Plus, Search, Pencil, Trash2, Eye, X, Send, Archive, Save, Image as ImageIcon, User, Clock, FileText, Tag, ChevronDown, Upload, Loader2, Sparkles, FileUp, CheckCircle2, AlertCircle } from 'lucide-react';
import { customAlert, customConfirm } from '../../utils/dialogUtils';
import Skeleton from '../../components/Skeleton.jsx';
import RichTextEditor from '../../components/RichTextEditor.jsx';

const C = {
  primary: 'var(--primary-color, #7C9C84)',
  primaryDark: 'var(--color-primary-dark, #66826D)',
  primaryLight: 'var(--primary-light, #BBCBC2)',
  sage100: 'var(--color-sage-100, #E5EDE8)',
  cream: 'var(--bg-main, #F6F5F2)',
  creamDarker: 'var(--border-color, #E5E4E0)',
  charcoal: 'var(--text-darker, #333)',
  charcoalMuted: 'var(--text-muted, #666)',
  muted: 'var(--text-muted, #888)',
  bgCard: 'var(--bg-card, white)',
  amber: '#d97706',
  blue: '#3b82f6',
  rose: '#f43f5e'
};

const AUTHOR_PRESETS = [
  { name: "Dr. Sarah Jenkins", role: "Clinical Neuropsychologist", img: "https://images.unsplash.com/photo-1544005313-94ddf0286df2" },
  { name: "Marcus Thorne", role: "Sleep Science Specialist", img: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d" },
  { name: "Elena Vance", role: "Mindfulness & Performance Coach", img: "https://images.unsplash.com/photo-1554151228-14d9def656e4" },
  { name: "Dr. Julian Reyes", role: "Nutritional Psychiatrist", img: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e" },
  { name: "Kenji Yamamoto", role: "Behavioral Economist", img: "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e" }
];

const CATEGORY_TEMPLATES = {
  "Science-Backed": "https://images.unsplash.com/photo-1507413245164-6160d8298b31",
  "Mental Health": "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b",
  "Self-Care": "https://images.unsplash.com/photo-1506126613408-eca07ce68773",
  "Anxiety": "https://images.unsplash.com/photo-1474418397713-7ded81cf2000",
  "Productivity": "https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5",
  "Recommend": "https://images.unsplash.com/photo-1484480974693-6ca0a78fb36b"
};

const card = { background: C.bgCard, borderRadius: '20px', boxShadow: '0 2px 16px rgba(0,0,0,0.06)', padding: '20px' };
const sLabel = { fontFamily: 'Outfit', fontSize: '10px', fontWeight: 700, textTransform: 'uppercase', letterSpacing: '0.08em', color: C.muted };
const badge = (type) => ({ display: 'inline-flex', padding: '3px 10px', borderRadius: '999px', fontSize: '11px', fontWeight: 700, fontFamily: 'Outfit', background: type === 'green' ? C.sage100 : type === 'gray' ? C.creamDarker : '#fffbeb', color: type === 'green' ? C.primary : type === 'gray' ? C.muted : '#d97706' });

export default function Articles() {
  const { data: articles, loading } = useArticles();
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [deleting, setDeleting] = useState(null);
  const [isEditorOpen, setIsEditorOpen] = useState(false);
  const [editingArticle, setEditingArticle] = useState(null);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 8;
  
  const [uploadProgress, setUploadProgress] = useState({ imageUrl: 0, authorImageUrl: 0 });
  const [isUploading, setIsUploading] = useState({ imageUrl: false, authorImageUrl: false });
  const [isSummarizing, setIsSummarizing] = useState(false);
  const [isBulkImporting, setIsBulkImporting] = useState(false);
  const [isPreviewMode, setIsPreviewMode] = useState(false);
  const [viewingArticle, setViewingArticle] = useState(null);
  const [preloading, setPreloading] = useState(null);

  const viewWithPreload = (a) => {
    if (preloading) return;
    if (!a.imageUrl) return setViewingArticle(a);
    
    setPreloading(a.id);
    const img = new Image();
    img.src = a.imageUrl;
    img.onload = () => {
      setPreloading(null);
      setViewingArticle(a);
    };
    img.onerror = () => {
      setPreloading(null);
      setViewingArticle(a);
    };
  };
  
  const fileInputRef = useRef(null);
  const importInputRef = useRef(null);
  const authorInputRef = useRef(null);

  const handleFileUpload = (e, targetField) => {
    const file = e.target.files[0];
    if (!file) return;

    setIsUploading(prev => ({ ...prev, [targetField]: true }));
    const storageRef = ref(storage, `articles/${targetField}/${Date.now()}_${file.name}`);
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

  const autoCalculateReadingTime = () => {
    if (!formData.content) return;
    const wordsPerMinute = 200;
    const words = formData.content.trim().split(/\s+/).length;
    const minutes = Math.ceil(words / wordsPerMinute);
    setFormData(prev => ({ ...prev, readingTime: `${minutes} min read` }));
  };

  const autoGenerateSummary = async () => {
    if (!formData.content) {
      await customAlert("Please enter content first to generate a summary.", "Content Required");
      return;
    }
    
    setIsSummarizing(true);
    
    // Simulate AI delay for better UX
    setTimeout(() => {
      // Basic sentence detection and extraction
      const cleanContent = formData.content.replace(/[#*`]/g, '').trim();
      const sentences = cleanContent.match(/[^.!?]+[.!?]+/g) || [cleanContent];
      
      let summary = "";
      if (sentences.length <= 2) {
        summary = sentences.join(" ");
      } else {
        // Take the first 2-3 sentences, but keep it under 180 chars
        summary = sentences.slice(0, 2).join(" ");
        if (summary.length < 100 && sentences[2]) {
          summary += " " + sentences[2];
        }
      }
      
      // Cleanup and truncate if still too long
      if (summary.length > 200) {
        summary = summary.substring(0, 197) + "...";
      }
      
      setFormData(prev => ({ ...prev, subtitle: summary }));
      setIsSummarizing(false);
    }, 800);
  };

  const applyAuthorPreset = (author) => {
    setFormData(prev => ({
      ...prev,
      authorName: author.name,
      authorRole: author.role,
      authorImageUrl: author.img
    }));
  };

  const applyCategoryTemplate = (cat) => {
    if (CATEGORY_TEMPLATES[cat]) {
      setFormData(prev => ({ ...prev, tag: cat, imageUrl: CATEGORY_TEMPLATES[cat] }));
    }
  };



  
  // Form State
  const [formData, setFormData] = useState({
    title: '',
    tag: '',
    subtitle: '',
    content: '',
    imageUrl: '',
    authorName: '',
    authorRole: '',
    authorImageUrl: '',
    readingTime: '',
    sourceLink: '',
    status: 'draft'
  });

  const filtered = (articles || []).filter(a => {
    const matchesSearch = (a.title || '').toLowerCase().includes(search.toLowerCase()) || 
                          (a.tag || '').toLowerCase().includes(search.toLowerCase());
    const matchesCategory = categoryFilter === 'all' || (a.tag || '').toLowerCase() === categoryFilter.toLowerCase();
    const matchesStatus = statusFilter === 'all' || (a.status || 'draft').toLowerCase() === statusFilter.toLowerCase();
    
    return matchesSearch && matchesCategory && matchesStatus;
  });

  // Pagination
  const totalPages = Math.ceil(filtered.length / itemsPerPage);
  const paginatedItems = filtered.slice(
    (currentPage - 1) * itemsPerPage,
    currentPage * itemsPerPage
  );

  const handleOpenEditor = (article = null) => {
    if (article) {
      setEditingArticle(article);
      setFormData({
        title: article.title || '',
        tag: article.tag || '',
        subtitle: article.subtitle || '',
        content: article.content || '',
        imageUrl: article.imageUrl || '',
        authorName: article.authorName || '',
        authorRole: article.authorRole || '',
        authorImageUrl: article.authorImageUrl || '',
        readingTime: article.readingTime || '',
        sourceLink: article.sourceLink || '',
        status: article.status || 'draft'
      });
    } else {
      setEditingArticle(null);
      setFormData({
        title: '',
        tag: '',
        subtitle: '',
        content: '',
        imageUrl: '',
        authorName: '',
        authorRole: '',
        authorImageUrl: '',
        readingTime: '',
        sourceLink: '',
        status: 'draft'
      });
    }
    setIsEditorOpen(true);
  };

  const handleCloseEditor = () => {
    setIsEditorOpen(false);
    setEditingArticle(null);
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    // Form Validation
    if (!formData.title.trim() || !formData.tag.trim() || !formData.content.trim() || !formData.imageUrl.trim()) {
      await customAlert("Please fill in all required fields (Title, Category, Content, and Cover Image).", "Missing Details");
      return;
    }

    // Title Length Validation
    if (formData.title.trim().length > 100) {
      await customAlert("Title is too long. Please keep it under 100 characters.", "Title Too Long");
      return;
    }

    // Reading Time Validation
    if (formData.readingTime && !/^\d+(\s*min\s*read)?$/i.test(formData.readingTime.trim())) {
      await customAlert("Reading time must be a number followed by 'min read' (e.g., '6 min read' or '6').", "Invalid Reading Time");
      return;
    }

    // URL Validation
    if (formData.imageUrl && !/^https?:\/\//.test(formData.imageUrl) && !formData.imageUrl.startsWith('blob:') && !formData.imageUrl.startsWith('/')) {
        await customAlert("Please provide a valid URL for the Cover Image.", "Invalid URL");
        return;
    }

    try {
      let finalData = { ...formData };
      
      // Auto-generate summary if missing
      if (!finalData.subtitle && finalData.content) {
        const cleanContent = finalData.content.replace(/[#*`]/g, '').trim();
        const sentences = cleanContent.match(/[^.!?]+[.!?]+/g) || [cleanContent];
        let summary = sentences.slice(0, 2).join(" ");
        if (summary.length > 200) summary = summary.substring(0, 197) + "...";
        finalData.subtitle = summary;
      }

      if (editingArticle) {
        // Update existing article
        const docRef = doc(db, 'articles', editingArticle.id);
        await updateDoc(docRef, {
          ...finalData,
          updatedAt: serverTimestamp()
        });
        await customAlert("Article successfully updated.", "Success");
      } else {
        // Add new article
        await addDoc(collection(db, 'articles'), {
          ...finalData,
          createdAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
          views: 0,
          clicks: 0,
          rating: 0
        });
        await customAlert("Article successfully published.", "Success");
      }
      handleCloseEditor();
    } catch (error) {
      console.error("Error saving article: ", error);
      await customAlert("Failed to save article. View console for details.", "Error");
    }
  };

  const handleDelete = async (id) => {
    const confirmed = await customConfirm('Delete this article?', 'Confirm Delete');
    if (!confirmed) return;
    setDeleting(id);
    try {
      await deleteDoc(doc(db, 'articles', id));
      await customAlert("Article successfully deleted.", "Success");
    } catch (error) {
      console.error("Error deleting article: ", error);
    }
    setDeleting(null);
  };

  const handleArchive = async (id, currentStatus) => {
    const isArchiving = currentStatus !== 'archived';
    const confirmed = await customConfirm(
      `Are you sure you want to ${isArchiving ? 'archive' : 'unarchive'} this article?`, 
      isArchiving ? 'Confirm Archive' : 'Confirm Unarchive'
    );
    if (!confirmed) return;

    const newStatus = isArchiving ? 'archived' : 'draft';
    try {
      await updateDoc(doc(db, 'articles', id), {
        status: newStatus,
        updatedAt: serverTimestamp()
      });
      await customAlert(`Article successfully ${isArchiving ? 'archived' : 'unarchived'}.`, 'Success');
    } catch (error) {
      console.error("Error archiving article: ", error);
      await customAlert(`Failed to update status: ${error.message || error}`, "Error");
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px', position: 'relative' }}>
      <style>
        {`
          .tab-btn.inactive { background: ${C.cream}; color: ${C.charcoalMuted}; }
          .markdown-preview { font-family: 'Outfit', sans-serif; line-height: 1.6; color: ${C.charcoal}; padding: 10px; }
          .markdown-preview h1, .markdown-preview h2, .markdown-preview h3 { font-family: 'Playfair Display'; margin-top: 1.5em; border-bottom: 1px solid ${C.creamDarker}; padding-bottom: 0.3em; }
          .markdown-preview code { background: ${C.cream}; padding: 2px 5px; border-radius: 4px; }
          
          .form-group { margin-bottom: 20px; }
          .form-label { display: flex; align-items: center; gap: 6px; font-family: 'Outfit', sans-serif; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em; color: ${C.muted}; margin-bottom: 8px; }
          .form-input { width: 100%; background: ${C.cream}; border: 1px solid ${C.creamDarker}; border-radius: 12px; padding: 10px 14px; height: 42px; font-family: 'Outfit', sans-serif; font-size: 14px; color: ${C.charcoal}; outline: none; box-sizing: border-box; transition: all 0.2s ease; }
          .form-input:hover { border-color: ${C.primaryLight}; }
          .form-input:focus { border-color: ${C.primary}; box-shadow: 0 0 0 3px ${C.sage100}; background: transparent; }
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
          <h2 style={{ fontFamily: '"Playfair Display", serif', fontWeight: 600, fontSize: '24px', color: C.charcoal, margin: 0 }}>Article Content</h2>
        </div>
          <button
            onClick={() => handleOpenEditor()}
            style={{ display: 'flex', alignItems: 'center', gap: '6px', background: C.primary, color: 'white', border: 'none', borderRadius: '14px', padding: '10px 18px', fontFamily: 'Outfit', fontWeight: 600, fontSize: '14px', cursor: 'pointer', transition: 'background 0.2s', boxShadow: '0 4px 12px rgba(124, 156, 132, 0.2)' }}
            onMouseOver={(e) => e.target.style.background = C.primaryDark}
            onMouseOut={(e) => e.target.style.background = C.primary}
          >
            <Plus size={15} /> New Article
          </button>
        </div>

      <div style={card}>
        <div style={{ display: 'flex', gap: '12px', marginBottom: '20px', flexWrap: 'wrap' }}>
          <div style={{ position: 'relative', flex: '1', minWidth: '220px' }}>
            <Search size={14} style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: C.muted }} />
            <input
              style={{ width: '100%', background: C.cream, border: `1px solid ${C.creamDarker}`, borderRadius: '12px', padding: '10px 12px 10px 36px', fontFamily: 'Outfit', fontSize: '13px', color: C.charcoal, outline: 'none', boxSizing: 'border-box' }}
              placeholder="Search by title or category..."
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
            <option value="Mental Health">Mental Health</option>
            <option value="Self-Care">Self-Care</option>
            <option value="Science-Backed">Science-Backed</option>
            <option value="Anxiety">Anxiety</option>
            <option value="Productivity">Productivity</option>
          </select>

          <select
            className="custom-dropdown"
            value={statusFilter}
            onChange={e => setStatusFilter(e.target.value)}
          >
            <option value="all">All Status</option>
            <option value="draft">Draft</option>
            <option value="published">Published</option>
            <option value="archived">Archived</option>
          </select>
        </div>
        
        {loading ? (
          <div className="flex flex-col gap-3 mt-4">
            {[1, 2, 3, 4, 5].map((i) => (
              <div key={i} className="flex items-center gap-4 py-3 border-b border-cream-darker last:border-none">
                <Skeleton type="rectangle" className="w-9 h-9 shrink-0" />
                <div className="flex flex-col gap-2 flex-1">
                  <Skeleton type="title" className="w-1/3 h-5" />
                </div>
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
          <p style={{ fontFamily: 'Outfit', fontSize: '13px', color: C.muted }}>No articles found.</p>
        ) : (
          <>
            <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontFamily: 'Outfit', fontSize: '13px' }}>
              <thead>
                <tr style={{ borderBottom: `1px solid ${C.creamDarker}` }}>
                  {['Title', 'Category', 'Status', 'Metrics', 'Actions'].map(h => (
                    <th key={h} style={{ textAlign: 'left', paddingBottom: '10px', fontWeight: 700, fontSize: '10px', textTransform: 'uppercase', letterSpacing: '0.06em', color: C.muted }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {paginatedItems.map((a, i) => (
                  <tr 
                    key={a.id} 
                    onClick={() => viewWithPreload(a)}
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
                          {a.imageUrl ? (
                            <img src={a.imageUrl} alt="" style={{ width: '100%', height: '100%', objectCover: 'cover' }} />
                          ) : (
                            <span style={{ fontSize: '12px', fontWeight: 800, color: C.primary }}>
                              {(a.title || '?').charAt(0).toUpperCase()}
                            </span>
                          )}
                        </div>
                        <div style={{ display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
                          <span style={{ fontWeight: 600, maxWidth: '240px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {a.title || 'Untitled'}
                          </span>
                          {preloading === a.id && (
                            <div style={{ display: 'flex', alignItems: 'center', gap: '4px', fontSize: '10px', color: C.primary }}>
                              <Loader2 size={10} className="animate-spin" /> <span>Preloading Content...</span>
                            </div>
                          )}
                        </div>
                      </div>
                    </td>
                    <td style={{ padding: '12px 0' }}>
                      <span style={badge('green')}>{a.tag || a.category || 'Uncategorized'}</span>
                    </td>
                    <td style={{ padding: '12px 0' }}>
                      <span style={badge((a.status || '').toLowerCase() === 'published' ? 'green' : (a.status || '').toLowerCase() === 'archived' ? 'gray' : 'amber')}>
                        {a.status ? a.status.charAt(0).toUpperCase() + a.status.slice(1) : 'Draft'}
                      </span>
                    </td>
                    <td style={{ padding: '12px 0' }}>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '1px' }}>
                        <span style={{ fontSize: '11px', color: C.charcoalMuted, fontWeight: 600 }}>{(a.views || 0).toLocaleString()} <span style={{ color: C.muted, fontWeight: 400 }}>views</span></span>
                        <span style={{ fontSize: '11px', color: '#eab308' }}>★ {a.rating?.toFixed(1) || '0.0'}</span>
                      </div>
                    </td>
                    <td style={{ padding: '12px 0' }}>
                      <div style={{ display: 'flex', gap: '4px' }} onClick={e => e.stopPropagation()}>
                        <button 
                          onClick={() => handleOpenEditor(a)}
                          style={{ padding: '6px', border: 'none', background: C.cream, borderRadius: '8px', cursor: 'pointer', color: C.muted }}
                        >
                          <Pencil size={14} />
                        </button>
                        <button 
                          onClick={() => handleArchive(a.id, a.status)}
                          style={{ padding: '6px', border: 'none', background: C.cream, borderRadius: '8px', cursor: 'pointer', color: a.status === 'archived' ? C.primary : C.muted }}
                          title={a.status === 'archived' ? "Unarchive" : "Archive"}
                        >
                          <Archive size={14} />
                        </button>
                        <button
                          onClick={() => handleDelete(a.id)}
                          disabled={deleting === a.id}
                          style={{ padding: '6px', border: 'none', background: '#fef2f2', borderRadius: '8px', cursor: 'pointer', color: '#f87171' }}
                        >
                          {deleting === a.id ? <Loader2 size={14} className="animate-spin" /> : <Trash2 size={14} />}
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
              Showing {paginatedItems.length} of {filtered.length} articles
            </p>
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
              <button 
                disabled={currentPage === 1}
                onClick={() => setCurrentPage(prev => prev - 1)}
                style={{ padding: '6px 14px', borderRadius: '10px', border: `1px solid ${C.creamDarker}`, background: C.bgCard, fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.charcoal, cursor: currentPage === 1 ? 'default' : 'pointer', opacity: currentPage === 1 ? 0.4 : 1 }}
              >
                Previous
              </button>
              {[...Array(totalPages)].map((_, i) => (
                <button 
                  key={i}
                  onClick={() => setCurrentPage(i + 1)}
                  style={{ width: '32px', height: '32px', borderRadius: '10px', border: currentPage === i + 1 ? `1px solid ${C.primary}` : `1px solid ${C.creamDarker}`, background: currentPage === i + 1 ? C.primary : 'white', fontFamily: 'Outfit', fontSize: '12px', fontWeight: 700, color: currentPage === i + 1 ? 'white' : C.charcoal, cursor: 'pointer', transition: 'all 0.2s' }}
                >
                  {i + 1}
                </button>
              ))}
              <button 
                disabled={currentPage === totalPages || totalPages === 0}
                onClick={() => setCurrentPage(prev => prev + 1)}
                style={{ padding: '6px 14px', borderRadius: '10px', border: `1px solid ${C.creamDarker}`, background: C.bgCard, fontFamily: 'Outfit', fontSize: '12px', fontWeight: 600, color: C.charcoal, cursor: (currentPage === totalPages || totalPages === 0) ? 'default' : 'pointer', opacity: (currentPage === totalPages || totalPages === 0) ? 0.4 : 1 }}
              >
                Next
              </button>
            </div>
          </div>
        </>
      )}
    </div>

      {/* Article Preview Modal */}
      {viewingArticle && (
        <div 
          style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.4)', backdropFilter: 'blur(8px)', zIndex: 1000, display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '20px' }}
          onClick={() => setViewingArticle(null)}
        >
          <div 
            style={{ width: '100%', maxWidth: '900px', maxHeight: '90vh', background: C.bgCard, borderRadius: '32px', overflow: 'hidden', display: 'flex', flexDirection: 'column', boxShadow: '0 30px 60px rgba(0,0,0,0.15)' }}
            onClick={e => e.stopPropagation()}
          >
            <div style={{ padding: '40px', overflowY: 'auto' }}>
               <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '32px' }}>
                 <div>
                    <span style={badge('green')}>{viewingArticle.tag}</span>
                    <h2 style={{ fontFamily: 'Playfair Display', fontSize: '36px', margin: '16px 0 8px 0', lineHeight: 1.2 }}>{viewingArticle.title}</h2>
                    <p style={{ fontSize: '18px', color: C.charcoalMuted, lineHeight: 1.6, margin: 0 }}>{viewingArticle.subtitle}</p>
                 </div>
                 <button onClick={() => setViewingArticle(null)} style={{ padding: '12px', background: C.cream, border: 'none', borderRadius: '50%', cursor: 'pointer' }}>
                   <X size={24} />
                 </button>
               </div>

               <div style={{ display: 'flex', alignItems: 'center', gap: '16px', padding: '24px', background: C.cream, borderRadius: '24px', marginBottom: '40px' }}>
                 <img src={viewingArticle.authorImageUrl} style={{ width: '56px', height: '56px', borderRadius: '16px', objectFit: 'cover' }} alt="Author" />
                 <div>
                   <p style={{ margin: 0, fontWeight: 700, fontSize: '16px' }}>{viewingArticle.authorName}</p>
                   <p style={{ margin: 0, fontSize: '13px', color: C.muted }}>{viewingArticle.authorRole} · {viewingArticle.readingTime}</p>
                 </div>
               </div>

               {viewingArticle.imageUrl && (
                 <img src={viewingArticle.imageUrl} style={{ width: '100%', height: '400px', borderRadius: '24px', objectFit: 'cover', marginBottom: '40px' }} alt="Article" />
               )}

               <div 
                style={{ fontSize: '17px', lineHeight: 1.9, color: C.charcoal, fontFamily: 'Outfit' }}
                dangerouslySetInnerHTML={{ 
                  __html: /<[a-z][\s\S]*>/i.test(viewingArticle.content) 
                    ? viewingArticle.content 
                    : viewingArticle.content?.replace(/\n/g, '<br/>') 
                }}
               />
            </div>
            <div style={{ padding: '20px 40px', background: C.cream, borderTop: `1px solid ${C.creamDarker}`, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
               <div style={{ display: 'flex', gap: '24px' }}>
                 <div style={{ textAlign: 'center' }}>
                   <p style={{ margin: 0, fontSize: '10px', fontWeight: 700, color: C.muted, textTransform: 'uppercase' }}>Views</p>
                   <p style={{ margin: 0, fontSize: '18px', fontWeight: 600 }}>{viewingArticle.views}</p>
                 </div>
                 <div style={{ textAlign: 'center' }}>
                   <p style={{ margin: 0, fontSize: '10px', fontWeight: 700, color: C.muted, textTransform: 'uppercase' }}>Rating</p>
                   <p style={{ margin: 0, fontSize: '18px', fontWeight: 600 }}>{viewingArticle.rating?.toFixed(1) || '0.0'}</p>
                 </div>
               </div>
               <button onClick={() => { setViewingArticle(null); handleOpenEditor(viewingArticle); }} style={{ padding: '12px 24px', background: C.primary, color: 'white', border: 'none', borderRadius: '14px', fontWeight: 600, cursor: 'pointer' }}>Edit Content</button>
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
              maxWidth: '600px',
              background: C.bgCard,
              height: '100%',
              display: 'flex',
              flexDirection: 'column',
              boxShadow: '-4px 0 24px rgba(0,0,0,0.1)',
              animation: 'slideIn 0.3s ease-out'
            }}
          >
            <div className="editor-header">
              <div style={{ flex: 1 }}>
                <span style={sLabel}>{editingArticle ? 'Editing Article' : 'Creation'}</span>
                <h3 style={{ margin: 0, fontFamily: 'Playfair Display', fontSize: '20px', fontWeight: 600 }}>{editingArticle ? 'Edit Article' : 'New Article'}</h3>
              </div>
              
              <div style={{ background: C.cream, borderRadius: '12px', padding: '4px', display: 'flex', gap: '4px' }}>
                <button 
                  className={`tab-btn ${!isPreviewMode ? 'active' : 'inactive'}`}
                  onClick={() => setIsPreviewMode(false)}
                >
                  Edit
                </button>
                <button 
                  className={`tab-btn ${isPreviewMode ? 'active' : 'inactive'}`}
                  onClick={() => setIsPreviewMode(true)}
                >
                  Preview
                </button>
              </div>

              <button 
                onClick={handleCloseEditor}
                style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '8px', color: C.muted }}
              >
                <X size={20} />
              </button>
            </div>

            <div className="editor-content">
              {!isPreviewMode ? (
                <>
                  <div className="form-group">
                    <label className="form-label"><FileText size={12} /> Title</label>
                    <input 
                      className="form-input" 
                      value={formData.title} 
                      onChange={e => setFormData({...formData, title: e.target.value})} 
                      placeholder="e.g., The Neurobiology of Daily Gratitude"
                      required
                    />
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                    <div className="form-group">
                      <label className="form-label"><Tag size={12} /> Category / Tag</label>
                      <select 
                        className="form-input" 
                        value={formData.tag} 
                        onChange={e => {
                          const val = e.target.value;
                          setFormData({...formData, tag: val});
                          applyCategoryTemplate(val);
                        }} 
                        required
                      >
                        <option value="" disabled>Select a category</option>
                        {Object.keys(CATEGORY_TEMPLATES).map(cat => (
                          <option key={cat} value={cat}>{cat}</option>
                        ))}
                      </select>
                    </div>
                    <div className="form-group">
                      <label className="form-label"><Clock size={12} /> Reading Time</label>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <input 
                          className="form-input" 
                          value={formData.readingTime} 
                          onChange={e => setFormData({...formData, readingTime: e.target.value})} 
                          placeholder="e.g., 6 min read"
                          style={{ flex: 1 }}
                        />
                        <button 
                          type="button"
                          onClick={autoCalculateReadingTime}
                          title="Auto-calculate from content"
                          style={{ padding: '0 15px', borderRadius: '12px', border: `1px solid ${C.creamDarker}`, background: '#f8faf9', cursor: 'pointer', display: 'flex', alignItems: 'center', color: C.primary }}
                        >
                          <Sparkles size={16} />
                        </button>
                      </div>
                    </div>
                  </div>

              <div className="form-group">
                <label className="form-label"><FileText size={12} /> Subtitle / Excerpt</label>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <input 
                    className="form-input" 
                    value={formData.subtitle} 
                    onChange={e => setFormData({...formData, subtitle: e.target.value})} 
                    placeholder="A short summary shown in listing cards..."
                    style={{ flex: 1 }}
                  />
                  <button 
                    type="button"
                    onClick={autoGenerateSummary}
                    disabled={isSummarizing}
                    title="Auto-generate summary from content"
                    style={{ 
                      padding: '0 15px', 
                      borderRadius: '12px', 
                      border: `1px solid ${C.creamDarker}`, 
                      background: isSummarizing ? C.cream : C.cream, 
                      cursor: 'pointer', 
                      display: 'flex', 
                      alignItems: 'center', 
                      color: C.primary,
                      transition: 'all 0.2s'
                    }}
                  >
                    {isSummarizing ? <Loader2 size={16} className="animate-spin text-muted" /> : <Sparkles size={16} />}
                  </button>
                </div>
              </div>

              <div className="form-group">
                <label className="form-label"><ImageIcon size={12} /> Article Cover Image <span style={{color: 'red'}}>*</span></label>
                <input 
                  type="file" 
                  hidden 
                  ref={fileInputRef} 
                  accept="image/*"
                  onChange={(e) => handleFileUpload(e, 'imageUrl')} 
                />
                <div 
                  onClick={() => !isUploading.imageUrl && fileInputRef.current.click()}
                  style={{
                    width: '100%',
                    height: '200px',
                    borderRadius: '16px',
                    border: formData.imageUrl ? 'none' : `2px dashed ${C.primaryLight}`,
                    background: formData.imageUrl ? 'transparent' : C.cream,
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
                         className="hover-overlay"
                         style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.4)', display: 'flex', alignItems: 'center', justifyContent: 'center', opacity: 0, transition: 'opacity 0.2s' }} 
                         onMouseOver={e => e.currentTarget.style.opacity = 1} 
                         onMouseOut={e => e.currentTarget.style.opacity = 0}
                       >
                         <div style={{ background: C.bgCard, padding: '8px 16px', borderRadius: '20px', display: 'flex', alignItems: 'center', gap: '8px', fontSize: '13px', fontWeight: 600, color: C.charcoal }}>
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

              <div style={{ background: C.cream, padding: '16px', borderRadius: '16px', marginBottom: '20px', border: `1px solid ${C.creamDarker}` }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
                  <span className="form-label" style={{ marginBottom: 0 }}><User size={12} /> Author Profile</span>
                  <select 
                    style={{ background: C.bgCard, border: `1px solid ${C.creamDarker}`, borderRadius: '8px', padding: '4px 8px', fontSize: '11px', fontFamily: 'Outfit', cursor: 'pointer' }}
                    onChange={(e) => {
                      const author = AUTHOR_PRESETS.find(a => a.name === e.target.value);
                      if (author) applyAuthorPreset(author);
                    }}
                  >
                    <option value="">Quick Select Author...</option>
                    {AUTHOR_PRESETS.map(a => <option key={a.name} value={a.name}>{a.name}</option>)}
                  </select>
                </div>
                
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div className="form-group" style={{ marginBottom: 0 }}>
                    <label className="form-label" style={{ fontSize: '9px', opacity: 0.8 }}>Display Name</label>
                    <input 
                      className="form-input" 
                      style={{ background: C.white }}
                      value={formData.authorName} 
                      onChange={e => setFormData({...formData, authorName: e.target.value})} 
                      placeholder="e.g., Dr. Elena Vance"
                    />
                  </div>
                  <div className="form-group" style={{ marginBottom: 0 }}>
                    <label className="form-label" style={{ fontSize: '9px', opacity: 0.8 }}>Professional Role</label>
                    <input 
                      className="form-input" 
                      style={{ background: C.white }}
                      value={formData.authorRole} 
                      onChange={e => setFormData({...formData, authorRole: e.target.value})} 
                      placeholder="e.g., Neuroscientist"
                    />
                  </div>
                </div>

                <div className="form-group" style={{ marginTop: '16px', marginBottom: 0 }}>
                  <label className="form-label" style={{ fontSize: '9px', opacity: 0.8 }}>Profile Image URL (Avatar)</label>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <input 
                      className="form-input" 
                      style={{ background: C.white, flex: 1 }}
                      value={formData.authorImageUrl} 
                      onChange={e => setFormData({...formData, authorImageUrl: e.target.value})} 
                      placeholder="https://..."
                    />
                    <input 
                      type="file" 
                      hidden 
                      ref={authorInputRef} 
                      accept="image/*"
                      onChange={(e) => handleFileUpload(e, 'authorImageUrl')} 
                    />
                    <button 
                      type="button"
                      onClick={() => authorInputRef.current.click()}
                      disabled={isUploading.authorImageUrl}
                      style={{ padding: '0 15px', borderRadius: '12px', border: `1px solid ${C.creamDarker}`, background: '#f8faf9', cursor: 'pointer', display: 'flex', alignItems: 'center' }}
                    >
                      {isUploading.authorImageUrl ? <Loader2 size={16} className="animate-spin" /> : <Upload size={16} />}
                    </button>
                  </div>
                </div>
              </div>

                  <div className="form-group">
                    <label className="form-label"><FileText size={12} /> Source Link (Optional external credit)</label>
                    <input 
                      className="form-input" 
                      value={formData.sourceLink} 
                      onChange={e => setFormData({...formData, sourceLink: e.target.value})} 
                      placeholder="e.g., https://verywellmind.com/article..."
                    />
                  </div>

                  <div className="form-group">
                    <label className="form-label"><FileText size={12} /> Main Content (Rich Text)</label>
                    <RichTextEditor
                      value={formData.content}
                      onChange={(newContent) => setFormData({...formData, content: newContent})}
                      placeholder="Type the full article text here. Use the toolbar for formatting..."
                    />
                  </div>

                  <div className="form-group">
                    <label className="form-label"><Send size={12} /> Status</label>
                    <select 
                      className="form-input"
                      value={formData.status}
                      onChange={e => setFormData({...formData, status: e.target.value})}
                    >
                      <option value="draft">Draft (Hidden from App)</option>
                      <option value="published">Published (Live in App)</option>
                      <option value="archived">Archived (Hidden from App)</option>
                    </select>
                  </div>
                </>
              ) : (
                <div className="markdown-preview">
                  <div style={{ marginBottom: '20px', borderRadius: '20px', overflow: 'hidden', height: '240px', background: C.cream, display: 'flex', alignItems: 'center', justifyContent: 'center', border: `1px solid ${C.creamDarker}` }}>
                    {formData.imageUrl ? (
                      <img src={formData.imageUrl} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                    ) : (
                      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', color: C.muted }}>
                        <ImageIcon size={32} style={{ marginBottom: '8px', opacity: 0.5 }} />
                        <span style={{ fontSize: '13px', fontWeight: 600 }}>No Cover Image</span>
                      </div>
                    )}
                  </div>
                  <h1 style={{ fontFamily: 'Playfair Display', fontSize: '32px', marginBottom: '8px' }}>{formData.title || 'Untitled Article'}</h1>
                  <p style={{ color: C.muted, fontSize: '14px', marginBottom: '24px' }}>{formData.readingTime} · Published in <span style={{ color: C.primary, fontWeight: 700 }}>{formData.tag}</span></p>
                  
                  <div style={{ display: 'flex', alignItems: 'center', gap: '12px', padding: '16px', background: C.cream, borderRadius: '16px', marginBottom: '32px' }}>
                    {formData.authorImageUrl ? (
                      <img src={formData.authorImageUrl} style={{ width: '48px', height: '48px', borderRadius: '50%', objectFit: 'cover' }} />
                    ) : (
                      <div style={{ width: '48px', height: '48px', borderRadius: '50%', background: C.sage100, color: C.primary, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '18px', fontWeight: 700 }}>
                        {(formData.authorName || 'A')[0].toUpperCase()}
                      </div>
                    )}
                    <div>
                      <div style={{ fontWeight: 700, color: C.charcoal }}>{formData.authorName || 'Anonymous'}</div>
                      <div style={{ fontSize: '12px', color: C.charcoalMuted }}>{formData.authorRole || 'Contributor'}</div>
                    </div>
                  </div>

                  <div style={{ fontSize: '18px', fontStyle: 'italic', color: C.charcoalMuted, borderLeft: `4px solid ${C.primary}`, paddingLeft: '20px', marginBottom: '32px' }}>
                    {formData.subtitle || 'No summary provided.'}
                  </div>

                  {/* Simple Rich Text Preview simulation */}
                  <div style={{ whiteSpace: /<[a-z][\s\S]*>/i.test(formData.content) ? 'normal' : 'pre-wrap' }}
                       dangerouslySetInnerHTML={{ 
                         __html: /<[a-z][\s\S]*>/i.test(formData.content) 
                           ? formData.content 
                           : formData.content?.replace(/\n/g, '<br/>') || 'No content yet.'
                       }}
                  />
                </div>
              )}
            </div>

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
                {editingArticle ? <><Save size={16} /> Update Article</> : <><Send size={16} /> Publish Article</>}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
