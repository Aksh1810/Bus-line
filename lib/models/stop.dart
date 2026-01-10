class Stop {
  final double lat;
  final double lon;
  final String name;

  Stop({
    required this.lat,
    required this.lon,
    required this.name,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    final lat = json['latitude'];
    final lon = json['longitude'];

    if (lat == null || lon == null) {
      throw Exception('Invalid stop coordinates');
    }

    return Stop(
      lat: (lat as num).toDouble(),
      lon: (lon as num).toDouble(),
      name: json['name'] ?? '',
    );
  }
}