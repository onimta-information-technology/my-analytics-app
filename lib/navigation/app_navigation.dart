import 'package:ballys_reservation_app/data/repositories/airport_repository.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/data/repositories/inactive_members_repository.dart';
import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/main.dart';
import 'package:ballys_reservation_app/models/birthday.dart';
import 'package:ballys_reservation_app/models/gift/special_gift_request.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/screens/approve_reject_show_screen.dart';
import 'package:ballys_reservation_app/screens/auth/login_screen.dart';
import 'package:ballys_reservation_app/screens/auth/otpVerification_screen.dart';
import 'package:ballys_reservation_app/screens/birthday_gift_price_increase_screen.dart';
import 'package:ballys_reservation_app/screens/birthday_screen.dart';
import 'package:ballys_reservation_app/screens/daily_walking_guests/daily_walking_guests%20_screen.dart';
import 'package:ballys_reservation_app/screens/chat_screen.dart';
import 'package:ballys_reservation_app/screens/gifts/gifts_main.dart';
import 'package:ballys_reservation_app/screens/gifts/guest_gifts_screen.dart';
import 'package:ballys_reservation_app/screens/gifts/gifts_screen.dart';
import 'package:ballys_reservation_app/screens/gifts/new_gift_request.dart';
import 'package:ballys_reservation_app/screens/gifts/previous_gift.dart';
import 'package:ballys_reservation_app/screens/gifts/special_gift_request_screen.dart';
import 'package:ballys_reservation_app/screens/gifts/view_special_gift.dart';
import 'package:ballys_reservation_app/screens/home_screen.dart';
import 'package:ballys_reservation_app/screens/inactive_members.dart';
import 'package:ballys_reservation_app/screens/member_visits.dart';
import 'package:ballys_reservation_app/screens/member_visits/sales_persons.dart';
import 'package:ballys_reservation_app/screens/members_screen.dart';
import 'package:ballys_reservation_app/screens/profile/guest_performance/guest_performance_screen.dart';
import 'package:ballys_reservation_app/screens/profile/member_summary_screen.dart';
import 'package:ballys_reservation_app/screens/profile/profile_screen.dart';
import 'package:ballys_reservation_app/screens/menu_screen.dart';
import 'package:ballys_reservation_app/screens/profile/trip_history_screen.dart';
import 'package:ballys_reservation_app/screens/report_screen.dart';
import 'package:ballys_reservation_app/screens/reservations/air_tickets_selection_screen.dart';
import 'package:ballys_reservation_app/screens/reservations/new_reservation_screen.dart';
import 'package:ballys_reservation_app/screens/reservations/reservation_screen.dart';
import 'package:ballys_reservation_app/screens/reservations/reservation_view_screen.dart';
import 'package:ballys_reservation_app/screens/settings_screen.dart';
import 'package:ballys_reservation_app/screens/support_screen.dart';
import 'package:ballys_reservation_app/wrappers/main_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:ballys_reservation_app/main.dart' show navigatorKey;

class AppNavigation {
  AppNavigation._();

  static String initialRoute = '/splash';

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: initialRoute,
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            child: const LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
          );
        },
      ),
      GoRoute(
        path: '/otp-verification',
        pageBuilder: (context, state) {
          final Map<String, dynamic> extra =
              state.extra as Map<String, dynamic>;
          return CustomTransitionPage(
            child: OTPVerificationScreen(
              phoneNumber: extra['phoneNumber'] as String,
              username: extra['username'] as String,
              password: extra['password'] as String,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).animate(
                          CurveTween(
                            curve: Curves.easeInOut,
                          ).animate(animation),
                        ),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) => MainWrapper(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => CustomTransitionPage(
              fullscreenDialog: true,
              key: state.pageKey,
              child: const HomeScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurveTween(
                        curve: Curves.easeInOutCirc,
                      ).animate(animation),
                      child: child,
                    );
                  },
            ),
            routes: [
              GoRoute(
                path: 'profile',
                pageBuilder: (context, state) {
                  return CustomTransitionPage(
                    fullscreenDialog: false,
                    key: state.pageKey,
                    child: const ProfileScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: CurveTween(
                              curve: Curves.easeInOutCirc,
                            ).animate(animation),
                            child: child,
                          );
                        },
                  );
                },
                routes: [
                  GoRoute(
                    path: 'guest-performance',
                    pageBuilder: (context, state) {
                      return CustomTransitionPage(
                        fullscreenDialog: false,
                        key: state.pageKey,
                        child: GuestPerformanceScreen(
                          memberProfileRepository: MemberProfileRepository(
                            ApiService(const FlutterSecureStorage()),
                          ),
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: CurveTween(
                                  curve: Curves.easeInOutCirc,
                                ).animate(animation),
                                child: child,
                              );
                            },
                      );
                    },
                  ),
                  GoRoute(
                    path: 'member-summary',
                    pageBuilder: (context, state) {
                      return CustomTransitionPage(
                        fullscreenDialog: false,
                        key: state.pageKey,
                        child: MemberSummaryScreen(
                          memberProfileRepository: MemberProfileRepository(
                            ApiService(const FlutterSecureStorage()),
                          ),
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: CurveTween(
                                  curve: Curves.easeInOutCirc,
                                ).animate(animation),
                                child: child,
                              );
                            },
                      );
                    },
                  ),
                  GoRoute(
                    path: 'trip-history',
                    pageBuilder: (context, state) {
                      return CustomTransitionPage(
                        fullscreenDialog: false,
                        key: state.pageKey,
                        child: TripHistoryScreen(
                          memberProfileRepository: MemberProfileRepository(
                            ApiService(const FlutterSecureStorage()),
                          ),
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: CurveTween(
                                  curve: Curves.easeInOutCirc,
                                ).animate(animation),
                                child: child,
                              );
                            },
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'member-visits',
                pageBuilder: (context, state) {
                  final Map<String, dynamic> data =
                      state.extra as Map<String, dynamic>;
                  final String title = data['title'] as String;
                  final List<Guest> guestList =
                      data['guestList'] as List<Guest>;

                  return CustomTransitionPage(
                    fullscreenDialog: false,
                    key: state.pageKey,
                    child: MemberVisits(title: title, guestList: guestList),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: CurveTween(
                              curve: Curves.easeInOutCirc,
                            ).animate(animation),
                            child: child,
                          );
                        },
                  );
                },
                routes: const [],
              ),
              GoRoute(
                path: 'sales-persons',
                pageBuilder: (context, state) {
                  final Map<String, dynamic> data =
                      state.extra as Map<String, dynamic>;
                  final String title = data['title'] as String;
                  final Map<String, List<Guest>> salesPersons =
                      data['salesPersons'] as Map<String, List<Guest>>;

                  return CustomTransitionPage(
                    fullscreenDialog: false,
                    key: state.pageKey,
                    child: SalesPersonsScreen(
                      title: title,
                      salesPersons: salesPersons,
                    ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: CurveTween(
                              curve: Curves.easeInOutCirc,
                            ).animate(animation),
                            child: child,
                          );
                        },
                  );
                },
                routes: const [],
              ),
            ],
          ),
          GoRoute(
            path: '/reservations',
            pageBuilder: (context, state) => CustomTransitionPage(
              fullscreenDialog: true,
              key: state.pageKey,
              child: const ReservationScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurveTween(
                        curve: Curves.easeInOutCirc,
                      ).animate(animation),
                      child: child,
                    );
                  },
            ),
            routes: [
              GoRoute(
                path: 'new-reservation',
                pageBuilder: (context, state) {
                  return CustomTransitionPage(
                    fullscreenDialog: false,
                    key: state.pageKey,
                    child: const NewReservationScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: CurveTween(
                              curve: Curves.easeInOutCirc,
                            ).animate(animation),
                            child: child,
                          );
                        },
                  );
                },
                routes: [
                  //   GoRoute(
                  //     path: 'hotel-selection',
                  //     pageBuilder: (context, state) {
                  //       return CustomTransitionPage(
                  //         fullscreenDialog: false,
                  //         key: state.pageKey,
                  //         child: HotelAndRoomSelectionScreen(
                  //             RoomCategoryRepository(
                  //                 ApiService(const FlutterSecureStorage()))),
                  //         transitionsBuilder:
                  //             (context, animation, secondaryAnimation, child) {
                  //           return FadeTransition(
                  //             opacity: CurveTween(curve: Curves.easeInOutCirc)
                  //                 .animate(animation),
                  //             child: child,
                  //           );
                  //         },
                  //       );
                  //     },
                  //   ),
                  GoRoute(
                    path: 'air-tickets-selection',
                    pageBuilder: (context, state) {
                      final Map<String, dynamic> data =
                          state.extra as Map<String, dynamic>;
                      final arrivalDate = data['arrivalDate'] ?? '';
                      final departureDate = data['departureDate'] ?? '';
                      return CustomTransitionPage(
                        fullscreenDialog: false,
                        key: state.pageKey,
                        child: AirTicketsSelectionScreen(
                          AirportRepository(
                            ApiService(const FlutterSecureStorage()),
                          ),
                          arrivalDate: arrivalDate,
                          departureDate: departureDate,
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: CurveTween(
                                  curve: Curves.easeInOutCirc,
                                ).animate(animation),
                                child: child,
                              );
                            },
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'reservation-view',
                pageBuilder: (context, state) {
                  return CustomTransitionPage(
                    fullscreenDialog: false,
                    key: state.pageKey,
                    child: const ReservationViewScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: CurveTween(
                              curve: Curves.easeInOutCirc,
                            ).animate(animation),
                            child: child,
                          );
                        },
                  );
                },
              ),
              // GoRoute(
              //   path: 'reservation-edit',
              //   pageBuilder: (context, state) {
              //     return CustomTransitionPage(
              //       fullscreenDialog: false,
              //       key: state.pageKey,
              //       child: const ReservationEditScreen(),
              //       transitionsBuilder:
              //           (context, animation, secondaryAnimation, child) {
              //         return FadeTransition(
              //           opacity: CurveTween(curve: Curves.easeInOutCirc)
              //               .animate(animation),
              //           child: child,
              //         );
              //       },
              //     );
              //   },
              // ),
            ],
          ),
          // GoRoute(
          //   path: '/chats',
          //   pageBuilder: (context, state) => CustomTransitionPage(
          //     fullscreenDialog: true,
          //     key: state.pageKey,
          //     child: const ChatScreen(),
          //     transitionsBuilder:
          //         (context, animation, secondaryAnimation, child) {
          //           return FadeTransition(
          //             opacity: CurveTween(
          //               curve: Curves.easeInOutCirc,
          //             ).animate(animation),
          //             child: child,
          //           );
          //         },
          //   ),
          // ),
          GoRoute(
            path: '/support',
            pageBuilder: (context, state) => CustomTransitionPage(
              fullscreenDialog: true,
              key: state.pageKey,
              child: const SupportScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurveTween(
                        curve: Curves.easeInOutCirc,
                      ).animate(animation),
                      child: child,
                    );
                  },
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => CustomTransitionPage(
              fullscreenDialog: true,
              key: state.pageKey,
              child: const SettingsScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurveTween(
                        curve: Curves.easeInOutCirc,
                      ).animate(animation),
                      child: child,
                    );
                  },
            ),
          ),
          // GoRoute(
          //   path: '/settings',
          //   builder: (context, state) => const SettingsPopupMenu(),
          // ),
          // GoRoute(
          //   path: '/birthdays',
          //   pageBuilder: (context, state) => CustomTransitionPage(
          //     fullscreenDialog: true,
          //     key: state.pageKey,
          //     child: const BirthdayScreen(),
          //     transitionsBuilder:
          //         (context, animation, secondaryAnimation, child) {
          //           return FadeTransition(
          //             opacity: CurveTween(
          //               curve: Curves.easeInOutCirc,
          //             ).animate(animation),
          //             child: child,
          //           );
          //         },
          //   ),
          // ),
          GoRoute(
            path: '/birthdays',
            pageBuilder: (context, state) => CustomTransitionPage(
              fullscreenDialog: true,
              key: state.pageKey,
              child: BirthdayScreen(
                giftsRepository: GiftsRepository(
                  ApiService(const FlutterSecureStorage()),
                ),
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurveTween(
                        curve: Curves.easeInOutCirc,
                      ).animate(animation),
                      child: child,
                    );
                  },
            ),
            routes: [
              // Add this nested route for birthday gift price increase
              GoRoute(
                path: 'gift-price-increase',
                pageBuilder: (context, state) {
                  final birthday = state.extra as Birthday;
                  return CustomTransitionPage(
                    fullscreenDialog: false,
                    key: state.pageKey,
                    child: BirthdayGiftPriceIncreaseScreen(
                      birthday: birthday,
                      giftsRepository: GiftsRepository(
                        ApiService(const FlutterSecureStorage()),
                      ),
                    ),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: CurveTween(
                              curve: Curves.easeInOutCirc,
                            ).animate(animation),
                            child: child,
                          );
                        },
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/inactive-members',
            pageBuilder: (context, state) => CustomTransitionPage(
              fullscreenDialog: true,
              key: state.pageKey,
              child: InactiveMembersScreen(
                inactiveMembersRepository: InactiveMembersRepository(
                  ApiService(const FlutterSecureStorage()),
                ),
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurveTween(
                        curve: Curves.easeInOutCirc,
                      ).animate(animation),
                      child: child,
                    );
                  },
            ),
          ),
          GoRoute(
            path: '/gifts',
            pageBuilder: (context, state) => CustomTransitionPage(
              fullscreenDialog: false,
              key: state.pageKey,
              child: GiftsMainScreen(
                giftsRepository: GiftsRepository(
                  ApiService(const FlutterSecureStorage()),
                ),
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurveTween(
                        curve: Curves.easeInOutCirc,
                      ).animate(animation),
                      child: child,
                    );
                  },
            ),
            routes: [
              GoRoute(
                path: 'event-gifts',
                pageBuilder: (context, state) => CustomTransitionPage(
                  fullscreenDialog: false,
                  key: state.pageKey,
                  child: GiftsScreen(
                    giftsRepository: GiftsRepository(
                      ApiService(const FlutterSecureStorage()),
                    ),
                  ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: CurveTween(
                            curve: Curves.easeInOutCirc,
                          ).animate(animation),
                          child: child,
                        );
                      },
                ),
                routes: [
                  GoRoute(
                    path: 'guest-gifts/:mid',
                    pageBuilder: (context, state) {
                      final String mid = state.pathParameters['mid']!;
                      return CustomTransitionPage(
                        fullscreenDialog: false,
                        key: state.pageKey,
                        child: GuestGiftsScreen(
                          giftsRepository: GiftsRepository(
                            ApiService(const FlutterSecureStorage()),
                          ),
                          mid: mid,
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: CurveTween(
                                  curve: Curves.easeInOutCirc,
                                ).animate(animation),
                                child: child,
                              );
                            },
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: '/special-gift-requests',
                pageBuilder: (context, state) => CustomTransitionPage(
                  fullscreenDialog: false,
                  key: state.pageKey,
                  child: SpecialGiftRequestScreen(
                    giftsRepository: GiftsRepository(
                      ApiService(const FlutterSecureStorage()),
                    ),
                  ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: CurveTween(
                            curve: Curves.easeInOutCirc,
                          ).animate(animation),
                          child: child,
                        );
                      },
                ),
                routes: [
                  GoRoute(
                    path: 'new-gift-request',
                    pageBuilder: (context, state) => CustomTransitionPage(
                      fullscreenDialog: false,
                      key: state.pageKey,
                      child: NewGiftRequest(
                        giftsRepository: GiftsRepository(
                          ApiService(const FlutterSecureStorage()),
                        ),
                      ),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: CurveTween(
                                curve: Curves.easeInOutCirc,
                              ).animate(animation),
                              child: child,
                            );
                          },
                    ),
                  ),
                  GoRoute(
                    path: 'prv-gifts/:mid',
                    pageBuilder: (context, state) {
                      final String mid = state.pathParameters['mid']!;
                      return CustomTransitionPage(
                        fullscreenDialog: false,
                        key: state.pageKey,
                        child: PrvGiftScreen(
                          memberId: mid,
                          giftsRepository: GiftsRepository(
                            ApiService(const FlutterSecureStorage()),
                          ),
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOutCirc,
                                ),
                                child: child,
                              );
                            },
                      );
                    },
                  ),
                  // GoRoute(
                  //   path: 'view-specific-gift-request',
                  //   pageBuilder: (context, state) => CustomTransitionPage(
                  //     fullscreenDialog: false,
                  //     key: state.pageKey,
                  //     child: ViewSpecificGiftRequest(
                  //       giftsRepository: GiftsRepository(
                  //         ApiService(const FlutterSecureStorage()),
                  //       ),
                  //     ),
                  //     transitionsBuilder:
                  //         (context, animation, secondaryAnimation, child) {
                  //           return FadeTransition(
                  //             opacity: CurveTween(
                  //               curve: Curves.easeInOutCirc,
                  //             ).animate(animation),
                  //             child: child,
                  //           );
                  //         },
                  //   ),
                  // ),
                  GoRoute(
                    path: 'view-specific-gift-request',
                    builder: (context, state) {
                      // Expecting state.extra to be a Map<String, dynamic>
                      final extra = state.extra as Map<String, dynamic>? ?? {};
                      final gift = extra['gift'] as SpecialGiftRequest?;
                      final isPending =
                          extra['isPending'] as bool? ?? false; // ✅ read flag
                      final isApproved = extra['isApproved'] as bool? ?? false;
                      return ViewSpecificGiftRequest(
                        giftsRepository: GiftsRepository(
                          ApiService(const FlutterSecureStorage()),
                        ),
                        gift: gift,
                        isPending: isPending,
                        isApproved: isApproved,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          GoRoute(
            path: '/members',
            pageBuilder: (context, state) => CustomTransitionPage(
              fullscreenDialog: true,
              key: state.pageKey,
              child: MembersScreen(
                giftsRepository: GiftsRepository(
                  ApiService(const FlutterSecureStorage()),
                ),
              ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurveTween(
                        curve: Curves.easeInOutCirc,
                      ).animate(animation),
                      child: child,
                    );
                  },
            ),
          ),
          GoRoute(
            path: '/daily-gests',
            pageBuilder: (context, state) => CustomTransitionPage(
              fullscreenDialog: true,
              key: state.pageKey,
              child: const DailyWalkingGuestScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(
                      opacity: CurveTween(
                        curve: Curves.easeInOutCirc,
                      ).animate(animation),
                      child: child,
                    );
                  },
            ),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
        ],
      ),
      // GoRoute(path: '/menu', builder: (context, state) => const MenuScreen()),
      GoRoute(
        path: '/menu',
        pageBuilder: (context, state) => CustomTransitionPage(
          fullscreenDialog: true,
          key: state.pageKey,
          child: const MenuScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurveTween(
                curve: Curves.easeInOutCirc,
              ).animate(animation),
              child: child,
            );
          },
        ),
        routes: [
          // GoRoute(
          //   path: 'chats',
          //   pageBuilder: (context, state) => CustomTransitionPage(
          //     fullscreenDialog: false,
          //     key: state.pageKey,
          //     child: const ChatScreen(),
          //     transitionsBuilder: (context, animation, secondaryAnimation, child) {
          //       return FadeTransition(
          //         opacity: CurveTween(curve: Curves.easeInOutCirc).animate(animation),
          //         child: child,
          //       );
          //     },
          //   ),
          // ),
          GoRoute(
            path: 'chats',
            pageBuilder: (context, state) {
              // Extract notification data from state.extra
              final notificationData = state.extra as Map<String, dynamic>?;

              return CustomTransitionPage(
                fullscreenDialog: false,
                key: state.pageKey,
                child: ChatScreen(
                  notificationData: notificationData,
                ), // Pass notification data
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: CurveTween(
                          curve: Curves.easeInOutCirc,
                        ).animate(animation),
                        child: child,
                      );
                    },
              );
            },
          ),
          GoRoute(
            path:
                'approve-reject', // ✅ Changed from '/approve-reject' to 'approve-reject'
            builder: (context, state) => const ApproveScreen(),
            routes: [
              GoRoute(
                path:
                    '/reservations', // ✅ Changed from '/reservations' to 'reservations'
                pageBuilder: (context, state) => CustomTransitionPage(
                  fullscreenDialog: true,
                  key: state.pageKey,
                  child: const ReservationScreen(hideAddButton: true),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: CurveTween(
                            curve: Curves.easeInOutCirc,
                          ).animate(animation),
                          child: child,
                        );
                      },
                ),
                routes: [
                  GoRoute(
                    path: 'new-reservation',
                    pageBuilder: (context, state) {
                      return CustomTransitionPage(
                        fullscreenDialog: false,
                        key: state.pageKey,
                        child: const NewReservationScreen(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: CurveTween(
                                  curve: Curves.easeInOutCirc,
                                ).animate(animation),
                                child: child,
                              );
                            },
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'air-tickets-selection',
                        pageBuilder: (context, state) {
                          final Map<String, dynamic> data =
                              state.extra as Map<String, dynamic>;
                          final arrivalDate = data['arrivalDate'] ?? '';
                          final departureDate = data['departureDate'] ?? '';
                          return CustomTransitionPage(
                            fullscreenDialog: false,
                            key: state.pageKey,
                            child: AirTicketsSelectionScreen(
                              AirportRepository(
                                ApiService(const FlutterSecureStorage()),
                              ),
                              arrivalDate: arrivalDate,
                              departureDate: departureDate,
                            ),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
                                  return FadeTransition(
                                    opacity: CurveTween(
                                      curve: Curves.easeInOutCirc,
                                    ).animate(animation),
                                    child: child,
                                  );
                                },
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'reservation-view',
                    pageBuilder: (context, state) {
                      return CustomTransitionPage(
                        fullscreenDialog: false,
                        key: state.pageKey,
                        child: const ReservationViewScreen(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: CurveTween(
                                  curve: Curves.easeInOutCirc,
                                ).animate(animation),
                                child: child,
                              );
                            },
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: '/special-gift-requests',
                pageBuilder: (context, state) => CustomTransitionPage(
                  fullscreenDialog: false,
                  key: state.pageKey,
                  child: SpecialGiftRequestScreen(
                    giftsRepository: GiftsRepository(
                      ApiService(const FlutterSecureStorage()),
                    ),
                    hideAddButton: true,
                  ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: CurveTween(
                            curve: Curves.easeInOutCirc,
                          ).animate(animation),
                          child: child,
                        );
                      },
                ),
                routes: [
                  GoRoute(
                    path: 'new-gift-request',
                    pageBuilder: (context, state) => CustomTransitionPage(
                      fullscreenDialog: false,
                      key: state.pageKey,
                      child: NewGiftRequest(
                        giftsRepository: GiftsRepository(
                          ApiService(const FlutterSecureStorage()),
                        ),
                      ),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: CurveTween(
                                curve: Curves.easeInOutCirc,
                              ).animate(animation),
                              child: child,
                            );
                          },
                    ),
                  ),
                  GoRoute(
                    path: 'prv-gifts/:mid',
                    pageBuilder: (context, state) {
                      final String mid = state.pathParameters['mid']!;
                      return CustomTransitionPage(
                        fullscreenDialog: false,
                        key: state.pageKey,
                        child: PrvGiftScreen(
                          memberId: mid,
                          giftsRepository: GiftsRepository(
                            ApiService(const FlutterSecureStorage()),
                          ),
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOutCirc,
                                ),
                                child: child,
                              );
                            },
                      );
                    },
                  ),
                  // GoRoute(
                  //   path: 'view-specific-gift-request',
                  //   pageBuilder: (context, state) => CustomTransitionPage(
                  //     fullscreenDialog: false,
                  //     key: state.pageKey,
                  //     child: ViewSpecificGiftRequest(
                  //       giftsRepository: GiftsRepository(
                  //         ApiService(const FlutterSecureStorage()),
                  //       ),
                  //     ),
                  //     transitionsBuilder:
                  //         (context, animation, secondaryAnimation, child) {
                  //           return FadeTransition(
                  //             opacity: CurveTween(
                  //               curve: Curves.easeInOutCirc,
                  //             ).animate(animation),
                  //             child: child,
                  //           );
                  //         },
                  //   ),
                  // ),
                  GoRoute(
                    path: 'view-specific-gift-request',
                    builder: (context, state) {
                      // Expecting state.extra to be a Map<String, dynamic>
                      final extra = state.extra as Map<String, dynamic>? ?? {};
                      final gift = extra['gift'] as SpecialGiftRequest?;
                      final isPending =
                          extra['isPending'] as bool? ?? false; // ✅ read flag
                      final isApproved = extra['isApproved'] as bool? ?? false;
                      return ViewSpecificGiftRequest(
                        giftsRepository: GiftsRepository(
                          ApiService(const FlutterSecureStorage()),
                        ),
                        gift: gift,
                        isPending: isPending,
                        isApproved: isApproved,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // GoRoute(
      //   path: '/menu',
      //   pageBuilder: (context, state) => CustomTransitionPage(
      //     transitionDuration: const Duration(milliseconds: 400),
      //     fullscreenDialog: true,
      //     key: state.pageKey,
      //     child: const MenuScreen(),
      //     transitionsBuilder: (context, animation, secondaryAnimation, child) {
      //       return SlideTransition(
      //         position: Tween<Offset>(
      //           begin: const Offset(-1.0, 0.0),
      //           end: const Offset(0.0, 0.0),
      //         ).animate(animation),
      //         child: child,
      //       );
      //     },
      //   ),
      // ),
    ],
  );
}
