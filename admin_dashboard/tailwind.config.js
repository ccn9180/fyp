/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#7C9C84',
          light: '#A3BBA9',
          lighter: '#BBCBC2',
          dark: '#5C7D65',
          muted: '#AAB8AE',
        },
        cream: {
          DEFAULT: '#F6F5F2',
          dark: '#EEEDE9',
          darker: '#E5E4E0',
        },
        sage: {
          50:  '#F4F7F5',
          100: '#E5EDE8',
          200: '#BBCBC2',
          300: '#A3BBA9',
          400: '#8DAA95',
          500: '#7C9C84',
          600: '#6A8A72',
          700: '#577860',
          800: '#3F5947',
          900: '#263A2C',
        },
        charcoal: {
          DEFAULT: '#333333',
          light: '#555555',
          muted: '#888888',
          subtle: '#AAAAAA',
        },
      },
      fontFamily: {
        display: ['"Playfair Display"', 'Georgia', 'serif'],
        body: ['"Outfit"', 'Inter', 'sans-serif'],
      },
      borderRadius: {
        '2xl': '1rem',
        '3xl': '1.5rem',
        '4xl': '2rem',
      },
      boxShadow: {
        'card': '0 2px 16px 0 rgba(0,0,0,0.06)',
        'card-hover': '0 6px 24px 0 rgba(124,156,132,0.14)',
      },
    },
  },
  plugins: [],
};
