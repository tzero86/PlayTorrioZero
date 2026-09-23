
import 'package:zplay/models/subtitle/subtitle_model.dart';

abstract class SubtitleProvider {
  String get name;

  /// Searches for available subtitles for the given movie/episode.
  Future<List<SubtitleVariant>> search(
    String movieName, {
    String? imdbId,
    int? season,
    int? episode,
    int? year,
  });

  /// Downloads and extracts the subtitle file to a temporary directory.
  /// Returns the absolute path to the local .srt or .vtt file.
  Future<String?> download(SubtitleVariant variant);
}
