# Custom credentials and identities

ZPlay talks to several third-party services. This page is the complete list of
every credential, identifier and host the app needs for that, where to obtain
your own, and how to put it into a build. Nothing here is required to compile:
every value has a working default, which is either a neutral ZPlay value or the
value inherited from the upstream PlayTorrio fork. Replacing the inherited
values is what removes the app's dependence on the upstream developer's
accounts and servers.

## The table

`Define` is the build-time name: pass it with `--dart-define=NAME=value` or
through the file given to `--dart-define-from-file`. For the keys that also have
a field in Settings, the user's value wins over `Define`, and `Define` wins over
the inherited value.

| What | Used for | Where to get your own | Define | Consumed by | Inherited upstream value still standing in |
| --- | --- | --- | --- | --- | --- |
| TMDb API key | Movie and TV metadata, ranked rails, and the scraper lookups that need a TMDb id | themoviedb.org, account settings, API (free key) | `TMDB_API_KEY` | `lib/services/metadata/tmdb_service.dart` (Settings row "TMDb API Key") | Yes, `TmdbService.builtInKey` is the last-resort fallback |
| Wyzie subtitle key | Subtitle search and download | store.wyzie.io/redeem (free key) | `WYZIE_API_KEY` | `lib/services/subtitles/providers/wyzie_provider.dart` through `ServiceCredentials` | Yes |
| Audionest search key | Audiobook search API (Google API key form) | No public signup, upstream private backend | `AUDIOBOOK_SEARCH_KEY` | `lib/services/audiobook/audiobook_scraper_service.dart` through `ServiceCredentials` | Yes |
| Audionest service bearer | Audiobook service calls (`Authorization: Bearer`) | No public signup, upstream private backend | `AUDIOBOOK_SERVICE_KEY` | `lib/services/audiobook/audiobook_scraper_service.dart` through `ServiceCredentials` | Yes |
| Paper2Audio key | PDF to audio conversion service | No public signup, upstream private backend | `PAPER2AUDIO_KEY` | `lib/services/audiobook/paper2audio_service.dart` through `ServiceCredentials` | Yes |
| VidGod bearer | Video scraper (`Authorization: Bearer`) | No public signup, and the cache cluster behind it is upstream infrastructure | `VIDGOD_TOKEN` | `lib/services/scraper/sites/vidgod.dart` through `ServiceCredentials` | No, blank by default |
| Films365 downloader bearer | Video scraper (`Authorization: Bearer`) | Third-party site credential, never issued to ZPlay | `XDOWNLOADER_TOKEN` | `lib/services/scraper/sites/xdownloader.dart` through `ServiceCredentials` | Yes |
| Trakt client id | Trakt OAuth device flow and all Trakt API calls | trakt.tv/oauth/applications (create an app, free) | `TRAKT_CLIENT_ID` | `lib/services/trakt/trakt_constants.dart` | No value is committed; build-time only |
| Trakt client secret | Trakt OAuth token exchange | Same Trakt application page | `TRAKT_CLIENT_SECRET` | `lib/services/trakt/trakt_constants.dart` | No value is committed; build-time only |
| Simkl client id | Simkl OAuth PIN flow and all Simkl API calls | simkl.com, developer app registration (free) | `SIMKL_CLIENT_ID` | `lib/services/simkl/simkl_constants.dart` | No value is committed; build-time only |
| Simkl client secret | Simkl OAuth token exchange | Same Simkl application page | `SIMKL_CLIENT_SECRET` | `lib/services/simkl/simkl_constants.dart` | No value is committed; build-time only |
| Simkl app name | The app name Simkl records for your requests, sent as the `app-name` query parameter and as the `User-Agent` | Any name you own; default is `ZPlay` | `SIMKL_APP_NAME` | `lib/services/simkl/simkl_constants.dart`, used by `lib/services/simkl/simkl_service.dart` | No: upstream's `debrify` was removed, the default is `ZPlay` |
| Discord application id | Discord Rich Presence (desktop) | discord.com/developers/applications | `DISCORD_APP_ID` | `lib/services/discord/discord_rpc_service.dart` | Not in the repo, but the id in use may be upstream's app; supply your own |
| AllDebrid agent | Agent identifier sent as the `agent` query parameter on AllDebrid API calls, which their terms require to be registered | Register the agent id with AllDebrid for your app; the value is the short slug you register | `ALLDEBRID_AGENT` | `lib/services/debrid/providers/alldebrid_service.dart` | No: the default is the neutral `ZPlay`, but it still has to be registered with AllDebrid |
| TMDb proxy host | Keyless TMDb fallback used when no TMDb key is available, see below | Your own TMDb-compatible proxy, or blank to disable | `TMDB_PROXY_BASE` | `lib/services/scraper/sites/tmdb_helper.dart` | No, off by default |
| Videasy API host | API host of the Videasy scraper (`ZPlayHTTP`), see below | Your own deployment, or blank to disable the scraper | `VIDEASY_API_BASE` | `lib/services/scraper/sites/videasy.dart` | No, off by default |

## Where the values live

| File | Role |
| --- | --- |
| `lib/services/config/env_service.dart` | Resolves every build-time value: `--dart-define` first, then a root `.env`, then the platform environment |
| `lib/services/config/service_credentials.dart` | The six service keys above, user-settable in Settings > Service API Keys, with the precedence user value, then build-time value, then inherited value |
| `lib/services/config/legacy_upstream_credentials.dart` | The single file holding every inherited upstream service key. Blank a line here once your replacement is live |
| `lib/services/metadata/tmdb_service.dart` | `builtInKey`, the inherited TMDb key kept only as the last-resort fallback |

Stored values are never shown back in the UI and never logged, so a key saved in
Settings can only be replaced, not read out.

## Building with your own values

1. Create a root `.env` file. It is gitignored, and no value from it may ever be
   committed or pasted into an issue:

   ```
   TMDB_API_KEY=your-tmdb-key
   WYZIE_API_KEY=your-wyzie-key
   AUDIOBOOK_SEARCH_KEY=your-audionest-search-key
   AUDIOBOOK_SERVICE_KEY=your-audionest-service-token
   PAPER2AUDIO_KEY=your-paper2audio-key
   VIDGOD_TOKEN=your-vidgod-token
   XDOWNLOADER_TOKEN=your-films365-token
   TRAKT_CLIENT_ID=your-trakt-client-id
   TRAKT_CLIENT_SECRET=your-trakt-client-secret
   SIMKL_CLIENT_ID=your-simkl-client-id
   SIMKL_CLIENT_SECRET=your-simkl-client-secret
   SIMKL_APP_NAME=ZPlay
   DISCORD_APP_ID=your-discord-application-id
   ALLDEBRID_AGENT=your-registered-agent-id
   TMDB_PROXY_BASE=your-tmdb-proxy-base
   VIDEASY_API_BASE=your-videasy-api-base
   ```

   Every name you do not own or do not need can simply be left out: the
   inherited or neutral default then stays in effect.

2. Build with the file:

   ```
   flutter build apk --dart-define-from-file=.env
   ```

   Single values can also be passed directly, for example
   `flutter build apk --dart-define=TMDB_API_KEY=your-tmdb-key`.

Rules:

- `--dart-define` wins over the `.env` file.
- The runtime `.env` reader covers debug and desktop runs plus a bundled asset;
  release mobile builds should use `--dart-define-from-file`.
- Never commit a credential, and never paste one into an issue, a chat log or a
  build log.

## The two upstream hosts, off by default

Both hosts belong to the upstream developer. Neither carries a credential, but
both point your users' requests at a machine you do not control, so neither is
used unless you name a replacement host at build time.

### `TMDB_PROXY_BASE` (`lib/services/scraper/sites/tmdb_helper.dart`)

An optional keyless TMDb lookup path: `tmdb_helper.dart` calls `<base>/find/<imdb id>`
and `<base>/search/<movie or tv>` with no API key at all. It is only tried after the
direct TMDb call has failed, or when no key exists.

- Unset: disabled. No request leaves for any third-party host.
- Set to your own TMDb-compatible host: that host is used with the same two paths.
  Be aware that hosting this for your users puts their TMDb traffic and quota on
  your account, which is what the key in Settings exists to avoid.
- With no host and no key, scrapers that need a TMDb id stop resolving titles and
  return no results. Set a key in Settings > TMDb API Key, or `TMDB_API_KEY`, or
  fall back to the inherited `TmdbService.builtInKey`.

### `VIDEASY_API_BASE` (`lib/services/scraper/sites/videasy.dart`)

The API host of the Videasy scraper, reported as `ZPlayHTTP` in the source list.
It fetches a seed (`<base>/seed?mediaId=<tmdb id>`) and then, per provider path,
one sources response (`<base>/cdn/sources-with-title`, `/neon2/...`, `/m4uhd/...`,
`/meine/...`, `/lamovie/...`), decrypts it and turns it into stream sources.

- Unset: disabled. This scraper contributes no sources and nothing else changes.
- Set to your own deployment of that API: it is used instead. Replacing this one
  means reimplementing a multi-CDN extractor, so the realistic choices are your
  own deployment or leaving it off.

## Identities the app presents to third parties

- Simkl: `SIMKL_APP_NAME` (default `ZPlay`) is sent as `app-name` and as the
  `User-Agent`. Upstream's `debrify` identity is gone.
- Reddit OAuth (IPTV catalog): `_oauthUa` in `lib/services/iptv/iptv_network.dart`
  is now `android:io.github.tzero86.zplay:v1.2.1 (+https://github.com/tzero86/ZPlay)`.
  Reddit expects a unique, descriptive User-Agent; adding a contact Reddit
  username as `by /u/<username>` is advisable, and that constant is where to add it.
- AllDebrid: the `agent` value described above, which their terms expect to be
  registered with them.
- Discord: the application id above, which also owns the Rich Presence asset keys
  (`logo`), so an inherited id shows the wrong artwork.

## Attribution

This product uses the TMDB API but is not endorsed or certified by TMDB.
