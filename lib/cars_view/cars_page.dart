import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'cars_data.dart';
import 'map_widget.dart';

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

    fetchCarsFuture = fetchVisibleCars();
  }

  static Color colorFromInt(int colorInt) {
    // I store in DB as 8-bit BGRA channels.
    return Color.fromARGB(
      (colorInt >> 32) & 0xFF,
      (colorInt >> 16) & 0xFF,
      (colorInt >> 8) & 0xFF,
      (colorInt) & 0xFF,
    );
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
            color: colorFromInt(docSnapshot["color"]),
            name: docSnapshot["name"],
            owner: docSnapshot["owner"],
            sharedEmails: List<String>.from(docSnapshot["shared_emails"]),
            textLocation: docSnapshot.data().containsKey("text_location") ? docSnapshot["text_location"] : null,
            geoLocation: docSnapshot.data().containsKey("geo_location") ? docSnapshot["geo_location"] : null,
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
    }).then((a) {
      // Update the map markers.
      _refreshCars();

      print("Parked car!!!!!11!!11!!1!!!");
    });
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
              Text("Park Your Car"),
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

  static void tryTakeCar(String carID) {

  }

  Widget buildVisibleCarsList(List<CarData> carsData) {
    List<Card> cards = List.empty(growable: true);
    for (var car in carsData)
    {
      cards.add(
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
          child: Padding(
            padding: EdgeInsetsGeometry.all(10),
            child: Row(
              spacing: 5,
              children: [
                Center(child: Icon(Icons.directions_car, color: car.color, size: 50.0)),
                Column(
                  children: [
                    Text(car.name),
                    Text(car.textLocation ?? ""),
                    Text(""), // Spacer doesn't work for some reason. Causes an assertion failure in dart.
                    Row(
                      spacing: 10,
                      children: [
                        ElevatedButton(
                          onPressed: (){ return openCarParkDialog(car.carID); },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade300, // The button's background color
                            foregroundColor: Colors.white, // The text/icon color
                          ),
                          child: Text("Park"),
                        ),
                        ElevatedButton(
                          onPressed: (){ return tryTakeCar(car.carID); },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade300, // The button's background color
                            foregroundColor: Colors.white, // The text/icon color
                          ),
                          child: Text("Take")
                        ),
                      ],
                    ),
                  ]
                )
              ],
            )
          )
        )
      );
    }

    return Column(children: cards);
  }

// Calling this function will trigger BOTH FutureBuilders simultaneously
  void _refreshCars() {
    setState(() {
      fetchCarsFuture = fetchVisibleCars();
    });
  }

  @override
  Widget build(BuildContext context) {
    var visibleCarsWidget = FutureBuilder<List<CarData>>(
      future: fetchCarsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator(); // Show loading while waiting
        }
        if (snapshot.hasError) return Text("Error: ${snapshot.error}");

        // Update the map markers.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          mapKey.currentState?.setCarMarkers(snapshot.data!);
        });

        // Actually build the car list.
        return buildVisibleCarsList(snapshot.data!);
      },
    );

    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the CarsPage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: (){ FirebaseAuth.instance.signOut(); }, icon: Icon(Icons.logout))
        ],
      ),
      body: Row(
        spacing: 2,

        children: [
          visibleCarsWidget,
          Expanded(child: MapWidget(key: mapKey, clickMarker: false)),
        ],
      ),
    );
  }
}
