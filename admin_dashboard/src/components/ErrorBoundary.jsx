import React from 'react';
import { AlertTriangle, RefreshCcw } from 'lucide-react';

class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error("ErrorBoundary caught an error:", error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="flex flex-col items-center justify-center p-10 bg-white rounded-2xl shadow-[0_2px_16px_rgba(0,0,0,0.06)] border border-red-100 min-h-[300px] w-full">
          <div className="w-16 h-16 bg-red-50 text-red-500 rounded-full flex items-center justify-center mb-4">
            <AlertTriangle size={32} />
          </div>
          <h2 className="font-outfit text-xl font-bold text-charcoal mb-2">Something went wrong</h2>
          <p className="font-body text-sm text-charcoal-muted mb-6 text-center max-w-md">
            This specific section of the dashboard encountered an unexpected error.
          </p>
          <button 
            onClick={() => window.location.reload()}
            className="flex items-center gap-2 bg-cream hover:bg-cream-darker text-charcoal px-5 py-2.5 rounded-xl font-semibold transition-colors"
          >
            <RefreshCcw size={16} /> Reload Page
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}

export default ErrorBoundary;
