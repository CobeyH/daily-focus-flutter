import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/task.dart';
import 'providers/task_provider.dart';

class TaskCreation extends ConsumerStatefulWidget {
  const TaskCreation({Key? key}) : super(key: key);

  @override
  TaskCreationState createState() => TaskCreationState();
}

class TaskCreationState extends ConsumerState<TaskCreation> {
  final _formKey = GlobalKey<FormState>();
  final Task _formValues = Task.empty();

  Future<void> _dialogBuilder(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create a new task'),
          content: Form(key: _formKey, child: formFields()),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Save'),
              onPressed: () {
                _saveForm();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _saveForm() {
    ref.read(tasksProvider.notifier).createNew(_formValues);
  }

  Widget customRadioButton(String text, int index) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _formValues.incremental = index == 0 ? true : false;
        });
      },
      child: Text(
        text,
        style: TextStyle(
          color: (_formValues.incremental) ? Colors.green : Colors.black,
        ),
      ),
    );
  }

  _pickIcon() async {
    IconData? pickedIcon = (await FlutterIconPicker.showIconPicker(context,
        iconPackModes: [IconPack.material]));
    if (pickedIcon != null) {
      setState(() {
        _formValues.iconPoint = pickedIcon.codePoint;
      });
    }
  }

  Widget formFields() {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          customRadioButton("Timer", 0),
          customRadioButton("Incremental", 1)
        ]),
        TextFormField(
          decoration: const InputDecoration(label: Text("Name")),
          onChanged: (newValue) => _formValues.name = newValue,
        ),
        TextFormField(
          decoration: const InputDecoration(label: Text("Goal")),
          onChanged: (newValue) => _formValues.goal = int.parse(newValue),
          validator: (newValue) => newValue!.isEmpty
              ? 'Please enter a goal'
              : newValue.contains(RegExp(r'[0-9]'))
                  ? null
                  : 'Please enter a number',
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              IconData(_formValues.iconPoint, fontFamily: 'MaterialIcons'),
            ),
            const SizedBox(width: 10),
            ElevatedButton(onPressed: _pickIcon, child: const Text("Pick Icon"))
          ],
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _dialogBuilder(context),
      child: const Icon(Icons.add),
    );
  }
}
