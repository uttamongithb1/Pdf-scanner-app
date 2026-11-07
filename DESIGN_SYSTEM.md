# Lumen — PDF Scanner Design System

**Version:** 1.0 · **Date:** 15 October 2026 · **Status:** Proposed specification

**Product requirements:** [PRD.md](PRD.md)

**Implementation:** [Current source and validation status](docs/IMPLEMENTATION.md). The first app slice follows the core palette/workflow; full token enforcement, localisation and accessibility qualification remain pending.

**Scope:** Android and iOS app-owned screens, components and interaction behaviour. This is a build specification, not an existing component library or a signed-off visual design.

> Hosted ML Kit/VisionKit scanner screens are controlled by the platform SDK. Their layouts, shutter animations, live edge detection and permission UI cannot be replaced by the tokens below unless the SDK explicitly supports it. Custom camera specifications apply only to the app-owned fallback/future camera.

---

## Contents

1. Design direction
2. Foundations and tokens
3. Layout and navigation
4. Shared components
5. Scanner-specific screens and components
6. Accessibility and inclusive interaction
7. Platform, localisation and motion behaviour
8. Implementation and governance
9. Screen acceptance checklist

## 1. Design direction

### 1.1 Product character

**Precise, calm, readable and trustworthy.** The app is an instrument for handling documents, not a camera-effects playground. Use a restrained indigo accent, neutral surfaces and real document previews. Do not add promotional distractions to capture or export.

**Lumen** is an internal name for the design system, not a second product name or an approved app brand.

### 1.2 Principles

1. **The page is the hero.** Keep page content legible; do not colour-correct actual output to match a UI theme.
2. **One obvious next step.** Each workflow stage has one filled primary action.
3. **Show the state of the work.** Capturing, preparing, rendering, publishing and saved are different states.
4. **Explain where files live.** Destination and PDF/image retention are part of export, not hidden settings.
5. **Make edits reversible.** Keep reset, retake and undo where they are technically valid.
6. **Design for one hand and assistive technology.** Primary actions sit low; drag/gesture actions always have alternatives.
7. **Be honest about platform limits.** No success before publication verification, no cloud destination described as local storage, no app-lock described as encrypted files.
8. **Quiet motion, useful feedback.** Animate orientation or state, not decoration. Haptics never carry meaning alone.

### 1.3 Visual hierarchy

- Screen title: a single prominent title, not multiple competing headlines.
- Primary action: filled indigo, normally once per visible workflow surface.
- Secondary action: outlined or tonal.
- Destructive action: error tone, confirmation for permanent deletion.
- Document status: icon + text; colour is supplementary.
- Information density: comfortable by default, compact metadata only where it remains readable.

## 2. Foundations and tokens

All dimensions below are **logical pixels** unless specified. Flutter maps these to platform logical units; do not use physical camera pixels for layout. Text styles are baseline values and must honour system text scaling.

### 2.1 Token layers

```text
Primitive palette / type / spacing
                 ↓
Semantic roles: primary, surface, text, error, canvas
                 ↓
Component tokens: button radius, page-card gap, export footer inset
                 ↓
Product widgets and screens
```

Feature code uses semantic roles and component APIs. Primitive hex values belong only in token definitions. Intentional exceptions require a named token and rationale.

### 2.2 Primitive palette

| Family | Tokens |
|---|---|
| Indigo | 50 `#EEF2FF`, 100 `#E0E7FF`, 300 `#A5B4FC`, 600 `#4F46E5`, 700 `#4338CA`, 900 `#312E81`, 950 `#1E1B4B` |
| Slate | 0 `#FFFFFF`, 25 `#F8F9FB`, 50 `#F2F4F7`, 100 `#E9ECF1`, 200 `#DDE1E8`, 400 `#98A0AE`, 600 `#4B5361`, 800 `#212734`, 900 `#151A23`, 950 `#0B0E14` |
| Teal | 100 `#CCFBF1`, 300 `#5EEAD4`, 700 `#0F766E`, 900 `#134E4A` |

### 2.3 Semantic colour contract

| Role | Light | Dark | Usage |
|---|---|---|---|
| `primary` | `#4F46E5` | `#A5B4FC` | Main action, selected controls |
| `onPrimary` | `#FFFFFF` | `#1E1B4B` | Text/icons on primary |
| `primaryPressed` | `#4338CA` | `#C7D2FE` | Pressed primary action |
| `primaryContainer` | `#E0E7FF` | `#312E81` | Tonal action and selected panels |
| `onPrimaryContainer` | `#1E1B4B` | `#E0E7FF` | Content on tonal panels |
| `secondary` | `#0F766E` | `#5EEAD4` | Low-frequency secondary emphasis |
| `onSecondary` | `#FFFFFF` | `#134E4A` | Text/icons on secondary |
| `surface` | `#FFFFFF` | `#0B0E14` | Screen background |
| `surfaceLow` | `#F8F9FB` | `#151A23` | Cards, grouped settings |
| `surfaceHigh` | `#F2F4F7` | `#212734` | Input wells, elevated regions |
| `onSurface` | `#151A23` | `#E9ECF1` | Primary text |
| `onSurfaceVariant` | `#4B5361` | `#B4BCC9` | Supporting text |
| `outline` | `#6B7280` | `#98A0AE` | Meaningful control boundaries |
| `outlineVariant` | `#DDE1E8` | `#343B48` | Decorative separators only |
| `inverseSurface` | `#212734` | `#E9ECF1` | Snackbar |
| `onInverseSurface` | `#F2F4F7` | `#212734` | Snackbar text |
| `focusRing` | `#4F46E5` | `#A5B4FC` | Visible keyboard/switch focus |
| `canvas` | `#E4E7EC` | `#07090D` | Area behind document previews |
| `scrim` | Black 32% | Black 60% | Modal background dimming |

**Document colours are not theme tokens.** Never tint scanned pixels to `onSurface`, replace ink with brand colour, or turn the actual page grey in dark mode. A source page remains the same in preview and export; dark mode changes surrounding chrome only.

### 2.4 Status colours

| State | Light text/icon | Light background | Dark text/icon | Dark background |
|---|---|---|---|---|
| Success | `#146C2E` | `#C8F0CC` | `#7EDC96` | `#0B3D1B` |
| Warning | `#8A5300` | `#FFDDBA` | `#F5B95C` | `#4A2D00` |
| Error | `#B3261E` | `#F9DEDC` | `#F2B8B5` | `#601410` |
| Info | `#1A5FA8` | `#D6E6FB` | `#A6C8F5` | `#0C3557` |

Pair each with a label and appropriate symbol. Do not make error text red on a red fill without using the correct foreground/background pair.

### 2.5 Contrast and colour rules

- Normal text: at least 4.5:1; large text and meaningful UI boundaries: at least 3:1.
- Verify actual rendered combinations, including selected/pressed states, icons, disabled explanations, image overlays and translucent surfaces.
- `outlineVariant` is decorative; it is not sufficient as the only visible boundary of an otherwise invisible control.
- White on teal `#0F766E` is the approved secondary-button pairing; lighter teals are not substitutes for small text on white.
- Disabled controls may use muted styling, but explain *why* a blocked action is unavailable in readable adjacent text. Do not make a disabled button the only path to essential information.
- Dark mode is designed, not colour inversion. Test both themes independently.
- Camera overlays need a dark/light double stroke or scrim so they remain visible on arbitrary imagery.

### 2.6 Typography

**MVP:** platform system fonts (Roboto/system on Android, SF system on iOS), with appropriate script fallback. This avoids a network font request and gives reliable native-language coverage. An optional bundled Inter family may be evaluated later with its licence and script coverage; it is not a launch dependency.

| Semantic style | Size / line height | Weight | Usage |
|---|---|---|---|
| `hero` | 32 / 40 | 600 | Onboarding/empty-state headline, used sparingly |
| `headline` | 24 / 32 | 600 | Sheet/dialog heading |
| `screenTitle` | 22 / 28 | 600 | App bar |
| `title` | 16 / 24 | 600 | Card or list title |
| `body` | 16 / 24 | 400 | Main explanations |
| `bodySmall` | 14 / 20 | 400 | Secondary explanations, helper text |
| `label` | 14 / 20 | 600 | Buttons and controls |
| `caption` | 12 / 18 | 400 | Nonessential metadata |
| `badge` | 12 / 16 | 600 | Page number/status |

Use sentence case. Enable tabular numerals for progress, sizes and page counts. Use full readable labels for critical operations; do not rely on 12 px captions to explain data loss.

At large text sizes, increase component height and allow wrapping. Long filenames may truncate visually, but details and accessible names expose the full name. Never disable text scaling to preserve a mockup.

### 2.7 Spacing

Use a 4 px base grid. A 2 px optical/hairline adjustment is allowed only inside primitives.

| Token | Value | Typical role |
|---|---|---|
| `space.1` | 4 | Small internal gap |
| `space.2` | 8 | Related controls, icon/label gap |
| `space.3` | 12 | Card padding, grid gap |
| `space.4` | 16 | Compact screen gutter, standard padding |
| `space.5` | 20 | Comfortable control padding |
| `space.6` | 24 | Section gap, tablet gutter |
| `space.8` | 32 | Major section separation |
| `space.10` | 40 | Empty-state rhythm |
| `space.12` | 48 | Minimum interactive area |
| `space.16` | 64 | Tablet/hero spacing |

Use directional insets and positioning (`start/end`), not hard-coded left/right, except where image coordinates explicitly require them.

### 2.8 Shape and elevation

| Token | Value | Role |
|---|---|---|
| `radius.small` | 8 | Thumbnails and compact chips |
| `radius.medium` | 12 | Cards and fields |
| `radius.large` | 20 | Sheets and dialogs |
| `radius.pill` | Fully rounded | Extended scan shortcut, badges |

| Elevation | Usage | Treatment |
|---|---|---|
| 0 | Default screen/content | No shadow |
| 1 | Interactive cards | Subtle shadow or outline, not both by default |
| 3 | Floating action | Visible separation |
| 4 | Sheet/dialog | Modal scrim plus elevated surface |

Prefer tonal separation in dark mode; a dark shadow alone is not a visible elevation cue. Document page shadows are restrained and do not change the actual image.

### 2.9 Iconography

Use one coherent outlined icon family, preferably Flutter-bundled Material symbols/icons for app-owned screens. Standard visual size is 24, small metadata 20, empty state 48–64. Touch area remains at least 48 regardless of icon size.

Essential icons: scan, import image, folder, PDF, rotate, crop, reorder, filter, share, rename, delete, storage, retry, close, back and settings. Every icon-only action has a meaningful semantic label and, where useful, a tooltip. Do not label every action merely “More”.

### 2.10 Motion and haptics

| Token | Duration | Usage |
|---|---|---|
| `motion.quick` | 100 ms | Press and focus feedback |
| `motion.standard` | 200 ms | Selection, fade, filter preview transition |
| `motion.emphasis` | 300 ms | Sheets and route continuity |

Default easing: decelerating cubic `(0.2, 0, 0, 1)` for entry; accelerating exit where appropriate. Prefer transforms/opacity for frequent animation, but allow measured layout animation where needed for accessible expansion. Do not ban layout animation as an absolute rule.

No decorative endless animation. Reduced-motion settings replace nonessential movement with instant changes or a brief fade. Progress remains understandable without a spinning graphic. Optional haptics: light capture confirmation, success notification at completed save, no repeated vibration during progress.

## 3. Layout and navigation

### 3.1 Responsive structure

| Width class | Width | Shell/content behaviour |
|---|---|---|
| Compact | < 600 | Bottom navigation, 16 gutter, one content column |
| Medium | 600–839 | Navigation rail where suitable, 24 gutter, adaptive grids |
| Expanded | ≥ 840 | Rail, 32 gutter, optional preview/detail split |

Cap reading text at approximately 640 px. Grids may use wider space but must not stretch cards indiscriminately. Respect system safe areas, notches, keyboard insets and edge-to-edge navigation gestures.

Start review/library grids at two columns on phones and three/four on larger widths, **then adapt to usable card width and text scale**. At large text, a list or one-column mode may be needed. A fixed aspect ratio must not clip metadata.

### 3.2 Shell hierarchy

- Destinations: **Home**, **Files**, **Settings**.
- On Home, the hero **Scan document** button is primary; do not also show an identical filled FAB.
- On Files/Settings, an end-aligned scan shortcut may be shown without covering content; reserve scroll padding beneath it.
- Capture/editor/export are focused routes without shell tabs.
- Preserve each tab's navigation and scroll state.
- OS-native back and cancellation work predictably. Warn before discarding an unsaved draft, not before every harmless back action.

### 3.3 Screen anatomy

```text
Safe top / app bar
Screen title + relevant contextual action
Content: sections, pages, library or settings
Sticky workflow action when needed
Safe bottom / shell navigation (not in focused workflow)
```

Primary action areas wrap and grow with text scaling. Do not double-add safe-area padding if the native navigation component already includes it.

## 4. Shared components

Each component must specify light/dark variants, focus/pressed/disabled/error/loading states where relevant, semantic labels and large-text behaviour before implementation is considered complete.

### 4.1 Button

| Variant | Styling | Use |
|---|---|---|
| Filled | Primary + onPrimary | One main action |
| Tonal | Primary container + onPrimaryContainer | Secondary choice |
| Outlined | Outline + primary text | Alternative/retry/cancel |
| Text | Transparent + primary | Low-emphasis navigation |
| Destructive | Error + correct on-error foreground | Confirmed destructive action |

Minimum touch area 48 × 48; default minimum height 48, prominent export action 56. Horizontal padding 20–24. Use minimum heights, not fixed heights that clip scaled text. Busy state retains the label (“Saving…”), reserves stable width and prevents duplicate submission. Announce its state.

Pressed uses the defined tone/state layer; focused uses a visible ring. Disabled state does not masquerade as an active button. Do not hide the reason for disabled **Save** when there are no pages or no destination access.

### 4.2 Icon action

24 visual icon inside a minimum 48 target. Tooltip/semantic label describes the action and subject, e.g. **Rotate page 3 clockwise**, not “Rotate right” without context. Overflow menu label is **Actions for Invoice**.

### 4.3 Card and list row

12 radius, 12–16 internal padding, surfaceLow or outlined surface. Cards are interactive only if they have an action; do not announce a static container as a button. Keep nested overflow actions separately accessible.

Rows have title, optional subtitle, leading icon/thumbnail and trailing value/control. Height grows for wrapped descriptions. The whole row can toggle a setting without creating two conflicting screen-reader nodes.

### 4.4 Text field

Floating/static visible label, not placeholder-only. File-name field has a noneditable `.pdf` suffix, helper text and clear validation near the field. Normal minimum height 56; expands as needed. Focus/error boundary is 2 px. Maintain a visible focus state distinct from error.

Validation must not silently delete meaningful user text while typing. Sanitise at commit, show the resulting filename and explain invalid path characters. Announce validation errors once.

### 4.5 Choice chips and segmented controls

Use chips for page formats/filters; segmented controls for a few mutually exclusive options such as quality. Selection includes a check or border/shape cue plus semantic selected state. Touch targets are at least 48; visible chip fill may be smaller.

At large text, use wrapping chips or a vertical radio list instead of shrinking labels. Horizontal scrolling must not hide the selected option or the only action required to continue.

### 4.6 Sheet and dialog

Sheets use 20 top radius, drag handle, heading, scrollable body and an action footer. On phones use up to approximately 90% available height; allow full screen with keyboard/large text rather than clipping controls. On tablets use an appropriately bounded dialog or side sheet.

Dialogs are for decisions, not routine navigation. Trap focus while modal and restore it on dismissal. A destructive confirmation names the files and scope. During export, a dismiss gesture must not abandon an active job silently: keep the status accessible or ask whether to cancel.

### 4.7 Feedback

| Component | Role |
|---|---|
| Inline helper/error | Field-specific issue and repair |
| Banner | Persistent storage/permission condition with action |
| Snackbar | Brief confirmation or undo |
| Full-screen recovery | A workflow cannot proceed, e.g. no camera and no permission |
| Empty state | No documents yet, with a useful next action |

An undo snackbar remains actionable long enough for accessibility, respects OS accessibility timeout preferences and is not the only way to recover a destructive action. A permanently deleted SAF/provider file must not show a fake undo option.

### 4.8 Loading and progress

Skeletons are for loading known lists, not an empty library. Spinners always have a label. Determinate progress uses real completed work; do not invent a percentage while the provider is doing unknown-duration I/O.

Examples:

- **Preparing pages…**
- **Processing page 4 of 10**
- **Saving to PDF Scanner…**
- **Checking saved file…**

Announce milestones, not every animation tick. For a long task show **Cancel**, current phase and a message that the draft will be retained.

### 4.9 Standard state copy

| State | Heading/message | Action |
|---|---|---|
| Empty library | No PDFs yet. Scan a document or import photos to get started. | Scan document / Import images |
| Camera denied | Camera access is off. You can enable it in Settings or import photos instead. | Open Settings / Import images |
| Library access lost | We can't access this folder. Reconnect the storage or choose a folder to continue. | Choose folder |
| Storage full | Not enough space to save. Your draft is safe. Free up space and try again. | Storage / Try again |
| Partial save | PDF saved, but some page images couldn't be saved. | Retry images / Keep PDF only |
| Save complete | PDF and page images saved. | Open / Share / Done |

Only use the last message when both output types were actually committed. If image retention is off, say **PDF saved** instead.

## 5. Scanner-specific screens and components

### 5.1 Home

Title: **PDF Scanner**. A hero area with **Scan document** as the only filled primary action and **Import images** as an outlined/tonal action. Below it, recent documents with an unobtrusive **See all** link. Do not show a second empty-state scan button if the hero already supplies it.

A resume-draft banner appears above recent files when a recoverable session exists. It shows page count and **Resume**/**Discard**, not private document titles in a lock-screen-like notification.

### 5.2 Hosted capture

Before entering, handle capability/provisioning failure and provide a route to the manual fallback. After returning, transition into the app-owned review without implying that every pixel of the hosted scanner follows Lumen.

Do not place a Flutter overlay on top of a system scanner and assume live corners/shutter timing are available. Document any visual mismatch as an intentional native transition.

### 5.3 App-owned fallback capture

Always use dark camera chrome, regardless of theme, to improve preview contrast. This is a visual-camera exception only; dialogs and permission explanations must remain readable.

```text
Close                       Flash if supported

                  Camera preview
         Guide: place one page inside the frame

Imported/captured-page thumbnail       Page count

Import                 Shutter              Review
```

Shutter visual diameter 64–72 with at least the same touch area. Manual capture is available even without edge detection. Provide no fake automatic-stability timer if detection is not implemented. Flash appears only when the device supports it; it has an on/off/auto label as actually supported.

If automatic edge assistance is added, bracket geometry is a custom-camera component: neutral while searching, highlighted plus a textual “Page detected” cue when stable. Corners use a contrasting double stroke. Colour alone is insufficient.

### 5.4 Page review

App bar: back/close, page count, **Add pages**. Main content: ordered page grid/list. Bottom: **Save PDF**.

Each page tile includes:

- A bounded thumbnail preserving the full page aspect ratio; do not crop off content to fill a card.
- Visible sequence number and selected state.
- Edit/overflow action with page-specific accessible label.
- Reorder drag handle plus accessible **Move to position**.
- Remove/retake actions.

A filter toolbar applies to the selected page or to all pages only through an explicit **Apply to all** action. Never silently change every page when the user believes they selected one.

Reorder lift is subtle (roughly 1.03 scale), reduced-motion compatible. Removal has genuine session undo. PDF and saved-image numbering follow this order exactly.

### 5.5 Single-page editor and crop

Tools: **Crop**, **Rotate**, **Filter**, **Reset**; primary footer **Done**, secondary **Cancel**. Preview supports zoom and pan with controls for users who cannot pinch.

- Four-corner perspective mode is distinct from rectangular trim/aspect-ratio crop.
- Handles have at least 48 touch regions even when their visible brackets are smaller. Avoid overlapping hit regions at high zoom; select a corner and offer directional nudge controls as an alternative.
- Use a dimmed outside region and optional thirds grid. Crop instructions must remain readable on arbitrary imagery.
- Keep corners in valid convex order; explain invalid adjustment instead of creating a folded image.
- Display orientation is separate from source coordinates; preview and export share the PRD's transform order.
- **Reset** returns to the app-available original, not an implied RAW or pre-native-correction camera image.

### 5.6 Filter strip

Variants: **Original**, **Enhanced**, **Greyscale**, **B&W**. Each has a thumbnail, label and selection check. Provide a loading state per preview; stale preview work is cancellable.

Previews should use the actual native filter on small rasters so they do not materially misrepresent export. If a temporary approximation is unavoidable, validate its differences and label preview preparation; never use an arbitrary GPU matrix while claiming adaptive binarisation.

Filter defaults must not erase faint pencil marks/stamps. Keep Original easy to recover. In dark mode do not invert document pixels.

### 5.7 Export options

```text
Save PDF
[Small first-page preview]
File name                         .pdf
Page format        A4 / Letter / Image-fit
Orientation        Portrait / Landscape (standard sheets)
Quality            Small / Balanced / High
Margins            None / Small / Large

Destination: [readable local path/provider label] [Change]
Save page images: On
Keep original images: Off
Estimated space: …   (PDF + selected image outputs)

                         [Save PDF]
```

Use the PRD's presets and margin units. Image-fit disables incompatible sheet-only controls with explanatory text. The filename suffix is not editable. Validate collision handling before final publication, not only when opening the sheet.

The destination is visible, not inferred. Label private fallback storage **App storage** and explain how to export independently. Do not represent a cloud document provider as local-only.

Size estimate is approximate and may show a range; final actual size is shown after save. Include retained images in storage estimates, not just PDF bytes. If estimation is unavailable, say so instead of displaying a fabricated number.

### 5.8 Export progress and completion

Progress shows phase, page count, destination and **Cancel**. Disable conflicting actions but keep navigation semantics understandable. Persist state through interruptions; a restored job should say what it is resuming/retrying.

Completion displays PDF title, pages, final size, image-save status and location. Actions: **Open**, **Share**, **Done**. A PDF-only partial success must be visually different from full success and provide a retry path for images.

Do not imply tapping Share succeeded in sending the file; the receiving app controls that result.

### 5.9 Library

Toolbar: search, sort (newest, name, size), list/grid toggle. Cards show actual first-page thumbnail or a labelled PDF placeholder, title, pages, size and modified date. Opening a card must do something; never expose a noninteractive card as a button.

States: loading, empty, populated, unavailable file, unreadable PDF, search with no matches, permission/provider unavailable. Missing files are not quietly removed. Refresh/resume checks for external changes; an explicit Refresh action is available if reconciliation is delayed.

Overflow: **Open**, **Share**, **Rename**, **Delete**, **Details**. Delete confirmation distinguishes PDF-only from PDF plus associated saved images. Explain permanent deletion when no reliable undo mechanism exists.

### 5.10 Settings and storage

Groups:

- **Defaults:** page format, orientation, quality, filter, margins.
- **Images:** save processed images, keep originals, explanations of re-edit/storage consequences.
- **Appearance:** System / Light / Dark.
- **Storage:** canonical location, PDF/image/cache breakdown, missing/revoked access, change location, cleanup.
- **Privacy and help:** on-device processing, SDK provisioning, OS backup/uninstall explanation, version and support.

Storage bars include labels and numeric amounts, not colour-only segments. **Clean cache** must not delete final PDFs, final image copies or recoverable drafts. Destructive storage cleanup previews categories/counts and asks for confirmation.

## 6. Accessibility and inclusive interaction

Use WCAG 2.2 AA as a design baseline alongside Android/iOS native guidance. Compliance is demonstrated by testing, not by naming a standard.

### 6.1 Semantics

| Element | Example accessible name/state |
|---|---|
| Capture | Capture page, button |
| Page tile | Page 3 of 8, selected; actions: edit, move, remove |
| Rotate | Rotate page 3 clockwise |
| Filter | Enhanced, selected option |
| Export progress | Processing page 4 of 8, progress |
| Library card | Invoice, 8 pages, 1.4 megabytes, modified 15 October |
| Image-retention toggle | Save page images, on; description of location and storage impact |

Avoid duplicate announcements from parent and child labels. Announce asynchronous completion politely; use assertive announcements only when an urgent interruption truly warrants it. Capture chatter must not overwhelm speech.

### 6.2 Text, focus and targets

- At least 48 × 48 app-owned touch targets; visible icons may be 24.
- Text at 200% must not clip actions, cover page counts or hide destination warnings.
- Field descriptions wrap; action footers grow; sheets scroll. A fixed-height chip cannot both keep its height and wrap unlimited scaled text—adapt it.
- Keyboard/switch focus follows visual reading order: app bar, content, footer.
- Focus ring is visible in light/dark and restored after modal close.
- External keyboard Enter activates the focused control; Escape dismisses safe modals. Never bind Enter to destructive confirmation unexpectedly.

### 6.3 Gesture alternatives

Every drag/long-press/pinch interaction has a discoverable tap or assistive action:

- Reorder → **Move to position**.
- Crop → choose corner and nudge.
- Zoom → plus/minus/reset controls.
- Long-press selection → **Select** button/menu.
- Swipe deletion → explicit delete action.

Hosted scanner accessibility must be tested on each supported platform. Do not claim it is fully under our control.

## 7. Platform, localisation and motion behaviour

### 7.1 Platform adaptation

| Concern | Rule |
|---|---|
| Back | Honour Android back/predictive back where applicable and iOS navigation/dismiss conventions |
| Sharing | Use system share sheet; correctly anchor popovers on iPad |
| Folder selection | Android SAF picker; iOS Files/document export, not a custom imitation |
| Camera | Hosted native UI when available; app-owned fallback follows Lumen |
| Menus and dialogs | Use familiar platform behaviour; shared semantic roles and content hierarchy |
| Safe areas | Support gesture navigation, keyboard, notches and tablet split view |
| Theme | App-owned themes consistent; hosted scanner differences disclosed |

Aim for consistent tasks and hierarchy, not a fabricated percentage of cross-platform pixel parity.

### 7.2 Localisation

All user-visible text belongs in localisation resources, including error messages, tooltips, accessibility names, plural page counts and size units. Launch locale choices follow the PRD; supporting layout direction does not mean translations exist.

Allow substantial text expansion; test long German pseudo-localisation and Arabic RTL fixtures even before those locales ship. Use script-appropriate system font fallback. Do not assume every Hindi/Arabic label is shorter than English.

Mirror navigation and directional layout in RTL; **never mirror document content, page-image pixels, logos or physical tool meanings**. Crop coordinates always describe the source image, not the UI reading direction. Rotation direction must match its announced meaning. Page-order logic stays consistent with the user's explicitly chosen sequence.

Dates and sizes are locale-aware in the interface. Filename patterns remain safe/sortable; user-entered Unicode names are preserved after normalisation and validation.

### 7.3 Motion rules

A live camera does not justify constant animated chrome. Animate only capture confirmation, selection, route continuity and state changes. Never synthesize unobservable hosted-scanner detection states.

When reduce motion is active, replace page fly-ins/reorder lifts with immediate changes or minimal fades. Keep progress text and success/error cues. Haptics follow user/system preferences and are not required for understanding.

## 8. Implementation and governance

### 8.1 Suggested Flutter structure

```text
lib/design_system/
├── tokens/
│   ├── palette.dart
│   ├── semantic_colors.dart
│   ├── typography.dart
│   ├── spacing.dart
│   ├── shape.dart
│   └── motion.dart
├── theme/
│   ├── lumen_theme.dart
│   └── lumen_extension.dart
└── components/
    ├── button.dart
    ├── field.dart
    ├── feedback.dart
    ├── document_card.dart
    └── page_tile.dart
```

Map standard roles to Flutter `ColorScheme`/`TextTheme`. Put product canvas/status tokens not covered by Material into a `ThemeExtension`, with tested `copyWith` and `lerp`. Register **one extension instance per type for the active theme**—registering light and dark instances of the same type together does not create a theme switch.

Keep domain edit geometry separate from widget geometry. Widgets request preview assets via a service; they do not decode arbitrary full-resolution batches synchronously.

No production Dart snippets are supplied here because Flutter API signatures vary by chosen SDK. Pin the SDK and compile/test the component implementation rather than treating illustrative snippets as validated code.

### 8.2 Component contract and testing

Every component includes:

1. Purpose and permitted variants.
2. State model and loading/error behaviour.
3. Minimum—not rigid—dimensions and scaling behaviour.
4. Semantic labels, focus, keyboard and gesture alternatives.
5. Light/dark and RTL behaviour.
6. Motion/reduced-motion behaviour.
7. Examples and widget/golden tests.

Goldens detect visual regression; they do not replace screen-reader or native camera testing. Run representative compact/tablet, long-name, large-text, empty/error/loading fixtures.

### 8.3 Token enforcement

Code review prohibits ad hoc feature hex values and unexplained spacing. A custom lint may later automate that rule; it is a **planned** tool, not an existing CI guarantee. Do not block legitimate image-coordinate math, geometry conversion or algorithm constants with a blanket “no numbers” rule.

Maintain a component catalogue/story app during implementation. Add component documentation and tests in the same PR. Update both this document and the PRD if an interaction changes a product requirement.

### 8.4 Ownership and change control

Suggested accountable roles: mobile lead for implementation/quality, designer for hierarchy/tokens, QA/accessibility reviewer for validation, product owner for workflow and copy. These are roles to assign, not completed approvals.

- New token: include rationale, affected screens and contrast tests.
- Token value change: review golden diffs and both themes.
- Breaking component API: deprecation/migration plan.
- New workflow state: update recovery semantics and acceptance criteria.
- Version the design system independently once implemented; record meaningful changes and migration impact, not just file edits.

## 9. Screen acceptance checklist

For every app-owned screen before release:

- [ ] One clear primary action; no competing filled scan buttons.
- [ ] Loading, empty, error, partial and successful states are defined where relevant.
- [ ] Light and dark tokens are used; actual document pixels remain unchanged.
- [ ] Contrast checked for real foreground/background pairs and overlays.
- [ ] Interactive regions are at least 48 × 48 with meaningful labels.
- [ ] TalkBack/VoiceOver reading order and actions work.
- [ ] 200% text, long names, keyboard and safe areas do not hide essential controls.
- [ ] Drag/pinch/long-press have accessible alternatives.
- [ ] Tablet/multi-window layout is usable.
- [ ] RTL mirrors interface chrome but not documents.
- [ ] Reduced motion and haptic preferences are respected.
- [ ] Errors describe what happened and an actionable next step.
- [ ] Save status matches actual PDF/image publication; destination is clear.
- [ ] Delete/cleanup scope and any limitations of undo are truthful.
- [ ] Native scanner/provider limitations have been verified on physical devices.

---

**Next design gate:** review the core capture → review → export prototype on Android and iPhone with large text and screen readers, then approve tokens/components against real document fixtures.
