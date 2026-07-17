/**
 * add_school_code.js
 * 
 * Adds schoolCode to all existing students that don't have one.
 * Also adds parentIds array (replacing old parentUids/parentId fields).
 * 
 * Run: node add_school_code.js
 * 
 * Place serviceAccountKey.json in same folder before running.
 */
const admin = require('firebase-admin');
const { getFirestore } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.cert(serviceAccount),
});

const db = getFirestore();

// ← CHANGE THIS to match your school code
const SCHOOL_CODE = 'DSS2025';

async function migrate() {
  console.log(`Adding schoolCode "${SCHOOL_CODE}" to students without it...`);
  
  const snap = await db.collection('students').get();
  
  let updated = 0;
  let skipped = 0;
  const batch = db.batch();
  let batchCount = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const updates = {};

    // Add schoolCode if missing
    if (!data.schoolCode) {
      updates.schoolCode = SCHOOL_CODE;
    }

    // Normalize parentIds — merge from parentUids and parentId
    if (data.parentIds === undefined) {
      const ids = new Set();
      
      // From old parentUids array
      if (Array.isArray(data.parentUids)) {
        data.parentUids.forEach(id => { if (id) ids.add(id); });
      }
      
      // From old parentId string
      if (data.parentId && typeof data.parentId === 'string' && data.parentId.trim()) {
        ids.add(data.parentId.trim());
      }
      
      updates.parentIds = Array.from(ids);
    }

    if (Object.keys(updates).length > 0) {
      batch.update(doc.ref, updates);
      batchCount++;
      updated++;
    } else {
      skipped++;
    }

    // Commit every 499
    if (batchCount >= 499) {
      await batch.commit();
      console.log(`  Committed ${updated} so far...`);
      batchCount = 0;
    }
  }

  if (batchCount > 0) await batch.commit();

  console.log(`\nDone!`);
  console.log(`  Updated: ${updated} students`);
  console.log(`  Skipped: ${skipped} (already had schoolCode)`);
  console.log(`\nAll students now have schoolCode="${SCHOOL_CODE}" and parentIds array.`);
  console.log('View Students in the admin app should now show all students.');
  
  process.exit(0);
}

migrate().catch(e => {
  console.error('Error:', e);
  process.exit(1);
});
