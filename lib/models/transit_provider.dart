/// A GTFS feed provider (from the static `assets/data/providers.json`).
///
/// Mirrors the data.gov.my provider metadata payload:
/// https://api.data.gov.my/gtfs-static
class TransitProvider {
  final int id;
  final String providerKey;
  final String providerName;
  final String category;
  final String descShort;
  final String descLong;
  final String gtfsUrl;
  final String? gtfsRealtimeUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransitProvider({
    required this.id,
    required this.providerKey,
    required this.providerName,
    required this.category,
    required this.descShort,
    required this.descLong,
    required this.gtfsUrl,
    this.gtfsRealtimeUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransitProvider.fromJson(Map<String, dynamic> json) {
    return TransitProvider(
      id: json['id'] as int,
      providerKey: json['provider_key'] as String,
      providerName: json['provider_name'] as String,
      category: json['category'] as String,
      descShort: json['desc_short'] as String,
      descLong: json['desc_long'] as String,
      gtfsUrl: json['gtfs_url'] as String,
      gtfsRealtimeUrl: json['gtfs_r_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider_key': providerKey,
      'provider_name': providerName,
      'category': category,
      'desc_short': descShort,
      'desc_long': descLong,
      'gtfs_url': gtfsUrl,
      'gtfs_r_url': gtfsRealtimeUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() => 'TransitProvider($providerKey: $providerName)';
}
