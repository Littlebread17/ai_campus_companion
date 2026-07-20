import 'package:latlong2/latlong.dart';

/// Ground-truth lat/lon per campus block, used when the Wi-Fi fingerprint gives
/// us a confident block prediction but GPS is unreliable (indoors, weak signal,
/// or an emulator with fake GPS). Kept in one place so [LocationsScreen] and
/// the arrow-guide agree on the same coordinates.
class CampusCoords {
  CampusCoords._();

  static const buildings = <String, LatLng>{
    'Academic Block A': LatLng(2.814000, 101.758273),
    'Academic Block B': LatLng(2.814300, 101.758500),
    'Academic Block C': LatLng(2.813700, 101.758600),
    'Academic Block D': LatLng(2.813600, 101.758000),
    'Academic Block E': LatLng(2.813400, 101.758400),
    'Learning Resource Centre': LatLng(2.814400, 101.758100),
    'Student Centre': LatLng(2.813300, 101.758800),
    'Sports Complex': LatLng(2.814600, 101.758700),
    'Hall of Residence': LatLng(2.813100, 101.759000),
    'Service Building': LatLng(2.813800, 101.757800),
  };

  static LatLng? forBlock(String block) => buildings[block];
}
