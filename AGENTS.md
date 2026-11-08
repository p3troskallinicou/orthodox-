# Klimax change and backup rules

- The user requires one preserved backup of the original code, not a new backup for every change.
- Preserve `backup/original-before-additions-2026-11-08` at `5f8ccf302c6eb8520cb40bc3c09e0961eb1ac6f4` permanently. Never overwrite, force-push to, merge into, or delete that branch.
- Do not create additional backup branches or tags unless the user explicitly requests them. Normal Git history and pull requests track subsequent changes.
- Do not reset or force-push `main` to restore an old version. Prepare a restoration branch and reviewable pull request instead.
- Browser previews are separate prototypes. Only changes explicitly approved for the iOS application should be translated into SwiftUI. Do not commit browser preview files, private transfer artifacts, or credentials here.

See `Documentation/quote-update-and-backups.md` for this update's verified backup references.
