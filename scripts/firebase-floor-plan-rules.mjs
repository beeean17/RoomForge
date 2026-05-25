import { deleteApp, initializeApp } from 'firebase/app';
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
  signOut,
} from 'firebase/auth';
import {
  connectFirestoreEmulator,
  doc,
  getDoc,
  getFirestore,
  setDoc,
  writeBatch,
} from 'firebase/firestore';
import {
  connectStorageEmulator,
  getBytes,
  getStorage,
  listAll,
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

async function createProjectSetup(owner, suffix) {
  const id = `floor-plan-project-${suffix}-${runId}`;
  await setDoc(doc(db, 'projects', id), {
    project_id: id,
    owner_uid: owner.uid,
    name: `Floor Plan Project ${suffix}`,
    schema_version: 1,
    created_at: new Date(),
    updated_at: new Date(),
  });
  await setDoc(doc(db, 'projects', id, 'room_dimensions', 'current'), {
    project_id: id,
    owner_uid: owner.uid,
    width_m: 4.2,
    depth_m: 3.6,
    height_m: 2.7,
    unit: 'meters',
    source: 'user_entered',
    created_at: new Date(),
    updated_at: new Date(),
    schema_version: 1,
  });
  await setDoc(doc(db, 'projects', id, 'source_images', 'source-1'), {
    source_image_id: 'source-1',
    project_id: id,
    owner_uid: owner.uid,
    storage_path: `users/${owner.uid}/projects/${id}/source-images/source-1/room.jpg`,
    original_filename: 'room.jpg',
    stored_filename: 'room.jpg',
    content_type: 'image/jpeg',
    byte_size: 4,
    sha256_hex:
      '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
    width_px: 1280,
    height_px: 720,
    capture_source: 'file_upload',
    retention_status: 'active',
    uploaded_at: new Date(),
    created_at: new Date(),
    updated_at: new Date(),
    schema_version: 1,
  });
  await createJobWithTransition(owner, id, 'job-1');
  await setDoc(
    doc(db, 'projects', id, 'confirmed_geometries', 'geometry-1'),
    confirmedGeometryPayload(owner, id),
  );
  return id;
}

async function createJobWithTransition(owner, projectIdValue, jobId) {
  const transitionId = `transition-${jobId}`;
  const batch = writeBatch(db);
  batch.set(doc(db, 'projects', projectIdValue, 'reconstruction_jobs', jobId), {
    job_id: jobId,
    project_id: projectIdValue,
    owner_uid: owner.uid,
    source_image_id: 'source-1',
    room_dimensions_id: 'current',
    status: 'review_required',
    status_updated_at: new Date(),
    provider_type: 'manual_assisted_opencv',
    algorithm_id: 'opencv_lines_corners_v1',
    created_by_uid: owner.uid,
    root_job_id: jobId,
    retry_count: 0,
    latest_transition_id: transitionId,
    artifact_refs: [],
    created_at: new Date(),
    updated_at: new Date(),
    schema_version: 1,
  });
  batch.set(
    doc(
      db,
      'projects',
      projectIdValue,
      'reconstruction_jobs',
      jobId,
      'transitions',
      transitionId,
    ),
    {
      transition_id: transitionId,
      project_id: projectIdValue,
      owner_uid: owner.uid,
      job_id: jobId,
      to_status: 'review_required',
      occurred_at: new Date(),
      actor_type: 'user',
      actor_uid: owner.uid,
      reason_code: 'candidate_review_required',
      reason_message: 'Candidate extraction requires user review.',
      artifact_refs: [],
      schema_version: 1,
    },
  );
  await batch.commit();
}

function confirmedGeometryPayload(owner, projectIdValue) {
  return {
    geometry_id: 'geometry-1',
    project_id: projectIdValue,
    owner_uid: owner.uid,
    job_id: 'job-1',
    source_image_id: 'source-1',
    coordinate_space: 'image_pixels',
    boundary_type: 'rectangle',
    boundary_points: [
      { x: 0, y: 0 },
      { x: 100, y: 0 },
      { x: 100, y: 80 },
      { x: 0, y: 80 },
    ],
    correction_method: 'candidate_adjusted',
    confirmed_by_uid: owner.uid,
    created_at: new Date(),
    updated_at: new Date(),
    schema_version: 1,
  };
}

function artifactPath(owner, projectIdValue, artifactId, filename = 'overlay.png') {
  return `users/${owner.uid}/projects/${projectIdValue}/artifacts/job-1/${artifactId}/${filename}`;
}

function artifactMetadata(owner, projectIdValue, artifactId, contentType = 'image/png') {
  return {
    customMetadata: {
      owner_uid: owner.uid,
      project_id: projectIdValue,
      job_id: 'job-1',
      artifact_id: artifactId,
      uploaded_by_uid: owner.uid,
    },
    contentType,
  };
}

function floorPlanPayload(owner, projectIdValue, coordinateSpace) {
  const artifactId = 'artifact-1';
  return {
    floor_plan_id: 'floor-plan-1',
    project_id: projectIdValue,
    owner_uid: owner.uid,
    job_id: 'job-1',
    source_image_id: 'source-1',
    confirmed_geometry_id: 'geometry-1',
    room_dimensions_id: 'current',
    coordinate_space: coordinateSpace,
    room_dimensions: {
      project_id: projectIdValue,
      owner_uid: owner.uid,
      width_m: 4.2,
      depth_m: 3.6,
      height_m: 2.7,
      unit: 'meters',
      source: 'user_entered',
      created_at: new Date(),
      updated_at: new Date(),
      schema_version: 1,
    },
    floor_polygon: [
      { x: 0, y: 0 },
      { x: 4.2, y: 0 },
      { x: 4.2, y: 3.6 },
      { x: 0, y: 3.6 },
    ],
    walls: [],
    calibration: {
      scale_px_per_meter: 100,
      method: 'room_dimensions_rect',
    },
    quality_status: 'review_required',
    warnings: ['Needs review'],
    artifact_refs: [
      {
        artifact_id: artifactId,
        storage_path: artifactPath(owner, projectIdValue, artifactId),
        artifact_type: 'opencv_overlay',
        content_type: 'image/png',
        byte_size: 4,
        created_at: new Date(),
      },
    ],
    created_at: new Date(),
    updated_at: new Date(),
    schema_version: 1,
  };
}

function floorPlanWithArtifactRef(owner, projectIdValue, artifactRef) {
  const payload = floorPlanPayload(owner, projectIdValue, 'meters');
  payload.artifact_refs = [artifactRef];
  return payload;
}

async function expectPermissionDenied(operation) {
  try {
    await operation();
  } catch (error) {
    if (
      error?.code === 'permission-denied' ||
      error?.code === 'storage/unauthorized'
    ) {
      return;
    }
    throw error;
  }

  throw new Error('Expected permission-denied, but operation succeeded.');
}

const tests = [
  {
    id: 'fs-floor-plan-meters-allow',
    run: async () => {
      const owner = await createSignedInUser('floor-plan-owner');
      const projectIdValue = await createProjectSetup(owner, 'allow');
      await setDoc(
        doc(db, 'projects', projectIdValue, 'floor_plans', 'floor-plan-1'),
        floorPlanPayload(owner, projectIdValue, 'meters'),
      );
      const snapshot = await getDoc(
        doc(db, 'projects', projectIdValue, 'floor_plans', 'floor-plan-1'),
      );
      if (snapshot.data()?.coordinate_space !== 'meters') {
        throw new Error('Floor plan did not persist as meters.');
      }
      if (snapshot.data()?.quality_status !== 'review_required') {
        throw new Error('Floor plan review state was not preserved.');
      }
    },
  },
  {
    id: 'fs-floor-plan-image-pixels-deny',
    run: async () => {
      const owner = await createSignedInUser('floor-plan-pixels-owner');
      const projectIdValue = await createProjectSetup(owner, 'pixels-deny');
      await expectPermissionDenied(() =>
        setDoc(
          doc(db, 'projects', projectIdValue, 'floor_plans', 'floor-plan-1'),
          floorPlanPayload(owner, projectIdValue, 'image_pixels'),
        ),
      );
    },
  },
  {
    id: 'fs-floor-plan-artifact-path-link-deny',
    run: async () => {
      const owner = await createSignedInUser('floor-plan-artifact-path');
      const projectIdValue = await createProjectSetup(owner, 'artifact-path');
      await expectPermissionDenied(() =>
        setDoc(
          doc(db, 'projects', projectIdValue, 'floor_plans', 'floor-plan-1'),
          floorPlanWithArtifactRef(owner, projectIdValue, {
            artifact_id: 'artifact-1',
            storage_path:
              'users/other-user/projects/other-project/artifacts/job-1/artifact-1/overlay.png',
            artifact_type: 'opencv_overlay',
            content_type: 'image/png',
            byte_size: 4,
          }),
        ),
      );
    },
  },
  {
    id: 'fs-floor-plan-artifact-invalid-type-deny',
    run: async () => {
      const owner = await createSignedInUser('floor-plan-artifact-type');
      const projectIdValue = await createProjectSetup(owner, 'artifact-invalid');
      await expectPermissionDenied(() =>
        setDoc(
          doc(db, 'projects', projectIdValue, 'floor_plans', 'floor-plan-1'),
          floorPlanWithArtifactRef(owner, projectIdValue, {
            artifact_id: 'artifact-1',
            storage_path: artifactPath(owner, projectIdValue, 'artifact-1'),
            artifact_type: 'opencv_overlay',
            content_type: 'text/plain',
            byte_size: 4,
          }),
        ),
      );
    },
  },
  {
    id: 'fs-floor-plan-artifact-regex-id-deny',
    run: async () => {
      const owner = await createSignedInUser('floor-plan-artifact-regex');
      const projectIdValue = await createProjectSetup(owner, 'artifact-regex');
      await expectPermissionDenied(() =>
        setDoc(
          doc(db, 'projects', projectIdValue, 'floor_plans', 'floor-plan-1'),
          floorPlanWithArtifactRef(owner, projectIdValue, {
            artifact_id: '.*',
            storage_path: `users/${owner.uid}/projects/${projectIdValue}/artifacts/job-1/other-artifact/overlay.png`,
            artifact_type: 'opencv_overlay',
            content_type: 'image/png',
            byte_size: 4,
          }),
        ),
      );
    },
  },
  {
    id: 'st-artifact-owner-read-allow',
    run: async () => {
      const owner = await createSignedInUser('artifact-owner-read');
      const projectIdValue = await createProjectSetup(owner, 'artifact-read');
      const storageRef = ref(
        storage,
        artifactPath(owner, projectIdValue, 'artifact-read-1'),
      );
      await uploadBytes(
        storageRef,
        new Uint8Array([1, 2, 3, 4]),
        artifactMetadata(owner, projectIdValue, 'artifact-read-1'),
      );
      const downloaded = await getBytes(storageRef);
      if (downloaded.byteLength !== 4) {
        throw new Error('Uploaded artifact bytes were not readable.');
      }
    },
  },
  {
    id: 'st-artifact-invalid-type-deny',
    run: async () => {
      const owner = await createSignedInUser('artifact-invalid-type');
      const projectIdValue = await createProjectSetup(owner, 'artifact-type');
      await expectPermissionDenied(() =>
        uploadBytes(
          ref(storage, artifactPath(owner, projectIdValue, 'artifact-type-1', 'debug.txt')),
          new Uint8Array([1]),
          artifactMetadata(
            owner,
            projectIdValue,
            'artifact-type-1',
            'text/plain',
          ),
        ),
      );
    },
  },
  {
    id: 'st-artifact-public-list-deny',
    run: async () => {
      const owner = await createSignedInUser('artifact-public-list');
      const projectIdValue = await createProjectSetup(owner, 'artifact-list');
      await signOut(auth);
      await expectPermissionDenied(() =>
        listAll(
          ref(
            storage,
            `users/${owner.uid}/projects/${projectIdValue}/artifacts`,
          ),
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
    console.error(`${test.id}: fail`);
    console.error(error);
  }
}

await deleteApp(app);

if (failed > 0) {
  process.exit(1);
}
