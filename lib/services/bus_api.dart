import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bus.dart';

class BusApi {
  static const String _url =
      'http://10.0.2.2:3000/vehicles'; // change if NOT android emulator

  static Future<List<Bus>> fetchBuses() async {
    final res = await http.get(Uri.parse(_url));

    if (res.statusCode != 200) {
      throw Exception('Failed to load buses');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => Bus.fromJson(e)).toList();
  }
}