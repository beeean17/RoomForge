---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-02b-vision
  - step-02c-executive-summary
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
inputDocuments:
  - _bmad-output/planning-artifacts/product-brief-RoomForge.md
  - notes/basic_document.md
workflowType: "prd"
workflow: "edit"
documentCounts:
  productBriefs: 1
  research: 0
  brainstorming: 0
  projectDocs: 0
contextNotes:
  - "Architecture constraint from user: lightweight app/API server runs on Oracle Cloud 1GB RAM; the MVP must not depend on heavy server-side CV/GPU processing on that server."
  - "Course correction from user: this is a computer vision term project, so the MVP needs an OpenCV-centered killer feature."
  - "Client priority from user: web first; smartphone support later should include direct photo capture."
  - "Deployment/auth from user: Firebase deploy for client hosting and Firebase Google Auth for authentication."
  - "GPU direction after course correction: external GPU inference is optional/post-MVP, not a Phase 1 dependency."
  - "MVP intent from user: MVP should be an actually usable app, not only a presentation/demo artifact."
  - "Storage decision from user: MVP storage should use an Oracle database, not Firestore as the primary application data store."
  - "3D viewer direction: Flutter app shell with a web-first Three.js room/furniture editor."
  - "Reconstruction direction after course correction: use OpenCV-assisted line/corner detection, perspective geometry, user correction, and metric scale calibration as the MVP CV workflow."
  - "Admin decision from user: MVP requires an admin screen for job/provider monitoring, failed job recovery, and user/project/layout lookup."
classification:
  projectType: "cross_platform_flutter_web_first"
  domain: "scientific"
  complexity: "medium"
  projectContext: "greenfield"
releaseMode: "phased"
lastEdited: "2026-05-07"
editHistory:
  - date: "2026-05-07"
    changes: "Applied validation-guided PRD improvements: measurable NFRs, scientific validation thresholds, project-type technical boundaries, API/status/data outlines, and FR50 specificity."
  - date: "2026-05-07"
    changes: "Course correction: shifted Phase 1 from required external GPU inference to OpenCV-assisted reconstruction as the MVP computer vision killer feature; moved GPU inference to optional/post-MVP provider."
---

# Product Requirements Document - RoomForge

**Author:** Yoon
**Date:** 2026-05-07

## Executive Summary

RoomForge is a web-first indoor layout reconstruction and furniture placement application with planned smartphone support. The MVP prioritizes a usable web client and a clear computer vision term-project contribution: an OpenCV-assisted workflow that turns a room photo, user-corrected geometry, and real room dimensions into an editable metric 2D/3D layout. Flutter is considered as the client technology to support Firebase-hosted web deployment and future mobile capture workflows.

RoomForge enables users to upload a single horizontally captured room photo, enter real room dimensions, and generate a simple metric 3D room layout that can be edited with proxy furniture objects. The product targets users who need practical furniture layout decisions but do not want to manually draw a floor plan or rely on image-only interior redesign tools.

The MVP focuses on constrained OpenCV-assisted reconstruction rather than fully automatic 3D scene recovery. RoomForge uses a horizontal camera prior, user-provided room dimensions, OpenCV line/edge/corner detection, user-assisted floor or room-boundary correction, perspective geometry, and metric scale calibration to create a rectangular or simple polygonal metric floor plan. The resulting layout is used to generate a basic 3D room scene where users can add, move, rotate, resize, delete, save, and export furniture arrangements.

The system uses a lightweight backend architecture. Firebase supports client deployment and Google authentication. A lightweight Oracle Cloud 1GB RAM server should avoid heavy computer vision or GPU work and primarily handle data retrieval, request coordination, job metadata, and API integration responsibilities. Oracle DB is the MVP application data store. The core MVP must work without an external GPU server by using a manual-assisted/OpenCV reconstruction provider. GPU depth or segmentation can be added later as an optional inference provider through the same asynchronous job/result contract. The 3D editing experience should use a Flutter app shell with an integrated web-first Three.js editor.

### What Makes This Special

RoomForge's core differentiator is its pragmatic treatment of single-image reconstruction as an explainable OpenCV workflow. It does not promise photorealistic, fully automatic room recovery. Instead, it uses user-provided dimensions as a metric anchor, OpenCV-detected visual structure as a starting point, and user correction as a normal part of the flow to produce an editable layout that is useful for furniture planning.

The key insight is that furniture placement does not require perfect reconstruction of every object in the source image. Users need a trustworthy room scale, an editable floor plan, and direct control over furniture proxies. This allows RoomForge to avoid high-risk MVP scope such as automatic furniture mesh recovery, AR placement, non-rectangular room reconstruction, and real product asset matching.

Users will choose RoomForge over alternatives when they need a bridge between a real room photo and a to-scale editable planning environment. Photo redesign tools generate visual inspiration, while traditional planners require manual room modeling. RoomForge occupies the middle: image-grounded, dimension-calibrated, and editable.

## Project Classification

RoomForge is classified as a greenfield web-first cross-platform Flutter application with Firebase deployment/authentication and a lightweight web/API backend. Its domain is applied computer vision, with medium complexity: the product includes interactive 2D/3D client requirements, an OpenCV-assisted reconstruction pipeline, computer vision quality risks, Firebase authentication/deployment, and a lightweight Oracle-backed data architecture, but it does not operate in a regulated domain.

The primary product surface is a browser-based experience. The supporting system includes Firebase Hosting, Firebase Google Auth, a lightweight Oracle Cloud API/data server, Oracle DB, and an optional asynchronous inference-provider interface. External GPU inference is a post-MVP enhancement, not a Phase 1 prerequisite.

## Success Criteria

### User Success

Users can complete the full RoomForge workflow without developer assistance: authenticate with Google, access the web client, upload or provide a room photo, enter room dimensions, trigger reconstruction, inspect the generated room, place proxy furniture, and save or export the final layout.

The primary user success moment is when a user sees a real room photo become an editable, dimension-calibrated room where furniture can be tested at approximate real scale. The MVP should prioritize trust and control over visual magic: users should understand when the result is reliable, when input quality is poor, and how to adjust the layout.

### Business Success

The MVP is successful if it functions as a usable deployed application, not only a local demo or presentation artifact. It should be deployable through Firebase for the client experience, use Firebase Google Auth for user access, and rely on a lightweight Oracle Cloud server for data/API coordination.

Near-term business success is demonstrated by a stable end-to-end app that can be used repeatedly on real room examples. Longer-term success depends on reducing user effort compared with manual room planners while providing more spatial utility than image-only interior redesign tools.

### Technical Success

The system successfully separates lightweight application responsibilities from computer vision execution and reconstruction-result storage. The Oracle Cloud 1GB RAM server must avoid heavy image processing, model inference, and GPU workloads. It should focus on data retrieval, request coordination, job/result metadata, API integration, and persistence.

The MVP reconstruction path should be OpenCV-assisted and manual-correction friendly. It should support line/edge/corner detection, user-selected or user-corrected room boundaries, perspective or homography-based reasoning where applicable, metric scale calibration from user dimensions, and generation of a 2D floor plan that can be extruded into a simple 3D room.

The MVP storage layer should use an Oracle database as the primary application data store. Firebase is used for hosting and Google authentication, while RoomForge application data such as user mappings, room projects, layout JSON, reconstruction attempts/jobs, OpenCV result metadata, and optional inference result metadata are stored through the Oracle-backed API layer.

The reconstruction pipeline should produce a rectangular or simple polygonal metric floor plan from valid inputs using user-entered room dimensions as the scale anchor. The 3D editor should use a Flutter app shell with a web-first Three.js room/furniture editor so that editable room and furniture interactions are not constrained by passive model-viewer packages.

### Measurable Outcomes

- A user can complete the web flow from login to saved/exported layout on a valid input image.
- The web client can be deployed through Firebase.
- Users can authenticate with Google through Firebase Auth.
- The Oracle Cloud 1GB RAM server does not run heavy OpenCV processing, model inference, or GPU inference.
- The system stores users, projects, layout JSON, reconstruction attempts/jobs, OpenCV result metadata, and optional inference result metadata in an Oracle database.
- The system can run or coordinate an OpenCV-assisted reconstruction flow that exposes candidate lines/corners/boundaries, accepts user correction, applies metric scale calibration, and returns an editable floor plan.
- The generated room export preserves room dimensions, camera/input metadata, floor plan data, and furniture object state.
- Users can place and edit at least five furniture proxy categories: bed, desk, chair, wardrobe, and sofa.
- The app provides input quality guidance or failure feedback when the photo is unsuitable.
- The project produces visual evaluation artifacts: source image, OpenCV edge/line/corner overlays, corrected boundary points, perspective/scale calibration output, metric floor plan, 3D room, and final layout.
- The project can compare at least the core ablation conditions: manual baseline, OpenCV candidate assistance only, metric anchor only, and OpenCV assistance plus metric anchor.

## Product Scope

### MVP - Minimum Viable Product

The MVP includes a web-first client experience, Firebase deployment, Firebase Google Auth, room photo upload, room dimension entry, OpenCV-assisted reconstruction, user-correctable room boundary editing, Oracle database-backed persistence, reconstruction attempt/job metadata, metric floor plan generation, 2D/3D room viewing/editing, proxy furniture editing, and layout save/export.

The client should use Flutter as the product shell and should embed or integrate a web-first Three.js editor for the editable 3D room experience. The MVP should prioritize the web client first, while preserving a path to smartphone support with direct camera capture.

The MVP must be usable as an application. It should not depend on an external GPU server or manual developer intervention for the main user flow. GPU inference can be added later through an optional provider, but the core OpenCV-assisted/manual-correction workflow must work without it.

### Growth Features (Post-MVP)

Post-MVP growth features include smartphone client support with direct camera capture, richer OpenCV guidance, optional GPU depth/segmentation providers, realtime job updates, richer 3D viewer interactions, existing furniture detection, collision checks, movement/path analysis, shareable layouts, and improved project history.

### Vision (Future)

The long-term vision is a practical spatial planning workspace that turns casual room capture into actionable layout decisions. Future versions may include automatic door/window detection, real furniture asset matching, product catalog integration, layout recommendations, multi-image reconstruction, AR placement, and design recommendation workflows.

## User Journeys

### Journey 1: Web-First Room Planning Success Path

Minji is moving into a small apartment and wants to know whether a desk, bed, and wardrobe can fit before buying furniture. She opens the RoomForge web app, signs in with Google, and starts a new room project. The app asks for a room photo and explains the capture assumptions: the photo should be level, show visible floor, and include the wall-floor boundary where possible.

Minji uploads a room photo from her laptop and enters the room width, depth, and optional height. RoomForge runs the OpenCV-assisted reconstruction workflow: it detects candidate lines/corners, suggests a room or floor boundary, and lets Minji correct the points before generating the metric floor plan. She sees a simple metric room with floor, walls, and dimension guides. She adds proxy furniture objects for a bed, desk, chair, wardrobe, and sofa, then adjusts their size, rotation, and position.

The value moment happens when Minji sees that the generated room is not just an image, but an editable to-scale environment. She saves the layout to her account and exports the layout JSON so she can revisit the plan later.

This journey reveals requirements for Google authentication, project creation, image upload, dimension input, OpenCV candidate detection, user-correctable boundary selection, metric calibration, 2D/3D room viewing, furniture proxy editing, Oracle DB persistence, and layout export.

### Journey 2: Bad Photo and Reconstruction Recovery

Jae uploads a room photo taken from a tilted angle with most of the floor hidden behind furniture. RoomForge accepts the upload but the OpenCV-assisted result has low confidence: candidate room lines are weak, the visible boundary is incomplete, and scale calibration cannot produce a trustworthy room layout without correction.

Instead of silently producing a misleading 3D room, the app explains what failed. It shows the source image, candidate line/corner overlays, and a quality warning such as "room boundary not visible enough" or "camera angle appears too tilted." Jae can either upload a new photo, follow retake guidance, or manually adjust boundary/corner points to continue.

The value moment is trust preservation. Jae learns what kind of input RoomForge needs and can recover without assuming the app is broken.

This journey reveals requirements for input quality checks, OpenCV confidence states, user-facing failure messages, retake guidance, manual boundary correction, and safe handling of unusable CV output.

### Journey 3: Future Smartphone Capture Path

Sora uses RoomForge from a smartphone after the web MVP has proven the core flow. Instead of selecting an existing file, she directly captures a room photo through the mobile client. The app guides her to keep the device level, show the floor and wall boundary, and capture as much of the room as possible.

After capture, Sora enters room dimensions and submits the same OpenCV-assisted/manual-correction workflow used by the web client. She can review the room, make lightweight edits, and save the project. If detailed 3D editing is easier on a larger screen, the project remains available through the web client because data is stored in the Oracle-backed application layer.

The value moment is continuity: phone capture makes input easier, while the web-first editor remains the strongest environment for detailed layout work.

This journey reveals requirements for future mobile capture, capture guidance, shared project persistence across clients, and client architecture that does not lock reconstruction or layout editing to one device type.

### Journey 4: Admin Operations and Reconstruction Job Management

Yoon operates the MVP and wants to keep the OpenCV-assisted reconstruction flow observable while maintaining a usable app. He opens an admin screen and reviews reconstruction attempts/jobs by status: created, processing, review_required, succeeded, failed, and retried. The admin screen shows job creation time, user/project reference, input metadata, processing duration, result availability, OpenCV provider information, and failure reason.

If an optional inference provider is enabled later, the admin screen can show provider lifecycle state and retry provider-backed jobs. For the MVP, the admin value is mainly in inspecting failed reconstruction attempts, reviewing CV artifacts, understanding whether the failure came from input quality or processing, and helping users recover.

The value moment is operational clarity. The admin screen makes reconstruction attempts observable enough to debug failures, support the term-project evaluation, and preserve trust in saved user work.

This journey reveals requirements for an admin UI, job monitoring, provider/status visibility, failed job inspection, retry controls, CV artifact lookup, and Oracle DB-backed operational data.

### Journey 5: Support and Troubleshooting

A user reports that a saved layout is missing or a reconstruction attempt never completed. A support/admin user searches by user, project, or job ID in the admin screen. They inspect whether authentication succeeded, whether the layout exists in Oracle DB, whether the OpenCV/manual-assisted reconstruction produced artifacts, and whether the failure came from input quality, calibration, processing, save/load, or optional provider failure.

If the issue is recoverable, the support/admin user retries the job, asks the user to correct boundary points, or asks the user to upload a better photo. If the issue is data-related, they verify the saved layout JSON and project metadata. If the issue is provider-related, they use job and provider state to determine whether the Oracle API, database, OpenCV/manual-assisted provider, or optional future inference provider is the source of failure.

The value moment is fast diagnosis. RoomForge avoids becoming a black box by exposing enough operational state to explain failures.

This journey reveals requirements for admin search/filtering, job detail pages, persisted status transitions, error messages, retry history, layout/project lookup, and minimum observability across the Oracle API, OpenCV/manual-assisted provider, and optional future inference providers.

### Journey Requirements Summary

The journeys require RoomForge to support both user-facing and admin-facing workflows. The user-facing app must include Firebase Google Auth, project creation, image upload, room dimension entry, OpenCV-assisted reconstruction, user boundary/corner correction, metric calibration, 2D/3D room viewing, furniture proxy editing, save/export, and clear recovery paths for poor inputs.

The admin-facing app must include job monitoring, job detail inspection, provider/status visibility, failed job retry, CV artifact lookup, and user/project/layout lookup. Because reconstruction quality and save/load trust are central to the MVP, admin capabilities remain MVP-critical even without a required GPU server.

The system must persist enough state in Oracle DB to support both experiences: users, project records, source image metadata, reconstruction attempts/jobs, job status transitions, OpenCV result metadata, optional inference result metadata, layout JSON, failure reasons, and retry history.

## Domain-Specific Requirements

### Compliance & Regulatory

RoomForge does not operate in a regulated domain for the MVP. No healthcare, financial, government, or safety-critical compliance requirements are expected. Standard privacy and security expectations still apply because user accounts, room images, project metadata, and layout data are stored.

### Technical Constraints

The product must treat computer vision output as probabilistic rather than guaranteed truth. OpenCV line/edge/corner detection, boundary suggestions, perspective reasoning, and scale calibration results must include status and quality metadata so the app can distinguish successful, review-needed, and failed reconstructions.

OpenCV outputs should be reproducible enough for debugging and evaluation. The system should store relevant processing metadata, including OpenCV version where available, algorithm/provider identifier, job ID, input image metadata, processing timestamps, status transitions, failure reasons, user-corrected points, and result artifact references.

Heavy image processing and any future GPU inference must be isolated from the Oracle Cloud 1GB RAM server. The Oracle server coordinates jobs and data access only. The MVP should prefer client-side or lightweight async OpenCV/manual-assisted processing, while future GPU-heavy model execution should happen through an optional external provider.

### MVP Computer Vision Killer Feature

The MVP computer vision killer feature is OpenCV-assisted room geometry extraction and metric calibration. The system should take a room photo, run explainable OpenCV steps such as edge detection, dominant line detection, corner candidate extraction, and optional perspective/homography reasoning, then present candidate room boundaries for user correction.

The feature is successful when users can see the CV evidence, correct the proposed geometry, enter known room dimensions, and generate a metric 2D floor plan that becomes a simple editable 3D room. This keeps the project clearly grounded in computer vision while avoiding a dependency on opaque GPU/deep-learning reconstruction.

### Validation Thresholds

MVP reconstruction quality should be evaluated with explicit categories so users and admins can distinguish usable results from risky outputs.

- Boundary/corner suggestion quality should be evaluated against a small manually labeled validation set where ground truth points or room boundaries are available.
- Scale calibration should target exported room width/depth deviation <= 5% from user-entered dimensions for valid rectangular-room inputs.
- Aspect ratio error after calibration should target <= 5% for valid inputs.
- Reconstruction confidence should use at least three categories: success, review_required, and failed, with persisted `review_required` displayed to users as "Needs review."
- A reconstruction should be marked failed when room boundaries are not sufficiently visible, detected candidate lines/corners are too weak, the image is too tilted for the assumed geometry, or scale calibration cannot produce a metric floor plan.
- Evaluation artifacts should include source image, OpenCV edge/line/corner overlays, corrected boundary points, perspective/scale calibration output, metric floor plan, generated 3D room, final furniture layout, and job metadata.

### Integration Requirements

RoomForge integrates Firebase Hosting, Firebase Google Auth, Oracle API/data server, Oracle database, a manual-assisted/OpenCV reconstruction provider, and optional future inference providers. The client must be able to create reconstruction attempts/jobs, retrieve or produce OpenCV-assisted results, persist corrected geometry, and save layout edits through the Oracle-backed API layer.

Any provider-backed worker introduced later must be able to receive or pull queued jobs, update job status, write result metadata, and fail safely when the provider is unavailable or processing fails.

### Risk Mitigations

Poor input photos, weak OpenCV line/corner candidates, incomplete boundaries, and unstable scale calibration must not produce silently trusted layouts. The app should show input quality guidance, confidence/failure messages, and recovery paths such as retake, reupload, retry, or manual boundary correction.

Optional provider-backed processing introduces latency and availability risks. The system should expose provider/job state to admins, support retries, timeouts, failure reasons, and avoid indefinite queued jobs.

## Innovation & Novel Patterns

### Detected Innovation Areas

RoomForge's innovation is a pragmatic combination of OpenCV-assisted image geometry, metric user input, user correction, and editable 3D planning. The product does not try to solve unconstrained single-image reconstruction. Instead, it uses user-entered room dimensions as a metric anchor, OpenCV line/corner candidates as explainable visual evidence, and a horizontal camera prior as a geometric constraint to produce a useful room planning representation.

The second innovation area is workflow design: RoomForge treats reconstruction as an inspectable, recoverable job rather than an invisible AI result. Users and admins can see quality states, failure reasons, and job lifecycle status, which makes the system more trustworthy than black-box image generation.

The third innovation area is a staged inference architecture. The MVP delivers its CV term-project value through OpenCV/manual-assisted reconstruction without requiring a GPU server, while preserving a provider interface for optional GPU depth or segmentation later.

### Market Context & Competitive Landscape

RoomForge sits between image-first AI interior redesign tools and manual floor-plan planners. Image redesign tools provide visual inspiration but do not necessarily produce editable metric geometry. Traditional planners and floor-plan tools can support accurate layout work, but they often require users to manually draw rooms or start from existing plans.

RoomForge's differentiator is not photorealism. It is the ability to turn a real room image and known dimensions into a constrained, editable, approximately to-scale planning environment.

### Validation Approach

Innovation should be validated through end-to-end usability and technical evaluation. The product must show that users can complete the flow from image and dimensions to saved editable layout. The CV approach should be validated with visual outputs and ablation comparisons: manual baseline, OpenCV candidate assistance only, metric anchor only, and OpenCV assistance plus metric anchor.

The architecture should be validated by showing that reconstruction attempts can create OpenCV/manual-assisted results, persist metadata and corrected geometry, and return results without running heavy CV or GPU workloads on the Oracle 1GB RAM server. Optional future providers should plug into the same job/result contract.

### Risk Mitigation

If OpenCV-assisted reconstruction is not accurate enough, RoomForge should degrade into an honest guided planner: use the photo for grounding, accept user dimensions, provide manual correction, and preserve editable layout value.

If optional provider-backed processing is unreliable, the MVP should still expose admin controls, failed states, retry paths, and clear temporary limitations rather than hiding processing failures.

## Cross-Platform Flutter/Web App Specific Requirements

### Project-Type Overview

RoomForge is a web-first Flutter application with planned smartphone support. The product uses Firebase Hosting for client deployment, Firebase Google Auth for authentication, an Oracle Cloud API/data server for application data, an Oracle database for persistence, and an OpenCV-assisted/manual-correction reconstruction workflow. Optional GPU-backed inference providers are post-MVP enhancements.

The MVP should optimize for a usable web experience first while preserving a path to smartphone capture. The 3D room editor should be implemented as a web-first Three.js editor integrated into the Flutter app shell.

### Platform Requirements

The MVP must support a browser-based web client deployed through Firebase. The web client must support Google sign-in, project creation, image upload, room dimension entry, OpenCV-assisted boundary/corner review, user correction, 2D/3D room editing, layout saving, and export.

The MVP web client should target the latest stable versions of Chrome, Safari, Edge, and Firefox. The primary responsive target is desktop and laptop web usage for detailed 3D editing, with tablet-width layouts supported for review and light editing. Narrow mobile web layouts may provide project review and upload flows, but direct smartphone capture is Phase 2.

The web client should target WCAG 2.2 AA for core non-3D controls, including authentication, project management, forms, job status, admin tables, and error guidance. The 3D editor should provide visible focus/selection states and non-color-only status indicators where feasible.

Smartphone support is planned after the web-first MVP. Smartphone clients should include direct camera capture and capture guidance for horizontal room photos, visible floor area, and wall-floor boundaries.

### Authentication Model

Firebase Google Auth is the required MVP authentication mechanism. The Oracle API must verify authenticated users before reading or writing application data. The system should maintain a user mapping between Firebase Auth identity and Oracle database records.

Admin access must be restricted. Admin users need access to job/provider monitoring, failed job recovery, user/project lookup, CV artifact review, and layout/job troubleshooting.

### API and Data Requirements

The Oracle API must expose capabilities for authenticated project management, image/input metadata registration, reconstruction attempt/job metadata, OpenCV result metadata persistence, corrected geometry persistence, optional provider result retrieval, layout save/load, layout export, and admin job operations.

The Oracle database must store user mappings, room projects, source image metadata, room dimensions, reconstruction attempts/jobs, job status transitions, OpenCV result metadata, corrected boundary points, optional inference result metadata, layout JSON, failure reasons, and retry history.

API capability groups should include: auth/session verification, user/project management, image/input registration, reconstruction attempt/job lifecycle, OpenCV result metadata persistence, optional inference result retrieval, corrected geometry persistence, layout persistence/export, admin job operations, optional provider lifecycle operations, and support/troubleshooting lookup.

API error responses should distinguish at minimum: unauthenticated, unauthorized, validation_error, not_found, conflict, rate_limited, provider_unavailable, reconstruction_failed, calibration_failed, timeout, and internal_error.

Core data entities should include User, RoomProject, SourceImage, RoomDimensions, ReconstructionJob, JobStatusTransition, OpenCvResult, CorrectedBoundary, optional InferenceResult, FloorPlan, Layout, FurnitureObject, AdminAction, and RetryAttempt.

### 3D Editor Requirements

The 3D editor must support editable room and furniture interactions rather than passive model viewing. Required interactions include viewing the generated room, adding furniture proxies, selecting objects, moving, rotating, resizing, deleting, and persisting furniture state.

The recommended MVP architecture is Flutter app shell plus embedded or integrated Three.js editor. This reduces risk compared with relying on passive model-viewer packages or immature Flutter-native 3D renderers.

### Reconstruction Provider Requirements

The reconstruction flow must support a provider-based contract. The MVP provider is manual-assisted/OpenCV reconstruction; future providers may include CPU-basic or GPU-depth-segmentation. The client creates or updates a reconstruction attempt/job, the system stores job/result metadata, and the client can retrieve current status/results.

Job states should include at minimum: created, processing, review_required, succeeded, failed, timeout, and cancelled if cancellation is supported. Admin users must be able to inspect failed jobs and retry recoverable failures.

Job status transitions should persist status, timestamp, actor/source, reason code, human-readable reason, and related artifact/result references where available.

### Implementation Considerations

The Oracle Cloud 1GB RAM server must remain lightweight and must not run heavy OpenCV processing, model inference, or GPU workloads. It should handle API routing, authentication verification, database access, job/result metadata, and result retrieval.

The MVP should avoid infrastructure assumptions that require an external GPU server. Where an optional provider cannot run or fails, the limitation must be explicit and visible in admin operations.

## Project Scoping & Phased Development

### MVP Strategy & Philosophy

**MVP Approach:** Web-first usable product MVP.

RoomForge Phase 1 must be an actually usable application, not only a local proof-of-concept or presentation demo. The MVP should validate the complete product loop: authenticated user access, room input, OpenCV-assisted reconstruction, user correction, editable 2D/3D layout, persistence, export, and operational/admin visibility.

**Resource Requirements:** The MVP requires client/frontend capability, backend/API capability, Oracle database design, Firebase deployment/authentication setup, OpenCV pipeline work, user-correction UX, Three.js 3D editor implementation, and basic operations/admin tooling.

### MVP Feature Set (Phase 1)

**Core User Journeys Supported:**

- Web-first room planning success path.
- Bad-photo and OpenCV/manual-correction recovery path.
- Admin operations and reconstruction job/provider management path.
- Support/troubleshooting path through admin visibility.

**Must-Have Capabilities:**

- Flutter web-first client shell.
- Firebase Hosting deployment.
- Firebase Google Auth.
- Oracle API server for authenticated application/data access.
- Oracle database persistence.
- User mapping between Firebase Auth identity and Oracle DB records.
- Project, room, layout, reconstruction job, OpenCV result, corrected boundary, and optional inference result persistence.
- Room photo upload.
- Room width/depth/height input, with height defaulting when omitted.
- OpenCV-assisted line/edge/corner detection.
- User-correctable room boundary or corner point selection.
- Perspective or homography-based reasoning where applicable.
- Metric rectangular or simple polygonal floor plan generation using user-entered dimensions as scale anchor.
- 3D room generation.
- Flutter-integrated web-first Three.js room/furniture editor.
- Furniture proxy add, select, move, rotate, resize, delete.
- Layout save/load and JSON export.
- Input quality guidance and failure states for unsuitable photos.
- Admin screen for job monitoring, provider/status visibility, failed job inspection, retry controls, CV artifact lookup, and user/project/layout lookup.

### Post-MVP Features

**Phase 2 (Post-MVP):**

- Smartphone client support with direct camera capture.
- Capture guidance for level room photos, visible floor, and wall-floor boundaries.
- Richer OpenCV boundary editing and correction aids.
- Realtime job updates beyond polling.
- Advanced project history and sharing.
- Optional GPU depth/segmentation provider integration.
- Better provider usage/cost analytics if GPU providers are enabled.
- Richer 3D interactions and editor ergonomics.
- Improved retry policies and optional provider lifecycle automation.

**Phase 3 (Expansion):**

- AR placement.
- Existing furniture detection.
- Door and window detection.
- Real furniture asset matching.
- Product catalog or shopping integrations.
- Collision checks and movement/path analysis.
- Layout recommendations.
- Multi-image reconstruction.
- Interior design recommendation workflows.

### Risk Mitigation Strategy

**Technical Risks:** The highest-risk areas are OpenCV-assisted reconstruction quality, user-correction ergonomics, and Three.js editor integration inside a Flutter shell. Mitigation is to keep the room model rectangular or simple polygonal in Phase 1, treat CV output as confidence-scored and recoverable, use Three.js for editable 3D rather than immature passive-viewer alternatives, and expose job/provider state in the admin screen.

**Market Risks:** The main market risk is that users may expect fully automatic photorealistic room reconstruction. Mitigation is to position RoomForge as a guided, editable, dimension-calibrated planning tool and measure whether users can successfully create a useful layout from real room inputs.

**Resource Risks:** The project spans frontend, 2D/3D editor, backend, database, auth, OpenCV pipeline work, user-correction UX, and admin tooling. Mitigation is to keep Phase 1 focused on the complete usable loop and defer smartphone capture, GPU/deep-learning inference, AR, real furniture assets, complex non-rectangular rooms, and advanced recommendation features.

## Functional Requirements

### User Accounts & Access

- FR1: Users can sign in with Google.
- FR2: Users can sign out.
- FR3: The system can associate authenticated Firebase users with application user records.
- FR4: Admin users can access admin-only operational capabilities.

### Room Project Management

- FR5: Users can create room projects.
- FR6: Users can view their saved room projects.
- FR7: Users can open an existing room project.
- FR8: Users can update room project metadata.
- FR9: Users can delete room projects.

### Room Input & Capture Guidance

- FR10: Users can upload a room image for reconstruction.
- FR11: Users can enter room width and depth.
- FR12: Users can enter room height or use a default height.
- FR13: The system can provide guidance for suitable room photos.
- FR14: The system can preserve source image metadata for reconstruction and review.

### OpenCV-Assisted Reconstruction Workflow

- FR15: Users can submit a reconstruction job for a room project.
- FR16: The system can track reconstruction job status.
- FR17: Users can view reconstruction progress or current job state.
- FR18: The system can produce OpenCV candidate edges, lines, corners, or room boundary hints from a source image.
- FR19: Users can select or correct room boundary/corner points using the source image and OpenCV candidates.
- FR20: The system can apply perspective reasoning and metric scale calibration from user-provided dimensions to produce a floor plan.
- FR21: The system can mark reconstruction jobs as succeeded, failed, timed out, or cancelled where supported.

### Reconstruction Result & Quality Handling

- FR22: The system can store reconstruction result metadata.
- FR23: The system can store OpenCV edge/line/corner overlay outputs or references.
- FR24: The system can store user-corrected boundary/corner points.
- FR25: The system can produce a rectangular or simple polygonal metric floor plan from valid inputs.
- FR26: The system can report reconstruction quality or confidence states.
- FR27: Users can see failure reasons when reconstruction cannot produce a trustworthy result.
- FR28: Users can retry reconstruction after correcting input or uploading a new image.

### 3D Room & Furniture Editing

- FR29: Users can view a generated 3D room layout.
- FR30: Users can add furniture proxy objects.
- FR31: Users can select furniture proxy objects.
- FR32: Users can move furniture proxy objects.
- FR33: Users can rotate furniture proxy objects.
- FR34: Users can resize furniture proxy objects.
- FR35: Users can delete furniture proxy objects.
- FR36: Users can view room scale or dimension guidance while editing.

### Layout Persistence & Export

- FR37: Users can save room layouts.
- FR38: Users can load saved room layouts.
- FR39: Users can export layout data as JSON.
- FR40: The system can preserve room dimensions, floor plan data, source metadata, and furniture state in saved layouts.

### Admin Operations

- FR41: Admin users can view reconstruction jobs by status.
- FR42: Admin users can inspect reconstruction job details.
- FR43: Admin users can view reconstruction provider/status state, including OpenCV/manual-assisted provider details and optional future provider state.
- FR44: Admin users can retry failed reconstruction jobs.
- FR45: Admin users can retry provider-backed processing when supported.
- FR46: Admin users can inspect user, project, layout, OpenCV result, and optional inference result records.
- FR47: Admin users can view failure reasons and retry history.

### Support & Troubleshooting

- FR48: Support/admin users can search for jobs by user, project, or job identifier.
- FR49: Support/admin users can determine whether a failure came from input quality, OpenCV candidate detection, user calibration, API handling, database state, or optional provider processing.
- FR50: The system can preserve job status transitions, timestamps, actor/source, reason code, human-readable reason, and failure/retry history for troubleshooting.

## Non-Functional Requirements

### Performance

- NFR1: Non-CV API requests for project list, project detail, layout save, and layout load should return within 1 second at p95 under MVP expected load, measured from client request to API response.
- NFR2: Layout editing actions should update local editor state within 100 ms for MVP-scale scenes, measured in browser developer performance tooling.
- NFR3: The 3D editor should sustain at least 30 FPS on a recent laptop browser for a rectangular room with up to 20 furniture proxy objects.
- NFR4: Reconstruction job status should be retrievable by the client at least every 5 seconds while a provider-backed job is created, processing, review_required, succeeded, failed, or timed out.
- NFR5: Long-running reconstruction or optional provider requests must not rely on a single blocking HTTP request longer than 30 seconds; long-running reconstruction must use job status retrieval.

### Security

- NFR6: Every user-facing API request for project, layout, job, image, or result data must require a valid authenticated user identity.
- NFR7: Authorization checks must prevent users from reading or modifying projects, layouts, images, jobs, or results owned by other users.
- NFR8: Admin capabilities must require an admin authorization check distinct from normal authenticated user access.
- NFR9: Stored room images, layout data, OpenCV result metadata, corrected geometry, and optional inference metadata must not be publicly accessible without authenticated and authorized API access.
- NFR10: Authentication and authorization failures must return explicit unauthenticated or unauthorized error categories without exposing another user's data.

### Reliability & Recoverability

- NFR11: Reconstruction jobs must reach a terminal state of succeeded, failed, timeout, or cancelled within 30 minutes of creation unless explicitly retried.
- NFR12: Failed reconstruction jobs must preserve a machine-readable reason code and human-readable reason whenever the failure source is known.
- NFR13: Admin users must be able to inspect the current job status, status transition history, provider state, retry count, and failure reason for any reconstruction job.
- NFR14: Provider-backed jobs must be marked timeout or failed if processing does not start within 10 minutes.
- NFR15: Admin retry actions must create a new retry attempt record linked to the original job and preserve the previous failure history.

### Cost & Resource Efficiency

- NFR16: Heavy OpenCV processing, deep-learning model inference, and GPU model inference must not execute on the lightweight application/API server.
- NFR17: The system should allow optional reconstruction providers, including future on-demand GPU providers, without making them required for the MVP user flow.
- NFR18: The lightweight API server should keep responsibilities limited to authentication verification, API routing, database access, job orchestration, and result retrieval.
- NFR19: Admin users must be able to see reconstruction provider state, current active job count, recent failure state, and optional GPU provider lifecycle data when GPU providers are enabled.

### Data Integrity

- NFR20: Saved layouts must preserve room dimensions, floor plan data, source metadata, and all furniture object IDs, categories, positions, sizes, rotations, and colors.
- NFR21: Reconstruction results must be traceable to source image ID, input dimensions, job ID, provider/algorithm identifier, OpenCV version where available, processing timestamps, corrected boundary points, and result artifact references.
- NFR22: Job status transitions must persist status, timestamp, actor/source, reason code, human-readable reason, and retry linkage where available.
- NFR23: A save/load round trip for a layout must preserve all required layout and furniture fields exactly, except for server-managed metadata such as updated timestamps.

### Accessibility & Usability

- NFR24: The web client should display photo suitability guidance before upload and display reconstruction failure guidance within the job result view when a job fails or returns persisted status `review_required`.
- NFR25: Reconstruction results with persisted status `review_required` must show the user-facing label "Needs review" and display a visible warning before users can save or export the resulting layout.
- NFR26: In a lightweight usability review with at least three test users or reviewers, users should be able to complete login, project creation, image upload, dimension entry, job submission, 3D layout review, and layout save/export without developer assistance.
