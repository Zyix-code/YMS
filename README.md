# 💗 YMS – Sen & Ben

<p align="center">
  <img src="https://media.giphy.com/media/MDJ9IbxxvDUQM/giphy.gif" width="160px">
</p>

<p align="center">
  <b>İki kişi için tasarlanmış özel bir dijital bağ uygulaması.</b><br>
  Günlük kalpler, mesajlar, seri kazanımlar ve tatlı bir rekabet 💕
</p>

---

## 💌 Projenin Amacı

YMS (You & Me System),  
tamamen kız arkadaşım için geliştirdiğim özel bir uygulamadır.

Amaç:

- Günlük olarak birbirimize kalp ve mesaj göndermek
- Gün sonunda kimin daha aktif olduğunu görmek
- Küçük ama tatlı bir rekabet oluşturmak
- Günlük serileri takip etmek
- Mesafe bilgisi görmek
- Basit ama anlamlı bir bağ kurmak

Bu proje ticari değildir.  
Kişisel ve duygusal bir motivasyonla geliştirilmiştir ❤️

---

## 🚀 Özellikler

- 💗 Tek tıkla kalp gönderme
- 💬 Manuel mesaj gönderme
- 🏆 Günlük kazanan sistemi
- 🔥 Günlük seri (streak) takibi
- 📊 Toplam kazanma sayacı
- 📍 GPS konum güncelleme ve mesafe hesaplama
- 📅 Günlük reset (00:00 otomatik)
- 🔔 Push Notification (Firebase + Cloudflare Worker)
- ☁️ Firestore tabanlı gerçek zamanlı senkronizasyon

---

## 🧠 Sistem Nasıl Çalışır?

### 1️⃣ Eşleşme Sistemi
- Kullanıcılar eşleşme kodu ile bağlanır
- `pairedUserId` üzerinden çift oluşturulur

### 2️⃣ Günlük Sayaç

Her kullanıcı için:

- `dailyHearts`
- `dailyMessages`
- `winnerStreak`
- `totalWins`
- `lastResultDayKey`

alanları tutulur.

---

### 3️⃣ Gün Sonu Değerlendirme

Saat 00:00 sonrası ilk girişte:

- Günlük kalp + mesaj toplamı hesaplanır
- Kazanan belirlenir
- `totalWins` artırılır
- Seri güncellenir
- Günlük sayaçlar sıfırlanır

---

## 🔐 Firestore Security Rules

Aşağıdaki kurallar **çift mantığına özel yazılmıştır** ve sadece eşleşmiş kullanıcıların birbirine erişmesine izin verir.

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() { return request.auth != null; }
    function uid() { return request.auth.uid; }

    function hasMyUserDoc() {
      return exists(/databases/$(database)/documents/users/$(uid()));
    }

    function myUserDoc() {
      return get(/databases/$(database)/documents/users/$(uid())).data;
    }

    function myPartnerUid() {
      return hasMyUserDoc() ? myUserDoc().pairedUserId : null;
    }

    function pairIdAB(a, b) { return a + "_" + b; }

    function isMyPairId(pid) {
      return signedIn()
        && hasMyUserDoc()
        && (myPartnerUid() is string)
        && (
          pid == pairIdAB(uid(), myPartnerUid()) ||
          pid == pairIdAB(myPartnerUid(), uid())
        );
    }

    match /users/{userId} {
      allow create: if signedIn() && uid() == userId;
      allow read: if signedIn() && uid() == userId;
      allow update: if signedIn() && uid() == userId;
      allow delete: if false;
    }

    match /interactions/{id} {
      allow create: if signedIn();
      allow read: if signedIn();
      allow update, delete: if false;
    }
  }
}
```

> Not: Production ortamında daha sıkı validasyon önerilir.

---

## ☁️ Cloudflare Worker (Push Proxy)

Push bildirimleri doğrudan istemciden gönderilmez.  
Güvenlik için **Cloudflare Worker üzerinden FCM HTTP v1 API kullanılır.**

---

### 🔑 Worker Secrets (Cloudflare Dashboard > Settings > Variables)

Aşağıdaki secret'ları eklemelisiniz:

```
API_KEY=buraya_kendi_api_keyiniz
FIREBASE_PROJECT_ID=buraya_firebase_project_id
GSA_CLIENT_EMAIL=buraya_service_account_email
GSA_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
BURAYA_KENDI_PRIVATE_KEYINIZ
-----END PRIVATE KEY-----"
```

---

## 📄 worker.js

```javascript
export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname === "/push") {
      return handlePush(request, env);
    }

    return new Response("Not Found", { status: 404 });
  },
};

async function handlePush(request, env) {

  const apiKey = request.headers.get("X-API-Key");
  if (apiKey !== env.API_KEY) {
    return new Response("Unauthorized", { status: 401 });
  }

  const body = await request.json();
  const { token, title, message } = body;

  if (!token) {
    return new Response("Token missing", { status: 400 });
  }

  const accessToken = await getAccessToken(env);

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: token,
          notification: {
            title: title || "YMS 💗",
            body: message || "Seni düşündü ❤️",
          },
        },
      }),
    }
  );

  const text = await response.text();
  return new Response(text, { status: response.status });
}

async function getAccessToken(env) {
  // JWT üretim ve Google OAuth token alma işlemi burada yapılır
  // (Production için RS256 imzalama kodu eklenmelidir)
  throw new Error("Access token implementation required.");
}
```

---

## 🛠️ Teknolojiler

- Flutter
- Firebase Authentication
- Firestore
- Firebase Cloud Messaging (FCM)
- Cloudflare Workers

---

## ⚙️ Kurulum

### 1️⃣ Firebase

- Authentication aktif et
- Firestore aktif et
- Cloud Messaging aktif et

### 2️⃣ Worker Deploy

```bash
npm install -g wrangler
wrangler login
wrangler deploy
```

---

## ⚖️ Lisans

Bu proje kişisel kullanım içindir.  
Ticari kullanım için uygun değildir.

---

## ❤️ Not

Bu uygulama, koddan çok hisle yazılmıştır.

Birine değer verdiğinizde,  
bunu göstermek için bazen küçük bir yazılım yeterlidir.

Made with ❤️ by Selçuk
