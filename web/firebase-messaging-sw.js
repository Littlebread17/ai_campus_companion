// Firebase Cloud Messaging service worker for web push.
// Required by FirebaseMessaging on the web platform.
importScripts(
  'https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyArykB2I2HzGI0RUSsJ47pR0WDVxyNQkfE',
  appId: '1:409017158410:web:df8c5f4831aa6859a388f3',
  messagingSenderId: '409017158410',
  projectId: 'ai-campus-companion-413c3',
  authDomain: 'ai-campus-companion-413c3.firebaseapp.com',
  storageBucket: 'ai-campus-companion-413c3.firebasestorage.app',
  measurementId: 'G-M8QB5V2BW4',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  self.registration.showNotification(notification.title || 'Campus Companion', {
    body: notification.body || '',
    icon: '/icons/Icon-192.png',
  });
});
