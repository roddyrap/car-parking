
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CarData {
  CarData({required this.carID, required this.color, required this.name, required this.owner, required this.sharedEmails, required this.textLocation, required this.geoLocation});

  final String carID;

  final Color color;
  final String name;
  final String owner;

  final List<String> sharedEmails;

  final String? textLocation;
  final GeoPoint? geoLocation;
}
