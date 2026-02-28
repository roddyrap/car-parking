import 'package:flutter/material.dart';

class EditableStringList extends StatefulWidget {
  const EditableStringList({super.key});

  @override
  State<EditableStringList> createState() => EditableStringListState();
}

class EditableStringListState extends State<EditableStringList> {
  final List<TextEditingController> _controllers = [];

  List<String> getItems() {
    return _controllers.map((controller) => controller.text).toList();
  }

  void _addEntry() {
    setState(() {
      _controllers.add(TextEditingController());
    });
  }

  void _removeEntry(int index) {
    setState(() {
      _controllers[index].dispose();
      _controllers.removeAt(index);
    });
  }

  @override
  void dispose() {
    // Clean up all controllers when the screen is closed
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _controllers.isEmpty
            ? const Center(child: Text("No items yet. Tap '+' to start."))
            : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _controllers.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: TextField(
                    controller: _controllers[index],
                    decoration: InputDecoration(
                      hintText: "Item ${index + 1}",
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeEntry(index),
                  ),
                );
              },
            ),

        // The Add Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _addEntry,
            icon: const Icon(Icons.add),
            label: const Text("Add Item"),
          ),
        ),
      ],
    );
  }
}