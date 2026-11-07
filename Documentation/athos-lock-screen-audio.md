# Athos Lock Screen artwork

Athos Audio now includes `MPMediaItemPropertyArtwork` in every Now Playing
metadata update, including pause, seek and queue changes. The artwork uses the
episode's subject rather than a navigation label (for example Search or Daily
Clip), matching the full-screen audio player's cover. Bundled source covers are
rendered once into a square 600px image and cached with an eight-cover limit.
No cover download is needed for offline playback.

Verification on 22 October 2026:

- Debug simulator build passed.
- `test-athos-now-playing.mjs`, `test-athos-player-navigation.mjs` and
  `test-media-progress.mjs` passed.
- An isolated iOS simulator harness using the production artwork and metadata
  functions verified image pixels, square dimensions, cache reuse, pause/seek
  retention, next-episode artwork replacement and an unknown-topic fallback.
- Final Lock Screen appearance still needs a physical iPhone check: the QA
  simulator did not display system media controls, even with a local-audio test.

## Athos TV / audio switch — not implemented

The TV catalogue contains YouTube IDs and watch URLs, but no independent audio
URLs. The bundled audio archive has no YouTube episode mappings. Do not guess a
counterpart from its title or scrape a YouTube media URL.

The current TV player remains foreground-only, and this change does not fix its
system-player artwork. Its metadata is controlled by the embedded player.
YouTube's developer policies prohibit separated audio and background playback:
https://developers.google.com/youtube/terms/developer-policies-guide

A native audio switch requires authorized, independently hosted audio for the
same episodes, with an explicit video-ID mapping and any timing offsets. With
those sources, the shared Athos Audio player can be used and playback position
can be carried across the mode switch. No nonfunctional switch is shown today.
