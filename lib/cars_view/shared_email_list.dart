import 'package:flutter/material.dart';

class SharedEmailsList extends StatefulWidget {
  const SharedEmailsList({super.key, this.initialItems});

  @override
  State<SharedEmailsList> createState() => SharedEmailsListState();

  final List<String>? initialItems;
}

class SharedEmailsListState extends State<SharedEmailsList> {
  final List<TextEditingController> _controllers = [];

  List<String> getItems() {
    return _controllers.sublist(0, _controllers.length - 1).map((controller) => controller.text).toList();
  }

  void _addEntry({String? text}) {
    setState(() {
      _controllers.add(TextEditingController(text: text));
    });
  }

  void _removeEntry(int index) {
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
  }

  @override
  void initState() {
    super.initState();

    for (var item in widget.initialItems ?? []) {
      _controllers.add(TextEditingController(text: item));
    }

    // Add the 'empty' entry.
    if (_controllers.isEmpty || _controllers.last.text.isNotEmpty) {
      _controllers.add(TextEditingController(text: ""));
    }
  }

  @override
  void dispose() {
    // Clean up all controllers when the screen is closed
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void onTextChanged(int index, String newValue) {
    if (index == _controllers.length - 1 && newValue.isNotEmpty) {
      _addEntry();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _controllers.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: TextField(
            controller: _controllers[index],
            onChanged: (value) => onTextChanged(index, value),
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email),
              hintText: "Shared Email",
            ),
          ),
          trailing: index < _controllers.length - 1 ? IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () => _removeEntry(index),
          ) : null,
        );
      },
    );
  }
}