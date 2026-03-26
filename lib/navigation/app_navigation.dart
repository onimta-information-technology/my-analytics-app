import 'package:ballys_reservation_app/data/repositories/airport_repository.dart';
import 'package:ballys_reservation_app/data/repositories/gifts_repository.dart';
import 'package:ballys_reservation_app/data/repositories/guest_booking_repository.dart';
import 'package:ballys_reservation_app/data/repositories/inactive_members_repository.dart';
import 'package:ballys_reservation_app/data/repositories/member_profile_repository.dart';
import 'package:ballys_reservation_app/data/services/api_service.dart';
import 'package:ballys_reservation_app/main.dart';
import 'package:ballys_reservation_app/models/Guest/guest_booking.dart';
import 'package:ballys_reservation_app/models/birthday.dart';
import 'package:ballys_reservation_app/models/gift/birthday_gift_request.dart';
import 'package:ballys_reservation_app/models/gift/special_gift_request.dart';
import 'package:ballys_reservation_app/models/guest_modal.dart';
import 'package:ballys_reservation_app/screens/approve_reject_show_screen.dart';
import 'package:ballys_reservation_app/screens/auth/login_screen.dart';
import 'package:ballys_reservation_app/screens/auth/otpVerification_screen.dart';
import 'package:ballys_reservation_app/screens/birthdayGiftRequestScreen.dart';
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
import 'package:ballys_reservation_app/screens/guest_booking_screen.dart';
import 'package:ballys_reservation_app/screens/home_screen.dart';
import 'package:ballys_reservation_app/screens/inactive_members.dart';
import 'package:ballys_reservation_app/screens/member_visits.dart';
import 'package:ballys_reservation_app/screens/member_visits/customer_due_diligence_screen.dart';
import 'package:ballys_reservation_app/screens/member_visits/sales_persons.dart';
import 'package:ballys_reservation_app/screens/membersMainScreen.dart';
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
import 'package:ballys_reservation_app/screens/viewBirthdayGiftRequest.dart';
import 'package:ballys_reservation_app/screens/view_guest_booking.dart';
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
            ],
          ),
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
                      final extra = state.extra as Map<String, dynamic>? ?? {};
                      final int iid = extra['iid'] as int? ?? 8888;
                      return CustomTransitionPage(
                        fullscreenDialog: false,
                        key: state.pageKey,
                        child: PrvGiftScreen(
                          memberId: mid,
                          giftsRepository: GiftsRepository(
                            ApiService(const FlutterSecureStorage()),
                          ),
                          iid: iid,
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
                  GoRoute(
                    path: 'view-specific-gift-request',
                    builder: (context, state) {
                      final extra = state.extra as Map<String, dynamic>? ?? {};
                      final gift = extra['gift'] as SpecialGiftRequest?;
                      final isPending = extra['isPending'] as bool? ?? false;
                      final isApproved = extra['isApproved'] as bool? ?? false;
                      final isChecked = extra['isChecked'] as bool? ?? false;
                      return ViewSpecificGiftRequest(
                        giftsRepository: GiftsRepository(
                          ApiService(const FlutterSecureStorage()),
                        ),
                        gift: gift,
                        isPending: isPending,
                        isApproved: isApproved,
                        isChecked: isChecked,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/memberMain',
            pageBuilder: (context, state) => CustomTransitionPage(
              fullscreenDialog: true,
              key: state.pageKey,
              child: MemberMainScreen(
                // giftsRepository: GiftsRepository(
                //   ApiService(const FlutterSecureStorage()),
                // ),
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
                path: '/new_guest',
                pageBuilder: (context, state) => CustomTransitionPage(
                  fullscreenDialog: true,
                  key: state.pageKey,
                  child: CustomerDueDiligenceScreen(
                    // giftsRepository: GiftsRepository(
                    //   ApiService(const FlutterSecureStorage()),
                    // ),
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
            ],
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
          GoRoute(
            path: '/guest-bookings',
            pageBuilder: (context, state) => CustomTransitionPage(
              fullscreenDialog: true,
              key: state.pageKey,
              child: GuestBookingScreen(
                bookingRepository: GuestBookingRepository(
                  ApiService(const FlutterSecureStorage()),
                  const FlutterSecureStorage(),
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
                path: 'view-booking',
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>? ?? {};
                  final booking = extra['booking'] as GuestBooking?;
                  final isPending = extra['isPending'] as bool? ?? false;
                  return ViewGuestBooking(
                    bookingRepository: GuestBookingRepository(
                      ApiService(const FlutterSecureStorage()),
                      const FlutterSecureStorage(),
                    ),
                    booking: booking,
                    isPending: isPending,
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/menu',
            pageBuilder: (context, state) => CustomTransitionPage(
              fullscreenDialog: true,
              key: state.pageKey,
              child: const MenuScreen(),
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
                path: 'chats',
                pageBuilder: (context, state) {
                  final notificationData = state.extra as Map<String, dynamic>?;
                  return CustomTransitionPage(
                    fullscreenDialog: false,
                    key: state.pageKey,
                    child: ChatScreen(notificationData: notificationData),
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
                path: 'approve-reject',
                builder: (context, state) => const ApproveScreen(),
                routes: [
                  GoRoute(
                    path: '/reservations',
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
                          final extra =
                              state.extra as Map<String, dynamic>? ?? {};
                          final int iid = extra['iid'] as int? ?? 8888;
                          return CustomTransitionPage(
                            fullscreenDialog: false,
                            key: state.pageKey,
                            child: PrvGiftScreen(
                              memberId: mid,
                              giftsRepository: GiftsRepository(
                                ApiService(const FlutterSecureStorage()),
                              ),
                              iid: iid,
                            ),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
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
                      GoRoute(
                        path: 'view-specific-gift-request',
                        builder: (context, state) {
                          final extra =
                              state.extra as Map<String, dynamic>? ?? {};
                          final gift = extra['gift'] as SpecialGiftRequest?;
                          final isPending =
                              extra['isPending'] as bool? ?? false;
                          final isApproved =
                              extra['isApproved'] as bool? ?? false;
                          final isChecked =
                              extra['isChecked'] as bool? ?? false;
                          return ViewSpecificGiftRequest(
                            giftsRepository: GiftsRepository(
                              ApiService(const FlutterSecureStorage()),
                            ),
                            gift: gift,
                            isPending: isPending,
                            isApproved: isApproved,
                            isChecked: isChecked,
                          );
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: '/birthday-gifts',
                    pageBuilder: (context, state) => CustomTransitionPage(
                      fullscreenDialog: true,
                      key: state.pageKey,
                      child: BirthdayGiftRequestScreen(
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
                      // ── View Birthday Gift Request ─────────────────────────────
                      // Now passes isChecked so the detail screen knows which tab
                      // opened it and renders the correct buttons.
                      GoRoute(
                        path: 'view-birthday-gift-request',
                        builder: (context, state) {
                          final extra =
                              state.extra as Map<String, dynamic>? ?? {};
                          final gift =
                              extra['gift'] as BirthdayIncressGiftRequest?;
                          final isPending =
                              extra['isPending'] as bool? ?? false;
                          final isApproved =
                              extra['isApproved'] as bool? ?? false;
                          final isChecked =
                              extra['isChecked'] as bool? ?? false; // ← fixed
                          return ViewBirthdayGiftRequest(
                            giftsRepository: GiftsRepository(
                              ApiService(const FlutterSecureStorage()),
                            ),
                            gift: gift,
                            isPending: isPending,
                            isApproved: isApproved,
                            isChecked: isChecked, // ← passed through
                          );
                        },
                      ),
                      GoRoute(
                        path: 'prv-gifts/:mid',
                        pageBuilder: (context, state) {
                          final String mid = state.pathParameters['mid']!;
                          final extra =
                              state.extra as Map<String, dynamic>? ?? {};
                          final int iid = extra['iid'] as int? ?? 8888;
                          return CustomTransitionPage(
                            fullscreenDialog: false,
                            key: state.pageKey,
                            child: PrvGiftScreen(
                              memberId: mid,
                              giftsRepository: GiftsRepository(
                                ApiService(const FlutterSecureStorage()),
                              ),
                              iid: iid,
                            ),
                            transitionsBuilder:
                                (
                                  context,
                                  animation,
                                  secondaryAnimation,
                                  child,
                                ) {
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
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
