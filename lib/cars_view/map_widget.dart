import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final Alignment attributionsAlignment;

  const MapWidget({super.key, required this.clickMarker, this.attributionsAlignment = Alignment.bottomRight});

  @override
  State<MapWidget> createState() => MapWidgetState();
}

class MapWidgetState extends State<MapWidget> {
  MapWidgetState();

  final MapController _mapController = MapController();

  final MarkersList _markers = MarkersList();
  Timer? _clientPositionTimer;
  Timer? _mapPositionSaveTimer;

  late Future<(LatLng, double)?> _initialMapStateFuture;

  @override
  void initState() {
    super.initState();

    _initialMapStateFuture = _loadMapState();

    // Only focus the map on the first time. I want to allow users to move the map freely.
    _updateClientPositionMaker(focusMap: true);

    _clientPositionTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _updateClientPositionMaker();
    });
  }

  @override
  void dispose() {
    super.dispose();

    _clientPositionTimer?.cancel();
    _mapPositionSaveTimer?.cancel();
  }

  LatLng? getTouchMarkerPosition() {
    return _markers.getTouchMarkerPosition();
  }

  void focusOnLatLng(LatLng position) {
    _mapController.move(position, _mapController.camera.zoom);
  } 

  void setCarMarkers(List<CarData> carData) {
    _markers.updateCarMarkers(carData);
  }

  static Future<Position?> _getClientPosition() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    // Check and request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (!(permission == LocationPermission.whileInUse || permission ==  LocationPermission.always)) {
        return null;
      }
    }

    // Get the current position
    try {
      return Geolocator.getCurrentPosition();
    } catch (e) {
      return null;
    }
  }

  Future<(LatLng, double)?> _loadMapState() async {
    final prefs = await SharedPreferences.getInstance();

    final lat = prefs.getDouble('map_lat');
    final lng = prefs.getDouble('map_lng');
    final zoom = prefs.getDouble('map_zoom');

    if (lat != null && lng != null && zoom != null) {
      return (LatLng(lat, lng), zoom);
    }

    // Fallback to center the map over Tel Aviv, Israel if nothing is found.
    return null;
  }

  void _saveMapState(LatLng center, double zoom) {
    // Cancel the previous timer if the user is still moving the map
    if (_mapPositionSaveTimer?.isActive ?? false) _mapPositionSaveTimer!.cancel();

    // Only actually save to memory after the map has been still for 500ms
    _mapPositionSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      final prefs = await SharedPreferences.getInstance();
      prefs.setDouble('map_lat', center.latitude);
      prefs.setDouble('map_lng', center.longitude);
      prefs.setDouble('map_zoom', zoom);
    });
  }

  void _handleTap(TapPosition tapPosition, LatLng latlng) {
    // This function shouldn't be wired to respond to clicks if that's the case, but I want to be safe.
    if (!widget.clickMarker) return;
    _markers.updateTouchMarker(latlng);
  }

  Future<void> _updateClientPositionMaker({bool focusMap = false}) async {
    var currentPosition = await _getClientPosition();

    // We check if the widget is mounted because it might be closed by the time the position is found.
    if (currentPosition == null || !mounted) return;

    var currentLatLng = LatLng(currentPosition.latitude, currentPosition.longitude);
    _markers.updateCurrentPositionMarker(currentLatLng);

    // Update the current map position.
    if (focusMap) {
      _mapController.move(currentLatLng, _mapController.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The top(Center,Left,Right) have -1 as the y alignment. Essentially, if the attribution is
    // at the top we want more padding so the button won't overlap with it.
    final focusButtonTopPadding = 10.0 + (widget.attributionsAlignment.y == -1 ? 20.0 : 0.0);

    TileLayer tileLayer = TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'dev.roddyra.carpark (contact: roddy.rappaport@gmail.com)'
    );

    return FutureBuilder(
      future: _initialMapStateFuture,
      builder: (context, snapshot) {
        // Show a simple loader while fetching the map position.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // If no prior position is found (Due to first time or failure) center over Tel Aviv, Israel
        // as the default.
        final initialCenter = snapshot.data?.$1 ?? const LatLng(32.0853, 34.7818);
        final initialZoom = snapshot.data?.$2 ?? 18.0;

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: initialZoom,
            onTap: widget.clickMarker ? _handleTap : null,
            onPositionChanged: (MapCamera camera, bool hasGesture) {
              if (hasGesture) {
                _saveMapState(camera.center, camera.zoom);
              }
            },
          ),
          children: [
            Theme.of(context).brightness == Brightness.dark ? darkModeTilesContainerBuilder(context, tileLayer) : tileLayer,
            ListenableBuilder(
              listenable: _markers,
              builder: (context, _) {
                return MarkerLayer(
                  markers: _markers.getMarkers(),
                );
              }
            ),
            Align(
              alignment: widget.attributionsAlignment,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.only(left: 5, right: 5),
                  color: Theme.of(context).colorScheme.surface.withAlpha(200),
                  child: const Text(
                    "flutter_map | © OpenStreetMap under the 'Open Database License' (ODbL)",
                  )
                )
              )
            ),
            Padding(
              padding: EdgeInsets.only(left: 10, right: 0, top: focusButtonTopPadding, bottom: 0),
              child: FloatingActionButton(
                onPressed: () => _updateClientPositionMaker(focusMap: true),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                child: const Icon(Icons.my_location),
              )
            ),
          ],
        );
      }
    );
  }
}