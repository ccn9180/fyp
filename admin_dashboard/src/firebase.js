import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';
import { getStorage } from 'firebase/storage';

const firebaseConfig = {
  apiKey: 'AIzaSyDAehybWM3_vYntsXTWSiYqWBY00pPIUSI',
  authDomain: 'hifyp-ea16a.firebaseapp.com',
  projectId: 'hifyp-ea16a',
  storageBucket: 'hifyp-ea16a.firebasestorage.app',
  messagingSenderId: '286777752164',
  appId: '1:286777752164:web:fd879627ac9b592a63bd71',
  measurementId: 'G-DSPD2GNGWV',
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const auth = getAuth(app);
export const storage = getStorage(app);
export default app;
