// Import the functions you need from the SDKs you need
import { FirebaseApp, initializeApp } from 'firebase/app';
// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

export default class FirebaseInitialization {
  private app: FirebaseApp | null = null;

  constructor() {
    if (this.app !== null) {
      return;
    }

    this.app = this.initialize();
  }

  private initialize(): FirebaseApp {
    // Your web app's Firebase configuration
    // For Firebase JS SDK v7.20.0 and later, measurementId is optional
    const firebaseConfig = {
      apiKey: 'AIzaSyAsyg8vgDV2r4uH5iZSpxvhxqqRQgzjbZc',
      authDomain: 'flaza-17d8c.firebaseapp.com',
      projectId: 'flaza-17d8c',
      storageBucket: 'flaza-17d8c.appspot.com',
      messagingSenderId: '282295142919',
      appId: '1:282295142919:web:5dbe9007f48a49ad70f8a2',
      measurementId: 'G-ZCJ8NTQ6KY',
    };

    // Initialize Firebase
    return initializeApp(firebaseConfig);
  }

  appInstance(): FirebaseApp {
    // コンストラクタで初期化しているため、nullにはなり得ない
    return this.app as FirebaseApp;
  }
}
