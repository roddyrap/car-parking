import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:car_parking_tracker/theme.dart';

import 'car_operations.dart';
import 'car_dialogs.dart';
import 'cars_data.dart';
import 'map_widget.dart';

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

  Text _buildCarTextlocation(CarData currentCar) {
    if (currentCar.isOccupied()) {
      final String occupierText = currentCar.isOccupiedByMe() 
          ? "Occupied by me"
          : "Occupied by ${currentCar.occuppierEmail!}";
          
      return Text(occupierText);
    }

    if (currentCar.textLocation?.isNotEmpty ?? false) {
      return Text(currentCar.textLocation!);
    }

    return const Text(
      "No text location provided",
      style: TextStyle(
        fontStyle: FontStyle.italic,
        color: Colors.grey,
        fontSize: 10.0,
      ),
    );
  }

  Widget _buildCarCard(CarData currentCar) {
    bool isLocationPresent = !currentCar.isOccupied() && currentCar.geoLocation != null;

    Color? cardColor;
    if (currentCar.isOccupied()) {
      if (currentCar.isOccupiedByMe()) {
        cardColor = Theme.of(context).extension<CarStatusColors>()!.occupiedByMeColor;
      }
      else {
        cardColor = Theme.of(context).extension<CarStatusColors>()!.occupiedByOtherColor;
      }
    }
    else {
      cardColor = Theme.of(context).colorScheme.secondaryContainer;
    }

    return Card(
      color: cardColor,
      child: ListTile(
        leading: currentCar.buildCarIcon(),
        title: Text(currentCar.name),
        subtitle: _buildCarTextlocation(currentCar),
        trailing: Row(
          mainAxisSize: MainAxisSize.min, // Essential to prevent layout crashes
          children: [
            IconButton(
              onPressed: (){ openCarParkDialog(context, currentCar.carID); },
              icon: Icon(Icons.local_parking),
              color: Colors.blue
            ),
            IconButton(
              onPressed: () { tryTakeCar(currentCar); },
              icon: currentCar.isOccupiedByMe() ? Icon(Icons.lock_open) : Icon(Icons.lock),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),// 2. What happens when a user picks an option
              onSelected: (String result) {
                if (result == "delete") {
                  tryDeleteCar(currentCar.carID);
                }
                if (result == "edit") {
                  openModifyCarDialog(context: context, currentCarData: currentCar);
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
                  onPressed: () => openModifyCarDialog(context: context, currentCarData: null),
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
