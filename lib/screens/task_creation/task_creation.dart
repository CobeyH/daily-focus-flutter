import 'package:flutter/material.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/task_provider.dart';

class TaskCreation extends ConsumerStatefulWidget {
  final Task? task;
  const TaskCreation({Key? key, this.task}) : super(key: key);

  @override
  TaskCreationState createState() => TaskCreationState();
}

class TaskCreationState extends ConsumerState<TaskCreation> {
  final _formKey = GlobalKey<FormState>();
  late Task _formValues;
  late bool _isNew;

  @override
  void initState() {
    super.initState();
    _isNew = widget.task == null;
    _formValues = widget.task ?? Task.empty();
  }

  void _saveForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isNew) {
      ref.read(tasksProvider.notifier).createNew(_formValues);
    } else {
      ref.read(tasksProvider.notifier).updateTask(_formValues);
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
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
          initialValue: _formValues.name,
        ),
        TextFormField(
          decoration: const InputDecoration(label: Text("Goal")),
          onChanged: (newValue) =>
              _formValues.goal = int.tryParse(newValue) ?? 0,
          initialValue: _formValues.goal.toString(),
          validator: (newValue) => newValue!.isEmpty
              ? 'Enter a goal'
              : int.tryParse(newValue) != null
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
