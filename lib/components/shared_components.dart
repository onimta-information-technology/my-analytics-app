import 'package:flutter/material.dart';

AppBar buildAppBar(BuildContext context, String title) {
  return AppBar(
    elevation: 10.0,
    title: Text(
      title,
      style: const TextStyle(fontSize: 15.0),
    ),
    backgroundColor: Colors.white,
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: () {},
      ),
      IconButton(
        icon: const Icon(Icons.notifications),
        onPressed: () {},
      ),
    ],
  );
}
