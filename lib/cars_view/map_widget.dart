import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'cars_data.dart';

class MarkersList extends ChangeNotifier {
  List<Marker> _carMarkers = [];
  Marker? _touchMarker;
  Marker? _clientPositionMarker;

  void updateCarMarkers(List<CarData> carData) {
    _carMarkers = carData
      .where((car) => car.geoLocation != null && !car.isOccupied())
      .map((car) => Marker(
        rotate: true,
        child: Tooltip(
          message: car.name,
          child: car.buildCarIcon()
        ),
        point: LatLng(car.geoLocation!.latitude, car.geoLocation!.longitude)
      )).toList();

    notifyListeners();
  }

  void updateTouchMarker(LatLng touchLatLng) {
    _touchMarker = Marker(
      alignment: Alignment.topCenter,
      point: touchLatLng,
      rotate: true,
      width: 80,
      height: 80,
      child: Transform.translate(
        offset: const Offset(0, 24),
        child: const Icon(Icons.location_on, color: Colors.red, size: 40)
      ),
    );

    notifyListeners();
  }

  void updateCurrentPositionMarker(LatLng currentLatLng) {
    _clientPositionMarker = Marker(
      point: currentLatLng,
      child: const CircleAvatar(
        backgroundColor: Colors.white,
        child: Icon(Icons.my_location, color: Colors.blue)
      )
    );

    notifyListeners();
  }

  LatLng? getTouchMarkerPosition() {
    return _touchMarker?.point;
  }

  List<Marker> getMarkers() {
    return [
      ?_clientPositionMarker,
      ..._carMarkers,
      ?_touchMarker
    ];
  }
}

class MapWidget extends StatefulWidget {
  final bool clickMarker;

  const MapWidget({super.key, required this.clickMarker});

  @override
  State<MapWidget> createState() => MapWidgetState();
}

class MapWidgetState extends State<MapWidget> {
  MapWidgetState();

  final MapController mapController = MapController();

  MarkersList markers = MarkersList();
  Timer? clientPositionTimer;

  @override
  void initState() {
    super.initState();

    // Only focus the map on the first time. I want to allow users to move the map freely.
    updateClientPositionMaker(focusMap: true);
    clientPositionTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      updateClientPositionMaker();
    });
  }

  @override
  void dispose() {
    super.dispose();
    clientPositionTimer?.cancel();
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
    markers.updateTouchMarker(latlng);
  }

  LatLng? getTouchMarkerPosition() {
    return markers.getTouchMarkerPosition();
  }

  void focusOnLatLng(LatLng position) {
    mapController.move(position, mapController.camera.zoom);
  } 

  Future<void> updateClientPositionMaker({bool focusMap = false}) async {
    var currentPosition = await getClientPosition();

    // We check if the widget is mounted because it might be closed by the time the position is found.
    if (currentPosition == null || !mounted) return;

    var currentLatLng = LatLng(currentPosition.latitude, currentPosition.longitude);
    markers.updateCurrentPositionMarker(currentLatLng);

    // Update the current map position.
    if (focusMap) {
      mapController.move(currentLatLng, mapController.camera.zoom);
    }
  }

  void setCarMarkers(List<CarData> carData) {
    markers.updateCarMarkers(carData);
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
        ListenableBuilder(
          listenable: markers,
          builder: (context, _) {
            return MarkerLayer(
              markers: markers.getMarkers(),
            );
          }
        ),
      ],
    );
  }
}