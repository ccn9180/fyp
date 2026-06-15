import React from 'react';
import { X, Download, Eye, Loader2, Printer } from 'lucide-react';

/**
 * ReportPreview Component
 * Used to preview reports before downloading them as PDF.
 * 
 * @param {boolean} isOpen - Whether the modal is open
 * @param {function} onClose - Function to close the modal
 * @param {function} onDownload - Function to trigger the PDF download
 * @param {string} title - Title of the report
 * @param {boolean} isExporting - Loading state for download button
 * @param {React.ReactNode} children - The content to preview (should match the PDF content)
 */
export default function ReportPreview({ isOpen, onClose, onDownload, title, isExporting, children }) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[2000] flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-in fade-in duration-200 no-print">
      <div className="bg-[#F6F5F2] w-full max-w-5xl h-[90vh] rounded-[2rem] shadow-2xl flex flex-col overflow-hidden border border-white/20 animate-in zoom-in-95 duration-300">
        {/* Header */}
        <div className="bg-white/80 backdrop-blur-md px-8 py-4 flex justify-between items-center border-b border-[#E5E4E0] shadow-sm no-print">
          <div className="flex items-center gap-3">
             <div className="w-10 h-10 rounded-xl bg-[#E5EDE8] flex items-center justify-center text-[#7C9C84]">
                <Eye size={20} />
             </div>
             <div>
                <h3 className="font-display font-bold text-[#333] leading-tight">{title || 'Report Preview'}</h3>
                <p className="text-[10px] font-bold text-[#666] uppercase tracking-wider">Document Preview Mode</p>
             </div>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={onDownload}
              disabled={isExporting}
              className="flex items-center gap-2 px-6 py-2.5 bg-[#7C9C84] text-white rounded-xl font-bold text-sm shadow-lg shadow-[#7C9C84]/20 hover:opacity-90 transition active:scale-95 disabled:opacity-50 no-print"
            >
              {isExporting ? <Loader2 size={16} className="animate-spin" /> : <Download size={16} />}
              Confirm Download
            </button>
            <div className="w-px h-8 bg-[#E5E4E0] mx-2 no-print" />
            <button
              onClick={onClose}
              className="p-2.5 hover:bg-[#F6F5F2] rounded-xl transition text-[#888] hover:text-[#333] no-print"
            >
              <X size={24} />
            </button>
          </div>
        </div>

        {/* Preview Area */}
        <div className="flex-1 overflow-y-auto p-12 flex justify-center bg-[#525659]/10 scrollbar-hide">
          <div className="bg-white shadow-[0_0_50px_rgba(0,0,0,0.15)] w-[794px] min-h-[1123px] origin-top transform transition-transform duration-500 hover:shadow-[0_0_60px_rgba(0,0,0,0.2)]">
             {/* Scale wrapper for responsiveness if needed, but here we keep it fixed width for accuracy */}
             <div className="w-full h-full">
                {children}
             </div>
          </div>
        </div>

        {/* Footer */}
        <div className="bg-white/80 backdrop-blur-md px-8 py-3 flex justify-between items-center border-t border-[#E5E4E0] no-print">
            <p className="text-[10px] text-[#666] font-bold uppercase tracking-widest">Eunoia Wellness Platform • Official Audit Record</p>
            <div className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-[#7C9C84] animate-pulse" />
                <span className="text-[10px] font-bold text-[#7C9C84] uppercase tracking-wider">Ready for Export</span>
            </div>
        </div>
      </div>
    </div>
  );
}
