const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { HttpsError, onCall } = require('firebase-functions/v2/https');

initializeApp();

const projectIdPattern = /^[A-Za-z0-9_-]{1,128}$/;

exports.deleteProject = onCall({
  region: 'us-central1',
  invoker: 'public',
  cors: [
    /^http:\/\/localhost:\d+$/,
    /^http:\/\/127\.0\.0\.1:\d+$/,
    'https://roomforge-cbbdd.web.app',
    'https://roomforge-cbbdd.firebaseapp.com',
  ],
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication is required.');
  }

  const projectId = request.data?.projectId;
  if (typeof projectId !== 'string' || !projectIdPattern.test(projectId)) {
    throw new HttpsError('invalid-argument', 'A valid projectId is required.');
  }

  const db = getFirestore();
  const projectRef = db.collection('projects').doc(projectId);
  const projectSnapshot = await projectRef.get();
  if (!projectSnapshot.exists) {
    throw new HttpsError('not-found', 'Project was not found.');
  }

  const project = projectSnapshot.data() || {};
  const ownerUid = project.owner_uid;
  if (typeof ownerUid !== 'string' || ownerUid.length === 0) {
    throw new HttpsError('failed-precondition', 'Project owner is missing.');
  }

  const actorUid = request.auth.uid;
  const adminSnapshot = await db.collection('users').doc(actorUid).get();
  const isAdmin = adminSnapshot.exists && adminSnapshot.get('role') === 'admin';
  if (ownerUid !== actorUid && !isAdmin) {
    throw new HttpsError('permission-denied', 'Project ownership or admin access is required.');
  }

  const storagePrefix = `users/${ownerUid}/projects/${projectId}/`;
  await getStorage().bucket().deleteFiles({
    force: true,
    prefix: storagePrefix,
  });

  await db.recursiveDelete(projectRef);

  return {
    data: {
      project_id: projectId,
      owner_uid: ownerUid,
      deleted_by_uid: actorUid,
      storage_prefix: storagePrefix,
    },
  };
});
