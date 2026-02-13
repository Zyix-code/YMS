/* Firebase Messaging Service Worker (UMD v8 - SW compatible) */

importScripts('https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js');
importScripts('https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js');

firebase.initializeApp({
  apiKey: "AIzaSyC3yGugiY6QLHkeQkIpbehAGKm2yx5bciE",
  authDomain: "ymss-c7a49.firebaseapp.com",
  projectId: "ymss-c7a49",
  storageBucket: "ymss-c7a49.firebasestorage.app",
  messagingSenderId: "472099892182",
  appId: "1:472099892182:web:b634bc61e1551184fe1277",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  if (payload && payload.notification) {
    return;
  }

  const data = (payload && payload.data) || {};

  const title = (data.title || "YMS 💗").toString().trim() || "YMS 💗";
  const body  = (data.body  || data.message || "Seni hatırladı").toString().trim();
  const tag =
    (data.mid || data.messageId || data.createdAtMs || `${title}|${body}`).toString();

  self.registration.showNotification(title, {
    body,
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    tag,
    renotify: false,
    data: data,
  });
});

self.addEventListener("notificationclick", function (event) {
  event.notification.close();

  const targetUrl = "/";
  event.waitUntil((async () => {
    const allClients = await clients.matchAll({ type: "window", includeUncontrolled: true });
    for (const client of allClients) {
      if (client.url.includes(targetUrl) && "focus" in client) return client.focus();
    }
    if (clients.openWindow) return clients.openWindow(targetUrl);
  })());
});
