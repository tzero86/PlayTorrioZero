# Perf headroom — 3 targets

## 1) Recently-seen service cache
- Add bounded `Map<String, List>` to `ContinueWatchingService` / `MyListService` (max 20, LRU via insertion order).
- Key = `sectionType + filter + lastWatchedAt` (stable); value = last list snapshot.
- Invalidate on `add`/`remove`/`toggle`; never touch storage (memory only).
- Reduces redundant rebuilds when the same tab is revisited.

## 2) Adult/NSFW stale-while-refresh
- Replace all-or-nothing `_onAdultContentChanged` with per-row refresh.
- Keep existing `_animeRows` visible; set `_staleAnime = true`; refresh each row independently via `_ensureAnimeRows()` per row.
- Clear only the recommendation cache (`clearRecommendationCache`) but do NOT clear `_animeRows`.
- Debounce stays 800 ms; reload fires per-row rather than full `_loadHome`.

## 3) Manga / dense-grid precache
- Bump reader precache from `current±1` to `current±2` at `2× screenWidth`.
- Keep thumb precache at 140 (`memCacheWidth`).
- Memory stays bounded (resize key is same `ResizeImage` entry).
