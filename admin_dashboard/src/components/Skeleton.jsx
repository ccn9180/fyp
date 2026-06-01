import React from 'react';

export default function Skeleton({ type = 'rectangle', className = '', style = {} }) {
  // Base classes for the pulse animation
  const baseClasses = 'animate-pulse bg-cream-darker/60';
  
  // Specific shapes
  const typeClasses = {
    circle: 'rounded-full',
    rectangle: 'rounded-xl',
    text: 'rounded-md h-4 w-full',
    title: 'rounded-lg h-6 w-3/4'
  };

  return (
    <div 
      className={`${baseClasses} ${typeClasses[type] || typeClasses.rectangle} ${className}`}
      style={style}
    />
  );
}
