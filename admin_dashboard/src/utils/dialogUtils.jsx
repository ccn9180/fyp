import React, { useState } from 'react';
import { createRoot } from 'react-dom/client';
import { motion, AnimatePresence } from 'framer-motion';
import { AlertCircle, CheckCircle, Info, X, Edit3 } from 'lucide-react';

const Dialog = ({ type = 'alert', title, message, defaultValue = '', onConfirm, onCancel, close }) => {
  const isConfirm = type === 'confirm';
  const isPrompt = type === 'prompt';
  const Icon = type === 'error' ? AlertCircle : type === 'success' ? CheckCircle : type === 'prompt' ? Edit3 : Info;
  const iconColor = type === 'error' ? 'text-red-500' : type === 'success' ? 'text-green-500' : 'text-primary';

  const [inputValue, setInputValue] = useState(defaultValue);

  return (
    <AnimatePresence>
      <div className="fixed inset-0 z-[9999] flex items-center justify-center bg-charcoal/40 backdrop-blur-sm p-4">
        <motion.div
          initial={{ opacity: 0, scale: 0.95, y: 10 }}
          animate={{ opacity: 1, scale: 1, y: 0 }}
          exit={{ opacity: 0, scale: 0.95, y: 10 }}
          transition={{ type: "spring", duration: 0.4, bounce: 0.2 }}
          className="bg-white rounded-2xl shadow-xl w-full max-w-md overflow-hidden flex flex-col"
        >
          <div className="p-6 flex gap-4">
            <div className={`mt-1 shrink-0 ${iconColor}`}>
              <Icon size={24} />
            </div>
            <div className="flex-1 min-w-0">
              {title && <h3 className="font-display font-semibold text-lg text-charcoal mb-1">{title}</h3>}
              <p className="font-body text-charcoal-muted text-[15px] leading-relaxed mb-3">
                {message}
              </p>
              {isPrompt && (
                <textarea
                  className="w-full bg-cream border border-cream-darker rounded-xl p-3 font-body text-sm text-charcoal focus:outline-none focus:border-primary resize-none"
                  rows={3}
                  value={inputValue}
                  onChange={(e) => setInputValue(e.target.value)}
                  placeholder="Enter reason..."
                  autoFocus
                />
              )}
            </div>
            <button 
              onClick={() => { onCancel && onCancel(); close(); }}
              className="self-start p-1.5 -mt-1.5 -mr-1.5 text-muted hover:bg-cream rounded-lg transition-colors border-none cursor-pointer bg-transparent"
            >
              <X size={18} />
            </button>
          </div>
          <div className="px-6 py-4 bg-cream/50 border-t border-cream-darker flex justify-end gap-3">
            {(isConfirm || isPrompt) && (
              <button
                onClick={() => { onCancel && onCancel(); close(); }}
                className="px-4 py-2 font-body font-medium text-charcoal-muted bg-white border border-cream-darker hover:bg-cream-darker rounded-xl transition-colors cursor-pointer"
              >
                Cancel
              </button>
            )}
            <button
              onClick={() => { 
                if (isPrompt) {
                  onConfirm && onConfirm(inputValue);
                } else {
                  onConfirm && onConfirm(true); 
                }
                close(); 
              }}
              className="px-5 py-2 font-body font-semibold text-white bg-primary hover:bg-primary/90 rounded-xl transition-colors cursor-pointer border-none shadow-sm"
            >
              {isConfirm ? 'Confirm' : isPrompt ? 'Submit' : 'OK'}
            </button>
          </div>
        </motion.div>
      </div>
    </AnimatePresence>
  );
};

const createDialog = (props) => {
  return new Promise((resolve) => {
    const container = document.createElement('div');
    document.body.appendChild(container);
    const root = createRoot(container);

    const close = () => {
      root.unmount();
      if (container.parentNode) {
        container.parentNode.removeChild(container);
      }
    };

    root.render(
      <Dialog
        {...props}
        close={close}
        onConfirm={(val) => resolve(val !== undefined ? val : true)}
        onCancel={() => resolve(props.type === 'prompt' ? null : false)}
      />
    );
  });
};

export const customAlert = (message, title = 'System Notification', typeOverride = null) => {
  let type = typeOverride;
  if (!type) {
    const t = title.toLowerCase();
    if (t.includes('success')) type = 'success';
    else if (t.includes('error') || t.includes('fail')) type = 'error';
    else type = 'alert';
  }
  return createDialog({ type, message, title });
};

export const customConfirm = (message, title = 'Please Confirm') => {
  return createDialog({ type: 'confirm', message, title });
};

export const customPrompt = (message, title = 'Input Required', defaultValue = '') => {
  return createDialog({ type: 'prompt', message, title, defaultValue });
};
