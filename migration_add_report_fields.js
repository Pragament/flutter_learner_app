/**
 * One-time migration: add published/viewedAt/status fields to all existing
 * studentReports docs that don't have them yet.
 *
 * Run with Node.js on a machine that has access to the Firebase Admin SDK:
 *   npm install firebase-admin
 *   node migration_add_report_fields.js
 *
 * Also adds phoneNumber and parentUids to students docs that are missing them.
 */

const admin = require('firebase-admin');

// Download your service account key from:
// Firebase Console → Project Settings → Service Accounts → Generate new private key
const serviceAccount = require('./serviceAccountKey.json'); // <-- place here

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function migrateStudentReports() {
  console.log('Migrating studentReports...');
  const snap = await db.collection('studentReports').get();
  const batch = db.batch();
  let count = 0;

  for (const doc of snap.docs) {
    const d = doc.data();
    const updates = {};

    if (d.published === undefined) updates.published = false;
    if (d.publishedAt === undefined) updates.publishedAt = null;
    if (d.viewedAt === undefined) updates.viewedAt = null;
    if (d.viewedBy === undefined) updates.viewedBy = null;
    if (d.status === undefined) updates.status = 'pending';
    if (d.parentPhone === undefined) updates.parentPhone = '';

    if (Object.keys(updates).length > 0) {
      batch.update(doc.ref, updates);
      count++;
    }

    // Firestore batch limit is 500
    if (count % 499 === 0 && count > 0) {
      await batch.commit();
      console.log(`  committed ${count} studentReports so far...`);
    }
  }

  await batch.commit();
  console.log(`studentReports done: ${count} docs updated.`);
}

async function migrateStudents() {
  console.log('Migrating students...');
  const snap = await db.collection('students').get();
  const batch = db.batch();
  let count = 0;

  for (const doc of snap.docs) {
    const d = doc.data();
    const updates = {};

    if (d.phoneNumber === undefined) updates.phoneNumber = '';
    if (d.parentUids === undefined) updates.parentUids = [];

    if (Object.keys(updates).length > 0) {
      batch.update(doc.ref, updates);
      count++;
    }

    if (count % 499 === 0 && count > 0) {
      await batch.commit();
      console.log(`  committed ${count} students so far...`);
    }
  }

  await batch.commit();
  console.log(`students done: ${count} docs updated.`);
}

(async () => {
  await migrateStudentReports();
  await migrateStudents();
  console.log('Migration complete.');
  process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
