import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:flutter/material.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Screen'),
      ),
      body: Stack(
          children: [
            const Center(child: Text('Events Screen')),
           const Watermark(), 
          ]
      ),
     
    );
  }
}
