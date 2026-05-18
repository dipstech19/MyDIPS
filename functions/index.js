const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore();

async function tokensForSupervisors(equipeId) {
  const snap = await db
    .collection('notification_tokens')
    .where('active', '==', true)
    .get();

  const tokens = [];
  const isDistribution = equipeId.startsWith('distribution:');
  const groupId = isDistribution ? equipeId.replace('distribution:', '') : null;

  for (const doc of snap.docs) {
    const d = doc.data();
    const token = d.token || doc.id;
    if (!token) continue;

    const role = (d.role || '').toString();
    const adminRole = (d.adminRole || '').toString().toLowerCase();

    if (role === 'chefEquipe' || role === 'chauffeur') continue;

    if (isDistribution) {
      const ids = Array.isArray(d.distributionGroupIds) ? d.distributionGroupIds : [];
      const one = (d.distributionGroupId || '').toString();
      const watches =
        ids.includes(groupId) || one === groupId || adminRole.includes('zone');
      if (!watches) continue;
    } else if (adminRole.includes('zone')) {
      continue;
    }

    if (role === 'directeur' || adminRole.includes('atelier')) {
      tokens.push(token);
    }
  }
  return [...new Set(tokens)];
}

async function tokensForEquipe(equipeId) {
  const snap = await db
    .collection('notification_tokens')
    .where('active', '==', true)
    .where('equipeId', '==', equipeId)
    .get();
  return snap.docs.map((d) => d.data().token || d.id).filter(Boolean);
}

async function sendMulticast(tokens, title, body, data = {}) {
  if (!tokens.length) return;
  const messaging = getMessaging();
  const chunkSize = 500;
  for (let i = 0; i < tokens.length; i += chunkSize) {
    const chunk = tokens.slice(i, i + chunkSize);
    await messaging.sendEachForMulticast({
      tokens: chunk,
      notification: { title, body },
      data,
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  }
}

/** Push FCM quand un chef confirme le pointage ou manque la fenêtre. */
exports.onPointageEventCreated = onDocumentCreated(
  'pointage_events/{eventId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const type = (data.type || '').toString();
    const equipeId = (data.equipeId || '').toString();
    const equipeName = (data.equipeName || equipeId || 'Équipe').toString();
    const chefName = (data.chefName || 'Chef d\'équipe').toString();

    if (type === 'chef_report_submitted') {
      const tokens = await tokensForSupervisors(equipeId);
      await sendMulticast(
        tokens,
        'Pointage confirmé',
        `${chefName} a confirmé le pointage pour ${equipeName}.`,
        { type, equipeId },
      );
    } else if (type === 'chef_report_missed') {
      const tokens = await tokensForSupervisors(equipeId);
      await sendMulticast(
        tokens,
        'Pointage manqué',
        `Aucune confirmation de sortie pour ${equipeName}.`,
        { type, equipeId },
      );
      const chefTokens = await tokensForEquipe(equipeId);
      await sendMulticast(
        chefTokens,
        'Pointage non confirmé',
        `Confirmez le pointage de sortie pour ${equipeName}.`,
        { type, equipeId },
      );
    }
  },
);
