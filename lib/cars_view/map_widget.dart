import 'dart:async';

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
      this.markers = [],
      this.touchMarker = null;

  final MapController mapController = MapController();

  // LatLng clientPosition = 
  List<Marker> markers;
  Marker? clientPositionMarker;
  Marker? touchMarker;

  @override
  void initState() {
    super.initState();

    // Only focus the map on the first time. I want to allow users to move the map freely.
    updateClientPositionMaker(focusMap: true);
    Timer.periodic(Duration(seconds: 5), (timer) {
      updateClientPositionMaker();
    });
  }

  LatLng getMapPosition() {
    return mapController.camera.center;
  }

  static Future<Position?> getClientPosition() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Failed to get location: Service disabled");
      return null;
    }

    // Check and request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
      print("Failed to get location: No permission");
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("Failed to get location: No permission, forever");
      return null;
    }

    // Get the current position
    try {
      return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print("Failed to get location: Failed to get current position");
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

  void focusOnLatLng(LatLng position) {
    mapController.move(position, mapController.camera.zoom);
  } 

  Future<void> updateClientPositionMaker({bool focusMap = false}) async {
    var currentPosition = await getClientPosition();
    if (currentPosition == null) return;

    var currentLatLng = LatLng(currentPosition.latitude, currentPosition.longitude);
    setState(() {
      print("Setting current position marker!!!");
      // Update the current location marker.
      clientPositionMarker = Marker(
        point: currentLatLng,
        child: CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.my_location, color: Colors.blue))
      );
    });

    // Update the current map position.
    if (focusMap) {
      mapController.move(currentLatLng, mapController.camera.zoom);
    }
  }

  void setCarMarkers(List<CarData> carData) {
    setState(() {
      print("Updating actually displayed markers on the map!!!");
      markers = carData
      .where((car) => car.geoLocation != null && !car.isOccupied())
      .map((car) => Marker(
        rotate: true,
        child: Tooltip(
          message: car.name,
          child: car.buildCarIcon()
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
        initialZoom: 18.0,
        onTap: widget.clickMarker ? handleTap : null,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'dev.roddyra.carparking',
        ),
        Padding(
          padding: EdgeInsetsGeometry.all(5),
          child: FloatingActionButton(
            onPressed: () => updateClientPositionMaker(focusMap: true),
            child: Icon(Icons.my_location),
          )
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
          markers: [?touchMarker, ?clientPositionMarker] + markers,
        ),
      ],
    );
  }
}