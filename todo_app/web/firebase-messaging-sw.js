// ブラウザを閉じていない状態（タブを閉じていても可）でプッシュ通知を受け取り、
// 通知を表示するための Service Worker。
// Firebase の Web SDK は、この決まった名前のファイルを自動で探しに来る。
importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js',
);

// ここに置く値は公開されても問題ないもの（クライアント用の設定）。
firebase.initializeApp({
  apiKey: 'AIzaSyCOewPkE5PuaI63mdSHmLTqIGlHStOYsNk',
  appId: '1:457389964851:web:70cf933f305acc44956d46',
  messagingSenderId: '457389964851',
  projectId: 'todo-app-mokuson',
  authDomain: 'todo-app-mokuson.firebaseapp.com',
  storageBucket: 'todo-app-mokuson.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  // notification 付きのメッセージは Firebase の SDK が自動で表示するので、
  // ここで表示すると二重になる。PC(Chrome) は tag が同じ通知をまとめるため
  // 1件に見えるが、iOS Safari は tag による重複排除が効かず2件出てしまう。
  if (payload.notification) return;

  const title = 'Todo';
  const body = (payload.data && payload.data.body) || '';
  self.registration.showNotification(title, {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: (payload.data && payload.data.taskId) || undefined,
  });
});

// 通知をクリックしたらアプリのタブを前面に出す（無ければ開く）
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if ('focus' in client) return client.focus();
        }
        if (self.clients.openWindow) return self.clients.openWindow('/');
      }),
  );
});
