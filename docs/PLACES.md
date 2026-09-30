# Place search

City Explorer uses the Google Places API (New) when a key is available. The key is read at runtime from `CITY_EXPLORER_GOOGLE_PLACES_API_KEY`; it is never stored in the project or exported application. Autocomplete requests use the selected city's configured rectangular `locationRestriction`, and place details supply the exact latitude/longitude used by the existing nearest-road spawn logic.

Enable **Places API (New)** in a Google Cloud project with billing, create a separate API key, and restrict that key to Places API (New). For local development:

```sh
export CITY_EXPLORER_GOOGLE_PLACES_API_KEY='your-restricted-key'
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/hahneyshkondeti/Documents/ChatGPT/Explorer
```

For a local packaged build launched from Terminal:

```sh
CITY_EXPLORER_GOOGLE_PLACES_API_KEY='your-restricted-key' \
  '/Applications/City Explorer.app/Contents/MacOS/City Explorer'
```

Finder-launched applications do not normally inherit Terminal environment variables. A public desktop release should inject a restricted key through its launch/deployment configuration or use a small server-side key proxy. Do not commit a key or bake an unrestricted web-service key into the app.

With no key, search falls back to the bundled dated OpenStreetMap-derived address and place index. The fallback does not fabricate results and remains usable offline.
