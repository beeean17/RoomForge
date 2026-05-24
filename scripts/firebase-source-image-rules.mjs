import { deleteApp, initializeApp } from 'firebase/app';
import {
  createUserWithEmailAndPassword,
  connectAuthEmulator,
  getAuth,
} from 'firebase/auth';
import {
  connectFirestoreEmulator,
  doc,
  getFirestore,
  setDoc,
} from 'firebase/firestore';
import {
  connectStorageEmulator,
  getBytes,
  getStorage,
  ref,
  uploadBytes,
} from 'firebase/storage';

const projectId = process.env.GCLOUD_PROJECT || 'roomforge-local';
const app = initializeApp({
  apiKey: 'roomforge-local-api-key',
  appId: 'roomforge-local-app-id',
  authDomain: `${projectId}.firebaseapp.com`,
  messagingSenderId: '000000000000',
  projectId,
  storageBucket: `${projectId}.appspot.com`,
});

const auth = getAuth(app);
const db = getFirestore(app);
const storage = getStorage(app);

connectAuthEmulator(auth, 'http://127.0.0.1:9099', {
  disableWarnings: true,
});
connectFirestoreEmulator(db, '127.0.0.1', 8080);
connectStorageEmulator(storage, '127.0.0.1', 9199);

const runId = `${Date.now()}-${Math.floor(Math.random() * 100000)}`;

async function createSignedInUser(prefix) {
  const credential = await createUserWithEmailAndPassword(
    auth,
    `${prefix}-${runId}@example.test`,
    'Password123!',
  );
  return credential.user;
}

async function createProject(owner, suffix) {
  const id = `source-project-${suffix}-${runId}`;
  await setDoc(doc(db, 'projects', id), {
    project_id: id,
    owner_uid: owner.uid,
    name: `Source Project ${suffix}`,
    schema_version: 1,
    created_at: new Date(),
    updated_at: new Date(),
  });
  return id;
}

function sourcePath(uid, projectIdValue, sourceImageId, filename = 'room.jpg') {
  return `users/${uid}/projects/${projectIdValue}/source-images/${sourceImageId}/${filename}`;
}

function metadata(uid, projectIdValue, sourceImageId) {
  return {
    customMetadata: {
      owner_uid: uid,
      project_id: projectIdValue,
      source_image_id: sourceImageId,
      uploaded_by_uid: uid,
      sha256_hex: '00',
    },
    contentType: 'image/jpeg',
  };
}

function sourceImageMetadata(uid, projectIdValue, sourceImageId, path) {
  return {
    source_image_id: sourceImageId,
    project_id: projectIdValue,
    owner_uid: uid,
    storage_path: path,
    original_filename: 'room.jpg',
    stored_filename: 'room.jpg',
    content_type: 'image/jpeg',
    byte_size: 4,
    sha256_hex: '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
    width_px: 1280,
    height_px: 720,
    capture_source: 'file_upload',
    retention_status: 'active',
    uploaded_at: new Date(),
    created_at: new Date(),
    updated_at: new Date(),
    schema_version: 1,
  };
}

async function expectPermissionDenied(operation) {
  try {
    await operation();
  } catch (error) {
    if (
      error?.code === 'storage/unauthorized' ||
      error?.code === 'permission-denied'
    ) {
      return;
    }
    throw error;
  }

  throw new Error('Expected permission-denied, but operation succeeded.');
}

const tests = [
  {
    id: 'st-source-owner-upload-allow',
    run: async () => {
      const owner = await createSignedInUser('source-owner-upload');
      const projectIdValue = await createProject(owner, 'upload');
      const sourceImageId = `source-upload-${runId}`;
      const path = sourcePath(owner.uid, projectIdValue, sourceImageId);
      const storageRef = ref(
        storage,
        path,
      );

      await uploadBytes(
        storageRef,
        new Uint8Array([1, 2, 3, 4]),
        metadata(owner.uid, projectIdValue, sourceImageId),
      );
      const downloaded = await getBytes(storageRef);
      if (downloaded.byteLength !== 4) {
        throw new Error('Uploaded source image bytes were not readable.');
      }
      await setDoc(
        doc(db, 'projects', projectIdValue, 'source_images', sourceImageId),
        sourceImageMetadata(owner.uid, projectIdValue, sourceImageId, path),
      );
    },
  },
  {
    id: 'st-source-invalid-type-deny',
    run: async () => {
      const owner = await createSignedInUser('source-invalid-type');
      const projectIdValue = await createProject(owner, 'invalid-type');
      const sourceImageId = `source-invalid-type-${runId}`;
      const storageRef = ref(
        storage,
        sourcePath(owner.uid, projectIdValue, sourceImageId, 'room.txt'),
      );

      await expectPermissionDenied(() =>
        uploadBytes(storageRef, new Uint8Array([1]), {
          ...metadata(owner.uid, projectIdValue, sourceImageId),
          contentType: 'text/plain',
        }),
      );
    },
  },
  {
    id: 'st-source-overwrite-deny',
    run: async () => {
      const owner = await createSignedInUser('source-overwrite');
      const projectIdValue = await createProject(owner, 'overwrite');
      const sourceImageId = `source-overwrite-${runId}`;
      const storageRef = ref(
        storage,
        sourcePath(owner.uid, projectIdValue, sourceImageId),
      );

      await uploadBytes(
        storageRef,
        new Uint8Array([1, 2, 3, 4]),
        metadata(owner.uid, projectIdValue, sourceImageId),
      );
      await expectPermissionDenied(() =>
        uploadBytes(
          storageRef,
          new Uint8Array([5, 6, 7, 8]),
          metadata(owner.uid, projectIdValue, sourceImageId),
        ),
      );
    },
  },
  {
    id: 'st-source-too-large-deny',
    run: async () => {
      const owner = await createSignedInUser('source-too-large');
      const projectIdValue = await createProject(owner, 'too-large');
      const sourceImageId = `source-too-large-${runId}`;
      const storageRef = ref(
        storage,
        sourcePath(owner.uid, projectIdValue, sourceImageId),
      );

      await expectPermissionDenied(() =>
        uploadBytes(
          storageRef,
          new Uint8Array(10 * 1024 * 1024 + 1),
          metadata(owner.uid, projectIdValue, sourceImageId),
        ),
      );
    },
  },
  {
    id: 'st-source-cross-user-deny',
    run: async () => {
      const owner = await createSignedInUser('source-cross-owner');
      const projectIdValue = await createProject(owner, 'cross-user');
      const other = await createSignedInUser('source-cross-other');
      const sourceImageId = `source-cross-user-${runId}`;
      const storageRef = ref(
        storage,
        sourcePath(owner.uid, projectIdValue, sourceImageId),
      );

      await expectPermissionDenied(() =>
        uploadBytes(
          storageRef,
          new Uint8Array([1]),
          metadata(other.uid, projectIdValue, sourceImageId),
        ),
      );
    },
  },
  {
    id: 'st-source-path-uid-mismatch-deny',
    run: async () => {
      const owner = await createSignedInUser('source-path-owner');
      const projectIdValue = await createProject(owner, 'path-mismatch');
      const sourceImageId = `source-path-mismatch-${runId}`;
      const storageRef = ref(
        storage,
        sourcePath(`not-${owner.uid}`, projectIdValue, sourceImageId),
      );

      await expectPermissionDenied(() =>
        uploadBytes(
          storageRef,
          new Uint8Array([1]),
          metadata(owner.uid, projectIdValue, sourceImageId),
        ),
      );
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
