import { FirebaseApp, initializeApp } from 'firebase/app';

export default class FirebaseInitialization {
  private app: FirebaseApp;

  constructor() {
    // Firebaseコンソールが発行するWebアプリ設定。公開前提の識別子で秘匿情報ではない
    this.app = initializeApp({
      apiKey: 'AIzaSyAsyg8vgDV2r4uH5iZSpxvhxqqRQgzjbZc',
      authDomain: 'flaza-17d8c.firebaseapp.com',
      projectId: 'flaza-17d8c',
      storageBucket: 'flaza-17d8c.appspot.com',
      messagingSenderId: '282295142919',
      appId: '1:282295142919:web:5dbe9007f48a49ad70f8a2',
      measurementId: 'G-ZCJ8NTQ6KY',
    });
  }

  appInstance(): FirebaseApp {
    return this.app;
  }
}
