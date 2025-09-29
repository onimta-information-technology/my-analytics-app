import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ballys_reservation_app/utils/storage_util.dart';

class Watermark extends StatefulWidget {
  const Watermark({super.key});

  @override
  _WatermarkState createState() => _WatermarkState();
}

class _WatermarkState extends State<Watermark> {
  String userName = "Loading...";
  String lastSeen = "Loading...";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final name = await StorageUtil.getUserName();
    final now = DateTime.now();

    setState(() {
      userName = name ?? "Loading...";
      lastSeen = DateFormat('dd MMM yyyy, hh:mm a').format(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.2,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate how many watermarks we need based on screen size
              final itemWidth = 200.0; // Approximate width of each watermark
              final itemHeight = 40.0; // Approximate height of each watermark
              
              final columns = (constraints.maxWidth / itemWidth).ceil() + 1;
              final rows = (constraints.maxHeight / itemHeight).ceil() + 1;
              final totalItems = columns * rows;

              return Stack(
                children: List.generate(
                  totalItems,
                  (index) {
                    // Calculate position for each watermark
                    final row = index ~/ columns;
                    final col = index % columns;
                    
                    // Offset alternate rows for better coverage
                    final xOffset = col * itemWidth + (row.isOdd ? itemWidth / 2 : 0);
                    final yOffset = row * itemHeight;

                    return Positioned(
                      left: xOffset - itemWidth / 2,
                      top: yOffset,
                      child: Transform.rotate(
                        angle: -0.9,
                        child: SizedBox(
                          width: itemWidth,
                          child: Text(
                            "$userName\n$lastSeen",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}