# Changelog

All notable changes to ZPlay will be documented in this file.

## [1.1.8] - 2026-09-24

- Replaced the per-page floating dock with one adaptive shell, mounted once at the app root, so every destination always has navigation.
- Added five destinations (Home, Browse, Search, Library, Settings), shown on a left rail on tablet, desktop and TV and on a bottom bar on phones.
- Moved the seven media verticals into a single switcher inside Browse, each keeping its own scroll position and filters.
- Grouped My List and Downloads as tabs of Library.
- Moved playback into the shell, through one now-playing bar that follows the user between destinations.
- Gated the back buttons on the framework's canPop rule, so a page only shows back when it can actually pop.
- Replaced the ad-hoc breakpoints with one form-factor classifier built on shortestSide and remote-input detection.
- Deleted the dock widget, its settings page and its tests.

## [1.1.7] — 2026-09-24

- Refreshed the README and redesigned the GitHub Pages presentation.

## [3.0.0-early] — 2026-08-11

### Added
- Stremio-compatible addon protocol with catalog browsing, search, and metadata enrichment
- 9 VOD stream scrapers (FlyStream, Videasy, VidSrc, MultiEmbed, VidCore, 4KHDHub, XDownloader, Knaben, TorrentGalaxy)
- Native libtorrent streaming engine with intelligent file selection and real-time stats
- 9-source audiobook aggregator with torrent and direct streaming support
- WeebCentral manga reader with horizontal/vertical modes, zoom, and progress tracking
- Octave music streaming with library management, playlists, and keyboard shortcuts
- Subdl subtitle download and extraction with multi-language support
- Glassmorphism UI system with GPU shader effects and performance fallback toggle
- Custom route transitions (LiquidRevealRoute, CinematicSlideRoute)
- Responsive card layout adapting to phone, tablet, and desktop widths
- macOS-style liquid dock navigation
- 5-platform support (iOS, macOS, Android, Linux, Windows)
- Audiobook sleep timer and variable playback speed
- "More Like This" recommendations via BestSimilar scraper
- Search relevance scoring with exact-match-first ranking
- Progressive content loading across all sections
