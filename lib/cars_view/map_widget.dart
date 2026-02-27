import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cars_data.dart';

class MapWidget extends StatefulWidget {
  final bool clickMarker;

  const MapWidget({super.key, required this.clickMarker});

  @override
  State<MapWidget> createState() => MapWidgetState();
}

class MapWidgetState extends State<MapWidget> {
  MapWidgetState() :
      this.startPosition = LatLng(0, 0), // TODO: Get user's location.
      this.markers = [],
      this.touchMarker = null;

  final MapController mapController = MapController();

  LatLng startPosition;
  List<Marker> markers;
  Marker? touchMarker;

  @override
  void initState() {
    super.initState();

    // TODO: Doesn't work.
    // moveMapToCurrentPosition();
  }

  LatLng getMapPosition() {
    return mapController.camera.center;
  }

  static Future<Position?> getClientPosition() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    // Check and request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // Get the current position
    try {
      return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    // ignore: empty_catches
    } catch (e) {
      return null;
    }
  }

  void handleTap(TapPosition tapPosition, LatLng latlng) {
    // This function shouldn't be wired to respond to clicks if that's the case, but I want to be safe.
    if (!widget.clickMarker) return;

    setState(() {
      touchMarker = Marker(
        point: latlng,
        rotate: true,
        width: 80,
        height: 80,
        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
      );
    });
  }

  LatLng? getTouchMarkerPosition() {
    if (touchMarker == null) return null;

    return touchMarker!.point;
  }

  Future<void> moveMapToCurrentPosition() async {
    var currentPosition = await getClientPosition();
    if (currentPosition == null) return;

    setState(() {
      // mapController.animateCamera(CameraUpdate.newLatLng(LatLng(currentPosition.latitude, currentPosition.longitude)));
    });
  }

  void setCarMarkers(List<CarData> carData) {
    setState(() {
      print("Updating actually displayed markers on the map!!!");
      markers = carData
      .where((car) => car.geoLocation != null)
      .map((car) => Marker(
        rotate: true,
        child: Tooltip(
          message: car.name,
          child: Icon(
            Icons.directions_car,
            color: car.color,
            size: 40
          )
        ),
        point: LatLng(car.geoLocation!.latitude, car.geoLocation!.longitude)
      )).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: LatLng(32.0853, 34.7818), // Center the map over Tel Aviv, Israel.
        initialZoom: 9.2,
        onTap: widget.clickMarker ? handleTap : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'dev.roddyra.carparking',
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')), // (external)
            ),
          ],
        ),
        MarkerLayer(
          markers: markers + (touchMarker != null ? [touchMarker!] : []),
        ),
      ],
    );
  }
}