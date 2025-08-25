import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:flutter/material.dart';

class DailyWalkingGuests extends StatelessWidget {
  const DailyWalkingGuests({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Walking Guest Screen'),
      ),
      body: Stack(
          children: [
            const Center(child: Text('Daily Walking Guest Screen')),
           const Watermark(), 
          ]
      ),
     
    );
  }
}
