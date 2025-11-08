# VaultEye Copilot Instructions

Concise, project-specific guidance for AI agents contributing to this SwiftUI iOS app. Focus on existing patterns; do not introduce speculative architectures.

## Core Architecture

- Central model: `DetectionResult` (asset, `isFlagged`, `[DetectedRegion]`, `reason`, optional `geminiExplanation`, `privacyScore`, `thumbnail`). Any scanning pipeline MUST emit an array `[DetectionResult]` consumed by `ContentView` (only first element rendered) and `SwipeCardView` via `DetectionResultCard`.
- Detection primitives: `Detection` (type, confidence) and `SensitiveContentFlagger.flagSensitiveDetections(in:threshold:)` which gates sensitive items before OCR / Gemini. Always run flagger on raw model output first.
- Photo access & thumbnails: `PhotoLibraryManager` (`@MainActor`). Mutations to published state stay on main actor; expensive PhotoKit calls are bridged with `withCheckedContinuation`.
- Scanning placeholder: `ScannerService.scanPhotos()` currently returns every asset flagged with mock regions. Replace internals but preserve: async iteration, thumbnail prefetch (`loadThumbnail`), normalized bounding boxes (0–1) in `DetectedRegion.normalizedRect`.
- Redaction pipeline: `RedactionService.redactAndReplace(asset:)` loads full-res, Vision OCR (`VNRecognizeTextRequest`), merges & blurs boxes, creates new asset, deletes original. Keep OCR off main thread; UI-affecting deletes/saves via `@MainActor`.

## Interaction & State Flow

- Swipe UX: `SwipeCardView` maps right swipe → delete (stage), left swipe → keep. Threshold constant `swipeThreshold` and haptics provide tactile feedback; maintain these unless redesigning. Removal uses animated `detectionResults.removeAll { $0.id == result.id }`.
- Deletion staging: Use `DeleteBatchManager.stage(assetId)`; batch commit with `commit(using:)` after review. Don’t delete directly from swipe.
- Risk / explanation: After OCR, call `GeminiService.generateExplanation(ocrText:detections:)`; it returns JSON you can assign into `DetectionResult.geminiExplanation` and derive a `privacyScore` heuristic if desired (existing mock uses 0.5–0.89). Never send raw image bytes—only sanitized OCR text + detection metadata.

## Gemini Integration Constraints

- Endpoint: `gemini-2.5-flash` with `generationConfig.responseMimeType = application/json` enforced. Prompt forbids inventing identifiers; preserve keys: `explanation`, `risk_level`, `key_phrases`, `recommended_actions` mapped to `GeminiAnalysisPayload` (coding keys already defined). Extend by adding fields ONLY if both prompt & decoding updated.
- API key injection: via `GeminiService(apiKey:)`; do not hardcode keys. Prefer dependency injection.

## Concurrency & Threading

- UI mutations (`detectionResults`, `stagedAssetIds`, authorization) on main actor. Heavy Vision / JSON decoding / network calls off main actor; bridge PhotoKit & Vision with continuations.
- Use `Task { ... }` for initiating async work from button taps (`startScan`, permission requests).

## Data & Rendering Contracts

- Bounding boxes must remain normalized; overlay scaling logic in `BoundingBoxOverlay` assumes 0–1 coordinates relative to original image size.
- `DetectionResult.assetIdentifier` used for deletion resolution; ensure stable mapping when asset is available.
- Previews rely on `MockData` (`DetectionResult.mockFlagged`, `.mockClean`); keep mock fixtures updated when struct shape changes.

## Build, Test, Debug

- CLI build example: `xcodebuild -project VaultEye.xcodeproj -scheme VaultEye -destination 'platform=iOS Simulator,name=iPhone 15' build`.
- Add tests in `VaultEyeTests` for pure logic (e.g., `SensitiveContentFlagger` thresholds) and in `VaultEyeUITests` for swipe/flow. Mirror async patterns using `XCTestExpectation`.
- Prefer deterministic mocks over network calls; stub `URLSession` for `GeminiService` when testing decoding error paths.

## Extension Guidelines

- When adding a Core ML detector: produce `[Detection]`, pass through flagger, map to `DetectedRegion` with normalized rects, build `DetectionResult` entries incrementally to allow streaming UI (append then animate removal upon swipe).
- When adjusting redaction, keep masking strategy (white on black for `CIBlendWithMask`) unless demonstrating a measurable performance improvement.
- Do not bypass staging workflow or modify haptic feedback without rationale in PR description.

## Avoid

- Uploading raw images or unfiltered OCR text to Gemini.
- Blocking main actor with Vision or large loops (batch work inside `Task` with cooperative yielding if needed).
- Generic comments; document deviations directly in this file when conventions change.

Update this document whenever public struct shapes (`DetectionResult`, `Detection`, `SensitiveFlagResult`) or interaction thresholds change. Keep total length concise.
