import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/address/address_search_screen.dart';
import '../screens/address/map_selection_screen.dart';
import '../services/user_session.dart';
import '../screens/splash/splash_page.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/registration_screen.dart';
import '../screens/auth/google_registration_screen.dart';
import '../screens/auth/update_required_screen.dart';
import '../screens/home/home_map_startup_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/template/saved_templates_screen.dart';
import '../screens/route/route_preview_driver_screen.dart';
import '../screens/route/route_preview_passenger_screen.dart';
import '../screens/route/trip_search_results_screen.dart';
import 'globals.dart';
import 'navigation/route_arguments.dart';

T _requireRouteArgs<T extends Object>(GoRouterState state) {
  final extra = state.extra;
  if (extra is T) return extra;

  throw StateError(
    'Route "${state.matchedLocation}" requires arguments of type $T, '
    'but received ${extra.runtimeType}',
  );
}

CustomTransitionPage<void> buildAppTransition({
  required LocalKey key,
  required Widget child,
  bool fromLeft = false,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final bool isReversing = animation.status == AnimationStatus.reverse;

      final begin = isReversing
          ? const Offset(1.0, 0.0)
          : (fromLeft ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0));

      const end = Offset.zero;

      const curve = Curves.easeInOutCubic;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

      return SlideTransition(
        position: animation.drive(tween),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 15,
                spreadRadius: -4,
              )
            ],
          ),
          child: child,
        ),
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  navigatorKey: globalNavigatorKey,
  initialLocation: '/splash',
  refreshListenable: UserSession().authStatusNotifier,

  redirect: (context, state) {
    final status = UserSession().status;
    final isGoingToAuth = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register' ||
        state.matchedLocation == '/google-register';
    final isSplash = state.matchedLocation == '/splash';
    final isUpdateRequired = state.matchedLocation == '/update-required';

    if (status == AuthStatus.unknown) {
      return '/splash';
    }

    if (status == AuthStatus.appUpdateRequired) {
      return isUpdateRequired ? null : '/update-required';
    }

    if (isUpdateRequired) {
      return status == AuthStatus.authenticated ? '/' : '/login';
    }

    if (isSplash) {
      return status == AuthStatus.authenticated ? '/' : '/login';
    }

    if (status == AuthStatus.unauthenticated && !isGoingToAuth) {
      return '/login';
    }

    if (status == AuthStatus.authenticated && isGoingToAuth) {
      return '/';
    }

    return null;
  },

  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashPage(),
    ),

    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => buildAppTransition(
        key: state.pageKey,
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      path: '/update-required',
      builder: (context, state) => const UpdateRequiredScreen(),
    ),
    GoRoute(
      path: '/register',
      pageBuilder: (context, state) => buildAppTransition(
        key: state.pageKey,
        child: const RegistrationScreen(),
      ),
    ),
    GoRoute(
      path: '/google-register',
      pageBuilder: (context, state) {
        final args = _requireRouteArgs<GoogleRegistrationRouteArgs>(state);
        return buildAppTransition(
          key: state.pageKey,
          child: GoogleRegistrationScreen(
            googleEmail: args.googleEmail,
            googleName: args.googleName,
            googlePhotoUrl: args.googlePhotoUrl,
            idToken: args.idToken,
          ),
        );
      },
    ),

    GoRoute(
      path: '/',
      builder: (context, state) => HomeMapStartupScreen(
        mode: UserSession().currentMode,
      ),
      routes: [
        GoRoute(
          path: 'profile',
          pageBuilder: (context, state) => buildAppTransition(
            key: state.pageKey,
            child: const ProfileScreen(),
          ),
        ),
        GoRoute(
          path: 'saved-templates',
          pageBuilder: (context, state) {
            final args = _requireRouteArgs<SavedTemplatesRouteArgs>(state);
            return buildAppTransition(
              key: state.pageKey,
              child: SavedTemplatesScreen(
                isRegularRide: args.isRegularRide,
                selectedDateTime: args.selectedDateTime,
                selectedTime: args.selectedTime,
                selectedDays: args.selectedDays,
              ),
            );
          },
        ),

        GoRoute(
          path: 'address-search',
          pageBuilder: (context, state) {
            final args = _requireRouteArgs<AddressSearchRouteArgs>(state);
            return buildAppTransition(
              key: state.pageKey,
              child: AddressSearchScreen(
                initialOrigin: args.initialOrigin,
                initialDestination: args.initialDestination,
                focusOnDestination: args.focusOnDestination,
                isRegularRide: args.isRegularRide,
                selectedDateTime: args.selectedDateTime,
                selectedTime: args.selectedTime,
                selectedDays: args.selectedDays,
              ),
            );
          },
        ),

        GoRoute(
          path: 'map-selection',
          pageBuilder: (context, state) {
            final args = _requireRouteArgs<MapSelectionRouteArgs>(state);
            return buildAppTransition(
              key: state.pageKey,
              child: MapSelectionScreen(
                initialLocation: args.initialLocation,
                userLocation: args.userLocation,
                tileWarmup: args.tileWarmup,
                knownOrigin: args.knownOrigin,
                knownDestination: args.knownDestination,
                isSelectingDestination: args.isSelectingDestination,
                isRegularRide: args.isRegularRide,
                selectedDateTime: args.selectedDateTime,
                selectedTime: args.selectedTime,
                selectedDays: args.selectedDays,
              ),
            );
          },
        ),

        GoRoute(
          path: 'route-preview-driver',
          pageBuilder: (context, state) {
            final args = _requireRouteArgs<DriverRoutePreviewArgs>(state);
            return buildAppTransition(
              key: state.pageKey,
              fromLeft: true,
              child: RoutePreviewDriverScreen(
                origin: args.origin,
                destination: args.destination,
                isRegularRide: args.isRegularRide,
                selectedDateTime: args.selectedDateTime,
                selectedTime: args.selectedTime,
                selectedDays: args.selectedDays,
                isFromSavedTemplates: args.isFromSavedTemplates,
                preloadedRouteWithStops: args.preloadedRouteWithStops,
                waypoints: args.waypoints,
              ),
            );
          },
        ),
        GoRoute(
          path: 'trip-search-results',
          pageBuilder: (context, state) {
            final args = _requireRouteArgs<TripSearchResultsRouteArgs>(state);
            return buildAppTransition(
              key: state.pageKey,
              child: TripSearchResultsScreen(request: args.request),
            );
          },
        ),
        GoRoute(
          path: 'route-preview-passenger',
          pageBuilder: (context, state) {
            final args = _requireRouteArgs<PassengerRoutePreviewArgs>(state);
            return buildAppTransition(
              key: state.pageKey,
              fromLeft: true,
              child: RoutePreviewPassengerScreen(
                origin: args.origin,
                destination: args.destination,
                isRegularRide: args.isRegularRide,
                selectedDateTime: args.selectedDateTime,
                selectedTime: args.selectedTime,
                selectedDays: args.selectedDays,
                isFromSavedTemplates: args.isFromSavedTemplates,
                preloadedRoute: args.preloadedRoute,
              ),
            );
          },
        ),
      ],
    ),
  ],
);
