import { useState } from 'react';
import jsPDF from 'jspdf';
import html2canvas from 'html2canvas';

export const usePDFExport = () => {
  const [isExporting, setIsExporting] = useState(false);

  const exportPDF = async (paperRef, filenamePrefix = 'Eunoia_Report') => {
    if (isExporting) return;
    setIsExporting(true);

    try {
      // Optional: Add a slight delay if components need to render fully before capture
      await new Promise(resolve => setTimeout(resolve, 800));
      
      const input = paperRef.current;
      if (!input) {
        throw new Error("Report reference not found");
      }

      const canvas = await html2canvas(input, {
        scale: 2,
        useCORS: true,
        logging: false,
        backgroundColor: '#FFFFFF',
        width: 794 // Standard A4 width equivalent for consistent scaling
      });

      const imgData = canvas.toDataURL('image/png');
      const pdf = new jsPDF('p', 'mm', 'a4');
      const pdfWidth = pdf.internal.pageSize.getWidth();
      const pdfHeight = pdf.internal.pageSize.getHeight();
      const imgWidth = pdfWidth;
      const imgHeight = (canvas.height * imgWidth) / canvas.width;
      
      let heightLeft = imgHeight;
      let position = 0;
      let pageNumber = 1;
      const totalPages = Math.ceil(imgHeight / pdfHeight);

      // Helper to draw footer (optional, can be skipped if components render their own footer, but useful for consistency)
      const drawFooter = (pg) => {
        pdf.setFontSize(9);
        pdf.setTextColor(150);
        pdf.text(`Eunoia System Audit | Page ${pg} of ${totalPages}`, pdfWidth / 2, pdfHeight - 12, { align: 'center' });
      };

      // Draw first page
      pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
      drawFooter(pageNumber);
      heightLeft -= pdfHeight;

      while (heightLeft > 0) {
        position = heightLeft - imgHeight;
        pdf.addPage();
        pageNumber++;
        pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
        drawFooter(pageNumber);
        heightLeft -= pdfHeight;
      }

      pdf.save(`${filenamePrefix}_${new Date().toISOString().split('T')[0]}.pdf`);
      return true;
    } catch (err) {
      console.error('Export failed:', err);
      alert("Formal Export failed. High system memory load or missing elements.");
      return false;
    } finally {
      setIsExporting(false);
    }
  };

  return { exportPDF, isExporting };
};
