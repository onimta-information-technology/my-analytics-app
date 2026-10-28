import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// App-wide loading overlay: dims the page and shows the loader Lottie in a
// translucent dark box. The animation is drawn in white, so it needs the dark
// box behind it. Put it in the screen's Stack above the content.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      child: Center(
        child: Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/loders/card_suit_loader.json',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
                // Broken animation file: fall back to a spinner instead of
                // an error box.
                errorBuilder: (context, error, stackTrace) => const SizedBox(
                  width: 72,
                  height: 72,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
