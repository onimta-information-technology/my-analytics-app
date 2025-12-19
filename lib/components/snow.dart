import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class Event extends StatelessWidget {
  final bool isShow;

  const Event({
    Key? key,
    required this.isShow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isShow) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            /// ❄️ FULL SCREEN SNOW
            Positioned.fill(
              child: Lottie.asset(
                'assets/snow.json',
                fit: BoxFit.cover,
                repeat: true,
              ),
            ),

        Positioned(
      left: 0,       
      bottom: 0,    
      child: Lottie.asset(
        'assets/ChristmasTree.json',
        width: 250,    
        height: 250,
        fit: BoxFit.contain,
        repeat: true,
      ),
    ),
          ],
        ),
      ),
    );
  }
}
