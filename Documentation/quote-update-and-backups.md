# Approved saints' sayings update and backups

The original app, before the Porphyrios additions, is preserved in the remote branch
`backup/original-before-additions-2026-11-08` at commit
`5f8ccf302c6eb8520cb40bc3c09e0961eb1ac6f4` (41 Paisios sayings).

The main branch immediately before this approved update is separately preserved in
`backup/main-before-quote-update-2026-11-08` at commit
`9bec16b239577be92074cbc119deb4ce34e45fcb`.

Keep the original-before-additions backup permanently; never overwrite, force-push,
merge into, or delete it. The user clarified that no new backup is needed for each
change. Do not create further backup branches or tags without an explicit request;
normal Git history and pull requests track subsequent changes. Other snapshots
listed above are historical backups created before that clarification.

To inspect or restore an old version without altering main, create a new branch
from the relevant backup through GitHub's branch selector. Review any restoration
as a new pull request. Do not reset or force-push main.

## Final native feature scope

- 33 Porphyrios quotes, in the eight supplied categories, with seven original images.
- Existing Paisios quote texts, source attribution and verification status retained.
- Three collections: by saint, all saints, favourites.
- Local persistent favourites shared by the gallery, readers and full-screen feed.
- Stable shuffled all-saints feed with category filtering and text search.
- Full-screen vertical paging; floating search/filter controls; explicit exit.
- Complete quote text immediately visible; very long text scrolls within the reel.
- Idempotent double-tap likes, brief translucent heart feedback, reduced-motion support.
- Equal image and category-footer heights within each paired gallery row.
- Internal PDF/import notes and record IDs remain out of the source-details UI.

The browser preview is a separate prototype, not a shared runtime or a dependency
of the iOS app. General browser/device chrome refinements are not app features.
No browser-preview files, credentials or private transfer data belong in this repo.

## Approved Iakovos addition

- Six sayings of Άγιος Ιάκωβος Τσαλίκης, transcribed from the supplied PDF of the Kifissia Metropolis article, with its source URL retained. The source-check label records comparison with that PDF, not historical authentication.
- Five supplied photographs; JPEG originals copied unchanged, one WebP converted to PNG without changing decoded pixels for Xcode asset compatibility.
- Four existing topic IDs reused: family, Christian life/spiritual struggle, prayer/trust, and inner peace. No new categories or renaming of existing IDs.
- The landscape photo in the paired gallery fills its portrait-height frame with a reviewed horizontal crop. Its excerpt starts in the lower part of that frame; existing photo layouts retain their previous behaviour.
- Per-photo feed focus positions keep the new landscape portraits in view, while the existing photos keep their previous crops.
- Existing mixed feed, filtering, complete-text readers and persistent favourites include the new stable IDs automatically. Total: 80 sayings, three saints, 12 categories and 20 photographs.
- The original backup above remains unchanged. No additional backup branch is created.

## Approved November 9 collection and glass controls

- Native catalog now matches the approved collection: 116 replacement Paisios entries, 33 Evmenios sayings, 33 unchanged Porphyrios sayings and six unchanged Iakovos sayings. All 12 existing topic IDs and names are retained.
- The Paisios replacement covers every one of the 129 supplied source blocks. Continuous quotations and question-answer exchanges remain together. Original source wording, spelling and excerpt markers are retained; comparison status concerns the supplied PDF/page, not historical authentication.
- New Paisios IDs use the `paisios-haidari-` prefix. Retired `PAI-` favourites remain in the versioned stored set, but never resolve to unrelated replacement text or inflate visible favourites counts.
- Nine original Evmenios images are included. Two WebP images are converted to PNG with identical decoded pixels for Xcode asset compatibility. Existing Paisios image files are unchanged; their approved crop/text metadata is updated. Porphyrios and Iakovos data and image metadata are retained.
- Very long feed text begins collapsed, expands over the photo in place, scrolls when necessary and collapses using the same control. Complete shorter text stays visible. There is no separate dark reading panel.
- Filter and shuffle controls are aligned glass circles. The filter icon expands to a labelled pill and glass search/category panel. The category list uses the same glass material and selection checkmarks. Outside taps dismiss the panel.
- Category selection and shuffle preserve active filtering. Category selection closes the list/panel and contracts the pill before updating results. SwiftUI animation completion determines when the update occurs, with a brief results fade; pending tasks are cancelled on leaving the feed. Reduced motion bypasses animation.
- Native iOS 26 Liquid Glass uses the existing `athosGlass` helper; the existing material fallback supports older deployment targets. No dependency, workflow, Xcode project or unrelated application architecture changes are required.
- The preserved original backup remains unchanged; no new backup branch or tag is created. Browser-preview artifacts and private transfer files are excluded from this repository.

## Approved Κομποσχοίνι integration (November 10)

The approved browser feature is translated into dedicated native `PrayerRope.swift` and `PrayerRopeView.swift` components. It is a fourth entry in the existing Prayer dropdown; all existing categories and the five main tabs remain intact. A fixed seven-position close-up wool segment uses a single connecting cord, a proportionate opening cross, the lower knot as the control, and one-pitch motion with tap/downward-drag input. The separate Next button is absent. First advancement expands the prayer view and hides existing header/tab chrome; the back control restores it without losing progress. Reduce Motion shortens knot movement and bypasses the expansion transition.

All five cycle lengths and four intentions use the existing `DiptychaStore` and category IDs. `DiptychaEntry.prayerGrammar` is optional for backwards-compatible decoding of existing JSON. The existing name editor adds an optional disclosure for explicit grammatical gender, accusative, genitive and confirmation. Missing forms are never guessed; old names/notes/IDs/categories/dates remain intact. Confirmed forms are required only when using those entries in the rope. There is no second names store or sample data in the app. Renaming, recategorising or deleting selected names pauses an active prayer for review without rewriting its text or erasing progress.

`Application Support/Klimax/prayer-rope.json` stores only the new local draft/session, with atomic writes and iOS file protection until first unlock. Every deliberate advance is persisted, along with text visibility, focus state, length, intention and selected IDs. Canonical names remain in the existing diptycha file; a SHA-256 revision detects changes without copying another names database. Midpoint and completion feedback is consumed once per cycle after motion; inactive/interrupted movements are settled without a delayed haptic. Normal steps use very soft feedback, midpoint a gentle soft impact, completion a distinct rigid impact. No sound, rewards, tracking or external service is added. A UIKit haptic call compiling in a simulator does not validate physical iPhone feedback.

New transparent PNG assets contain only the approved wool knot/cross artwork, rasterised from the separate prototype at 3×. No browser HTML/JavaScript, preview data, transfer artifacts or private configuration are included in the native repository. Existing image/font assets are unchanged. Xcode changes are limited to registering two new Swift sources; build settings, dependencies and existing workflows are unchanged.

`Scripts/test-prayer-rope.swift` covers legacy entry decoding, exact Greek examples, missing/deleted names, all five complete cycles through 500 knots, one-shot milestones, persistence/resume, restart and name-change protection. Its documented command uses an existing Xcode Swift toolchain without packages. The Windows/Linux workspace has no Swift compiler; local execution is unavailable. The existing manual simulator workflow compiles the native application on macOS; actual touch, VoiceOver, animation and haptic behaviour require simulator/device review.

The sole required original backup remains `backup/original-before-additions-2026-11-08` at `5f8ccf302c6eb8520cb40bc3c09e0961eb1ac6f4`. No additional backup branch/tag is created. Integration uses normal feature-branch/PR history and a successful simulator build before merge.

## Prayer setup repair

The initial preview samples already contained confirmed forms, hiding the first-use path for real pre-existing Diptycha entries. Setup now distinguishes an empty selection from names requiring one-time confirmation. Each incomplete selected name has a direct confirmation link into its existing Diptycha editor, opened with grammatical fields expanded. In that requested context, confirmation requires both explicit forms and gender; saving or cancelling returns to prayer setup. Normal names editing remains optional and behaves as before. Confirming writes to the same canonical entry and immediately enables generated prayer text without another names store or guessed endings.

The Start button uses explicit white-on-oxblood enabled colours and readable ink on a neutral disabled surface, avoiding the inherited ink foreground which made the original prominent label unreadable. No prayer wording, case rules, existing names, cycle state, artwork, workflows, project settings or dependencies change.

## Automatic names and gender in Δίπτυχα

The mandatory case-form confirmation path is removed. Greek prayer forms now resolve through 167 explicit common names/nicknames/indeclinables/irregular forms, followed by regular masculine -ος/-ας/-ης and feminine -α/-η declension families. The -ος genitive handles stress movement with Greek vowel-pair/diaeresis rules. Known uppercase/accentless/previously inflected entries and compatible compound given names are supported. Explicit manual corrections retain priority. Unfamiliar forms remain unchanged when a grammatical gender is supplied; unknown or explicitly ambiguous names never get a guessed gender.

The existing Δίπτυχα editor has a visible Auto/Man/Woman selector. Its optional `prayerGender` is stored on the same `DiptychaEntry`; legacy JSON remains readable without migration or automatic rewriting. Ambiguous older entries can also receive that same field through a small inline gender choice when selected in prayer setup. This is a one-time gender choice, not a case-form confirmation step. Optional manual form correction remains under a collapsed disclosure; it is never required for automatically resolved names. Existing prayer wording, names/IDs/notes/categories/dates and the current session's saved text/count remain intact. Revision hashes stay byte-compatible when the new gender field is absent, so existing sessions aren't paused by an application update alone.

Browser/model fixtures cover all 167 dictionary rows and aliases (501 checks), 33 additional stress/compound/ambiguous/fallback cases, legacy-name startup with no metadata, gender selection persistence, explicitly supplied form priority and prior-session compatibility. `Scripts/prayer-name-cases.json` is test data, not a bundled personal dataset. The native standalone checks use the existing Xcode toolchain command; this workspace still has no Swift compiler. The existing manual simulator workflow compiles the native changes. No workflows, project settings, assets, dependencies or original backup references change.

## Prayer-rope bottom safe area repair

The Prayer library previously extended all section content through the bottom safe area. Κομποσχοίνι now opts out of that bottom-edge override; other Prayer sections retain their existing layout. Session progress, completion/review actions and save/return live in a native bottom `safeAreaInset`, so SwiftUI reserves their measured height above the home indicator or tab bar. The rope and text remain scrollable above the controls; fixed bottom padding no longer acts as the protection for session actions.

Completion actions retain their labels and behaviour. `ViewThatFits` chooses the existing horizontal row when it fits and a vertical stack when width/text size requires it; native large controls provide proper touch targets. Counting, prayer/name resolution, session persistence, artwork, dependency/project settings, existing workflows and original backup references are unchanged. Native compilation uses the existing manual macOS workflow; actual home-indicator layout still requires simulator/device visual review.
