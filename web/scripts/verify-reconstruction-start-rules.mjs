import { initializeApp, deleteApp } from 'firebase/app'
import {
  connectAuthEmulator,
  createUserWithEmailAndPassword,
  getAuth,
} from 'firebase/auth'
import {
  connectFirestoreEmulator,
  collection,
  doc,
  getFirestore,
  orderBy,
  query,
  limit,
  getDocs,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore'

const projectId = process.env.GCLOUD_PROJECT || 'roomforge-local'
const app = initializeApp({
  apiKey: 'roomforge-local-api-key',
  appId: 'roomforge-local-app-id',
  authDomain: `${projectId}.firebaseapp.com`,
  messagingSenderId: '000000000000',
  projectId,
})

const auth = getAuth(app)
const db = getFirestore(app)
connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true })
connectFirestoreEmulator(db, '127.0.0.1', 8080)

const runId = `${Date.now()}-${Math.floor(Math.random() * 100000)}`

async function main() {
  const credential = await createUserWithEmailAndPassword(
    auth,
    `conversion-start-${runId}@example.test`,
    'Password123!',
  )
  const owner = credential.user
  const id = `conversion-start-${runId}`
  const timestamp = serverTimestamp()

  await setDoc(doc(db, 'projects', id), {
    project_id: id,
    owner_uid: owner.uid,
    name: 'Conversion start rules test',
    schema_version: 1,
    created_at: timestamp,
    updated_at: timestamp,
    source_image_count: 0,
    source_capture_complete: false,
    current_pipeline_step: 'source',
    pipeline_progress: 0,
  })

  await setDoc(doc(db, 'projects', id, 'room_dimensions', 'current'), {
    project_id: id,
    owner_uid: owner.uid,
    width_m: 5.2,
    depth_m: 6,
    height_m: 2.8,
    unit: 'meters',
    source: 'web_source_form',
    created_at: timestamp,
    updated_at: timestamp,
    schema_version: 1,
  })

  await setDoc(doc(db, 'projects', id, 'source_images', 'source-old'), sourceImage(owner.uid, id, 'source-old', 1))
  await setDoc(doc(db, 'projects', id, 'source_images', 'source-new'), sourceImage(owner.uid, id, 'source-new', 2))

  const latest = await getDocs(
    query(
      collection(db, 'projects', id, 'source_images'),
      orderBy('uploaded_at', 'desc'),
      limit(1),
    ),
  )
  const sourceImageId = latest.docs[0]?.id
  if (sourceImageId !== 'source-new') {
    throw new Error(`Expected latest source-new, received ${sourceImageId}`)
  }

  const projectRef = doc(db, 'projects', id)
  const jobRef = doc(collection(db, 'projects', id, 'reconstruction_jobs'))
  const transitionRef = doc(collection(db, 'projects', id, 'reconstruction_jobs', jobRef.id, 'transitions'))
  const batch = writeBatch(db)

  batch.set(jobRef, {
    job_id: jobRef.id,
    project_id: id,
    owner_uid: owner.uid,
    source_image_id: sourceImageId,
    room_dimensions_id: 'current',
    status: 'created',
    status_updated_at: timestamp,
    provider_type: 'manual_assisted_opencv',
    algorithm_id: 'opencv_lines_corners_v1',
    created_by_uid: owner.uid,
    root_job_id: jobRef.id,
    retry_count: 0,
    latest_transition_id: transitionRef.id,
    created_at: timestamp,
    updated_at: timestamp,
    schema_version: 1,
  })
  batch.set(transitionRef, {
    transition_id: transitionRef.id,
    project_id: id,
    owner_uid: owner.uid,
    job_id: jobRef.id,
    to_status: 'created',
    occurred_at: timestamp,
    actor_type: 'user',
    actor_uid: owner.uid,
    reason_code: 'user_submitted',
    reason_message: 'Reconstruction job created from source image.',
    schema_version: 1,
  })

  await batch.commit()

  await updateDoc(projectRef, {
    latest_source_image_id: sourceImageId,
    latest_job_id: jobRef.id,
    current_reconstruction_status: 'created',
    current_pipeline_step: 'status',
    pipeline_progress: 12,
    updated_at: timestamp,
  })
  console.log('Reconstruction start Firestore rules contract verified')
}

function sourceImage(ownerUid, projectIdValue, sourceImageId, order) {
  return {
    source_image_id: sourceImageId,
    project_id: projectIdValue,
    owner_uid: ownerUid,
    storage_path: `users/${ownerUid}/projects/${projectIdValue}/source-images/${sourceImageId}/room.jpg`,
    original_filename: 'room.jpg',
    stored_filename: 'room.jpg',
    content_type: 'image/jpeg',
    byte_size: 4,
    sha256_hex: '9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a',
    width_px: 1280,
    height_px: 720,
    capture_source: 'file_upload',
    retention_status: 'active',
    uploaded_at: new Date(Date.now() + order),
    created_at: new Date(Date.now() + order),
    updated_at: new Date(Date.now() + order),
    schema_version: 1,
  }
}

main()
  .finally(async () => {
    await deleteApp(app)
  })
