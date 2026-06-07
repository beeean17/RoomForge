import { readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const editorRoot = path.resolve(scriptDir, '..')
const repoRoot = path.resolve(editorRoot, '..')
const defaultManifestPath = path.join(
  editorRoot,
  'fixtures',
  'cv-evaluation',
  'manifest.example.json',
)

const allowedRoles = new Set([
  'overview',
  'front_wall',
  'right_wall',
  'back_wall',
  'left_wall',
  'extra',
])
const allowedObjectTypes = new Set(['furniture', 'structural_fixture'])
const requiredIgnorePatterns = [
  'editor/fixtures/cv-evaluation/local/',
  'editor/fixtures/cv-evaluation/**/*.jpg',
  'editor/fixtures/cv-evaluation/**/*.png',
  'editor/fixtures/cv-evaluation/**/*.heic',
  'editor/fixtures/cv-evaluation/**/*.depth.json',
]

const manifestPaths = process.argv.slice(2)
const targets =
  manifestPaths.length > 0
    ? manifestPaths.map((item) => path.resolve(process.cwd(), item))
    : [defaultManifestPath]

const errors = []

validateGitIgnore(errors)

for (const target of targets) {
  validateManifestFile(target, errors)
}

if (errors.length > 0) {
  for (const error of errors) {
    console.error(`FAIL ${error}`)
  }
  process.exit(1)
}

console.log(`Validated ${targets.length} CV evaluation manifest file(s).`)

function validateGitIgnore(result) {
  const ignorePath = path.join(repoRoot, '.gitignore')
  const content = readFileSync(ignorePath, 'utf8')
  for (const pattern of requiredIgnorePatterns) {
    if (!content.includes(pattern)) {
      result.push(`.gitignore must include ${pattern}`)
    }
  }
}

function validateManifestFile(manifestPath, result) {
  let manifest
  try {
    manifest = JSON.parse(readFileSync(manifestPath, 'utf8'))
  } catch (error) {
    result.push(`${relativePath(manifestPath)} is not valid JSON: ${error.message}`)
    return
  }

  const root = recordValue(manifest)
  if (root.schemaVersion !== 1) {
    result.push(`${relativePath(manifestPath)} schemaVersion must be 1`)
  }
  const fixtures = arrayValue(root.fixtures)
  if (fixtures.length === 0) {
    result.push(`${relativePath(manifestPath)} fixtures must contain at least one fixture`)
    return
  }

  const fixtureIds = new Set()
  fixtures.forEach((fixtureValue, index) => {
    const fixture = recordValue(fixtureValue)
    const context = `${relativePath(manifestPath)} fixtures[${index}]`
    const fixtureId = requiredString(fixture.fixtureId, `${context}.fixtureId`, result)
    if (fixtureId) {
      if (fixtureIds.has(fixtureId)) {
        result.push(`${context}.fixtureId must be unique`)
      }
      fixtureIds.add(fixtureId)
    }
    optionalString(fixture.description, `${context}.description`, result)
    validateRoom(recordValue(fixture.room), `${context}.room`, result)
    const imageRoles = validateImages(arrayValue(fixture.images), `${context}.images`, result)
    validateExpectedObjects(
      arrayValue(fixture.expectedObjects),
      imageRoles,
      `${context}.expectedObjects`,
      result,
    )
    validateMetrics(recordValue(fixture.metrics), `${context}.metrics`, result)
  })
}

function validateRoom(room, context, result) {
  positiveNumber(room.widthMeters, `${context}.widthMeters`, result)
  positiveNumber(room.depthMeters, `${context}.depthMeters`, result)
  positiveNumber(room.heightMeters, `${context}.heightMeters`, result)
}

function validateImages(images, context, result) {
  if (images.length === 0) {
    result.push(`${context} must contain at least one image`)
    return new Set()
  }
  const roles = new Set()
  const imageIds = new Set()
  images.forEach((imageValue, index) => {
    const image = recordValue(imageValue)
    const itemContext = `${context}[${index}]`
    const imageId = requiredString(image.imageId, `${itemContext}.imageId`, result)
    if (imageId) {
      if (imageIds.has(imageId)) {
        result.push(`${itemContext}.imageId must be unique`)
      }
      imageIds.add(imageId)
    }
    const role = requiredString(image.role, `${itemContext}.role`, result)
    if (role && !allowedRoles.has(role)) {
      result.push(`${itemContext}.role must be one of ${[...allowedRoles].join(', ')}`)
    }
    if (role) {
      roles.add(role)
    }
    const imagePath = requiredString(image.path, `${itemContext}.path`, result)
    if (imagePath) {
      validateLocalImagePath(imagePath, `${itemContext}.path`, result)
    }
    positiveNumber(image.widthPx, `${itemContext}.widthPx`, result)
    positiveNumber(image.heightPx, `${itemContext}.heightPx`, result)
  })
  return roles
}

function validateExpectedObjects(objects, imageRoles, context, result) {
  if (objects.length === 0) {
    result.push(`${context} must contain at least one expected object`)
    return
  }
  const objectIds = new Set()
  objects.forEach((objectValue, index) => {
    const object = recordValue(objectValue)
    const itemContext = `${context}[${index}]`
    const objectId = requiredString(object.objectId, `${itemContext}.objectId`, result)
    if (objectId) {
      if (objectIds.has(objectId)) {
        result.push(`${itemContext}.objectId must be unique`)
      }
      objectIds.add(objectId)
    }
    const objectType = requiredString(object.objectType, `${itemContext}.objectType`, result)
    if (objectType && !allowedObjectTypes.has(objectType)) {
      result.push(`${itemContext}.objectType must be furniture or structural_fixture`)
    }
    requiredString(object.category, `${itemContext}.category`, result)
    const visibleIn = stringArrayValue(object.visibleIn)
    if (visibleIn.length === 0) {
      result.push(`${itemContext}.visibleIn must contain at least one image role`)
    }
    for (const role of visibleIn) {
      if (!allowedRoles.has(role)) {
        result.push(`${itemContext}.visibleIn contains unsupported role ${role}`)
      } else if (!imageRoles.has(role)) {
        result.push(`${itemContext}.visibleIn role ${role} must exist in images`)
      }
    }
    const wallRole = optionalString(object.wallRole, `${itemContext}.wallRole`, result)
    if (wallRole && !allowedRoles.has(wallRole)) {
      result.push(`${itemContext}.wallRole must be one of ${[...allowedRoles].join(', ')}`)
    }
    validatePoint(recordValue(object.approxPositionMeters), `${itemContext}.approxPositionMeters`, result)
    validatePoint(recordValue(object.approxSizeMeters), `${itemContext}.approxSizeMeters`, result)
    positiveNumber(
      object.positionToleranceMeters,
      `${itemContext}.positionToleranceMeters`,
      result,
    )
    positiveNumber(object.sizeToleranceMeters, `${itemContext}.sizeToleranceMeters`, result)
    nonNegativeInteger(object.expectedCorrections, `${itemContext}.expectedCorrections`, result)
  })
}

function validateMetrics(metrics, context, result) {
  if (Object.keys(metrics).length === 0) {
    return
  }
  nonNegativeInteger(metrics.expectedDetectionCount, `${context}.expectedDetectionCount`, result)
  optionalString(metrics.notes, `${context}.notes`, result)
}

function validatePoint(point, context, result) {
  finiteNumber(point.x, `${context}.x`, result)
  finiteNumber(point.y, `${context}.y`, result)
  finiteNumber(point.z, `${context}.z`, result)
}

function validateLocalImagePath(value, context, result) {
  if (path.isAbsolute(value)) {
    result.push(`${context} must be repo-relative, not absolute`)
  }
  if (value.split(/[\\/]/).includes('..')) {
    result.push(`${context} must not traverse outside the fixture directory`)
  }
  if (/^[a-z][a-z0-9+.-]*:/i.test(value)) {
    result.push(`${context} must be a local path, not a URL`)
  }
}

function recordValue(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? value : {}
}

function arrayValue(value) {
  return Array.isArray(value) ? value : []
}

function stringArrayValue(value) {
  return Array.isArray(value) ? value.filter((item) => typeof item === 'string') : []
}

function requiredString(value, context, result) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    result.push(`${context} must be a non-empty string`)
    return ''
  }
  return value
}

function optionalString(value, context, result) {
  if (value === undefined) {
    return undefined
  }
  if (typeof value !== 'string') {
    result.push(`${context} must be a string when provided`)
    return undefined
  }
  return value
}

function positiveNumber(value, context, result) {
  if (typeof value !== 'number' || !Number.isFinite(value) || value <= 0) {
    result.push(`${context} must be a positive number`)
  }
}

function finiteNumber(value, context, result) {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    result.push(`${context} must be a finite number`)
  }
}

function nonNegativeInteger(value, context, result) {
  if (value === undefined) {
    return
  }
  if (!Number.isInteger(value) || value < 0) {
    result.push(`${context} must be a non-negative integer when provided`)
  }
}

function relativePath(value) {
  return path.relative(repoRoot, value)
}
