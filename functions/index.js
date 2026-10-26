const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

/**
 * Paystack Webhook Handler
 * Endpoint: /paystackWebhook
 * Verifies Paystack HMAC SHA512 signature and processes event triggers:
 * - charge.success (Connections, Premium Subscriptions, Verifications, Post Boosts)
 */
exports.paystackWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  const paystackSecretKey = process.env.PAYSTACK_SECRET_KEY || functions.config().paystack?.secret_key;
  const signature = req.headers['x-paystack-signature'];

  if (paystackSecretKey && signature) {
    const hash = crypto
      .createHmac('sha512', paystackSecretKey)
      .update(JSON.stringify(req.body))
      .digest('hex');

    if (hash !== signature) {
      console.error('[WEBHOOK] Invalid Paystack signature signature mismatch');
      return res.status(400).send('Invalid signature');
    }
  }

  const event = req.body;
  console.log('[WEBHOOK] Received Paystack event:', event.event);

  if (event && event.event === 'charge.success') {
    const data = event.data;
    const metadata = data.metadata || {};
    const userId = metadata.userId;
    const type = metadata.type;
    const reference = data.reference || `paystack_${data.id}`;
    const amount = (data.amount || 0) / 100; // kobo to KES

    console.log(`[WEBHOOK] Processing successful charge for user ${userId}, type: ${type}, amount KES ${amount}`);

    try {
      // 1. Record completed transaction doc
      await db.collection('transactions').doc(reference).set({
        id: reference,
        userId: userId || 'unknown',
        type: type || 'payment',
        amount: amount,
        currency: data.currency || 'KES',
        paymentMethod: data.channel || 'mpesa',
        paymentReference: reference,
        status: 'completed',
        metadata: metadata,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      // 2. Process business logic by payment type
      if (userId) {
        const userRef = db.collection('users').doc(userId);

        if (type === 'premium') {
          const expiry = new Date();
          expiry.setDate(expiry.getDate() + 30);
          await userRef.set({
            isPremium: true,
            premiumExpiry: expiry.toISOString(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        } else if (type === 'verified') {
          const days = metadata.plan === 'yearly' ? 365 : 30;
          const expiry = new Date();
          expiry.setDate(expiry.getDate() + days);
          await userRef.set({
            isVerified: true,
            verifiedExpiry: expiry.toISOString(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        } else if (type === 'bundle') {
          const expiry = new Date();
          expiry.setDate(expiry.getDate() + 30);
          await userRef.set({
            isPremium: true,
            premiumExpiry: expiry.toISOString(),
            isVerified: true,
            verifiedExpiry: expiry.toISOString(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        } else if (type === 'boost' && metadata.postId) {
          const hours = metadata.hours || (metadata.duration === '7d' ? 168 : 24);
          const expiry = new Date();
          expiry.setHours(expiry.getHours() + hours);
          await db.collection('posts').doc(metadata.postId).set({
            isBoosted: true,
            boostExpiresAt: expiry.toISOString(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }

        // 3. Create private account/payment notification
        const notifId = `notif_pay_${reference}`;
        let notifType = 'system';
        let notifTitle = 'Payment Confirmed';
        let notifBody = `Your payment of KES ${amount} was processed successfully.`;
        if (type === 'premium' || type === 'bundle') {
          notifType = 'premium';
          notifTitle = 'Premium Activated!';
          notifBody = 'Enjoy unlimited connections and premium features for the next 30 days.';
        } else if (type === 'verified') {
          notifType = 'verification';
          notifTitle = 'Profile Verified!';
          notifBody = 'Your blue verification badge has been activated on your profile.';
        } else if (type === 'boost') {
          notifType = 'boost';
          notifTitle = 'Post Boosted!';
          notifBody = 'Your post is now boosted to the top of the community feed.';
        }

        await db.collection('users').doc(userId).collection('notifications').doc(notifId).set({
          id: notifId,
          userId: userId,
          fromUserId: 'system',
          fromUsername: 'Crushie Official',
          fromUserProfilePic: 'crushie_avatar_0',
          type: notifType,
          title: notifTitle,
          body: notifBody,
          isRead: false,
          createdAt: new Date().toISOString(),
        }, { merge: true });
      }

      return res.status(200).send('Webhook processed successfully');
    } catch (err) {
      console.error('[WEBHOOK] Error executing transaction update:', err);
      return res.status(500).send('Internal Server Error');
    }
  }

  return res.status(200).send('Event received');
});

/**
 * Trigger push notification when a new in-app notification document is created
 */
exports.sendPushOnNotificationCreated = functions.firestore
  .document('users/{userId}/notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notif = snap.data();
    const userId = context.params.userId;
    if (!notif || notif.isRead || notif.pushDispatched) return null;

    try {
      // 1. Mark push as dispatched early to avoid duplicate triggers
      await snap.ref.update({
        pushDispatched: true,
        pushDispatchedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 2. Read target user's registered FCM tokens
      const userDoc = await db.collection('users').doc(userId).get();
      const userData = userDoc.data() || {};
      
      const tokenSet = new Set();
      if (typeof userData.fcmToken === 'string' && userData.fcmToken.trim().length > 0) {
        tokenSet.add(userData.fcmToken.trim());
      }
      if (Array.isArray(userData.fcmTokens)) {
        userData.fcmTokens.forEach((t) => {
          if (typeof t === 'string' && t.trim().length > 0) tokenSet.add(t.trim());
        });
      }

      const tokens = Array.from(tokenSet);
      if (tokens.length === 0) {
        console.log(`[PUSH] User ${userId} has no registered FCM tokens. Skipping push.`);
        return null;
      }

      const payload = {
        notification: {
          title: notif.title || 'New Notification',
          body: notif.body || 'You have a new alert on Crushie',
        },
        data: {
          notificationId: notif.id || '',
          type: notif.type || '',
          postId: notif.postId || '',
          connectionId: notif.connectionId || '',
          fromUserId: notif.fromUserId || '',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'crushie_notifications',
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
      };

      // 3. Dispatch to all active tokens
      const staleTokens = [];
      const sendPromises = tokens.map(async (token) => {
        try {
          await admin.messaging().send({
            token: token,
            ...payload,
          });
        } catch (err) {
          const errCode = err.code || err.errorInfo?.code;
          if (
            errCode === 'messaging/registration-token-not-registered' ||
            errCode === 'messaging/invalid-registration-token' ||
            errCode === 'messaging/invalid-argument'
          ) {
            console.warn(`[PUSH] Stale/invalid FCM token detected for ${userId}: ${token}`);
            staleTokens.push(token);
          } else {
            console.error(`[PUSH] Error sending to token ${token}:`, err);
          }
        }
      });

      await Promise.all(sendPromises);

      // 4. Clean up stale tokens from user document
      if (staleTokens.length > 0) {
        console.log(`[PUSH] Cleaning up ${staleTokens.length} stale tokens for user ${userId}`);
        const userUpdate = {
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...staleTokens),
        };
        if (staleTokens.includes(userData.fcmToken)) {
          userUpdate.fcmToken = admin.firestore.FieldValue.delete();
        }
        await db.collection('users').doc(userId).update(userUpdate).catch((cleanupErr) => {
          console.error('[PUSH] Stale token cleanup error:', cleanupErr);
        });
      }

      console.log(`[PUSH] Push notification process completed for ${userId}`);
      return true;
    } catch (err) {
      console.error(`[PUSH] Fatal error sending push notification to ${userId}:`, err);
      return null;
    }
  });

