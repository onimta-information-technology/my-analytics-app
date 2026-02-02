import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

// OPTION 1: Small Flag in Top Right (Recommended)
class IndependenceEvent extends StatelessWidget {
  final bool isShow;

  const IndependenceEvent({
    Key? key,
    required this.isShow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isShow) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Lottie.asset(
              'assets/independenceDaySl.json',
              width: 500,
              height: 500,
              fit: BoxFit.contain,
              repeat: true,
            ),
          ),
        ),
      ),
    );
  }
}