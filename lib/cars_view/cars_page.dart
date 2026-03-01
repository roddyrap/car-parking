import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import 'cars_data.dart';
import 'map_widget.dart';
import 'editable_string_list.dart';

const Map<String, Color> CAR_COLORS = {
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

class CarsPage extends StatefulWidget {
  const CarsPage({super.key});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title = "Cars";

  @override
  State<CarsPage> createState() => _CarsPageState();
}

class _CarsPageState extends State<CarsPage> {
  final GlobalKey<MapWidgetState> mapKey = GlobalKey();
  Future<List<CarData>>? fetchCarsFuture;

  @override
  void initState() {
    super.initState();

    _refreshCars();
  }

  static Future<List<CarData>> fetchVisibleCars() {
    final db = FirebaseFirestore.instance;

    List<CarData> cars = List.empty(growable: true);
    print("UID: ${FirebaseAuth.instance.currentUser!.uid}");
    return db.collection("cars").where(
      Filter.or(
        Filter("owner", isEqualTo: FirebaseAuth.instance.currentUser!.uid),
        Filter("shared_emails", arrayContains: FirebaseAuth.instance.currentUser!.email!)
      )).get().then(
      (querySnapshot) {
        for (var docSnapshot in querySnapshot.docs) {
          cars.add(CarData(
            carID: docSnapshot.id,
            color: Color.new(docSnapshot["color"]),
            name: docSnapshot["name"],
            owner: docSnapshot["owner"],
            sharedEmails: List<String>.from(docSnapshot["shared_emails"]),
            textLocation: docSnapshot.data()["text_location"],
            geoLocation: docSnapshot.data()["geo_location"],
            occuppierEmail: docSnapshot.data()["occupier_email"]
          ));
        }

        print("Number of cars: ${querySnapshot.docs.length}");
        return cars;
      },
      onError: (e) => print("Error completing: $e"),
    );
  }

  void tryPark(String carID, String textLocation, LatLng? position) {
    print(FirebaseAuth.instance.currentUser!.uid);
    var db = FirebaseFirestore.instance;
    var modifiedCar = db.collection("cars").doc(carID);

    modifiedCar.update({
      "geo_location": position != null ? GeoPoint(position.latitude, position.longitude) : null,
      "text_location": textLocation,
      "occupier_email": null,
    }).then((a) {
      // Update the map markers.
      _refreshCars();

      print("Parked car!!!!!11!!11!!1!!!");
    });
  }

  void openAddCarDialog() {
    GlobalKey<EditableStringListState> sharedEmailsKey = GlobalKey();
    var carNameTextController = TextEditingController();
    String? carColorName = CAR_COLORS.keys.first;

    showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsetsGeometry.all(5),
            child: Column(
              children: [
                Row(children: [Icon(Icons.add), Text("Add a New Car")]),
                TextField(controller: carNameTextController, decoration: InputDecoration(label: Text("Car Name"))),
                Row(
                  children: [
                    Text("Color:"),
                    DropdownMenu<String>(
                      requestFocusOnTap: false,
                      onSelected: (value){ carColorName = value!; },
                      initialSelection: CAR_COLORS.keys.first,
                      dropdownMenuEntries: CAR_COLORS.keys.map((colorName) => DropdownMenuEntry<String>(value: colorName, label: colorName)).toList(),
                    ),
                  ],
                ),
                Text(textAlign: TextAlign.start, "Shared Emails:"),
                EditableStringList(key: sharedEmailsKey),
                Row(
                  children: [
                    TextButton(onPressed: () { Navigator.pop(context); }, child: Text("Cancel")),
                    TextButton(onPressed: () {
                      // TODO: Add car limit... (Should do it in firebase though).
                      Color carColor = CAR_COLORS[carColorName] ?? CAR_COLORS["white"]!;
                      var db = FirebaseFirestore.instance;
                      db.collection("cars").add({
                        "owner": FirebaseAuth.instance.currentUser!.uid,
                        "name": carNameTextController.text,
                        "color": carColor.toARGB32(),
                        "shared_emails": sharedEmailsKey.currentState!.getItems(),
                        "occupier_email": null
                      }).then((docReference){ _refreshCars(); });
                      Navigator.pop(context);
                    }, child: Text("Add Car")),
                  ],
                )
              ],
            )
          ),
        )
      )
    );
  }

  void openCarParkDialog(String carID) {
    GlobalKey<MapWidgetState> parkMapKey  = GlobalKey();
    TextEditingController     parkTextController = TextEditingController();

    showDialog<String>(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: Padding(
          padding: EdgeInsetsGeometry.all(10),
          child: Column(
            spacing: 5,
            children: [
              Row(children: [Icon(Icons.local_parking), Text("Park Your Car")]),
              TextField(
                controller: parkTextController,
                decoration: InputDecoration(
                  border: UnderlineInputBorder(),
                  labelText: "Text Position",
                ),
              ),
              Expanded(child: MapWidget(key: parkMapKey, clickMarker: true)),
              Center(
                child: Row(
                  children: [
                    TextButton(onPressed: (){ Navigator.pop(context); }, child: const Text("Cancel")),
                    TextButton(onPressed: () {
                      LatLng? mapPosition = parkMapKey.currentState!.getTouchMarkerPosition();
                      tryPark(carID, parkTextController.text, mapPosition);

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

  void tryDeleteCar(String carID) {
    FirebaseFirestore.instance.collection("cars").doc(carID).delete().then((_){ _refreshCars(); });
  }

  void tryTakeCar(CarData car) {
    String? newOccupier = FirebaseAuth.instance.currentUser?.email;
    if (car.isOccupiedByMe()) newOccupier = null;

    print("Trying to take a car");
    FirebaseFirestore.instance.collection("cars").doc(car.carID).update({"occupier_email": newOccupier}).then(
      (_){
        print("Updating taker state");
        _refreshCars();
      }
    );
  }

  Widget buildCarCard(CarData currentCar) {
    return Card(
      color: currentCar.isOccupied() ? (currentCar.isOccupiedByMe() ? Colors.blue.shade100 : Colors.red.shade100) : Colors.white,
      child: ListTile(
        leading: currentCar.buildCarIcon(),
        title: Text(currentCar.name),
        subtitle: Text(currentCar.isOccupied() ? (currentCar.isOccupiedByMe() ? "Occupied by me" : currentCar.occuppierEmail!) : (currentCar.textLocation ?? "")),
        trailing: Row(
          mainAxisSize: MainAxisSize.min, // Essential to prevent layout crashes
          children: [
            IconButton(
              onPressed: (){ openCarParkDialog(currentCar.carID); },
              icon: Icon(Icons.local_parking),
              color: Colors.blue
            ),
            IconButton(
              onPressed: () { tryTakeCar(currentCar); },
              icon: currentCar.isOccupiedByMe() ? Icon(Icons.lock_open) : Icon(Icons.lock),
              // color: currentCar.isOccupied() ? (currentCar.isOccupiedByMe() ? Colors.blue : Colors.red) : Colors.white
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),// 2. What happens when a user picks an option
              onSelected: (String result) {
                if (result == "delete") {
                  tryDeleteCar(currentCar.carID);
                }
                else if (result == "focus" && currentCar.geoLocation != null) {
                  mapKey.currentState?.focusOnLatLng(
                    LatLng(
                      currentCar.geoLocation!.latitude,
                      currentCar.geoLocation!.longitude
                    )
                  );
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (currentCar.isOwnedByMe()) const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete'),
                ),
                const PopupMenuItem<String>(
                  value: 'focus',
                  child: Text('Focus'),
                ),
              ],
            ),
          ]
        ),
      ),
    );
  }

  Widget buildVisibleCarsList(List<CarData> carsData, {ScrollController? scrollController, bool buildHandle = false}) {
    int buildHandleInt = buildHandle ? 1 : 0;
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      controller: scrollController,
      itemCount: carsData.length + 2 + buildHandleInt,
      itemBuilder: (context, index) {
        // Drag handle should be at the top if we build it.
        if (buildHandle && index == 0) {
          return Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            )
          );
        }

        // Refresh button at the beginning.
        if (index == buildHandleInt) {
          return ElevatedButton.icon(onPressed: (){ _refreshCars(); }, icon: Icon(Icons.refresh), label: Text("Refresh Cars"));
        }

        index -= 1 + buildHandleInt;

        // The add button at the end.
        if (index == carsData.length) {
          return ElevatedButton.icon(onPressed: (){ openAddCarDialog(); }, icon: Icon(Icons.add), label: Text("Add Car"));
        }

        return buildCarCard(carsData[index]);
      }
    );
  }

  Widget buildVisibleCarsListFuture(Future<List<CarData>>? carsData, {ScrollController? scrollController, bool buildHandle = false}) {
    return FutureBuilder(
      future: fetchCarsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // return CircularProgressIndicator(); // Show loading while waiting
          return Container();
        }
        if (snapshot.hasError) return Text("Error: ${snapshot.error}");

        return buildVisibleCarsList(snapshot.data!, scrollController: scrollController, buildHandle: buildHandle);
      }
    );
  }

// Calling this function will trigger BOTH FutureBuilders simultaneously
  void _refreshCars() {
    setState(() {
      print("Updating cars from DB");
      fetchCarsFuture = fetchVisibleCars();
      fetchCarsFuture!.then(
        (cars) {
          setState(() => mapKey.currentState?.setCarMarkers(cars));
        }
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 600;

    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
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
            MapWidget(key: mapKey, clickMarker: false),
            DraggableScrollableSheet(
              initialChildSize: 0.2,
              minChildSize: 0.1,
              builder: (context, scrollController){
                return Container(
                  decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(blurRadius: 10, color: Colors.black.withValues(alpha: 0.2)),
                      ],
                  ),
                  child: buildVisibleCarsListFuture(
                    fetchCarsFuture,
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
          IconButton(onPressed: (){ FirebaseAuth.instance.signOut(); }, icon: Icon(Icons.logout))
        ],
      ),
      body: Row(
        spacing: 2,

        children: [
          ConstrainedBox(constraints: BoxConstraints(maxWidth: 350), child: buildVisibleCarsListFuture(fetchCarsFuture)),
          Expanded(child: MapWidget(key: mapKey, clickMarker: false)),
        ],
      ),
    );
  }
}
