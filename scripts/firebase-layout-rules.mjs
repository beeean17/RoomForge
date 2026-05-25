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
const sourceTimestamp = new Date('2026-05-24T12:00:00.000Z');
const snapshotTimestamp = new Date('2026-05-24T12:10:00.000Z');

async function createSignedInUser(prefix) {
  const credential = await createUserWithEmailAndPassword(
    auth,
    `${prefix}-${runId}@example.test`,
    'Password123!',
  );
  return credential.user;
}

async function createProjectSetup(owner, suffix) {
  const id = `layout-project-${suffix}-${runId}`;
  await setDoc(doc(db, 'projects', id), {
    project_id: id,
    owner_uid: owner.uid,
    name: `Layout Project ${suffix}`,
    schema_version: 1,
    created_at: snapshotTimestamp,
    updated_at: snapshotTimestamp,
  });
  await setDoc(doc(db, 'projects', id, 'room_dimensions', 'current'), {
    project_id: id,
    owner_uid: owner.uid,
    width_m: 4.2,
    depth_m: 3.6,
    height_m: 2.7,
    unit: 'meters',
    source: 'user_entered',
    created_at: snapshotTimestamp,
    updated_at: snapshotTimestamp,
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
    uploaded_at: sourceTimestamp,
    created_at: sourceTimestamp,
    updated_at: sourceTimestamp,
    schema_version: 1,
  });
  await createJobWithTransition(owner, id);
  await setDoc(
    doc(db, 'projects', id, 'confirmed_geometries', 'geometry-1'),
    confirmedGeometryPayload(owner, id),
  );
  await setDoc(
    doc(db, 'projects', id, 'floor_plans', 'floor-plan-1'),
    floorPlanPayload(owner, id),
  );
  await setDoc(
    doc(db, 'projects', id),
    {
      latest_source_image_id: 'source-1',
      latest_job_id: 'job-1',
      latest_floor_plan_id: 'floor-plan-1',
      current_reconstruction_status: 'succeeded',
      updated_at: new Date(),
    },
    { merge: true },
  );
  return id;
}

async function createJobWithTransition(owner, projectIdValue) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'projects', projectIdValue, 'reconstruction_jobs', 'job-1'), {
    job_id: 'job-1',
    project_id: projectIdValue,
    owner_uid: owner.uid,
    source_image_id: 'source-1',
    room_dimensions_id: 'current',
    status: 'succeeded',
    status_updated_at: new Date(),
    provider_type: 'manual_assisted_opencv',
    algorithm_id: 'opencv_lines_corners_v1',
    created_by_uid: owner.uid,
    root_job_id: 'job-1',
    retry_count: 0,
    latest_transition_id: 'transition-job-1',
    latest_floor_plan_id: 'floor-plan-1',
    artifact_refs: [],
    created_at: snapshotTimestamp,
    updated_at: snapshotTimestamp,
    schema_version: 1,
  });
  batch.set(
    doc(
      db,
      'projects',
      projectIdValue,
      'reconstruction_jobs',
      'job-1',
      'transitions',
      'transition-job-1',
    ),
    {
      transition_id: 'transition-job-1',
      project_id: projectIdValue,
      owner_uid: owner.uid,
      job_id: 'job-1',
      to_status: 'succeeded',
      occurred_at: new Date(),
      actor_type: 'user',
      actor_uid: owner.uid,
      reason_code: 'floor_plan_ready',
      reason_message: 'Metric floor plan is ready.',
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
    created_at: snapshotTimestamp,
    updated_at: snapshotTimestamp,
    schema_version: 1,
  };
}

function floorPlanPayload(owner, projectIdValue) {
  return {
    floor_plan_id: 'floor-plan-1',
    project_id: projectIdValue,
    owner_uid: owner.uid,
    job_id: 'job-1',
    source_image_id: 'source-1',
    confirmed_geometry_id: 'geometry-1',
    room_dimensions_id: 'current',
    coordinate_space: 'meters',
    room_dimensions: roomDimensionsSnapshot(owner, projectIdValue),
    floor_polygon: metricFloorPolygon(),
    walls: [],
    calibration: {
      scale_px_per_meter: 100,
      method: 'room_dimensions_rect',
    },
    quality_status: 'success',
    warnings: [],
    artifact_refs: [],
    created_at: snapshotTimestamp,
    updated_at: snapshotTimestamp,
    schema_version: 1,
  };
}

function layoutPayload(owner, projectIdValue, overrides = {}) {
  return {
    layout_id: 'layout-1',
    project_id: projectIdValue,
    owner_uid: owner.uid,
    source_image_id: 'source-1',
    reconstruction_job_id: 'job-1',
    reconstruction_status: 'succeeded',
    review_required: false,
    floor_plan_id: 'floor-plan-1',
    coordinate_space: 'meters',
    room_dimensions: roomDimensionsSnapshot(owner, projectIdValue),
    source_metadata: {
      source_image_id: 'source-1',
      project_id: projectIdValue,
      owner_uid: owner.uid,
      storage_path: `users/${owner.uid}/projects/${projectIdValue}/source-images/source-1/room.jpg`,
      original_filename: 'room.jpg',
      stored_filename: 'room.jpg',
      reconstruction_job_id: 'job-1',
      reconstruction_status: 'succeeded',
      content_type: 'image/jpeg',
      byte_size: 4,
      sha256_hex:
        '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
      width_px: 1280,
      height_px: 720,
      capture_source: 'file_upload',
      retention_status: 'active',
      uploaded_at: sourceTimestamp,
      created_at: sourceTimestamp,
      updated_at: sourceTimestamp,
      schema_version: 1,
    },
    floor_plan: floorPlanPayload(owner, projectIdValue),
    editor_scene: {
      scene_id: 'scene-1',
      view_mode: '3d',
      has_unsaved_changes: false,
    },
    furniture_objects: [
      {
        furniture_id: 'chair-1',
        category: 'chair',
        position_m: { x: 1, y: 0, z: 1 },
        size_m: { x: 0.6, y: 0.8, z: 0.6 },
        rotation_deg: 0,
        color: '#64748b',
      },
    ],
    saved_at: new Date(),
    created_at: new Date(),
    updated_at: new Date(),
    schema_version: 1,
    export_version: 1,
    ...overrides,
  };
}

function roomDimensionsSnapshot(owner, projectIdValue) {
  return {
    project_id: projectIdValue,
    owner_uid: owner.uid,
    width_m: 4.2,
    depth_m: 3.6,
    height_m: 2.7,
    unit: 'meters',
    source: 'user_entered',
    created_at: snapshotTimestamp,
    updated_at: snapshotTimestamp,
    schema_version: 1,
  };
}

function metricFloorPolygon() {
  return [
    { x: 0, y: 0 },
    { x: 4.2, y: 0 },
    { x: 4.2, y: 3.6 },
    { x: 0, y: 3.6 },
  ];
}

async function expectPermissionDenied(operation) {
  try {
    await operation();
  } catch (error) {
    const message = String(error?.message ?? '');
    if (
      error?.code === 'permission-denied' ||
      error?.code === 7 ||
      message.includes('PERMISSION_DENIED')
    ) {
      return;
    }
    throw error;
  }

  throw new Error('Expected permission-denied, but operation succeeded.');
}

const tests = [
  {
    id: 'fs-layout-owner-roundtrip-write-allow',
    run: async () => {
      const owner = await createSignedInUser('layout-owner');
      const projectIdValue = await createProjectSetup(owner, 'roundtrip');
      await setDoc(
        doc(db, 'projects', projectIdValue, 'layouts', 'layout-1'),
        layoutPayload(owner, projectIdValue),
      );
      const snapshot = await getDoc(
        doc(db, 'projects', projectIdValue, 'layouts', 'layout-1'),
      );
      const data = snapshot.data();
      if (data?.coordinate_space !== 'meters') {
        throw new Error('Layout did not persist in meters.');
      }
      if (data?.furniture_objects?.[0]?.furniture_id !== 'chair-1') {
        throw new Error('Layout furniture object did not round-trip.');
      }
      if (data?.floor_plan?.floor_plan_id !== 'floor-plan-1') {
        throw new Error('Layout floor plan snapshot was not preserved.');
      }
    },
  },
  {
    id: 'fs-layout-non-owner-read-deny',
    run: async () => {
      const owner = await createSignedInUser('layout-owner-deny');
      const projectIdValue = await createProjectSetup(owner, 'read-deny');
      await setDoc(
        doc(db, 'projects', projectIdValue, 'layouts', 'layout-1'),
        layoutPayload(owner, projectIdValue),
      );
      await createSignedInUser('layout-other-user');
      await expectPermissionDenied(() =>
        getDoc(doc(db, 'projects', projectIdValue, 'layouts', 'layout-1')),
      );
    },
  },
  {
    id: 'fs-layout-invalid-status-deny',
    run: async () => {
      const owner = await createSignedInUser('layout-invalid-status');
      const projectIdValue = await createProjectSetup(owner, 'bad-status');
      await expectPermissionDenied(() =>
        setDoc(
          doc(db, 'projects', projectIdValue, 'layouts', 'layout-1'),
          layoutPayload(owner, projectIdValue, {
            reconstruction_status: 'done',
            source_metadata: {
              source_image_id: 'source-1',
              reconstruction_job_id: 'job-1',
              reconstruction_status: 'done',
            },
          }),
        ),
      );
    },
  },
  {
    id: 'fs-layout-missing-furniture-field-deny',
    run: async () => {
      const owner = await createSignedInUser('layout-missing-furniture');
      const projectIdValue = await createProjectSetup(owner, 'bad-furniture');
      const payload = layoutPayload(owner, projectIdValue);
      delete payload.furniture_objects[0].position_m;
      await expectPermissionDenied(() =>
        setDoc(doc(db, 'projects', projectIdValue, 'layouts', 'layout-1'), payload),
      );
    },
  },
  {
    id: 'fs-layout-zero-size-furniture-deny',
    run: async () => {
      const owner = await createSignedInUser('layout-zero-size-furniture');
      const projectIdValue = await createProjectSetup(owner, 'zero-furniture');
      const payload = layoutPayload(owner, projectIdValue);
      payload.furniture_objects[0].size_m.x = 0;
      await expectPermissionDenied(() =>
        setDoc(doc(db, 'projects', projectIdValue, 'layouts', 'layout-1'), payload),
      );
    },
  },
  {
    id: 'fs-layout-invalid-timestamp-deny',
    run: async () => {
      const owner = await createSignedInUser('layout-invalid-timestamp');
      const projectIdValue = await createProjectSetup(owner, 'bad-timestamp');
      await expectPermissionDenied(() =>
        setDoc(
          doc(db, 'projects', projectIdValue, 'layouts', 'layout-1'),
          layoutPayload(owner, projectIdValue, {
            saved_at: 'not-a-timestamp',
          }),
        ),
      );
    },
  },
  {
    id: 'fs-layout-incomplete-source-metadata-deny',
    run: async () => {
      const owner = await createSignedInUser('layout-source-incomplete');
      const projectIdValue = await createProjectSetup(owner, 'bad-source-metadata');
      const payload = layoutPayload(owner, projectIdValue);
      delete payload.source_metadata.sha256_hex;
      await expectPermissionDenied(() =>
        setDoc(doc(db, 'projects', projectIdValue, 'layouts', 'layout-1'), payload),
      );
    },
  },
  {
    id: 'fs-layout-incomplete-source-snapshot-deny',
    run: async () => {
      const owner = await createSignedInUser('layout-source-snapshot-incomplete');
      const projectIdValue = await createProjectSetup(owner, 'bad-source-snapshot');
      const payload = layoutPayload(owner, projectIdValue);
      delete payload.source_metadata.storage_path;
      await expectPermissionDenied(() =>
        setDoc(doc(db, 'projects', projectIdValue, 'layouts', 'layout-1'), payload),
      );
    },
  },
  {
    id: 'fs-layout-forged-source-reference-deny',
    run: async () => {
      const owner = await createSignedInUser('layout-forged-source-ref');
      const projectIdValue = await createProjectSetup(owner, 'forged-source-ref');
      const payload = layoutPayload(owner, projectIdValue);
      payload.source_image_id = 'missing-source';
      payload.source_metadata.source_image_id = 'missing-source';
      await expectPermissionDenied(() =>
        setDoc(doc(db, 'projects', projectIdValue, 'layouts', 'layout-1'), payload),
      );
    },
  },
  {
    id: 'fs-layout-incomplete-floor-plan-snapshot-deny',
    run: async () => {
      const owner = await createSignedInUser('layout-incomplete-floor-plan');
      const projectIdValue = await createProjectSetup(owner, 'bad-floor-plan');
      const payload = layoutPayload(owner, projectIdValue);
      delete payload.floor_plan.confirmed_geometry_id;
      await expectPermissionDenied(() =>
        setDoc(doc(db, 'projects', projectIdValue, 'layouts', 'layout-1'), payload),
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
