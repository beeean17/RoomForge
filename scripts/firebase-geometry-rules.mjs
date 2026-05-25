import { deleteApp, initializeApp } from 'firebase/app';
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
} from 'firebase/auth';
import {
  connectFirestoreEmulator,
  doc,
  getDoc,
  getFirestore,
  setDoc,
  writeBatch,
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

async function createProjectSetup(owner, suffix) {
  const id = `geometry-project-${suffix}-${runId}`;
  await setDoc(doc(db, 'projects', id), {
    project_id: id,
    owner_uid: owner.uid,
    name: `Geometry Project ${suffix}`,
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
    status: 'created',
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
      to_status: 'created',
      occurred_at: new Date(),
      actor_type: 'user',
      actor_uid: owner.uid,
      reason_code: 'user_submitted',
      reason_message: 'Reconstruction job created from source image.',
      artifact_refs: [],
      schema_version: 1,
    },
  );
  await batch.commit();
}

function openCvPayload(owner, projectIdValue, resultId, coordinateSpace) {
  return {
    result_id: resultId,
    project_id: projectIdValue,
    owner_uid: owner.uid,
    job_id: 'job-1',
    source_image_id: 'source-1',
    coordinate_space: coordinateSpace,
    algorithm_id: 'opencv_lines_corners_v1',
    candidate_edges: [],
    candidate_lines: [],
    candidate_corners: [
      { x: 0, y: 0 },
      { x: 100, y: 0 },
      { x: 100, y: 80 },
      { x: 0, y: 80 },
    ],
    boundary_hints: [],
    confidence_score: 0.84,
    quality_status: 'review_required',
    artifact_refs: [],
    processing_started_at: new Date(),
    processing_completed_at: new Date(),
    created_at: new Date(),
    updated_at: new Date(),
    schema_version: 1,
  };
}

function confirmedGeometryPayload(
  owner,
  projectIdValue,
  geometryId,
  coordinateSpace,
  boundaryType = 'rectangle',
) {
  return {
    geometry_id: geometryId,
    project_id: projectIdValue,
    owner_uid: owner.uid,
    job_id: 'job-1',
    source_image_id: 'source-1',
    opencv_result_id: 'result-1',
    coordinate_space: coordinateSpace,
    boundary_type: boundaryType,
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
    id: 'fs-opencv-image-pixels-allow',
    run: async () => {
      const owner = await createSignedInUser('opencv-owner');
      const projectIdValue = await createProjectSetup(owner, 'opencv-allow');
      await setDoc(
        doc(db, 'projects', projectIdValue, 'opencv_results', 'result-1'),
        openCvPayload(owner, projectIdValue, 'result-1', 'image_pixels'),
      );
      const snapshot = await getDoc(
        doc(db, 'projects', projectIdValue, 'opencv_results', 'result-1'),
      );
      if (snapshot.data()?.coordinate_space !== 'image_pixels') {
        throw new Error('OpenCV result did not persist as image_pixels.');
      }
    },
  },
  {
    id: 'fs-opencv-meters-deny',
    run: async () => {
      const owner = await createSignedInUser('opencv-meters-owner');
      const projectIdValue = await createProjectSetup(owner, 'opencv-meters');
      await expectPermissionDenied(() =>
        setDoc(
          doc(db, 'projects', projectIdValue, 'opencv_results', 'result-1'),
          openCvPayload(owner, projectIdValue, 'result-1', 'meters'),
        ),
      );
    },
  },
  {
    id: 'fs-opencv-created-at-update-deny',
    run: async () => {
      const owner = await createSignedInUser('opencv-update-owner');
      const projectIdValue = await createProjectSetup(owner, 'opencv-update');
      const validPayload = openCvPayload(
        owner,
        projectIdValue,
        'result-1',
        'image_pixels',
      );
      await setDoc(
        doc(db, 'projects', projectIdValue, 'opencv_results', 'result-1'),
        validPayload,
      );
      await expectPermissionDenied(() =>
        setDoc(doc(db, 'projects', projectIdValue, 'opencv_results', 'result-1'), {
          ...validPayload,
          created_at: new Date(Date.now() + 1000),
        }),
      );
    },
  },
  {
    id: 'fs-confirmed-geometry-image-pixels-allow',
    run: async () => {
      const owner = await createSignedInUser('confirmed-owner');
      const projectIdValue = await createProjectSetup(owner, 'confirmed-allow');
      await setDoc(
        doc(db, 'projects', projectIdValue, 'opencv_results', 'result-1'),
        openCvPayload(owner, projectIdValue, 'result-1', 'image_pixels'),
      );
      await setDoc(
        doc(db, 'projects', projectIdValue, 'confirmed_geometries', 'geometry-1'),
        confirmedGeometryPayload(owner, projectIdValue, 'geometry-1', 'image_pixels'),
      );
      const snapshot = await getDoc(
        doc(db, 'projects', projectIdValue, 'confirmed_geometries', 'geometry-1'),
      );
      if (snapshot.data()?.coordinate_space !== 'image_pixels') {
        throw new Error('Confirmed geometry did not persist as image_pixels.');
      }
    },
  },
  {
    id: 'fs-confirmed-geometry-meters-deny',
    run: async () => {
      const owner = await createSignedInUser('confirmed-meters-owner');
      const projectIdValue = await createProjectSetup(owner, 'confirmed-meters');
      await setDoc(
        doc(db, 'projects', projectIdValue, 'opencv_results', 'result-1'),
        openCvPayload(owner, projectIdValue, 'result-1', 'image_pixels'),
      );
      await expectPermissionDenied(() =>
        setDoc(
          doc(db, 'projects', projectIdValue, 'confirmed_geometries', 'geometry-1'),
          confirmedGeometryPayload(owner, projectIdValue, 'geometry-1', 'meters'),
        ),
      );
    },
  },
  {
    id: 'fs-confirmed-geometry-created-at-update-deny',
    run: async () => {
      const owner = await createSignedInUser('confirmed-update-owner');
      const projectIdValue = await createProjectSetup(owner, 'confirmed-update');
      await setDoc(
        doc(db, 'projects', projectIdValue, 'opencv_results', 'result-1'),
        openCvPayload(owner, projectIdValue, 'result-1', 'image_pixels'),
      );
      const validPayload = confirmedGeometryPayload(
        owner,
        projectIdValue,
        'geometry-1',
        'image_pixels',
      );
      await setDoc(
        doc(db, 'projects', projectIdValue, 'confirmed_geometries', 'geometry-1'),
        validPayload,
      );
      await expectPermissionDenied(() =>
        setDoc(
          doc(db, 'projects', projectIdValue, 'confirmed_geometries', 'geometry-1'),
          {
            ...validPayload,
            created_at: new Date(Date.now() + 1000),
          },
        ),
      );
    },
  },
  {
    id: 'fs-confirmed-geometry-opencv-job-mismatch-deny',
    run: async () => {
      const owner = await createSignedInUser('confirmed-link-owner');
      const projectIdValue = await createProjectSetup(owner, 'confirmed-link');
      await createJobWithTransition(owner, projectIdValue, 'job-2');
      await setDoc(
        doc(db, 'projects', projectIdValue, 'opencv_results', 'result-2'),
        {
          ...openCvPayload(owner, projectIdValue, 'result-2', 'image_pixels'),
          job_id: 'job-2',
        },
      );
      await expectPermissionDenied(() =>
        setDoc(
          doc(db, 'projects', projectIdValue, 'confirmed_geometries', 'geometry-1'),
          {
            ...confirmedGeometryPayload(
              owner,
              projectIdValue,
              'geometry-1',
              'image_pixels',
            ),
            opencv_result_id: 'result-2',
          },
        ),
      );
    },
  },
  {
    id: 'fs-confirmed-geometry-shape-allow',
    run: async () => {
      const owner = await createSignedInUser('confirmed-shape-owner');
      const projectIdValue = await createProjectSetup(owner, 'confirmed-shape');
      await setDoc(
        doc(db, 'projects', projectIdValue, 'opencv_results', 'result-1'),
        openCvPayload(owner, projectIdValue, 'result-1', 'image_pixels'),
      );
      await setDoc(
        doc(db, 'projects', projectIdValue, 'confirmed_geometries', 'geometry-1'),
        confirmedGeometryPayload(
          owner,
          projectIdValue,
          'geometry-1',
          'image_pixels',
          'simple_polygon',
        ),
      );
    },
  },
  {
    id: 'fs-candidate-confirmed-mix-deny',
    run: async () => {
      const owner = await createSignedInUser('candidate-mix-owner');
      const projectIdValue = await createProjectSetup(owner, 'candidate-mix');
      await expectPermissionDenied(() =>
        setDoc(
          doc(db, 'projects', projectIdValue, 'confirmed_geometries', 'geometry-1'),
          openCvPayload(owner, projectIdValue, 'result-1', 'image_pixels'),
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
