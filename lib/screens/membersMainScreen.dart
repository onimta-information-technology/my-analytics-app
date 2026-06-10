
import 'package:ballys_reservation_app/providers/font_settings_provider.dart';
import 'package:ballys_reservation_app/utils/connectivity_mixin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class MemberMainScreen extends ConsumerStatefulWidget {


  const MemberMainScreen({super.key});

  @override
  ConsumerState<MemberMainScreen> createState() => _MemberMainScreenState();
}

class _MemberMainScreenState extends ConsumerState<MemberMainScreen> with ConnectivityMixin{
  

  @override
  Widget build(BuildContext context) {
    ref.watch(fontSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Members'),leading: IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/menu');
      }
    },
  ),),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(5.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.go('/memberMain/members');
                        },
                        child: Card(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF0000),
                                  Color.fromARGB(192, 250, 2, 85),
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
                                   FontAwesomeIcons.person,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Members',
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.normal,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          context.go('/memberMain/cdd/names');
                        },
                        child: Card(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              gradient: const LinearGradient(
                                colors: [
                                 Color.fromARGB(255, 1, 1, 212),
                                  Color.fromARGB(255, 2, 235, 235),
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
                                    FontAwesomeIcons.accusoft,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Customer Due Diligence',
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.normal,
                                      color: Colors.white,
                                    ),
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
          
        ],
      ),
    );
  }
}
