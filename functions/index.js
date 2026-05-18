const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

const db = getFirestore();

function normRole(adminRole) {
  return (adminRole || '').toString().toLowerCase();
}

function isAdminGeneral(adminRole) {
  const r = normRole(adminRole);
  return r.includes('général') || r.includes('general');
}

function isChefZone(adminRole) {
  return normRole(adminRole).includes('zone');
}

function isAdminMagasin(adminRole) {
  const r = normRole(adminRole);
  return r.includes('magasin');
}

function hasPermission(d, key) {
  const perms = Array.isArray(d.permissions) ? d.permissions : [];
  return perms.includes('all') || perms.includes(key);
}

async function tokensForStockAdmins() {
  const snap = await db.collection('notification_tokens').where('active', '==', true).get();
  const tokens = [];
  for (const doc of snap.docs) {
    const d = doc.data();
    const token = d.token || doc.id;
    if (!token) continue;
    if ((d.role || '').toString() !== 'directeur') continue;
    const ar = d.adminRole || '';
    if (isAdminGeneral(ar) || isChefZone(ar) || isAdminMagasin(ar)) {
      tokens.push(token);
    }
  }
  return [...new Set(tokens)];
}

async function tokensForLogistiqueAdmins() {
  const snap = await db.collection('notification_tokens').where('active', '==', true).get();
  const tokens = [];
  for (const doc of snap.docs) {
    const d = doc.data();
    const token = d.token || doc.id;
    if (!token) continue;
    if ((d.role || '').toString() !== 'directeur') continue;
    const ar = d.adminRole || '';
    if (
      isAdminGeneral(ar) ||
      isChefZone(ar) ||
      hasPermission(d, 'logistique.view')
    ) {
      tokens.push(token);
    }
  }
  return [...new Set(tokens)];
}

async function tokensForSupervisors(equipeId) {
  const snap = await db.collection('notification_tokens').where('active', '==', true).get();

  const tokens = [];
  const isDistribution = equipeId.startsWith('distribution:');
  const groupId = isDistribution ? equipeId.replace('distribution:', '') : null;

  for (const doc of snap.docs) {
    const d = doc.data();
    const token = d.token || doc.id;
    if (!token) continue;

    const role = (d.role || '').toString();
    const adminRole = normRole(d.adminRole);

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
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, v == null ? '' : String(v)]),
      ),
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
  }
}

/** Push FCM — pointage */
exports.onPointageEventCreated = onDocumentCreated(
  'pointage_events/{eventId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const type = (data.type || '').toString();
    const equipeId = (data.equipeId || '').toString();
    const equipeName = (data.equipeName || equipeId || 'Équipe').toString();
    const chefName = (data.chefName || "Chef d'équipe").toString();

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

/** Push FCM — stock & logistique */
exports.onOpsEventCreated = onDocumentCreated('ops_events/{eventId}', async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const type = (data.type || '').toString();
  const title = (data.title || 'My DIPS').toString();
  const body = (data.body || '').toString();

  const stockTypes = new Set(['stock_sortie', 'stock_low', 'stock_rupture']);
  const logistiqueTypes = new Set(['logistique_digest', 'logistique_expiry', 'logistique_expire']);

  let tokens = [];
  if (stockTypes.has(type)) {
    tokens = await tokensForStockAdmins();
  } else if (logistiqueTypes.has(type)) {
    tokens = await tokensForLogistiqueAdmins();
  } else {
    return;
  }

  await sendMulticast(tokens, title, body, { type, ...data });
});

function daysUntil(date) {
  if (!date || !(date instanceof Timestamp)) return null;
  const ms = date.toDate().getTime() - Date.now();
  return Math.ceil(ms / (24 * 60 * 60 * 1000));
}

async function buildLogistiqueDigest(days = 30) {
  const snap = await db.collection('logistique').doc('parc').collection('vehicules').get();
  let expires = 0;
  let urgents = 0;
  let soon = 0;
  const lines = [];

  for (const doc of snap.docs) {
    const v = doc.data();
    const mat = (v.matricule || doc.id).toString();
    const checks = [
      ['Assurance', v.expirationAssurance],
      ['Visite technique', v.expirationVisite],
      ['Carte grise', v.expirationCarteGrise],
      ['Autorisation transport', v.expirationAutorisationTransport],
      ['Badge', v.expirationBadge],
    ];
    for (const [label, ts] of checks) {
      const j = daysUntil(ts);
      if (j == null) continue;
      if (j > days) continue;
      if (j < 0) {
        expires += 1;
        if (lines.length < 4) lines.push(`${mat} ${label} (expiré)`);
      } else if (j <= 7) {
        urgents += 1;
        if (lines.length < 4) lines.push(`${mat} ${label} (${j} j)`);
      } else {
        soon += 1;
        if (lines.length < 4) lines.push(`${mat} ${label} (${j} j)`);
      }
    }
  }

  const total = expires + urgents + soon;
  if (total === 0) return null;

  return {
    type: 'logistique_digest',
    title: `Logistique — ${total} alerte(s)`,
    body: `${expires} expiré(s), ${urgents} urgent(s), ${soon} à surveiller. ${lines.join(' · ')}`,
    expires,
    urgents,
    soon,
    count: total,
  };
}

async function buildStockDigest() {
  const snap = await db.collection('magasin').doc('stock').collection('produits').get();
  const ruptures = [];
  const bas = [];

  for (const doc of snap.docs) {
    const p = doc.data();
    const nom = (p.nom || doc.id).toString();
    const variantes = Array.isArray(p.variantes) ? p.variantes : [];
    const aVariantes = !!p.aVariantes;
    let total = (p.quantiteStock || 0) | 0;
    if (aVariantes) {
      total = variantes.reduce((s, v) => s + ((v.quantite || 0) | 0), 0);
      const anyZero = variantes.some((v) => (v.quantite || 0) === 0);
      const anyLow = variantes.some((v) => {
        const q = (v.quantite || 0) | 0;
        return q > 0 && q <= 2;
      });
      if (anyZero) ruptures.push(nom);
      else if (anyLow) bas.push(nom);
    } else {
      if (total === 0) ruptures.push(nom);
      else if (total > 0 && total <= 2) bas.push(nom);
    }
  }

  if (!ruptures.length && !bas.length) return null;

  const rSample = ruptures.slice(0, 2).join(', ');
  const bSample = bas.slice(0, 2).join(', ');
  let body = '';
  if (ruptures.length) body += `${ruptures.length} rupture(s)${rSample ? ` : $rSample` : ''}`;
  if (bas.length) {
    if (body) body += ' · ';
    body += `${bas.length} stock bas${bSample ? ` : $bSample` : ''}`;
  }

  return {
    type: 'stock_digest',
    title: 'Stock — alertes du jour',
    body,
    ruptures: ruptures.length,
    bas: bas.length,
  };
}

/** Tous les jours 07:00 (Casablanca) — rappel logistique + stock */
exports.dailyOpsDigest = onSchedule(
  {
    schedule: '0 7 * * *',
    timeZone: 'Africa/Casablanca',
  },
  async () => {
    const logistique = await buildLogistiqueDigest(30);
    if (logistique) {
      const tokens = await tokensForLogistiqueAdmins();
      await sendMulticast(tokens, logistique.title, logistique.body, {
        type: logistique.type,
      });
    }

    const stock = await buildStockDigest();
    if (stock) {
      const tokens = await tokensForStockAdmins();
      await sendMulticast(tokens, stock.title, stock.body, { type: stock.type });
    }
  },
);
