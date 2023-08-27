import 'package:flutter/material.dart';

class AnalyticsTab extends StatefulWidget {
  const AnalyticsTab({ Key? key }) : super(key: key);

  @override
  _AnalyticsTabState createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<AnalyticsTab> {
  @override
  Widget build(BuildContext context) {
    return const Text(
      "Stateful Analytics Page"
    );
  }
}