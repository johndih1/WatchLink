# A personal WatchLink store

Yes: we can design the catalog, author the content and define our own files.
The execution location matters more than the filename.

| Content type | What is needed | Current status |
|---|---|---|
| iPhone themes, saved layouts, catalog entries | Reader inside our iPhone app | Possible future app feature; not implemented in v0.1 |
| Images or music sent to the watch | A compatible existing watch receiver and a verified transfer protocol | Not verified |
| New watch faces | Existing compatible watch-face loader or an installable signed watch-face package | Not verified; custom extension alone is insufficient |
| New games, utilities or interactive watch apps | A watch-side executable or interpreter accepted by Tizen | Blocked until an installation/runtime route is established |

## Proposed format: `.watchlink`

A future `.watchlink` file could be a ZIP with a JSON manifest and content assets. It should contain data, not arbitrary executable code. An illustrative manifest:

```json
{
  "formatVersion": 1,
  "id": "personal.midnight",
  "title": "Midnight",
  "kind": "phone-theme",
  "target": "watchlink-ios",
  "minimumAppVersion": "0.2",
  "assets": ["preview.png"],
  "theme": { "accent": "#78E9CD", "background": "#0C1519" }
}
```

This example is a proposed schema, **not an importable v0.1 file**. We would implement schema validation, bounded archive sizes, safe path extraction, checksums and clear target compatibility before importing packages. Watch-targeted content must remain disabled until its receiver is proven to work.

## Store design

- **Discover:** compatible items with previews and clear phone/watch target labels.
- **My collection:** downloaded content and its supported destination.
- **Create:** author phone themes first; additional content types only after their runtime is available.
- **Details:** required app/runtime version, content author and actual compatibility.

No label should promise “Install to watch” for a file that only our phone can read. Our iPhone app interpreting data does not confer the ability to run that data on Tizen. If we eventually establish a way to install one watch-side host app, that host could become a runtime for our own content, subject to its capabilities and Tizen restrictions.
