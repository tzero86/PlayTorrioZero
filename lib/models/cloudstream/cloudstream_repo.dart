import 'dart:convert';

/// Represents a CloudStream extension repository.
class CloudStreamRepo {
  final String url;
  final String name;

  const CloudStreamRepo({
    required this.url,
    required this.name,
  });

  factory CloudStreamRepo.fromJson(Map<String, dynamic> json) {
    return CloudStreamRepo(
      url: json['url']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Repository',
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'name': name,
      };

  String encode() => jsonEncode(toJson());

  static CloudStreamRepo decode(String str) =>
      CloudStreamRepo.fromJson(jsonDecode(str) as Map<String, dynamic>);
}
