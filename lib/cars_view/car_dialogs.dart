import 'package:car_parking_tracker/cars_view/car_card/car_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:car_parking_tracker/cars_view/car_card/shared_email_list.dart';
import 'package:car_parking_tracker/cars_view/cars_data.dart';

import 'package:car_parking_tracker/cars_view/car_operations.dart';
import 'package:car_parking_tracker/cars_view/map_widget.dart';

import 'package:latlong2/latlong.dart';

// If we called with no `currentCarData` then adds a new car.
Future<void>? openModifyCarDialog({required BuildContext context, CarData? currentCarData}) async {
  GlobalKey<SharedEmailsListState> sharedEmailsKey = GlobalKey();

  var carNameTextController = TextEditingController();
  carNameTextController.text = currentCarData != null ? currentCarData.name : "";
  ValueNotifier<String> carColorName = ValueNotifier(
    (currentCarData != null ? getColorName(currentCarData.color) : null) ?? carColors.keys.first
  );

  return await showDialog<Future<void>>(
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
                  TextButton(onPressed: () { Navigator.pop(context, null); }, child: Text("Cancel")),
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

                    Navigator.pop(context, dbUpdateFuture);
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

void openCarParkDialog(BuildContext context, String carID) {
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