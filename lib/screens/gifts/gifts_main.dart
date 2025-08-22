import 'package:ballys_reservation_app/components/watermark.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class GiftsMainScreen extends ConsumerStatefulWidget {
  final GiftsRepository giftsRepository;

  const GiftsMainScreen({super.key, required this.giftsRepository});

  @override
  ConsumerState<GiftsMainScreen> createState() => _GiftsMainScreenState();
}

class _GiftsMainScreenState extends ConsumerState<GiftsMainScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(fontSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gifts'),
      ),
      body: Stack(
        children: [
          Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      context.go('/gifts/event-gifts');
                    },
                    child: Card(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.0),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF0000),
                              Color.fromARGB(192, 250, 2, 85)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Column(
                            children: [
                              Icon(
                                FontAwesomeIcons.gifts,
                                size: 60,
                                color: Colors.white,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Event Gifts',
                                style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      context.go('/gifts/special-gift-requests');
                    },
                    child: Card(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.0),
                          gradient: const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 1, 1, 212),
                              Color.fromARGB(255, 2, 235, 235)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Column(
                            children: [
                              Icon(
                                FontAwesomeIcons.gift,
                                size: 60,
                                color: Colors.white,
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Special Gifts',
                                style: TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
          ],
        ),
      ),
        const Watermark(),
        ],
      ),
    );
  }
}
