import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cars_data.dart';
import 'map_widget.dart';
import 'shared_email_list.dart';

const Map<String, Color> carColors = {
  "white": Colors.white,
  "black": Colors.black,
  "gray": Colors.grey,
  "blue": Colors.blue,
  "orange": Colors.orange,
  "purple": Colors.purple,
  "green": Colors.green,
  "yellow": Colors.yellow,
  "pink": Colors.pink,
  "red": Colors.red
};

String? getColorName(Color color) {
  for (var colorName in carColors.keys) {
    // Convert to ARGB32 in order to avoid floating-point imprecision.
    if (color.toARGB32() == carColors[colorName]?.toARGB32()) return colorName;
  }

  return null;
}

Future<void> fallbackUrlLaunch(Uri uri, Uri fallbackUri, {LaunchMode uriMode = LaunchMode.platformDefault, LaunchMode fallbackUriMode = LaunchMode.platformDefault }) async {
  try {
    bool urlLaunched = await launchUrl(uri, mode: uriMode);
      if (!urlLaunched) {
        throw Exception();
      }
  } catch (e) {
    launchUrl(fallbackUri, mode: fallbackUriMode);
  }
}

class CarsPage extends StatefulWidget {
  const CarsPage({super.key});

  final String title = "Car Parking Coordinator";

  @override
  State<CarsPage> createState() => _CarsPageState();
}

class _CarsPageState extends State<CarsPage> {
  final GlobalKey<MapWidgetState> _mapKey = GlobalKey();
  final ValueNotifier<List<CarData>> _carsDataNotifier = ValueNotifier([]);

  @override
  void initState() {
    super.initState();

    _carsDataNotifier.addListener(() => _mapKey.currentState?.setCarMarkers(_carsDataNotifier.value));
    _refreshCars();
  }

  static Future<List<CarData>> _fetchVisibleCars() {
    final db = FirebaseFirestore.instance;

    List<CarData> cars = List.empty(growable: true);
    return db.collection("cars").where(
      Filter.or(
        Filter("owner", isEqualTo: FirebaseAuth.instance.currentUser!.uid),
        Filter("shared_emails", arrayContains: FirebaseAuth.instance.currentUser!.email!)
      )).get().then(
      (querySnapshot) {
        for (var docSnapshot in querySnapshot.docs) {
          cars.add(CarData(
            carID: docSnapshot.id,
            color: Color(docSnapshot["color"]),
            name: docSnapshot["name"],
            owner: docSnapshot["owner"],
            sharedEmails: List<String>.from(docSnapshot["shared_emails"]),
            textLocation: docSnapshot.data()["text_location"],
            geoLocation: docSnapshot.data()["geo_location"],
            occuppierEmail: docSnapshot.data()["occupier_email"]
          ));
        }

        return cars;
      },
    );
  }

  void _tryPark(String carID, String textLocation, LatLng? position) {
    var db = FirebaseFirestore.instance;
    var modifiedCar = db.collection("cars").doc(carID);

    modifiedCar.update({
      "geo_location": position != null ? GeoPoint(position.latitude, position.longitude) : null,
      "text_location": textLocation,
      "occupier_email": null,
    }).then((a) {
      // Update the map markers.
      _refreshCars();
    });
  }

  // If we called with no `currentCarData` then adds a new car.
  void _openUpdateCarDialog({CarData? currentCarData}) {
    GlobalKey<SharedEmailsListState> sharedEmailsKey = GlobalKey();

    var carNameTextController = TextEditingController();
    carNameTextController.text = currentCarData != null ? currentCarData.name : "";
    ValueNotifier<String> carColorName = ValueNotifier(
      (currentCarData != null ? getColorName(currentCarData.color) : null) ?? carColors.keys.first
    );

    showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsetsGeometry.all(10),
            child: Column(
              spacing: 10,
              children: [
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(currentCarData != null ? Icons.edit : Icons.add),
                      Text(
                        currentCarData != null ? "Edit a Car" : "Add a New Car",
                        style: Theme.of(context).textTheme.titleLarge
                      )
                    ]
                  )
                ),
                Row(
                  children: [
                    DropdownMenu<String>(
                      width: 160,
                      leadingIcon: ValueListenableBuilder(
                        valueListenable: carColorName,
                        builder: (context, colorName, _) {
                          return Icon(
                            Icons.square_rounded,
                            color: carColors[colorName] ?? carColors.values.first
                          );
                        },
                      ),
                      label: const Text("Color"),
                      requestFocusOnTap: false,
                      onSelected: (value){ carColorName.value = value!; },
                      initialSelection: carColorName.value,
                      dropdownMenuEntries: carColors.keys.map((colorName) => DropdownMenuEntry<String>(value: colorName, label: colorName)).toList(),
                    ),
                    Expanded(
                      child: TextField(
                        controller: carNameTextController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.directions_car),
                          label: Text("Car Name")
                        )
                      ),
                    )
                  ]
                ),
                SharedEmailsList(key: sharedEmailsKey, initialItems: currentCarData?.sharedEmails ?? []),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(onPressed: () { Navigator.pop(context); }, child: Text("Cancel")),
                    TextButton(onPressed: () {
                      Color carColor = carColors[carColorName.value] ?? carColors["white"]!;
                      var db = FirebaseFirestore.instance;
                      var dbCarData = {
                        "owner": FirebaseAuth.instance.currentUser!.uid,
                        "name": carNameTextController.text,
                        "color": carColor.toARGB32(),
                        "shared_emails": sharedEmailsKey.currentState?.getItems() ?? [],
                        "occupier_email": null
                      };

                      Future<void> dbUpdateFuture;
                      if (currentCarData != null) {
                        dbUpdateFuture = db.collection("cars").doc(currentCarData.carID).update(dbCarData);
                      }
                      else {
                        final dbBatchOperation = db.batch();

                        final userRef = db.collection('users').doc(FirebaseAuth.instance.currentUser!.uid);
                        final carRef = db.collection("cars").doc();
                        dbBatchOperation.set(userRef, {'car_count': FieldValue.increment(1)}, SetOptions(merge: true));
                        dbBatchOperation.set(carRef, dbCarData);

                        dbUpdateFuture = dbBatchOperation.commit();
                      }

                      dbUpdateFuture.then((docReference){ _refreshCars(); });
                      Navigator.pop(context);
                    }, child: Text(currentCarData != null ? "Edit Car" : "Add Car")),
                  ],
                )
              ],
            )
          ),
        )
      )
    );
  }

  void _openCarParkDialog(String carID) {
    GlobalKey<MapWidgetState> parkMapKey  = GlobalKey();
    TextEditingController     parkTextController = TextEditingController();

    showDialog<String>(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: Padding(
          padding: const EdgeInsetsGeometry.all(10),
          child: Column(
            spacing: 5,
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_parking),
                    Text("Park Your Car", style: Theme.of(context).textTheme.titleLarge)
                  ]
                )
              ),
              TextField(
                controller: parkTextController,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: "Text Position",
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: MapWidget(key: parkMapKey, clickMarker: true)
                )
              ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(onPressed: (){ Navigator.pop(context); }, child: const Text("Cancel")),
                    TextButton(onPressed: () {
                      LatLng? mapPosition = parkMapKey.currentState?.getTouchMarkerPosition();
                      _tryPark(carID, parkTextController.text, mapPosition);

                      Navigator.pop(context);
                    }, child: const Text("Park"))
                  ],
                ),
              ),
            ],
          ),
        ),
      )
    );
  }

  void _tryDeleteCar(String carID) {
    final db = FirebaseFirestore.instance;

    final dbBatchOperation = db.batch();

    final userRef = db.collection('users').doc(FirebaseAuth.instance.currentUser!.uid);
    final carRef = db.collection("cars").doc(carID);

    dbBatchOperation.set(userRef, {'car_count': FieldValue.increment(-1)}, SetOptions(merge: true));
    dbBatchOperation.delete(carRef);

    dbBatchOperation.commit().then((_){ _refreshCars(); });
  }

  void _tryTakeCar(CarData car) {
    String? newOccupier = FirebaseAuth.instance.currentUser?.email;
    if (car.isOccupiedByMe()) newOccupier = null;

    FirebaseFirestore.instance.collection("cars").doc(car.carID).update({"occupier_email": newOccupier}).then(
      (_){
        _refreshCars();
      }
    );
  }

  Widget _buildCarCard(CarData currentCar) {
    bool isLocationPresent = !currentCar.isOccupied() && currentCar.geoLocation != null;
    return Card(
      color: currentCar.isOccupied() ? (currentCar.isOccupiedByMe() ? Colors.blue.shade100 : Colors.red.shade100) : Colors.white,
      child: ListTile(
        leading: currentCar.buildCarIcon(),
        title: Text(currentCar.name),
        subtitle: Text(currentCar.isOccupied() ? (currentCar.isOccupiedByMe() ? "Occupied by me" : "Occupied by ${currentCar.occuppierEmail!}") : (currentCar.textLocation ?? "")),
        trailing: Row(
          mainAxisSize: MainAxisSize.min, // Essential to prevent layout crashes
          children: [
            IconButton(
              onPressed: (){ _openCarParkDialog(currentCar.carID); },
              icon: Icon(Icons.local_parking),
              color: Colors.blue
            ),
            IconButton(
              onPressed: () { _tryTakeCar(currentCar); },
              icon: currentCar.isOccupiedByMe() ? Icon(Icons.lock_open) : Icon(Icons.lock),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),// 2. What happens when a user picks an option
              onSelected: (String result) {
                if (result == "delete") {
                  _tryDeleteCar(currentCar.carID);
                }
                if (result == "edit") {
                  _openUpdateCarDialog(currentCarData: currentCar);
                }
                else if (result == "focus" && isLocationPresent) {
                  _mapKey.currentState?.focusOnLatLng(
                    LatLng(
                      currentCar.geoLocation!.latitude,
                      currentCar.geoLocation!.longitude
                    )
                  );
                }
                else if (result == "navigate" && isLocationPresent) {
                  final lat = currentCar.geoLocation!.latitude;
                  final lng = currentCar.geoLocation!.longitude;

                  // Use the universal 'geo' URI for Android/IOS default app support, and open
                  // google maps on non-mobile web platforms.
                  final Uri geoUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng");
                  final Uri gmapsUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
                  if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
                    fallbackUrlLaunch(
                      geoUri,
                      gmapsUri,
                      fallbackUriMode: LaunchMode.externalApplication
                    );
                  }
                  else {
                    launchUrl(gmapsUri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (currentCar.isOwnedByMe()) const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                if (currentCar.isOwnedByMe()) const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete'),
                ),
                if (isLocationPresent) ...[
                  const PopupMenuItem<String>(
                    value: 'focus',
                    child: Text('Focus'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'navigate',
                    child: Text('Navigate')
                  ),
                ]
              ],
            ),
          ]
        ),
      ),
    );
  }

  Widget _buildCarsList(List<CarData> carsData, {ScrollController? scrollController, bool buildHandle = false}) {
    int buildHandleInt = buildHandle ? 1 : 0;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      controller: scrollController,
      itemCount: carsData.length + 1 + buildHandleInt,
      itemBuilder: (context, index) {
        // Drag handle should be at the top if we build it.
        if (buildHandle) {
          if (index == 0) {
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  // I can't use BorderRadius.circular because it's not const.
                  borderRadius: BorderRadius.all(Radius.circular(10))
                ),
              )
            );
          }

          index -= 1;
        }

        // The Refresh & Add Car buttons at the end of the list.
        if (index == carsData.length) {
          return Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 30,
              children: [
                TextButton.icon(
                  onPressed: _refreshCars,
                  label: const Text("Refresh"),
                  icon: const Icon(Icons.refresh),
                ),
                TextButton.icon(
                  onPressed: _openUpdateCarDialog,
                  label: const Text("Add Car"),
                  icon: const Icon(Icons.add),
                ),
              ],
            )
          );
        }

        return _buildCarCard(carsData[index]);
      }
    );
  }

  Widget _createCarsListBuilder({ScrollController? scrollController, bool buildHandle = false}) {
    return ValueListenableBuilder(
      valueListenable: _carsDataNotifier,
      builder: (context, cars, _) {
        return _buildCarsList(cars, scrollController: scrollController, buildHandle: buildHandle);
      }
    );
  }

// Calling this function will trigger BOTH FutureBuilders simultaneously
  void _refreshCars() {
    _fetchVisibleCars().then((cars) => _carsDataNotifier.value = cars);
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(widget.title),
          actions: [
            IconButton(onPressed: (){ FirebaseAuth.instance.signOut(); }, icon: Icon(Icons.logout))
          ],
        ),
        body: Stack(
          children: [
            MapWidget(key: _mapKey, clickMarker: false),
            DraggableScrollableSheet(
              initialChildSize: 0.2,
              // It's important that this be low so the attributions can be seen.
              minChildSize: 0.03,
              builder: (context, scrollController){
                return Container(
                  decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(blurRadius: 10, color: Colors.black.withValues(alpha: 0.2)),
                      ],
                  ),
                  child: _createCarsListBuilder(
                    scrollController: scrollController,
                    buildHandle: true
                  )
                );
              },
            )
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: (){ launchUrl(Uri.parse("https://github.com/roddyrap/car-parking"), mode: LaunchMode.externalApplication); },
            icon: SvgPicture.asset(
              'assets/GitHub_Invertocat_White.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.onSurface, BlendMode.srcIn)
            ),
          ),
          IconButton(
            onPressed: (){ FirebaseAuth.instance.signOut(); },
            icon: Icon(Icons.logout),
            color: Theme.of(context).colorScheme.onSurface,
          )
        ],
      ),
      body: Row(
        spacing: 2,

        children: [
          ConstrainedBox(constraints: BoxConstraints(maxWidth: 350), child: _createCarsListBuilder()),
          Expanded(child: MapWidget(key: _mapKey, clickMarker: false)),
        ],
      ),
    );
  }
}
