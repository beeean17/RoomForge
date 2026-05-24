import { deleteApp, initializeApp } from 'firebase/app';
import {
  createUserWithEmailAndPassword,
  connectAuthEmulator,
  getAuth,
} from 'firebase/auth';
import {
  connectFirestoreEmulator,
  doc,
  getDoc,
  getFirestore,
  setDoc,
  updateDoc,
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

const tests = [
  {
    id: 'fs-user-profile-upsert-allow',
    run: async () => {
      const credential = await createUserWithEmailAndPassword(
        auth,
        `profile-${runId}@example.test`,
        'Password123!',
      );
      const uid = credential.user.uid;
      const profileRef = doc(db, 'users', uid);

      await setDoc(profileRef, {
        uid,
        email: credential.user.email,
        display_name: 'Profile Test User',
        created_at: new Date(),
        updated_at: new Date(),
        schema_version: 1,
      });

      await updateDoc(profileRef, {
        display_name: 'Updated Profile Test User',
        updated_at: new Date(),
        last_seen_at: new Date(),
      });

      const snapshot = await getDoc(profileRef);
      if (!snapshot.exists()) {
        throw new Error('Profile document was not created.');
      }
      if (snapshot.data().role !== undefined) {
        throw new Error('Profile upsert unexpectedly created a role field.');
      }
    },
  },
];

let failed = 0;
for (const test of tests) {
  try {
    await test.run();
    console.log(`${test.id}: allow`);
  } catch (error) {
    failed += 1;
    console.error(`${test.id}: failed`);
    console.error(error);
  }
}

await auth.signOut().catch(() => undefined);
await deleteApp(app).catch(() => undefined);
process.exit(failed > 0 ? 1 : 0);
