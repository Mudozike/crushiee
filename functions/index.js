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
      }

      return res.status(200).send('Webhook processed successfully');
    } catch (err) {
      console.error('[WEBHOOK] Error executing transaction update:', err);
      return res.status(500).send('Internal Server Error');
    }
  }

  return res.status(200).send('Event received');
});
