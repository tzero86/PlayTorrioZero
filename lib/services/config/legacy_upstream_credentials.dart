import 'service_credentials.dart';

/// Credentials inherited from the upstream PlayTorrio fork, kept only so the
/// integrations that already depended on them keep working until the owner
/// supplies replacements. Blank a value here once the replacement is live.
///
/// A blank entry means that integration is off until someone opts in with a
/// build-time value or their own key in Settings. Entries are blank for one of
/// two reasons, recorded inline so nobody restores one by accident: the value is
/// a credential for a service that never issued it to ZPlay, or the endpoint is
/// a machine the upstream developer runs.
const Map<ServiceCredential, String> legacyUpstreamCredentialValues = {
  ServiceCredential.wyzie: 'wyzie-2q1gc0ypd8mkisqcw0ijt1b9zjytj7ex',
  ServiceCredential.audiobookSearch: 'AIzaSyAG-z_yl0_55NEYTEKGoVJyixtHG-FhnfA',
  ServiceCredential.audiobookService: 'MWJiNWM0MjA2N2ZkM2RiMDNhNWFmNGNk',
  ServiceCredential.paper2audio: 'AIzaSyAq9_a8hU7sNkwUBJFmSlbmhepbu8bRgqw',
  // Blank: the cache cluster behind this token is upstream infrastructure, the
  // same operator as the two hosts in tmdb_helper and videasy. Supply your own
  // or leave this scraper switched off.
  ServiceCredential.vidgod: '',
  ServiceCredential.xdownloader:
      '79a02956be35835728a044b11e2ae793149d45fb2c89cb6d029ec01aac19bfdb',
};
