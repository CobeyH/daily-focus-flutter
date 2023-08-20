import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';

class TaskCreation extends ConsumerStatefulWidget {
  const TaskCreation({Key? key}) : super(key: key);

  @override
  TaskCreationState createState() => TaskCreationState();
}

class TaskCreationState extends ConsumerState<TaskCreation> {
  final _formKey = GlobalKey<FormState>();
  final Task _formValues = Task.empty();

  void _saveForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    ref.read(tasksProvider.notifier).createNew(_formValues);
    Navigator.of(context).pop();
  }

  Widget customRadioButton(String text, int index) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: (_formValues.incremental ? index == 1 : index == 0)
            ? Colors.lightGreenAccent
            : Colors.white,
      ),
      onPressed: () {
        setState(() {
          _formValues.incremental = index == 0 ? false : true;
        });
      },
      child: Text(
        text,
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
        Row(children: [
          customRadioButton("Timer", 0),
          const SizedBox(width: 10),
          customRadioButton("Incremental", 1)
        ]),
        TextFormField(
          decoration: const InputDecoration(label: Text("Name")),
          onChanged: (newValue) => _formValues.name = newValue,
          validator: (value) => value!.isEmpty ? 'Enter a name' : null,
        ),
        TextFormField(
          decoration: const InputDecoration(label: Text("Goal")),
          onChanged: (newValue) => _formValues.goal = int.parse(newValue),
          validator: (newValue) => newValue!.isEmpty
              ? 'Enter a goal'
              : newValue.contains(RegExp(r'[0-9]'))
                  ? null
                  : 'Please enter a number',
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_formValues.iconPoint != null)
              Icon(
                IconData(_formValues.iconPoint!, fontFamily: 'MaterialIcons'),
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
    return Scaffold(
        appBar: AppBar(
          title: const Text('Create a new task'),
        ),
        body: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(key: _formKey, child: formFields())),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _saveForm(),
          child: const Icon(Icons.save),
        ));
  }
}
