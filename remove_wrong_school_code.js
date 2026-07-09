const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const serviceAccount = require('./serviceAccountKey.json');

initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

async function fix() {
  console.log('Finding students with schoolCode DSS2025...');
  const snap = await db.collection('students')
    .where('schoolCode', '==', 'DSS2025')
    .get();

  console.log(`Found ${snap.docs.length} students with DSS2025`);

  // Print first 5 to see their structure
  snap.docs.slice(0, 5).forEach(doc => {
    const d = doc.data();
    console.log(`Doc ${doc.id}: admissionNo=${d.admissionNo}, hasParentIds=${d.parentIds !== undefined}, hasParentUids=${d.parentUids !== undefined}, name=${d.name}`);
  });

  let removed = 0, kept = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const doc of snap.docs) {
    const data = doc.data();

    // Keep ONLY students that have parentIds array (newly imported ones)
    // Remove schoolCode from everyone else
    const hasParentIds = Array.isArray(data.parentIds);

    if (!hasParentIds) {
      // Old student — remove schoolCode
      batch.update(doc.ref, { schoolCode: FieldValue.delete() });
      batchCount++;
      removed++;
      if (batchCount >= 499) {
        await batch.commit();
        batch = db.batch();
        batchCount = 0;
      }
    } else {
      kept++;
    }
  }

  if (batchCount > 0) await batch.commit();
  console.log(`Done! Removed schoolCode from ${removed} old students. Kept ${kept} properly imported students.`);
  process.exit(0);
}

fix().catch(e => { console.error(e); process.exit(1); });