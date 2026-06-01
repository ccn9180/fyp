import { initializeApp } from "firebase/app";
import { getAuth, GoogleAuthProvider } from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

// Firebase configuration from main app (firebase_options.dart)
const firebaseConfig = {
  apiKey: "AIzaSyDAehybWM3_vYntsXTWSiYqWBY00pPIUSI",
  authDomain: "hifyp-ea16a.firebaseapp.com",
  projectId: "hifyp-ea16a",
  storageBucket: "hifyp-ea16a.firebasestorage.app",
  messagingSenderId: "286777752164",
  appId: "1:286777752164:web:fd879627ac9b592a63bd71",
  measurementId: "G-DSPD2GNGWV"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);

// Initialize Firebase services
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);
export const googleProvider = new GoogleAuthProvider();

export default app;
