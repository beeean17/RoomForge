---
title: "Product Brief: RoomForge"
status: "draft"
created: "2026-05-07"
updated: "2026-05-07"
inputs:
  - "notes/basic_document.md"
  - "Course correction: OpenCV term-project requirement"
  - "DecorAI product page"
  - "Inty product page"
  - "LUMI product page"
  - "Ritn3D product page"
  - "Roomform product page"
---

# Product Brief: RoomForge

## Executive Summary

RoomForge is a constraint-guided indoor reconstruction tool that turns one room photo, user-entered room dimensions, and OpenCV-assisted geometric correction into a simple, metric 3D room layout for furniture placement. Instead of attempting fully automatic single-image 3D reconstruction, RoomForge uses practical constraints: the user provides a room photo, enters real dimensions, reviews OpenCV line/corner/boundary candidates, and corrects the room boundary when needed. These inputs become geometric and metric anchors for producing a layout accurate enough for furniture planning.

The core opportunity is the gap between inspiration-first AI interior design tools and labor-heavy room planning tools. Many photo-based products generate styled room images, while floor-plan-first tools require users to draw, scan, or import plans before they can arrange furniture. RoomForge focuses on a narrower but valuable outcome: helping users quickly create an editable, to-scale room simulation from the kind of input they already have, a room photo plus approximate measurements.

The MVP should prove that an explainable OpenCV-assisted workflow can produce a useful metric floor plan and editable 3D room experience without promising high-fidelity reconstruction. Success means users can upload a room photo, enter dimensions, review detected line/corner/boundary candidates, correct the room outline, generate a simple 3D room, place proxy furniture, and save the resulting layout as structured JSON.

Because RoomForge is a computer vision term project, the MVP needs a visible OpenCV killer feature. The strongest candidate is an inspectable room-geometry extraction flow: OpenCV detects candidate edges, dominant lines, corners, or boundaries; the user corrects the geometry; and the system calibrates the result into a metric 2D/3D planning space.

## The Problem

Planning furniture layout is still awkward for everyday users. They may know their room dimensions, but they often struggle to translate those measurements into a usable floor plan or 3D scene. Traditional planners ask users to manually draw walls, enter shapes, and position furniture from scratch. Photo-based AI design tools reduce friction, but many focus on visual restyling rather than editable, to-scale spatial planning.

Fully automatic 3D reconstruction from a single RGB image is also fragile. A single photo lacks absolute scale, and indoor scenes introduce camera pose uncertainty, occlusion, furniture clutter, and ambiguous wall or floor boundaries. For an MVP, trying to solve all of these automatically would expand the technical risk beyond the actual user need: deciding what fits and where furniture should go.

RoomForge reframes the problem. The product does not need perfect reconstruction to be useful. It needs a reliable enough metric room layout that users can inspect, adjust, and use for furniture placement decisions.

## The Solution

RoomForge provides a guided workflow:

1. The user uploads one JPG or PNG room photo.
2. The user enters room width, depth, and optionally height.
3. The system uses OpenCV to detect candidate edges, dominant lines, corners, or room boundaries.
4. The user confirms or corrects the suggested room boundary/corner points.
5. The system applies perspective reasoning and calibrates the layout to the entered dimensions.
6. RoomForge creates a simple 2D floor plan and 3D room with floor, walls, grid, and dimension guides.
7. The user adds, moves, rotates, resizes, and deletes proxy furniture objects.
8. The final room and furniture layout is saved as JSON.

The product experience should stay honest and controllable. When the photo violates the assumptions, for example if the camera is heavily tilted or the floor is mostly hidden, RoomForge should warn the user and guide them to capture a better input rather than pretending the reconstruction is reliable.

## What Makes This Different

RoomForge's differentiator is not photorealistic interior generation. It is an explicit bridge between a real room photo and an editable metric layout.

Current alternatives tend to cluster around three approaches:

- Photo redesign tools, such as DecorAI and Inty, emphasize restyling or redesigning a real room from a photo.
- AI room planners, such as LUMI, combine photos, floor plans, and visual layout generation.
- Floor-plan-to-3D tools, such as Ritn3D and FloorCraft, start from an existing 2D plan or scanned plan.
- True-scale 3D planning tools, such as Roomform, emphasize LiDAR scans, drawn plans, or imported floor plans.

RoomForge should position itself as a pragmatic reconstruction workflow: less magical than fully automatic AI design, but more spatially useful than image-only redesign. The user provides just enough ground truth to resolve scale ambiguity, and the system uses that input to generate an editable planning environment.

## Who This Serves

The primary users are people who need to make furniture layout decisions for real rooms but do not want to draw a floor plan manually. This includes renters, homeowners, students, small-space dwellers, and DIY decorators who have a room photo, know approximate measurements, and want to test whether furniture arrangements will fit.

Secondary users include interior design students, project/demo evaluators, and technical users interested in practical computer vision workflows. For them, RoomForge is also a clear demonstration of constrained single-image reconstruction, metric calibration, and interactive 3D layout editing.

The key user "aha" moment is seeing their room become a simple, to-scale editable space instead of a static inspiration image.

## MVP Scope

The MVP includes:

- Single room photo upload.
- Room width, depth, and optional height input, with a default height of 2.4m.
- OpenCV-assisted edge/line/corner or boundary candidate detection.
- User-correctable room boundary/corner point selection.
- Perspective or homography-based reasoning where applicable.
- Metric scale calibration using entered dimensions.
- Rectangular 3D room generation with floor, back wall, side walls, and optional ceiling.
- Proxy furniture creation and editing: add, move, rotate, resize, delete.
- JSON export for room, camera prior, and furniture layout data.
- Basic quality outputs such as candidate quality, correction status, and calibration status.

The MVP excludes:

- Fully automatic existing-furniture reconstruction.
- High-precision non-rectangular room reconstruction.
- Automatic door and window detection.
- Automatic matching to real 3D furniture assets.
- Mobile AR placement.
- Multi-image reconstruction.

## Technical Approach

RoomForge should use a web-first architecture. The current product direction favors a Flutter web app shell deployed through Firebase, Firebase Google Auth, an Oracle-backed lightweight API/data server, and an embedded or integrated Three.js editor for 2D/3D room editing. The computer vision component should center on OpenCV-assisted geometry rather than requiring a GPU server for the MVP.

The computer vision pipeline should treat OpenCV outputs as explainable suggestions rather than guaranteed truth. User-entered dimensions are the metric anchor. Candidate lines/corners, corrected boundary points, perspective assumptions, and scale calibration are used together to estimate a floor representation that can be scaled to the known width and depth. Optional GPU/deep-learning providers can be added later, but the MVP should remain useful without them.

The 3D simulator should prioritize clarity over realism: stable controls, dimension guides, grid helper, editable proxy furniture, and a reliable JSON representation matter more than visual polish in the first version.

## Success Criteria

The MVP is successful if users can complete the core flow from photo to editable 3D layout without expert help.

Recommended product success signals:

- A user can create a room model from a valid photo and dimensions in under 5 minutes.
- The generated rectangular floor plan matches the user-entered width and depth exactly at the exported data level.
- Users can place and modify at least five common furniture proxies: bed, desk, chair, wardrobe, sofa.
- Users can save and reload a layout JSON without losing room or furniture state.
- The product detects or warns about invalid input conditions, such as missing visible floor or extreme camera tilt.

Recommended technical evaluation signals:

- Boundary/corner suggestion quality against a small hand-labeled validation set, where available.
- Aspect ratio error before and after calibration.
- Comparison across ablation conditions: manual baseline, OpenCV candidate assistance only, metric anchor only, and OpenCV assistance plus metric anchor.
- Qualitative side-by-side review of source image, OpenCV overlays, corrected boundary points, floor plan, 3D scene, and final furniture layout.

## Strategic Risks

The biggest product risk is expectation mismatch. Users may assume "AI room reconstruction" means accurate automatic recovery of all walls, furniture, windows, and object dimensions. RoomForge should avoid that trap by presenting itself as a guided planning tool, not a fully automatic room scanner.

The biggest technical risk is OpenCV candidate reliability. Lighting, clutter, furniture occlusion, lens distortion, weak room edges, and perspective ambiguity can break line/corner detection. The MVP should lean into user correction and input quality guidance rather than over-investing in full automation or GPU inference too early.

The biggest adoption risk is workflow friction. If users must measure the room anyway, they may wonder why they should not simply use an ordinary room planner. RoomForge must make the photo useful: faster orientation, visual grounding, easier floor identification, and a smoother path into a 3D layout than drawing from scratch.

## Vision

If the MVP works, RoomForge can grow into a practical spatial planning workspace for real rooms. Later versions can add existing furniture detection, door and window detection, collision checks, circulation analysis, real product catalogs, layout recommendations, shareable plans, and optional AR or LiDAR-assisted capture.

The long-term vision is not just "AI interior design." It is a bridge from casual room capture to useful spatial decisions: what fits, what changes, what layout works, and how a real room can be transformed with confidence.

## Open Questions for Review

- Should RoomForge target casual home users first, or present itself primarily as a technical/demo project for computer vision and interactive 3D?
- How accurate does the generated layout need to feel for the first user segment to trust it?
- How much manual boundary/corner correction should the MVP require before the OpenCV assistance feels useful rather than tedious?
- Should furniture dimensions be fully manual, preset-based, or both?
- Is the first version intended as a local prototype, a hosted web app, or a research/demo deliverable?

## References

- DecorAI: https://www.decoraiapp.io/
- Inty: https://www.intyai.app/
- LUMI: https://raumplaner.io/en
- Ritn3D: https://www.ritn3d.com/
- Roomform: https://www.roomform.ai/
