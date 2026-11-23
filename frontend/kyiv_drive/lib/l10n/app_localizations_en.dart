// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String greeting(Object name) {
    return 'Hello, $name!';
  }

  @override
  String get welcomeTitle => 'Welcome!';

  @override
  String get loginButton => 'Log In';

  @override
  String get passengerRole => 'I\'m a passenger';

  @override
  String get driverRole => 'I\'m a driver';

  @override
  String get needToAuth => 'To find travel companions\nyou must log in.';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get noAccountYet => 'Don\'t have an account yet? ';

  @override
  String get register => 'Sign up';

  @override
  String get or => 'or';

  @override
  String get viaGoogle => 'Sign in with Google';

  @override
  String get completionRegister => 'Complete Registration';

  @override
  String get chooseRoleDescription =>
      'This choice determines your main features.\nYou can change your role at any time in your profile settings.';

  @override
  String get yourName => 'Your name';

  @override
  String get confirmLogin => 'Confirm and log in';

  @override
  String get cancel => 'Cancel';

  @override
  String get leave => 'Leave';

  @override
  String get waypointRedrawInProgressTitle => 'Leave without saving?';

  @override
  String get waypointRedrawInProgressMessage =>
      'The route is being redrawn. If you leave, your waypoint changes will not be saved.';

  @override
  String get unsavedChangesTitle => 'Unsaved changes';

  @override
  String get unsavedChangesMessage =>
      'You have unsaved changes. Save them before leaving?';

  @override
  String get doNotSave => 'Don\'t save';

  @override
  String get waypointChangesNotRedrawnTitle => 'Route not redrawn';

  @override
  String get waypointChangesNotRedrawnMessage =>
      'The waypoints have changed, but the route has not been redrawn yet. Redraw it to see the updated path.';

  @override
  String get redraw => 'Redraw';

  @override
  String get registration => 'Registration';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get login => 'Log in';

  @override
  String get myRides => 'My rides';

  @override
  String get whereGoing => 'Where are we going?';

  @override
  String get savedTemplates => 'Saved templates';

  @override
  String get findCompanion => 'Find a ride';

  @override
  String get letsGoLoading => 'Let\'s go...';

  @override
  String get somethingWentWrong =>
      'Something went wrong. Please try again later.';

  @override
  String get serviceBusy => 'The service is busy';

  @override
  String get tryAgainLater => 'Please try again later.';

  @override
  String get retry => 'Try again';

  @override
  String get requestTimedOut => 'The request took too long. Try again later.';

  @override
  String get appUpdateRequiredTitle => 'Update required';

  @override
  String get appUpdateRequiredDescription =>
      'This version of KyivDrive is no longer supported. Install the latest version to continue.';

  @override
  String get nameTooShort => 'Minimum 2 characters';

  @override
  String get nameInvalidFormat => 'Invalid name format';

  @override
  String get emailInvalidFormat => 'Invalid email format';

  @override
  String get passwordTooShort => 'Password is too short';

  @override
  String get passwordComplexity => 'Uppercase, lowercase, and digit required';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get invalidCode => 'Invalid code';

  @override
  String get profile => 'Profile';

  @override
  String get unknownUser => 'Unknown user';

  @override
  String get role => 'Role';

  @override
  String get menu => 'Menu';

  @override
  String get cars => 'Cars';

  @override
  String get privacy => 'Privacy';

  @override
  String get help => 'Help';

  @override
  String get aboutService => 'About the service';

  @override
  String get logoutFromProfile => 'Log out of your profile';

  @override
  String get logout => 'Log out';

  @override
  String get logoutTitle => 'Log out of your profile?';

  @override
  String get logoutDescription =>
      'Are you sure you want to log out of your account? You will need to enter your password to log in again.';

  @override
  String get reviewOne => 'review';

  @override
  String get reviewTwo => 'reviews';

  @override
  String get reviewFive => 'reviews';

  @override
  String get planingTrip => 'Ride planning';

  @override
  String get notRegular => 'One-time';

  @override
  String get regular => 'Regular';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get mon => 'Mon';

  @override
  String get tue => 'Tue';

  @override
  String get wed => 'Wed';

  @override
  String get thu => 'Thu';

  @override
  String get fri => 'Fri';

  @override
  String get sat => 'Sat';

  @override
  String get sun => 'Sun';

  @override
  String get monShort => 'Mo';

  @override
  String get tueShort => 'Tu';

  @override
  String get wedShort => 'We';

  @override
  String get thuShort => 'Th';

  @override
  String get friShort => 'Fr';

  @override
  String get satShort => 'Sa';

  @override
  String get sunShort => 'Su';

  @override
  String get emailConfirmationTitle => 'Email confirmation';

  @override
  String get recoveryTitle => 'Password recovery';

  @override
  String get recoveryStep1Desc =>
      'Enter your email to receive a verification code';

  @override
  String recoveryStep2Desc(Object email) {
    return 'Enter the code sent to $email';
  }

  @override
  String get recoveryStep3Desc => 'Create a new password';

  @override
  String get sendCode => 'Next';

  @override
  String get verify => 'Verify';

  @override
  String get save => 'Save';

  @override
  String get codeHint => 'Code';

  @override
  String get newPassword => 'New password';

  @override
  String get successResetPassword => 'Password changed successfully';

  @override
  String get locationDisabledTitle => 'Location is disabled';

  @override
  String get locationDisabledContent =>
      'To use the map conveniently, please enable GPS.';

  @override
  String get enableButton => 'Enable';

  @override
  String get locationPermissionDeniedTitle => 'No location access';

  @override
  String get locationPermissionDeniedContent =>
      'The app cannot determine your location. Please allow access in settings.';

  @override
  String get settingsButton => 'Settings';

  @override
  String get allowLocationAccessToast => 'Please allow location access';

  @override
  String get locationUnknownErrorToast => 'Failed to determine location';

  @override
  String get outOfServiceArea => 'You are outside the service area';

  @override
  String get unknownLocation => 'Unknown location';

  @override
  String get route => 'Route';

  @override
  String get where => 'Where from';

  @override
  String get suggestedAddresses => 'Suggested addresses';

  @override
  String get refineSearchHint =>
      'Refine your search: add a city or street type (St, Ave, Blvd)';

  @override
  String get done => 'Done';

  @override
  String get selectOnMap => 'Select on the map';

  @override
  String get selectTime => 'Select time';

  @override
  String get jan => 'January';

  @override
  String get feb => 'February';

  @override
  String get mar => 'March';

  @override
  String get apr => 'April';

  @override
  String get may => 'May';

  @override
  String get jun => 'June';

  @override
  String get jul => 'July';

  @override
  String get aug => 'August';

  @override
  String get sep => 'September';

  @override
  String get oct => 'October';

  @override
  String get nov => 'November';

  @override
  String get dec => 'December';

  @override
  String get yearShort => 'y.';

  @override
  String get selectDifferentLocations =>
      'Please select different locations for the route';

  @override
  String get rideDetails => 'Ride details';

  @override
  String get travelTime => 'Travel time';

  @override
  String get distance => 'Distance';

  @override
  String get routePreviewTotal => 'Total';

  @override
  String get minutesShort => 'min';

  @override
  String get kilometersShort => 'km';

  @override
  String get hoursShort => 'h';

  @override
  String get metersShort => 'm';

  @override
  String get saveRoute => 'Save route';

  @override
  String get refreshRoute => 'Refresh route';

  @override
  String get refreshRouteShort => 'Refresh';

  @override
  String get routeTemplateSaved => 'Saved';

  @override
  String get routeSavedToTemplates => 'Route saved to templates';

  @override
  String routeTooManyStops(int maximumStops) {
    return 'The route contains too many stops: the maximum is $maximumStops.';
  }

  @override
  String get selectDaysOfWeek => 'Select days of the week';

  @override
  String get selectFirstRideDateAndTime =>
      'Select first ride date and departure time';

  @override
  String get selectDateAndTime => 'Select date and departure time';

  @override
  String get publishRide => 'Publish ride';

  @override
  String get tripPublished => 'Trip published';

  @override
  String get publicationNonexistentTime =>
      'On this date the clocks move forward, so the selected time does not exist. Choose another time.';

  @override
  String get publicationDepartureInPast =>
      'The departure time has already passed. Choose a future date or time.';

  @override
  String get publicationDateNotSelectedWeekday =>
      'The first departure date must fall on one of the selected weekdays.';

  @override
  String publicationDescriptionTooLong(int maximumLength) {
    return 'The description must not exceed $maximumLength characters.';
  }

  @override
  String get publicationRefreshRouteRequired =>
      'Refresh the route before publishing the trip.';

  @override
  String get stops => 'Stops';

  @override
  String get select => 'Select';

  @override
  String get deleteTemplate => 'Delete template?';

  @override
  String get sureToDeleteTemplate =>
      'Are you sure you want to delete this route?\nThis action cannot be undone.';

  @override
  String get delete => 'Delete';

  @override
  String get noSavedTemplates => 'No saved templates';

  @override
  String get routeWillAppear =>
      'Routes you save will appear here. Plan a ride and click the bookmark icon to save it for later.';

  @override
  String get stop => 'Stop';

  @override
  String get markStops =>
      'Mark the stops where it will be convenient for you to pick up or drop off passengers.';

  @override
  String get waypoints => 'Waypoints';

  @override
  String get waypoint => 'Waypoint';

  @override
  String get add => 'Add';

  @override
  String get redrawRoute => 'Redraw route';

  @override
  String get addWaypoint => 'Add waypoint';

  @override
  String get addWaypointsToRedrawAndUpdate =>
      'Add waypoints to edit the route. To update the route, click \"Redraw route\".';

  @override
  String get firstWaypointMatchesOrigin =>
      'The first waypoint cannot be placed at the starting point.';

  @override
  String get lastWaypointMatchesDestination =>
      'The last waypoint cannot be placed at the destination.';

  @override
  String adjacentWaypointsMatch(
    Object firstWaypointNumber,
    Object secondWaypointNumber,
  ) {
    return 'Waypoints $firstWaypointNumber and $secondWaypointNumber cannot be placed at the same point.';
  }

  @override
  String deleteWaypoint(Object displayIndex) {
    return 'Delete waypoint $displayIndex?';
  }

  @override
  String sureToDeleteWaypoint(Object displayIndex) {
    return 'Are you sure you want to remove waypoint $displayIndex from the route?';
  }

  @override
  String get makeSureTheRouteSuitsYou =>
      'Make sure the route suits you. The route and active stops can be changed.';

  @override
  String get serverTimeout =>
      'The server is not responding. Please check your internet connection.';

  @override
  String get noInternetConnection =>
      'Oops, the internet has gone down. Please check your connection.';

  @override
  String get noStopsFound => 'No stops found';

  @override
  String get noStopsDescription =>
      'There are no public transport stops on this route';

  @override
  String get colorWhite => 'White';

  @override
  String get colorBlack => 'Black';

  @override
  String get colorGray => 'Gray';

  @override
  String get colorSilver => 'Silver';

  @override
  String get colorRed => 'Red';

  @override
  String get colorBlue => 'Blue';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorBrown => 'Brown';

  @override
  String get colorBeige => 'Beige';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorPurple => 'Purple';

  @override
  String get deleteCar => 'Delete car?';

  @override
  String sureToDeleteCar(Object brand, Object model) {
    return 'Are you sure you want to delete $brand $model?\nThis action cannot be undone.';
  }

  @override
  String get scheduleRide => 'Schedule a ride';

  @override
  String get chooseCar => 'Choose a car';

  @override
  String get specifyFixedOrPerKilometerPrice =>
      'Specify a fixed price or a price per 1 km';

  @override
  String get price => 'Price';

  @override
  String get fixedPrice => 'Fixed price';

  @override
  String get pricePerKilometer => 'Price per 1 km';

  @override
  String get allowPriceNegotiation => 'Allow price negotiation';

  @override
  String get priceNegotiationHint =>
      'Passengers will be able to propose their own price';

  @override
  String get describeRideDetails =>
      'Describe ride details that potential passengers may find useful (optional)';

  @override
  String get rideDescriptionHint =>
      'For example: “Music will be playing during the ride”, “Electronic cigarettes are allowed”';

  @override
  String get carWithThisNumber =>
      'A car with this number has already been added';

  @override
  String get standardNumberNeedToEnterLatin =>
      'Standard number needs to be entered in Latin';

  @override
  String get incorrectNumberFormat => 'Incorrect number format';

  @override
  String get numberAndSeatClue =>
      'Only confirmed passengers will see the number.\nSeats — how many passengers you are willing to take.';

  @override
  String get addCar => 'Add car';

  @override
  String get editCar => 'Edit car';

  @override
  String get carEditExistingTripsHint =>
      'Changes will not affect the car details in trips you have already created.';

  @override
  String get brand => 'Brand';

  @override
  String get model => 'Model';

  @override
  String get number => 'Number';

  @override
  String get seats => 'Seats';

  @override
  String get bodyColor => 'Body color';

  @override
  String get anotherCar => 'Another car';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get seatOne => 'seat';

  @override
  String get seatTwo => 'seats';

  @override
  String get seatFive => 'seats';

  @override
  String get searchPriorities => 'Search priorities';

  @override
  String get searchTimePreferencesHint =>
      'Please set your preferred departure and arrival times. We’ll consider your preferences even if no priority is selected.';

  @override
  String get chooseMainSearchPriority => 'Choose your main priority';

  @override
  String get rankSearchPriorities => 'Rank priorities by importance';

  @override
  String get noSearchPriority => 'No priority';

  @override
  String get balancedSearchDescription => 'All criteria are equally important';

  @override
  String get priorityDeparture => 'Start after';

  @override
  String get priorityArrival => 'Arrive no later than';

  @override
  String get priorityWalking => 'Less walking';

  @override
  String get priorityPrice => 'Lower cost';

  @override
  String get priorityWeekdays => 'Matching weekdays';

  @override
  String get orderSearchPriorities => 'Set priority order';

  @override
  String get resetSearchPriorities => 'Reset priority order';

  @override
  String priorityArrivalDayOffset(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days later',
      one: 'Next day',
    );
    return '$_temp0';
  }

  @override
  String get movePriorityUp => 'Move priority up';

  @override
  String get movePriorityDown => 'Move priority down';

  @override
  String get routes => 'Routes';

  @override
  String get tripSearchSort => 'Sort';

  @override
  String get tripSearchFilter => 'Filter';

  @override
  String get tripSearchTimeFits =>
      'Departure and arrival fit your requested times';

  @override
  String get tripSearchTimeMismatch =>
      'Leaves earlier or arrives later than requested';

  @override
  String get tripSearchScheduleFits => 'Matches all requested dates';

  @override
  String get tripSearchScheduleIncomplete =>
      'Runs on only some of your requested dates';

  @override
  String get tripSearchScheduleStartsLater =>
      'First ride starts later than requested';

  @override
  String get tripSearchIdentityVerificationUnavailable =>
      'Identity verification via Diia is not available yet';

  @override
  String get tripSearchNoReviews => 'No reviews yet';

  @override
  String tripSearchFirstTripOn(String date) {
    return 'First ride — $date';
  }

  @override
  String tripSearchAvailableSeats(int available, int total) {
    return 'Available passenger seats: $available of $total';
  }

  @override
  String tripSearchDayOffset(int days) {
    return '+${days}d';
  }

  @override
  String get tripSearchByCar => 'By car';

  @override
  String get tripSearchEmpty => 'No routes found';

  @override
  String get tripSearchEmptyHint =>
      'Try changing the date, time or route in your search.';

  @override
  String get tripSearchBusy => 'The search service is busy';

  @override
  String get tripSearchRateLimited => 'Too many requests';

  @override
  String get tripSearchLoadMoreFailed => 'Could not load more routes';

  @override
  String get tripSearchRefresh => 'Refresh search';

  @override
  String get tripSearchExpired => 'Search results have expired';
}
