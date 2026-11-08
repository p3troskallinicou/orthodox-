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
