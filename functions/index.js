const admin = require("firebase-admin");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");

admin.initializeApp();

exports.pushOnIncoming = onDocumentUpdated("users/{uid}", async (event) => {
  const before = event.data.before.data() || {};
  const after = event.data.after.data() || {};

  const b = before.lastIncomingAt ? before.lastIncomingAt.toMillis?.() : null;
  const a = after.lastIncomingAt ? after.lastIncomingAt.toMillis?.() : null;
  if (!a || a === b) return;

  const token = after.webPushToken;
  if (!token) return;

  const bodyText = (after.lastIncomingText || "Seni hatırladı").toString();
  const title = "YMS 💗";

  try {
    await admin.messaging().send({
      token,
      notification: {
        title,
        body: bodyText.length > 160 ? bodyText.slice(0, 160) + "…" : bodyText,
      },
      data: {
        uid: event.params.uid,
        kind: "incoming",
      },
      webpush: {
        fcmOptions: { link: "/" },
      },
    });
  } catch (e) {
    console.error("push send error:", e);
  }
});
