import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class RunningMapScreen extends StatefulWidget {
  const RunningMapScreen({super.key});

  @override
  State<RunningMapScreen> createState() => _RunningMapScreenState();
}

class _RunningMapScreenState extends State<RunningMapScreen> {
  GoogleMapController? _mapController;
  List<LatLng> _route = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _route.add(LatLng(position.latitude, position.longitude));
    });
    // 지도 카메라 이동
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('러닝 경로', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _route.isNotEmpty ? _route.first : const LatLng(37.5665, 126.9780),
          zoom: 16,
        ),
        polylines: {
          Polyline(
            polylineId: const PolylineId('running_route'),
            points: _route,
            color: Colors.blue,
            width: 5,
          ),
        },
        myLocationEnabled: true,
        onMapCreated: (controller) => _mapController = controller,
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add_location),
        onPressed: _getCurrentLocation, // 위치 추가(테스트용)
      ),
    );
  }
}
