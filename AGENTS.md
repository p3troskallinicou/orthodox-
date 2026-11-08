# Klimax change and backup rules

- The user requires a backup before each approved update to `main`.
- Preserve `backup/original-before-additions-2026-11-08` at `5f8ccf302c6eb8520cb40bc3c09e0961eb1ac6f4` permanently. Never overwrite, force-push to, merge into, or delete that branch.
- Before merging into `main`, read the current remote main SHA, create a new remote branch `backup/main-before-<change>-<date>-<short-sha>` pointing to it, and verify the remote ref. Never reuse a backup name for a different commit.
- Do not reset or force-push `main` to restore an old version. Prepare a restoration branch and reviewable pull request instead.
- Browser previews are separate prototypes. Only changes explicitly approved for the iOS application should be translated into SwiftUI. Do not commit browser preview files, private transfer artifacts, or credentials here.

See `Documentation/quote-update-and-backups.md` for this update's verified backup references.
