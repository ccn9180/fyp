import React, { useState, useEffect } from 'react';
import { collection, query, where, getDocs, doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';
import { MessageSquare, Calendar, Sparkles, Brain, Clock, ChevronRight, User } from 'lucide-react';

export default function SharedInsights() {
  const [sharedChats, setSharedChats] = useState([]);
  const [selectedChat, setSelectedChat] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchSharedChats = async () => {
      const user = auth.currentUser;
      if (!user) return;
      setLoading(true);

      try {
        const q = query(
          collection(db, 'shared_chats'),
          where('counsellorId', '==', user.uid)
        );
        const snap = await getDocs(q);
        const chatsList = [];

        snap.forEach((docSnap) => {
          const data = docSnap.data();
          let sharedDate = null;
          if (data.sharedAt) {
            sharedDate = data.sharedAt.seconds ? new Date(data.sharedAt.seconds * 1000) : new Date(data.sharedAt);
          }
          chatsList.push({
            id: docSnap.id,
            ...data,
            resolvedSharedAt: sharedDate
          });
        });

        chatsList.sort((a, b) => (b.resolvedSharedAt || 0) - (a.resolvedSharedAt || 0));
        setSharedChats(chatsList);
        
        // Auto-select the first chat if available
        if (chatsList.length > 0) {
          setSelectedChat(chatsList[0]);
        }
      } catch (err) {
        console.error("Error loading shared insights:", err);
      } finally {
        setLoading(false);
      }
    };

    fetchSharedChats();
  }, []);

  const formatDate = (dateObj) => {
    if (!dateObj) return 'Recent';
    return dateObj.toLocaleDateString('en-US', { 
      month: 'short', 
      day: 'numeric',
      year: 'numeric'
    });
  };

  const formatTime = (dateObj) => {
    if (!dateObj) return '';
    return dateObj.toLocaleTimeString('en-US', { 
      hour: '2-digit', 
      minute: '2-digit' 
    });
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <header className="page-header" style={{ marginBottom: '24px' }}>
        <h1 className="page-title">Shared Insights</h1>
        <p className="page-subtitle">Analyze patient emotional profiles and clinical summaries from their shared Eunoia AI chatbot sessions.</p>
      </header>

      {loading ? (
        <div className="card" style={{ padding: '40px', textAlign: 'center', color: 'var(--text-muted)' }}>
          Loading shared chatbot histories…
        </div>
      ) : sharedChats.length === 0 ? (
        <div className="card" style={{ padding: '60px 20px', textAlign: 'center', border: '1px dashed var(--border-color)', backgroundColor: 'var(--bg-card)' }}>
          <Brain size={44} style={{ color: 'var(--text-muted)', marginBottom: '12px', opacity: 0.6 }} />
          <h3 style={{ fontSize: '18px', fontWeight: 600, color: 'var(--text-darker)' }}>
            No Shared Insights Yet
          </h3>
          <p style={{ fontSize: '14px', color: 'var(--text-muted)', marginTop: '4px' }}>
            Shared chatbot logs from your patients will automatically appear here when shared.
          </p>
        </div>
      ) : (
        <div className="insights-split-container">
          
          {/* Left Pane - Chat Sessions List */}
          <div className="insights-list-pane">
            <h4 style={{ fontSize: '10px', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.8px', marginBottom: '4px', paddingLeft: '4px' }}>
              Clients ({sharedChats.length})
            </h4>
            {sharedChats.map((chat) => (
              <div 
                key={chat.id} 
                className={`insights-list-card ${selectedChat?.id === chat.id ? 'active' : ''}`}
                onClick={() => setSelectedChat(chat)}
              >
                <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
                  <div style={{ 
                    width: '36px', 
                    height: '36px', 
                    borderRadius: '10px', 
                    backgroundColor: selectedChat?.id === chat.id ? 'var(--primary-color)' : 'var(--primary-light)', 
                    display: 'flex', 
                    alignItems: 'center', 
                    justifyContent: 'center',
                    color: selectedChat?.id === chat.id ? 'white' : 'var(--primary-color)',
                    fontWeight: 700,
                    fontSize: '13px'
                  }}>
                    {chat.userName?.charAt(0) || 'U'}
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <h4 style={{ fontSize: '13.5px', fontWeight: 700, color: 'var(--text-darker)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {chat.userName}
                    </h4>
                    <p style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '2px' }}>
                      {formatDate(chat.resolvedSharedAt)}
                    </p>
                  </div>
                  <ChevronRight size={14} style={{ color: 'var(--text-muted)', opacity: selectedChat?.id === chat.id ? 0.8 : 0.4 }} />
                </div>
              </div>
            ))}
          </div>

          {/* Right Pane - Chat Transcript & Summary Details */}
          <div className="insights-detail-pane" style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
            {selectedChat ? (
              <>
                {/* Detail Header */}
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid var(--border-color)', paddingBottom: '20px' }}>
                  <div>
                    <h2 style={{ fontSize: '22px', fontWeight: 700, color: 'var(--text-darker)' }}>
                      {selectedChat.userName}
                    </h2>
                    <div style={{ display: 'flex', gap: '14px', marginTop: '6px', color: 'var(--text-muted)', fontSize: '12px', alignItems: 'center' }}>
                      <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                        <Calendar size={13} /> {formatDate(selectedChat.resolvedSharedAt)}
                      </span>
                      <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                        <Clock size={13} /> {formatTime(selectedChat.resolvedSharedAt)}
                      </span>
                    </div>
                  </div>
                </div>

                {/* AI clinical summary */}
                <div style={{ padding: '20px', backgroundColor: 'var(--bg-secondary)', borderRadius: '16px', borderLeft: '4px solid var(--primary-color)' }}>
                  <h3 style={{ fontSize: '13.5px', fontWeight: 700, color: 'var(--primary-color)', marginBottom: '8px', display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <Sparkles size={14} /> AI Clinical Summary
                  </h3>
                  <p style={{ fontSize: '13.5px', color: 'var(--text-dark)', lineHeight: '1.6' }}>
                    {selectedChat.aiSummary || 'No summary provided.'}
                  </p>
                </div>

                {/* Emotion profile */}
                {selectedChat.emotionTags && selectedChat.emotionTags.length > 0 && (
                  <div>
                    <h4 style={{ fontSize: '11px', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.8px', marginBottom: '8px' }}>
                      Identified Mood Indicators
                    </h4>
                    <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                      {selectedChat.emotionTags.map((tag, idx) => (
                        <span key={idx} style={{ padding: '6px 12px', backgroundColor: '#EAF2ED', borderRadius: '10px', fontSize: '12px', fontWeight: 600, color: 'var(--primary-color)' }}>
                          #{tag}
                        </span>
                      ))}
                    </div>
                  </div>
                )}

                {/* Transcript Logs */}
                <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  <h4 style={{ fontSize: '11px', fontWeight: 700, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.8px', marginBottom: '4px' }}>
                    Transcription Log
                  </h4>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', overflowY: 'auto', maxHeight: '380px', paddingRight: '6px' }}>
                    {selectedChat.messages && selectedChat.messages.map((msg, index) => {
                      const isBot = msg.role === 'assistant' || msg.role === 'bot';
                      return (
                        <div 
                          key={index} 
                          style={{ 
                            padding: '12px 16px', 
                            borderRadius: '14px', 
                            backgroundColor: isBot ? 'var(--bg-secondary)' : '#EAF2ED',
                            border: '1px solid var(--border-color)',
                            alignSelf: isBot ? 'flex-start' : 'flex-end',
                            maxWidth: '85%'
                          }}
                        >
                          <p style={{ fontSize: '9px', fontWeight: 700, color: isBot ? 'var(--primary-color)' : 'var(--text-dark)', textTransform: 'uppercase', letterSpacing: '0.5px', marginBottom: '4px' }}>
                            {isBot ? 'Eunoia AI' : 'Client'}
                          </p>
                          <p style={{ fontSize: '13px', color: 'var(--text-darker)', lineHeight: '1.45' }}>
                            {msg.text}
                          </p>
                        </div>
                      );
                    })}
                  </div>
                </div>
              </>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '100%', color: 'var(--text-muted)' }}>
                <MessageSquare size={32} style={{ opacity: 0.5, marginBottom: '8px' }} />
                <p style={{ fontSize: '14px' }}>Select a client transcript from the left to view details</p>
              </div>
            )}
          </div>

        </div>
      )}
    </div>
  );
}
