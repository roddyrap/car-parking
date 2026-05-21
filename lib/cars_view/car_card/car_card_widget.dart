import 'package:flutter/material.dart';

import '../cars_data.dart';

class CarCard extends StatefulWidget {
  final CarData car;

  const CarCard({super.key, required this.car});

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

  // --- 3. UI COMPONENTS ---

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
          onPressed: () { /* Park Logic */ },
          icon: const Icon(Icons.local_parking, color: Colors.blue),
        ),
        IconButton(
          onPressed: () { /* Occupy Logic */ },
          icon: widget.car.isOccupiedByMe() ? const Icon(Icons.lock_open) : const Icon(Icons.lock),
        ),
        if (_hasGeoLocation) 
          IconButton(
            onPressed: () { /* Focus Logic */ },
            icon: const Icon(Icons.my_location),
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
                if (!_isMissingTextLocation) _buildFullLocationText(),
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
    return OverflowBar(
      alignment: MainAxisAlignment.end,
      children: [
        if (_hasGeoLocation)
          TextButton.icon(
            onPressed: () { /* Navigate Logic */ },
            icon: const Icon(Icons.navigation),
            label: const Text("Navigate"),
          ),
        if (widget.car.isOwnedByMe()) ...[
          TextButton.icon(
            onPressed: () { /* Edit Logic */ },
            icon: const Icon(Icons.edit),
            label: const Text("Edit"),
          ),
          TextButton.icon(
            onPressed: () { /* Delete Logic */ },
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ]
      ],
    );
  }
}