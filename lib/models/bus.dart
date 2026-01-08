class Bus {
  final String id;
  final double lat;
  final double lon;
  final double bearing;

  Bus({
    required this.id,
    required this.lat,
    required this.lon,
    required this.bearing,
  });

  factory Bus.fromJson(Map<String, dynamic> json) {
    return Bus(
      id: json['id'],
      lat: json['latitude'].toDouble(),
      lon: json['longitude'].toDouble(),
      bearing: json['bearing'].toDouble(),
    );
  }
}