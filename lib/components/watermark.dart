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
              return Wrap(
                alignment: WrapAlignment.start,
                runAlignment: WrapAlignment.center,
                spacing: 1,
                runSpacing: 25,
                children: List.generate(
                  100,
                  (index) => Transform.rotate(
                    angle: -0.7,
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
        ),
      ),
    );
  }
}
