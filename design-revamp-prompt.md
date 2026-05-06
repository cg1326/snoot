Redesign the entire visual design of the Snoot iOS app.
The existing functionality is complete — this prompt is purely a
design overhaul. Do not change any logic, data models, or navigation
structure. Only update the UI layer.

Design north star: Airbnb's spatial polish and photography-first
layouts, with the warmth and motion of Duolingo and Headspace.
Every screen should feel considered, alive, and delightful — not
like a default SwiftUI form.

---

## DESIGN SYSTEM

**Color palette:**
- Primary background:   #FDFAF6  (warm off-white, never pure white)
- Card background:      #FFFFFF  with 12pt corner radius and
                        shadow: 0 2px 12px rgba(0,0,0,0.07)
- Primary accent:       #F4845F  (warm coral-orange) — maps to `snootOrange`
- Secondary accent:     #7DAF7A  (sage green) — maps to `snootSage`
- Tertiary accent:      #F9C74F  (soft amber, use sparingly)
- Text primary:         #1A1A1A
- Text secondary:       #6B6B6B
- Text tertiary:        #ADADAD
- Dividers:             #F0EDE8
- Destructive:          #E05C5C

Note: `Color+Snoot.swift` already defines `snootCream`, `snootOrange`,
`snootSage`, `snootBrown`, and `snootCardBG`. Migrate these to the new
`DesignSystem.swift` and add all missing tokens.

**Typography (SF Pro):**
- Display:   34pt, bold, tracking -0.5, text primary
- Title 1:   28pt, bold, tracking -0.3
- Title 2:   22pt, semibold
- Title 3:   18pt, semibold
- Body:      16pt, regular, line height 24pt
- Caption:   13pt, regular, text secondary
- Label:     12pt, medium, letter-spacing +0.3, uppercase —
             use for section headers and tags only

**Spacing system (use consistently, no arbitrary values):**
4 / 8 / 12 / 16 / 20 / 24 / 32 / 48pt

**Corner radius system:**
- Small (tags, chips):  8pt
- Medium (cards):       16pt
- Large (sheets, hero): 24pt
- Full (avatars, FAB):  9999pt

**Shadows:**
- Card:     0 2px 12px rgba(0,0,0,0.07)
- Elevated: 0 8px 32px rgba(0,0,0,0.12)
- Subtle:   0 1px 4px rgba(0,0,0,0.05)

**Icons:**
- SF Symbols throughout, weight: medium
- Icon size: 20pt inside touch targets of minimum 44x44pt
- Always pair icons with labels — never icon-only for primary actions

---

## MOTION & ANIMATION

Use SwiftUI animations thoughtfully throughout:
- Screen transitions: `.easeInOut(duration: 0.3)`
- Card appearances: `.spring(response: 0.4, dampingFraction: 0.8)`
  with a subtle upward slide (offset Y from +16 to 0) + fade in
- Button press: scale to 0.97 on press, spring back on release
- Tab bar selection: icon bounces with
  `.spring(response: 0.3, dampingFraction: 0.6)`
- Onboarding step transitions: already uses
  `.asymmetric(insertion: .move(.trailing) + .opacity,
               removal: .move(.leading) + .opacity)` — keep and refine
- Progress bar: animated fill with `.easeInOut(duration: 0.4)` —
  `ProgressBarView` already uses `.spring(response: 0.4, dampingFraction: 0.8)`, keep
- Toggle/chip selection: background fills with spring animation
- Success states: brief scale pulse (1.0 → 1.08 → 1.0)

No animations over 0.5 seconds. Nothing that blocks interaction.

---

## HOME SCREEN (`ContentView`)

The home screen is a `NavigationStack`. It renders either an empty
state or a list of dog cards. A settings gear lives in the leading
toolbar, a plus button in the trailing toolbar.

**Navigation title:**
- Large navigation title: "My Dogs" in Display style
  (current title is "Snoot 🐾" — rename to "My Dogs")

**Dog card layout:**
- Current: 2-column adaptive `LazyVGrid` of `DogCard` items.
  Keep the 2-column grid but fully restyle each card:
  - Full-bleed photo background (no circle clip) with gradient overlay
    (bottom 40% fades to #1A1A1A at 70% opacity)
  - Dog name in Title 3, white, pinned bottom-left of card
  - Breed + age in Caption, white 70% opacity, below name
  - Card height: 200pt, corner radius 16pt
  - `isShared` badge: small "Shared" pill top-left (sage fill, white text)
  - `isSample` badge: small "Sample" pill top-left (sage fill, white text)
  - Completion arc: thin coral arc in top-right corner showing
    care profile completeness (0–100%), computed from `sectionData`
    in `ProfileHomeView`
  - No-photo fallback: coral gradient background with 48pt
    `pawprint.fill` SF Symbol centered

**Toolbar:**
- Trailing: keep the `plus.circle.fill` button (coral) — restyle it
  as a 56pt coral FAB pinned to the bottom-right corner with
  `.spring` shadow, rather than a toolbar button
- Leading: restyle the `gearshape` button to match the design system
  (20pt, snootBrown, no opacity hack)

**Banners (shown above the grid when relevant):**
- `OfflineBanner`: currently a grey full-width bar. Restyle as a
  warm amber card (tertiary accent, 10% opacity background),
  `wifi.slash` icon in amber, "You're offline" title, caption
  "Changes will sync when you reconnect." No full-width grey bar.
- `AccountPromptBanner`: currently a white card with small text.
  Restyle with coral gradient left accent (4pt wide), `sparkles`
  icon in coral, "Unlock live sharing" title, body copy, and a
  coral "Get started" pill CTA. Card shadow: elevated.

**Empty state (no dogs yet):**
- Centered illustration: `pawprint.fill` at 80pt, coral, soft shadow
- Title: "Add your first pup" in Title 1
- Subtitle: "Build a care guide your sitter will actually use" in Body,
  text secondary
- Large coral CTA button: "Add your first dog" with `plus` icon,
  56pt height, 16pt radius, full-width (padded 32pt each side)
- `EmptyStateView` already wraps this — restyle in place

**Context menu (long-press on dog card):**
- Keep "Delete profile" destructive action
- Style the contextMenu preview to show the card at full size

---

## DOG PROFILE HOME (`ProfileHomeView`)

Scrollable sheet. No tab bar. Dismissal via Done button (top-left
when presented as sheet, back chevron when pushed).

**Hero section (`HeroCard`):**
- Current: centered circle photo (110pt) in a white card.
- Redesign: full-width photo, 280pt tall, edge-to-edge (no corner
  radius, extends to screen edges)
- Floating name card overlaid at the bottom of the photo:
  white card, 24pt radius on top corners only, 16pt radius bottom,
  contains:
  - Dog name in Title 1
  - Breed + age + weight in Caption (e.g. "Golden Retriever · 2yr · 65 lbs")
  - Personality tags as a horizontally scrolling chip row below
    (coral 12% opacity background, coral text, 8pt radius)
  - Bio text (if present) in Body, text secondary, max 3 lines,
    below the tags
- Card floats over the photo with elevated shadow
- `isShared` pill: sage background, "Shared profile" white text,
  top-right of the name card
- `isSample` pill: sage background, "Sample" white text,
  top-right of the name card
- No-photo fallback: coral gradient background at 280pt with
  large centered `pawprint.fill` in white at 60pt

**Offline notice:**
- Current: inline grey row. Restyle to match the redesigned
  `OfflineBanner` card from the home screen (compact, amber card,
  rounded 12pt, 16pt horizontal margin)

**Three-dot menu (trailing toolbar, only when `!dog.isShared`):**
- Keep "Edit profile" and "Delete profile" actions
- Restyle trigger icon: `ellipsis.circle` at 20pt, snootBrown

**Care section cards (below hero):**
- Section header: "Care Profile" in Label style (12pt, uppercase,
  letter-spacing +0.3), coral color, 24pt top padding, 16pt left margin
- Layout: 2-column `LazyVGrid` of care section cards
- Current sections (from `sectionData` in `ProfileHomeView`):
  1. Mealtime       — icon: `fork.knife`
  2. Walks          — icon: `figure.walk`
  3. Personality    — icon: `heart`
  4. Quirks & behaviour — icon: `bolt`
  5. Health & meds  — icon: `cross.case`
  6. Bedtime        — icon: `moon.stars`
- Each card:
  - Icon (SF Symbol) in a 40x40pt circle, sage green background (#EBF4EA)
  - Section name in Title 3
  - Completion badge top-right:
    Complete → green checkmark badge (`checkmark.circle.fill`, sage)
    Incomplete → coral dot badge (`circle.fill`, coral, 8pt)
  - Summary text in Caption, text secondary, 2 lines max
  - Card shadow: subtle
- Tapping a card opens `OnboardingFlowView(editingDog:)` at the
  relevant step (wire up per section)

**Feature rows (full width, below grid):**
Shown only when `auth.isAuthenticated && dog.supabaseId != nil`.
These are `FeatureRow` components — restyle them as accent-bordered cards:

- "Sitter Links" (`FeatureRow`):
  - Coral left border accent (4pt wide)
  - Shows active link count or "No active links"
  - Icon: `link.circle.fill` in coral

- "Recent Visits" (`FeatureRow`):
  - Sage left border accent
  - Shows last visit summary (sitter name + relative time) or "No visits yet"
  - "New" badge: coral pill when `latestVisitIsNew`
  - Icon: `clock.badge.checkmark` in sage

- "Family Access" (`FeatureRow`):
  - Amber left border accent
  - Shows member count or "Just you"
  - Icon: `person.2.circle.fill` in amber/purple

**Auth/sync state rows (mutually exclusive with feature rows):**
- Not signed in: white card, `link.circle.fill` coral icon,
  "Sign in to unlock sharing" title, subtitle, chevron right.
  Coral left border accent.
- Signed in, not synced: white card, `arrow.triangle.2.circlepath`
  coral icon (or `ProgressView` when `isSyncing`), "Upload profile
  to enable sharing" title, subtitle, chevron right.
- Both use the same left-border card style as feature rows.

**Action buttons (below feature rows):**
- "Open sitter care guide": full-width, sage fill, white text,
  `person.fill.questionmark` icon, 56pt height, 16pt radius
- "Export as PDF": full-width, white fill, coral text and border
  (1.5pt), `doc.fill` icon, 56pt height, 16pt radius

**Toast overlay:**
- Keep the existing bottom toast. Restyle: coral/snootBrown 90%
  capsule with white text, `.spring` entry from bottom.

---

## ONBOARDING FLOW (`OnboardingFlowView`, Steps 1–8)

**Container:**
The flow uses a `NavigationStack` with a custom toolbar (back/cancel
leading). The existing `.asymmetric` transition is correct — keep it.

**Top bar:**
- Leading: back chevron (`chevron.left`, snootBrown) or "Cancel" text
  on step 1 (already implemented)
- Center: add a step pill indicator row — 8 small pill shapes
  (one per step), active = coral filled, complete = sage filled,
  upcoming = #F0EDE8 background. Animate each with spring on advance.
- Trailing: "Skip" text button (text secondary color) — currently
  implemented as a bottom button; move a "Skip" shortcut to the top
  bar for steps that allow skipping

**`OnboardingStep` wrapper (shared by all steps):**
- `ProgressBarView` at top: thin (3pt) capsule, coral fill,
  already spring-animated — restyle height from 6pt to 3pt,
  remove "Step X of Y" label (replace with pill indicator above)
- Top 35% of screen: illustration zone
  - Large SF Symbol relevant to the section (see per-step list below)
  - 72pt in a soft circular gradient background (coral at 10% opacity
    fading to transparent)
  - Illustration sits above the title/subtitle
- Section title: Title 1, centered, below illustration
- Section subtitle: Body, text secondary, centered, max 2 lines
- Bottom input area: white card container, 24pt top radius,
  background white, containing the step-specific inputs
- Continue CTA: full-width coral button, 56pt, 16pt radius,
  spring bounce on tap. Disabled state: #F0EDE8 background,
  text tertiary. Label varies by step (see below).
- Skip/Add later: text button below CTA, text secondary

**Per-step illustration symbols and labels:**

| Step | Title | Illustration symbol |
|------|-------|-------------------|
| 1 | First, the basics | `pawprint.fill` |
| 2 | \(name)'s personality | `heart.fill` |
| 3 | A word from the pup | `text.bubble.fill` |
| 4 | Mealtime | `fork.knife` |
| 5 | Walks | `figure.walk` |
| 6 | Quirks & feelings | `bolt.fill` |
| 7 | Health & meds | `cross.case.fill` |
| 8 | Bedtime | `moon.stars.fill` |

**Step 1 — Basics (photo, name, breed, DOB, weight):**
- Photo picker: round 120pt circle, coral dashed border when empty,
  camera icon + "Add photo" label inside. Filled: photo fills circle.
  `PhotosPicker` wraps this — no logic change.
- Name field: bottom border only (no box). Coral underline on focus,
  #F0EDE8 unfocused. Placeholder in text tertiary.
- Breed: tappable row showing selected breed + `chevron.right`.
  Tapping opens the breed picker sheet (already implemented as a
  `NavigationStack` list with search). Restyle the sheet to match
  design system: snootCream background, snootOrange checkmark.
- Date of birth: inline `DatePicker`, labelsHidden, styled as a
  card row with coral accent on selected date.
- Weight stepper: custom design — coral minus button (40pt circle),
  value in Title 2 centered, coral plus button (40pt circle).
  No default SwiftUI stepper styling.

**Step 2 — Personality (`TagChipGrid`):**
- `TagChipGrid` with preset personality options + custom tag input.
- Unselected chips: #F0EDE8 background, text secondary, 8pt radius,
  12pt H padding, 8pt V padding
- Selected chips: coral background, white text, spring fill animation
- Custom tag input: bottom-border text field + `plus.circle.fill`
  coral button when text is non-empty. Already implemented in
  `TagChipGrid` — restyle only.

**Step 3 — Bio (`TextEditor`):**
- Full `TextEditor` in a card container, 24pt top radius, min 160pt.
- Custom placeholder overlay (already implemented using ZStack).
- Placeholder text: text tertiary. No default grey background.

**Step 4 — Feeding:**
- Meals per day stepper: custom coral stepper (same as weight in Step 1).
  Value 0 = "Free feed" displayed instead of "0".
- Meal time pickers: one `DatePicker` per meal (up to `mealsPerDay`),
  each in its own card row. Coral accent on selected time row.
- Portion, food brand: bottom-border text fields.
- Portion unit: custom segmented control (cups / grams / oz) —
  pill-shaped container, #F0EDE8 background, white card on selected
  segment with card shadow, animated slide.
- Food allergies: `TagChipGrid` with custom input.
- Treats policy: custom segmented control ("Freely" / "Ask first" /
  "Never") with same styling.

**Step 5 — Walks:**
- Walks per day: custom coral stepper.
- Walk time pickers: one per walk, card row style.
- Walk duration: custom coral stepper (value shows "30 min", "1hr+").
- Leash behaviours: `TagChipGrid` with preset options.
- Off-leash trusted: custom toggle (not default UIKit toggle) —
  coral accent, large 44pt touch target.
- Off-leash notes: bottom-border text field (conditional, shown when
  `offLeashTrusted` is false).

**Step 6 — Behaviour:**
- Fear triggers: `TagChipGrid` with preset fear options + custom tag.
- Separation anxiety: custom segmented control
  (None / Mild / Moderate / Severe).
- Separation anxiety notes: bottom-border text field, conditionally
  shown with `.easeInOut(duration: 0.2)` animation when Moderate or
  Severe is selected (already implemented — restyle).
- Potty signal: bottom-border text field.
- Comfort items: bottom-border text field.

**Step 7 — Health & meds:**
- Has health conditions: custom toggle, coral accent.
- Health conditions text: conditional bottom-border text field.
- Medications list: each `MedEntry` shown as a card row with:
  medication name (Title 3), dose + timing + method (Caption).
  Add medication: coral `plus.circle.fill` button at bottom of list.
  Each entry is removable via a trailing swipe or red minus button.
- Warning signs: bottom-border text field.
- Vet info (name, clinic, phone): bottom-border text fields,
  grouped under a "Vet details" Label header.
- Emergency contact: bottom-border text field.

**Step 8 — Bedtime (last step, CTA = "Finish profile ✓"):**
- Sleep location: custom segmented control
  (Crate / Dog bed / Owner's bed / Anywhere).
- Bedtime: inline `DatePicker` (hourAndMinute), coral accent.
- Bedtime routine: `TagChipGrid` with preset options + custom tag.
- Night-time quirks: bottom-border text field.
- CTA: "Finish profile ✓" coral button (already wired to `finish()`).

---

## SITTER VIEW (`SitterView`, in-app)

Read-only care guide, presented as a sheet. Daytime / Overnight mode.

**Header:**
- Dog photo: full-width, 200pt, edge-to-edge (no corner radius).
  Gradient overlay on bottom 30% (same pattern as hero).
  No-photo fallback: coral gradient.
- Floating name card below the photo (same floating card pattern
  as profile home):
  - Dog name in Title 1
  - Breed + age in Caption
  - "Care guide for Daytime" / "Care guide for Overnight" in Caption,
    coral color
  - Card: white, 24pt top radius, elevated shadow

**Mode toggle:**
- Custom segmented pill below the name card:
  "Daytime" / "Overnight" options
- Coral selected state (white text), #F0EDE8 unselected,
  spring transition between segments

**Section cards (scrollable, 16pt horizontal margin):**
Each care section (`SitterSection` / `SectionCard`) is a full-width card.
Currently sections are: Mealtime, Walks, Medications (if any),
Heads up (if fear triggers or separation anxiety), Personality,
Emergency contacts. Overnight adds: Bedtime, First 24 hours.

For each card:
- Icon in sage circle (top left, 36pt circle)
- Section title in Title 3
- `InfoRow` items: label in Caption text secondary, value in Body
  text primary, subtle divider between rows
- `highlight: true` rows: amber/coral tint background, bold value text
- 16pt spacing between cards
- Cards use card shadow

**Section-specific details:**

Mealtime card:
- Meal times shown as horizontal row of coral time pills
  (e.g. "7:00 AM", "6:00 PM") before the info rows
- Free-feed state: single "Free feed all day" body row

Walks card:
- Walk times as sage time pills in a horizontal row
- Leash behaviour tags as a chip row below `InfoRow` items

Medications card (shown only when `!dog.medications.isEmpty`):
- Amber left border accent (4pt) to signal importance
- Each `Medication`: name in Title 3 bold, dose + timing + method
  in Body below

Heads up card (shown when fear triggers or separation anxiety != None):
- Orange/coral left border accent
- Fear trigger chips (highlight style)
- Separation anxiety level with highlight when Moderate or Severe

Emergency contacts card (always last):
- Coral/red left border accent
- Owner contact and vet info as tappable `tel:` link rows
  (use `Link` with `tel:` scheme)
- "No contacts added yet" empty state if both are blank

Overnight-only cards:
- Bedtime card: icon `moon.stars`, purple-ish iconColor
- First 24 hours card: auto-generated bullet list, icon `star.fill`,
  sage iconColor. Keep existing logic, restyle bullets with sage dot
  instead of text "•".

**Toolbar:**
- "Done" button (top right, confirmationAction) — keep, restyle
  in snootOrange

**Share / navigation:**
- No sticky share button needed for the in-app view (dismissed with Done)
- The web-facing sitter link view (HTML) is separate infrastructure
  and is not part of this Swift redesign

---

## VISIT HISTORY (`VisitHistoryView`, in-app)

List of `VisitLog` entries for the dog, fetched from Supabase.

**List screen:**
- Each visit: card with subtle shadow
  - Left side: date/time in Caption + sitter name (from `loggedByName`)
    in Title 3
  - Right side: icon row — `fork.knife` if `fed`, `figure.walk` if `walked`
  - Below: `notes` in Body, text secondary, max 2 lines
  - Unread/new visits: coral left border accent
- Swipe-to-refresh: pull-to-refresh with coral tint (`snootOrange`)
- Empty state: sage `pawprint.fill` at 56pt, "No visits logged yet"
  in Title 2, "Your sitter can log visits via their link" in Caption

---

## ACTIVE SITTER LINKS (`SitterLinksView`)

Management screen for `SitterLink` records.

**Each link card:**
- Dog name + mode (Daytime / Overnight / Both) in Title 3
- Created date and expiry in Caption, text secondary
- Active indicator: pulsing green dot (subtle `.repeatForever` scale
  animation 1.0 → 1.1 → 1.0)
- Deactivated links: greyed out card, text tertiary, 
  strike-through on title label
- Swipe actions: "Copy link" (sage) and "Deactivate" (destructive coral)

**Create link (`CreateLinkView`, bottom sheet):**
- 24pt top radius sheet with drag indicator at top
- Mode selection: custom segmented pill (Daytime / Overnight / Both)
- Expiry picker: card row with `DatePicker` (date only), coral accent
- "Create link" coral CTA at bottom, 56pt, 16pt radius

---

## FAMILY ACCESS (`FamilyAccessView`)

Manage `DogOwner` records (shared access roles).

**Member list:**
- Each `DogOwner` row: avatar circle (56pt, coral background, white
  initial letter if no photo), name + email in Title 3 / Caption,
  role pill (Owner / Editor / Viewer) in Label style, sage/amber/grey fill
- "Invite someone" button: outlined coral, `person.badge.plus` icon
- Pending invites (accepted = false): amber left border, "Pending"
  Caption label

---

## SETTINGS SCREEN (`SettingsView`)

Grouped list style with card containers, not default iOS grey table.
Each section in its own rounded card (16pt radius, card shadow).
Background: snootCream.

**Account card (authenticated):**
- Avatar row: 56pt full circle, coral background, white initial
  letter if no photo. Name in Title 3 next to avatar.
- Display name: bottom-border text field, inline save (checkmark
  when saved, `ProgressView` when saving)
- Email: read-only Caption row, text secondary
- "Change password": coral text, chevron right
- "Sign out": destructive text (#E05C5C), chevron right

**Account card (unauthenticated):**
- Single "Not signed in" row, text secondary
- Coral "Get started" button

**Notifications card:**
- "Visit log alerts" toggle, coral tint
- Caption below: "Get notified when a sitter logs a visit."

**Data card:**
- "Export all data as JSON" row, `square.and.arrow.up` icon, coral text
- "Delete account" row (if authenticated), #E05C5C text — in its own
  separate card at the bottom for visual isolation

**About card:**
- Version row: label + value in Caption

**Destructive actions (sign out, delete account):**
In their own card at the very bottom, text in #E05C5C.

**Change password sheet:**
- `NavigationStack` sheet, snootCream background
- Two `SecureField` rows (bottom-border style)
- Error inline: Caption, #E05C5C, `exclamationmark.circle` icon
- "Update password" coral CTA, disabled when fields don't match
  or password < 6 chars

---

## AUTH VIEW (`AuthView`)

Sign-in / sign-up sheet. Not currently styled to design system.

**Layout:**
- White/snootCream background, no navigation bar
- Snoot logo / `pawprint.fill` at 72pt coral, centered at top
- Title: "Welcome to Snoot" in Title 1, centered
- Subtitle: "Sign in to sync and share your dog's care guide"
  in Body, text secondary, centered
- Email + password fields: bottom-border style, coral underline on focus
- "Sign in" / "Create account" coral CTA button, full-width, 56pt
- Toggle between sign-in and sign-up modes: text button below CTA,
  text secondary
- Error state: inline below the relevant field, Caption, #E05C5C,
  `exclamationmark.circle` icon

---

## SHARE MODAL (`ShareModal`)

PDF export sheet (legacy, accessible via "Export as PDF" button in profile).

- `NavigationStack` sheet
- Preview of dog profile summary (name, photo, key care facts)
- "Export PDF" coral CTA
- Style to match design system (snootCream background, card containers)

---

## MICRO-DETAILS (apply everywhere)

**Haptic feedback:**
- Light impact: chip selection, toggle
- Medium impact: primary CTA button
- Success notification: link creation

**Empty states:** always include a relevant SF Symbol (large, coral or
sage), a title (Title 2), and a one-line subtitle (Caption). Never
just "No data."

**Loading states:** skeleton screens using shimmer animation
(opacity 0.4 → 0.8 → 0.4, 1.2s loop). Use `redacted(reason: .placeholder)`
as the foundation.

**Error states:** inline, below the relevant field, Caption size,
#E05C5C, with an SF Symbol `exclamationmark.circle`.

**Pull to refresh:** custom tint coral on all list screens.

**All buttons minimum 44x44pt touch target.**

**Keyboard avoidance:** all forms use `.ignoresSafeArea(.keyboard)`.
`OnboardingStep` is a `ScrollView` — keep this, ensure content clears
the keyboard correctly.

**Safe area:** all sticky bottom elements respect the home indicator
safe area using `.safeAreaInset(edge: .bottom)`.

---

## EXISTING COMPONENT INVENTORY

These components exist and need restyling (not rewriting):

- `TagChipView` / `TagChipGrid` — restyle per chip design spec above.
  Keep the custom tag text field + `plus.circle.fill` button.
- `SectionCard` / `OnboardingStep` — restyle per design spec.
- `ProgressBarView` — reduce to 3pt, remove step label,
  keep spring animation.
- `FlowLayout` — keep as-is (layout logic only).
- `FeatureRow` — restyle to left-border accent card.
- `HeroCard` — full redesign to full-bleed photo + floating name card.
- `DogCard` — full redesign to full-bleed photo card.
- `InfoRow` — restyle divider, label/value typography.
- `SitterSection` (wraps `SectionCard` in SitterView) — restyle per spec.
- `OfflineBanner` — restyle to amber card (not full-width grey bar).
- `AccountPromptBanner` — restyle to coral left-border accent card.
- `fieldStyle()` View extension — replace with bottom-border style.

---

## DELIVERABLES

1. Full updated Xcode project with all SwiftUI views restyled
2. A `DesignSystem.swift` file containing all colors, typography
   constants, spacing values, corner radii, and shadow styles as a
   single source of truth. Migrate and extend `Color+Snoot.swift`
   into this file. Include `TextStyle` and `Spacing` enums/structs.
3. All existing functionality preserved exactly — no changes to
   `Dog` model, `OnboardingViewModel`, `AuthService`, `SyncService`,
   `SupabaseService`, or any data layer
4. No placeholder styling — every screen fully implemented
5. Test on iPhone 15 Pro simulator at minimum
