import { deleteApp, initializeApp } from 'firebase/app';
import {
  createUserWithEmailAndPassword,
  connectAuthEmulator,
  getAuth,
} from 'firebase/auth';
import {
  collection,
  connectFirestoreEmulator,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const projectId = process.env.GCLOUD_PROJECT || 'roomforge-local';
const app = initializeApp({
  apiKey: 'roomforge-local-api-key',
  appId: 'roomforge-local-app-id',
  authDomain: `${projectId}.firebaseapp.com`,
  messagingSenderId: '000000000000',
  projectId,
});

const auth = getAuth(app);
const db = getFirestore(app);

connectAuthEmulator(auth, 'http://127.0.0.1:9099', {
  disableWarnings: true,
});
connectFirestoreEmulator(db, '127.0.0.1', 8080);

const runId = `${Date.now()}-${Math.floor(Math.random() * 100000)}`;

async function createSignedInUser(prefix) {
  const credential = await createUserWithEmailAndPassword(
    auth,
    `${prefix}-${runId}@example.test`,
    'Password123!',
  );
  return credential.user;
}

function projectPayload(projectIdValue, ownerUid, name = 'Room Project') {
  return {
    project_id: projectIdValue,
    owner_uid: ownerUid,
    name,
    description: 'Rules test project',
    schema_version: 1,
    created_at: new Date(),
    updated_at: new Date(),
  };
}

function dimensionsPayload(projectIdValue, ownerUid) {
  return {
    project_id: projectIdValue,
    owner_uid: ownerUid,
    width_m: 4.2,
    depth_m: 3.6,
    height_m: 2.4,
    unit: 'meters',
    source: 'user_entered',
    created_at: new Date(),
    updated_at: new Date(),
    schema_version: 1,
  };
}

async function expectPermissionDenied(operation) {
  try {
    await operation();
  } catch (error) {
    if (error?.code === 'permission-denied') {
      return;
    }
    throw error;
  }

  throw new Error('Expected permission-denied, but operation succeeded.');
}

const tests = [
  {
    id: 'fs-project-owner-create-allow',
    run: async () => {
      const user = await createSignedInUser('project-create');
      const id = `project-create-${runId}`;
      await setDoc(doc(db, 'projects', id), projectPayload(id, user.uid));
    },
  },
  {
    id: 'fs-project-owner-read-allow',
    run: async () => {
      const user = await createSignedInUser('project-read');
      const id = `project-read-${runId}`;
      await setDoc(doc(db, 'projects', id), projectPayload(id, user.uid));

      const snapshot = await getDoc(doc(db, 'projects', id));
      if (!snapshot.exists()) {
        throw new Error('Owner project read did not return a document.');
      }

      const projects = await getDocs(
        query(collection(db, 'projects'), where('owner_uid', '==', user.uid)),
      );
      if (projects.empty) {
        throw new Error('Owner-constrained project list did not return data.');
      }
    },
  },
  {
    id: 'fs-project-owner-immutable-deny',
    run: async () => {
      const owner = await createSignedInUser('project-immutable-owner');
      const id = `project-immutable-${runId}`;
      await setDoc(doc(db, 'projects', id), projectPayload(id, owner.uid));

      await expectPermissionDenied(() =>
        updateDoc(doc(db, 'projects', id), {
          owner_uid: `attacker-${runId}`,
          updated_at: new Date(),
        }),
      );
    },
  },
  {
    id: 'fs-project-non-owner-read-deny',
    run: async () => {
      const owner = await createSignedInUser('project-owner');
      const id = `project-non-owner-${runId}`;
      await setDoc(doc(db, 'projects', id), projectPayload(id, owner.uid));

      await createSignedInUser('project-non-owner');
      await expectPermissionDenied(() => getDoc(doc(db, 'projects', id)));
    },
  },
  {
    id: 'fs-room-dimensions-owner-write-read-allow',
    run: async () => {
      const owner = await createSignedInUser('dimensions-owner');
      const id = `dimensions-owner-${runId}`;
      await setDoc(doc(db, 'projects', id), projectPayload(id, owner.uid));
      const dimensionsRef = doc(db, 'projects', id, 'room_dimensions', 'current');

      await setDoc(dimensionsRef, dimensionsPayload(id, owner.uid));
      const snapshot = await getDoc(dimensionsRef);
      if (!snapshot.exists()) {
        throw new Error('Owner dimensions read did not return a document.');
      }
      if (snapshot.data().unit !== 'meters') {
        throw new Error('Dimensions unit must be meters.');
      }
    },
  },
  {
    id: 'fs-room-dimensions-non-owner-read-deny',
    run: async () => {
      const owner = await createSignedInUser('dimensions-owner-deny');
      const id = `dimensions-deny-${runId}`;
      await setDoc(doc(db, 'projects', id), projectPayload(id, owner.uid));
      const dimensionsRef = doc(db, 'projects', id, 'room_dimensions', 'current');
      await setDoc(dimensionsRef, dimensionsPayload(id, owner.uid));

      await createSignedInUser('dimensions-non-owner');
      await expectPermissionDenied(() => getDoc(dimensionsRef));
    },
  },
];

let failed = 0;
for (const test of tests) {
  try {
    await test.run();
    console.log(`${test.id}: pass`);
  } catch (error) {
    failed += 1;
    console.error(`${test.id}: failed`);
    console.error(error);
  }
}

await auth.signOut().catch(() => undefined);
await deleteApp(app).catch(() => undefined);
process.exit(failed > 0 ? 1 : 0);
