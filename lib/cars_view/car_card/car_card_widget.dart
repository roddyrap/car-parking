import 'package:car_parking_tracker/cars_view/car_dialogs.dart';
import 'package:car_parking_tracker/cars_view/car_operations.dart';
import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform;
import 'package:url_launcher/url_launcher.dart';

import '../cars_data.dart';

class CarCard extends StatefulWidget {
  final CarData car;
  final VoidCallback? focusAction;
  final VoidCallback refreshAction;

  const CarCard({super.key, required this.car, required this.refreshAction, required this.focusAction});

  @override
  State<CarCard> createState() => _CarCardState();
}

class _CarCardState extends State<CarCard> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  bool get _hasGeoLocation => widget.car.geoLocation != null;
  bool get _isMissingTextLocation =>
      !widget.car.isOccupied() &&
      (widget.car.textLocation?.isEmpty ?? true);

  String get _subtitleText {
    if (widget.car.isOccupied()) {
      return widget.car.isOccupiedByMe() 
          ? "Occupied by me" 
          : "Occupied by ${widget.car.occuppierEmail!}";
    }

    if (!_isMissingTextLocation) {
      return widget.car.textLocation!;
    }

    return "No text location provided";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _toggleExpand,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCompactHeader(),
            _buildExpandedDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    return ListTile(
      leading: widget.car.buildCarIcon(),
      title: Text(widget.car.name),
      subtitle: Text(
        _subtitleText,
        maxLines: 1, 
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontStyle: _isMissingTextLocation ? FontStyle.italic : FontStyle.normal,
          color: _isMissingTextLocation ? Colors.grey : null,
        ),
      ),
      trailing: _buildPrimaryActions(),
    );
  }

  Widget _buildPrimaryActions() {
    return Row(
      mainAxisSize: MainAxisSize.min, 
      children: [
        IconButton(
          onPressed: () => 
            openCarParkDialog(context, widget.car.carID).then((_) => widget.refreshAction()),
          icon: const Icon(Icons.local_parking, color: Colors.blue),
        ),
        IconButton(
          onPressed: () =>
            tryTakeCar(widget.car).then((_) => widget.refreshAction()),
          icon: widget.car.isOccupiedByMe() ? const Icon(Icons.lock_open) : const Icon(Icons.lock),
        ),
        // The arrow on the side that symbolizes the current expansion state.
        AnimatedRotation(
          turns: _isExpanded ? 0.0 : 0.25,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: const Icon(
            Icons.expand_more,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedDetails() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: !_isExpanded 
        ? const SizedBox.shrink() 
        : Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                if (!_isMissingTextLocation) ... [
                  _buildFullLocationText(),
                  const Divider(),
                ],
                _buildSecondaryActions(),
              ],
            ),
          ),
    );
  }

  Widget _buildFullLocationText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          "Full Location:",
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
        ),
        Text(_subtitleText),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSecondaryActions() {
    final bool isOwned = widget.car.isOwnedByMe();
    return OverflowBar(
      alignment: MainAxisAlignment.center,
      children: [
        _buildActionColumn(
          icon: Icons.my_location,
          label: "Focus",
          onTap: _hasGeoLocation ? widget.focusAction : null
        ),
        _buildActionColumn(
          icon: Icons.navigation,
          label: "Navigate",
          onTap: _hasGeoLocation ? () => _navigateToCar(widget.car) : null
        ),
        _buildActionColumn(
          icon: Icons.edit,
          label: "Edit",
          onTap: isOwned ? () => 
            openModifyCarDialog(context: context, currentCarData: widget.car).then((_) => widget.refreshAction()) : null
        ),
        _buildActionColumn(
          isDestructive: true,
          icon: Icons.delete,
          label: "Delete",
          onTap: isOwned ? () => tryDeleteCar(widget.car.carID).then((_) => widget.refreshAction()) : null
        )
      ],
    );
  }

  Widget _buildActionColumn({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final bool isDisabled = onTap == null;

    // Determine colors based on state
    final Color activeColor  = isDestructive ? Colors.red : Theme.of(context).colorScheme.primary;
    final Color displayColor = isDisabled ? Colors.grey.shade400 : activeColor;

    return InkWell(
      // Even if the button is disabled I still want to be clickable, just do nothing.
      onTap: onTap ?? (){},
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: displayColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: displayColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fallbackUrlLaunch(Uri uri, Uri fallbackUri, {LaunchMode uriMode = LaunchMode.platformDefault, LaunchMode fallbackUriMode = LaunchMode.platformDefault }) async {
    try {
      bool urlLaunched = await launchUrl(uri, mode: uriMode);
        if (!urlLaunched) {
          throw Exception();
        }
    } catch (e) {
      launchUrl(fallbackUri, mode: fallbackUriMode);
    }
  }

  void _navigateToCar(CarData carData) {
    final lat = carData.geoLocation!.latitude;
    final lng = carData.geoLocation!.longitude;

    // Use the universal 'geo' URI for Android/IOS default app support, and open
    // google maps on non-mobile web platforms.
    final Uri geoUri = Uri.parse("geo:$lat,$lng?q=$lat,$lng");
    final Uri gmapsUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      _fallbackUrlLaunch(
        geoUri,
        gmapsUri,
        fallbackUriMode: LaunchMode.externalApplication
      );
    }
    else {
      launchUrl(gmapsUri, mode: LaunchMode.externalApplication);
    }
  }
}