import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api/transit_api.dart';
import 'screens/map_screen.dart';
import 'services/polling_service.dart';
import 'state/map_ui_store.dart';
import 'state/transit_store.dart';

void main() {
  runApp(const BusLineApp());
}

class BusLineApp extends StatelessWidget {
  const BusLineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<TransitApi>(create: (_) => TransitApi()),
        ChangeNotifierProvider<MapUiStore>(create: (_) => MapUiStore()),
        ChangeNotifierProvider<TransitStore>(
          create: (ctx) => TransitStore(ctx.read<TransitApi>())..bootstrap(),
        ),
        Provider<PollingService>(
          lazy: false,
          create: (ctx) => PollingService(ctx.read<TransitStore>())..start(),
          dispose: (_, p) => p.stop(),
        ),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: MapScreen()),
      ),
    );
  }
}
