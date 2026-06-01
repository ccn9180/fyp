import React from 'react';
import { createRoot } from 'react-dom/client';
import { motion, AnimatePresence } from 'framer-motion';
import { AlertCircle, CheckCircle, Info, X } from 'lucide-react';

const Dialog = ({ type = 'alert', title, message, onConfirm, onCancel, close }) => {
  const isConfirm = type === 'confirm';
  const Icon = type === 'error' ? AlertCircle : type === 'success' ? CheckCircle : Info;
  const iconColor = type === 'error' ? 'text-red-500' : type === 'success' ? 'text-green-500' : 'text-primary';

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
              <p className="font-body text-charcoal-muted text-[15px] leading-relaxed">
                {message}
              </p>
            </div>
            <button 
              onClick={() => { onCancel && onCancel(); close(); }}
              className="self-start p-1.5 -mt-1.5 -mr-1.5 text-muted hover:bg-cream rounded-lg transition-colors border-none cursor-pointer bg-transparent"
            >
              <X size={18} />
            </button>
          </div>
          <div className="px-6 py-4 bg-cream/50 border-t border-cream-darker flex justify-end gap-3">
            {isConfirm && (
              <button
                onClick={() => { onCancel && onCancel(); close(); }}
                className="px-4 py-2 font-body font-medium text-charcoal-muted bg-white border border-cream-darker hover:bg-cream-darker rounded-xl transition-colors cursor-pointer"
              >
                Cancel
              </button>
            )}
            <button
              onClick={() => { onConfirm && onConfirm(); close(); }}
              className="px-5 py-2 font-body font-semibold text-white bg-primary hover:bg-primary/90 rounded-xl transition-colors cursor-pointer border-none shadow-sm"
            >
              {isConfirm ? 'Confirm' : 'OK'}
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
        onConfirm={() => resolve(true)}
        onCancel={() => resolve(false)}
      />
    );
  });
};

export const customAlert = (message, title = 'System Notification') => {
  return createDialog({ type: 'alert', message, title });
};

export const customConfirm = (message, title = 'Please Confirm') => {
  return createDialog({ type: 'confirm', message, title });
};
