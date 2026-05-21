import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

import 'cars_data.dart';

Future<void> tryDeleteCar(String carID) {
  final db = FirebaseFirestore.instance;

  final dbBatchOperation = db.batch();

  final userRef = db.collection('users').doc(FirebaseAuth.instance.currentUser!.uid);
  final carRef = db.collection("cars").doc(carID);

  dbBatchOperation.set(userRef, {'car_count': FieldValue.increment(-1)}, SetOptions(merge: true));
  dbBatchOperation.delete(carRef);

  return dbBatchOperation.commit();
}

Future<void> tryTakeCar(CarData car) {
  String? newOccupier = FirebaseAuth.instance.currentUser?.email;
  if (car.isOccupiedByMe()) newOccupier = null;

  return FirebaseFirestore.instance.collection("cars").doc(car.carID).update({"occupier_email": newOccupier});
}

Future<void> tryPark(String carID, String textLocation, LatLng? position) {
  var modifiedCar = FirebaseFirestore.instance.collection("cars").doc(carID);

  return modifiedCar.update({
    "geo_location": position != null ? GeoPoint(position.latitude, position.longitude) : null,
    "text_location": textLocation,
    "occupier_email": null,
  });
}