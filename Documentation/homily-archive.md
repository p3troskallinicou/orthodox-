# Homily archive delivery

The application bundles only `homily-archive.json`. The 1,850 MP3 files stay outside the application so the initial installation does not include the roughly 29 GB archive.

To publish the audio, upload the MP3 files without changing their filenames to an HTTPS object storage or CDN directory. Then regenerate the manifest with its public directory URL:

```sh
python3 Scripts/build-homily-catalog.py \
  /path/to/omilies.pdf \
  "/path/to/32GB 1850-2022" \
  Klimax/homily-archive.json \
  --audio-base-url "https://audio.example.org/homilies/"
```

Alternatively, set `HomilyArchiveBaseURL` in the application Info.plist. That value overrides the URL stored in the JSON and is useful when moving the same catalogue between environments.

The player streams from that address until the listener selects the download control. Downloaded files are stored in Application Support and are preferred automatically for later offline playback. Removing a download deletes only the local copy.
