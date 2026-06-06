import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:car_parking_tracker/theme.dart';

import 'car_card/car_card_widget.dart';
import 'car_dialogs.dart';
import 'cars_data.dart';
import 'map_widget.dart';

class CarsPage extends StatefulWidget {
  const CarsPage({super.key});

  final String title = "Car Parking Tracker";

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
                  onPressed: () => openModifyCarDialog(context: context, currentCarData: null)?.then((_) => _refreshCars()),
                  label: const Text("Add Car"),
                  icon: const Icon(Icons.add),
                ),
              ],
            )
          );
        }

        CarData carData = carsData[index];
        return CarCard(
          car: carData,
          refreshAction: _refreshCars,
          focusAction: () => _mapKey.currentState?.focusOnCar(carData),
          getCurrentLocation: () => _mapKey.currentState?.getCurrentPositionMarkerPosition(),
        );
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
    Alignment mapAttributionAlignment = isMobile ? Alignment.topLeft : Alignment.bottomRight;

    final pageTitle = Row(
      spacing: 5,
      children: [
        SvgPicture.asset(
          "assets/logo/new_logo.svg",
          width: 40,
          height: 40,
          colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.onSurface, BlendMode.srcIn)
        ),
        Text(widget.title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),)
      ]
    );

    final pageActions = [
      createThemeButton(context),
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
        icon: const Icon(Icons.logout),
        color: Theme.of(context).colorScheme.onSurface,
      )
    ];

    final pageAppBar = AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: pageTitle,
      actions: pageActions,
    );

    if (isMobile) {
      return Scaffold(
        appBar: pageAppBar,
        body: Stack(
          children: [
            MapWidget(key: _mapKey, clickMarker: false, attributionsAlignment: mapAttributionAlignment,),
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

    // Not-Mobile.
    return Scaffold(
      appBar: pageAppBar,
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
