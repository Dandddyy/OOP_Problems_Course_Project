import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
    Locale('uk'),
  ];

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}!'**
  String greeting(Object name);

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcomeTitle;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get loginButton;

  /// No description provided for @passengerRole.
  ///
  /// In en, this message translates to:
  /// **'I\'m a passenger'**
  String get passengerRole;

  /// No description provided for @driverRole.
  ///
  /// In en, this message translates to:
  /// **'I\'m a driver'**
  String get driverRole;

  /// No description provided for @needToAuth.
  ///
  /// In en, this message translates to:
  /// **'To find travel companions\nyou must log in.'**
  String get needToAuth;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @noAccountYet.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account yet? '**
  String get noAccountYet;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get register;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @viaGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get viaGoogle;

  /// No description provided for @completionRegister.
  ///
  /// In en, this message translates to:
  /// **'Complete Registration'**
  String get completionRegister;

  /// No description provided for @chooseRoleDescription.
  ///
  /// In en, this message translates to:
  /// **'This choice determines your main features.\nYou can change your role at any time in your profile settings.'**
  String get chooseRoleDescription;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @confirmLogin.
  ///
  /// In en, this message translates to:
  /// **'Confirm and log in'**
  String get confirmLogin;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @waypointRedrawInProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving?'**
  String get waypointRedrawInProgressTitle;

  /// No description provided for @waypointRedrawInProgressMessage.
  ///
  /// In en, this message translates to:
  /// **'The route is being redrawn. If you leave, your waypoint changes will not be saved.'**
  String get waypointRedrawInProgressMessage;

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Save them before leaving?'**
  String get unsavedChangesMessage;

  /// No description provided for @doNotSave.
  ///
  /// In en, this message translates to:
  /// **'Don\'t save'**
  String get doNotSave;

  /// No description provided for @waypointChangesNotRedrawnTitle.
  ///
  /// In en, this message translates to:
  /// **'Route not redrawn'**
  String get waypointChangesNotRedrawnTitle;

  /// No description provided for @waypointChangesNotRedrawnMessage.
  ///
  /// In en, this message translates to:
  /// **'The waypoints have changed, but the route has not been redrawn yet. Redraw it to see the updated path.'**
  String get waypointChangesNotRedrawnMessage;

  /// No description provided for @redraw.
  ///
  /// In en, this message translates to:
  /// **'Redraw'**
  String get redraw;

  /// No description provided for @registration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get registration;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @myRides.
  ///
  /// In en, this message translates to:
  /// **'My rides'**
  String get myRides;

  /// No description provided for @whereGoing.
  ///
  /// In en, this message translates to:
  /// **'Where are we going?'**
  String get whereGoing;

  /// No description provided for @savedTemplates.
  ///
  /// In en, this message translates to:
  /// **'Saved templates'**
  String get savedTemplates;

  /// No description provided for @findCompanion.
  ///
  /// In en, this message translates to:
  /// **'Find a ride'**
  String get findCompanion;

  /// No description provided for @letsGoLoading.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go...'**
  String get letsGoLoading;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again later.'**
  String get somethingWentWrong;

  /// No description provided for @serviceBusy.
  ///
  /// In en, this message translates to:
  /// **'The service is busy'**
  String get serviceBusy;

  /// No description provided for @tryAgainLater.
  ///
  /// In en, this message translates to:
  /// **'Please try again later.'**
  String get tryAgainLater;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @requestTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The request took too long. Try again later.'**
  String get requestTimedOut;

  /// No description provided for @appUpdateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get appUpdateRequiredTitle;

  /// No description provided for @appUpdateRequiredDescription.
  ///
  /// In en, this message translates to:
  /// **'This version of KyivDrive is no longer supported. Install the latest version to continue.'**
  String get appUpdateRequiredDescription;

  /// No description provided for @nameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Minimum 2 characters'**
  String get nameTooShort;

  /// No description provided for @nameInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid name format'**
  String get nameInvalidFormat;

  /// No description provided for @emailInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get emailInvalidFormat;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password is too short'**
  String get passwordTooShort;

  /// No description provided for @passwordComplexity.
  ///
  /// In en, this message translates to:
  /// **'Uppercase, lowercase, and digit required'**
  String get passwordComplexity;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @invalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code'**
  String get invalidCode;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown user'**
  String get unknownUser;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @cars.
  ///
  /// In en, this message translates to:
  /// **'Cars'**
  String get cars;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @aboutService.
  ///
  /// In en, this message translates to:
  /// **'About the service'**
  String get aboutService;

  /// No description provided for @logoutFromProfile.
  ///
  /// In en, this message translates to:
  /// **'Log out of your profile'**
  String get logoutFromProfile;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @logoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out of your profile?'**
  String get logoutTitle;

  /// No description provided for @logoutDescription.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out of your account? You will need to enter your password to log in again.'**
  String get logoutDescription;

  /// No description provided for @reviewOne.
  ///
  /// In en, this message translates to:
  /// **'review'**
  String get reviewOne;

  /// No description provided for @reviewTwo.
  ///
  /// In en, this message translates to:
  /// **'reviews'**
  String get reviewTwo;

  /// No description provided for @reviewFive.
  ///
  /// In en, this message translates to:
  /// **'reviews'**
  String get reviewFive;

  /// No description provided for @planingTrip.
  ///
  /// In en, this message translates to:
  /// **'Ride planning'**
  String get planingTrip;

  /// No description provided for @notRegular.
  ///
  /// In en, this message translates to:
  /// **'One-time'**
  String get notRegular;

  /// No description provided for @regular.
  ///
  /// In en, this message translates to:
  /// **'Regular'**
  String get regular;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @mon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get mon;

  /// No description provided for @tue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tue;

  /// No description provided for @wed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wed;

  /// No description provided for @thu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thu;

  /// No description provided for @fri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get fri;

  /// No description provided for @sat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get sat;

  /// No description provided for @sun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sun;

  /// No description provided for @monShort.
  ///
  /// In en, this message translates to:
  /// **'Mo'**
  String get monShort;

  /// No description provided for @tueShort.
  ///
  /// In en, this message translates to:
  /// **'Tu'**
  String get tueShort;

  /// No description provided for @wedShort.
  ///
  /// In en, this message translates to:
  /// **'We'**
  String get wedShort;

  /// No description provided for @thuShort.
  ///
  /// In en, this message translates to:
  /// **'Th'**
  String get thuShort;

  /// No description provided for @friShort.
  ///
  /// In en, this message translates to:
  /// **'Fr'**
  String get friShort;

  /// No description provided for @satShort.
  ///
  /// In en, this message translates to:
  /// **'Sa'**
  String get satShort;

  /// No description provided for @sunShort.
  ///
  /// In en, this message translates to:
  /// **'Su'**
  String get sunShort;

  /// No description provided for @emailConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Email confirmation'**
  String get emailConfirmationTitle;

  /// No description provided for @recoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Password recovery'**
  String get recoveryTitle;

  /// No description provided for @recoveryStep1Desc.
  ///
  /// In en, this message translates to:
  /// **'Enter your email to receive a verification code'**
  String get recoveryStep1Desc;

  /// No description provided for @recoveryStep2Desc.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to {email}'**
  String recoveryStep2Desc(Object email);

  /// No description provided for @recoveryStep3Desc.
  ///
  /// In en, this message translates to:
  /// **'Create a new password'**
  String get recoveryStep3Desc;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get sendCode;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @codeHint.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get codeHint;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @successResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get successResetPassword;

  /// No description provided for @locationDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Location is disabled'**
  String get locationDisabledTitle;

  /// No description provided for @locationDisabledContent.
  ///
  /// In en, this message translates to:
  /// **'To use the map conveniently, please enable GPS.'**
  String get locationDisabledContent;

  /// No description provided for @enableButton.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enableButton;

  /// No description provided for @locationPermissionDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'No location access'**
  String get locationPermissionDeniedTitle;

  /// No description provided for @locationPermissionDeniedContent.
  ///
  /// In en, this message translates to:
  /// **'The app cannot determine your location. Please allow access in settings.'**
  String get locationPermissionDeniedContent;

  /// No description provided for @settingsButton.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsButton;

  /// No description provided for @allowLocationAccessToast.
  ///
  /// In en, this message translates to:
  /// **'Please allow location access'**
  String get allowLocationAccessToast;

  /// No description provided for @locationUnknownErrorToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to determine location'**
  String get locationUnknownErrorToast;

  /// No description provided for @outOfServiceArea.
  ///
  /// In en, this message translates to:
  /// **'You are outside the service area'**
  String get outOfServiceArea;

  /// No description provided for @unknownLocation.
  ///
  /// In en, this message translates to:
  /// **'Unknown location'**
  String get unknownLocation;

  /// No description provided for @route.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get route;

  /// No description provided for @where.
  ///
  /// In en, this message translates to:
  /// **'Where from'**
  String get where;

  /// No description provided for @suggestedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Suggested addresses'**
  String get suggestedAddresses;

  /// No description provided for @refineSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Refine your search: add a city or street type (St, Ave, Blvd)'**
  String get refineSearchHint;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @selectOnMap.
  ///
  /// In en, this message translates to:
  /// **'Select on the map'**
  String get selectOnMap;

  /// No description provided for @selectTime.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get selectTime;

  /// No description provided for @jan.
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get jan;

  /// No description provided for @feb.
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get feb;

  /// No description provided for @mar.
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get mar;

  /// No description provided for @apr.
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get apr;

  /// No description provided for @may.
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get may;

  /// No description provided for @jun.
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get jun;

  /// No description provided for @jul.
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get jul;

  /// No description provided for @aug.
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get aug;

  /// No description provided for @sep.
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get sep;

  /// No description provided for @oct.
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get oct;

  /// No description provided for @nov.
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get nov;

  /// No description provided for @dec.
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get dec;

  /// No description provided for @yearShort.
  ///
  /// In en, this message translates to:
  /// **'y.'**
  String get yearShort;

  /// No description provided for @selectDifferentLocations.
  ///
  /// In en, this message translates to:
  /// **'Please select different locations for the route'**
  String get selectDifferentLocations;

  /// No description provided for @rideDetails.
  ///
  /// In en, this message translates to:
  /// **'Ride details'**
  String get rideDetails;

  /// No description provided for @travelTime.
  ///
  /// In en, this message translates to:
  /// **'Travel time'**
  String get travelTime;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @routePreviewTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get routePreviewTotal;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesShort;

  /// No description provided for @kilometersShort.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get kilometersShort;

  /// No description provided for @hoursShort.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get hoursShort;

  /// No description provided for @metersShort.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get metersShort;

  /// No description provided for @saveRoute.
  ///
  /// In en, this message translates to:
  /// **'Save route'**
  String get saveRoute;

  /// No description provided for @refreshRoute.
  ///
  /// In en, this message translates to:
  /// **'Refresh route'**
  String get refreshRoute;

  /// No description provided for @refreshRouteShort.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshRouteShort;

  /// No description provided for @routeTemplateSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get routeTemplateSaved;

  /// No description provided for @routeSavedToTemplates.
  ///
  /// In en, this message translates to:
  /// **'Route saved to templates'**
  String get routeSavedToTemplates;

  /// No description provided for @routeTooManyStops.
  ///
  /// In en, this message translates to:
  /// **'The route contains too many stops: the maximum is {maximumStops}.'**
  String routeTooManyStops(int maximumStops);

  /// No description provided for @selectDaysOfWeek.
  ///
  /// In en, this message translates to:
  /// **'Select days of the week'**
  String get selectDaysOfWeek;

  /// No description provided for @selectFirstRideDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Select first ride date and departure time'**
  String get selectFirstRideDateAndTime;

  /// No description provided for @selectDateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Select date and departure time'**
  String get selectDateAndTime;

  /// No description provided for @publishRide.
  ///
  /// In en, this message translates to:
  /// **'Publish ride'**
  String get publishRide;

  /// No description provided for @tripPublished.
  ///
  /// In en, this message translates to:
  /// **'Trip published'**
  String get tripPublished;

  /// No description provided for @publicationNonexistentTime.
  ///
  /// In en, this message translates to:
  /// **'On this date the clocks move forward, so the selected time does not exist. Choose another time.'**
  String get publicationNonexistentTime;

  /// No description provided for @publicationDepartureInPast.
  ///
  /// In en, this message translates to:
  /// **'The departure time has already passed. Choose a future date or time.'**
  String get publicationDepartureInPast;

  /// No description provided for @publicationDateNotSelectedWeekday.
  ///
  /// In en, this message translates to:
  /// **'The first departure date must fall on one of the selected weekdays.'**
  String get publicationDateNotSelectedWeekday;

  /// No description provided for @publicationDescriptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'The description must not exceed {maximumLength} characters.'**
  String publicationDescriptionTooLong(int maximumLength);

  /// No description provided for @publicationRefreshRouteRequired.
  ///
  /// In en, this message translates to:
  /// **'Refresh the route before publishing the trip.'**
  String get publicationRefreshRouteRequired;

  /// No description provided for @stops.
  ///
  /// In en, this message translates to:
  /// **'Stops'**
  String get stops;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @deleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Delete template?'**
  String get deleteTemplate;

  /// No description provided for @sureToDeleteTemplate.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this route?\nThis action cannot be undone.'**
  String get sureToDeleteTemplate;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @noSavedTemplates.
  ///
  /// In en, this message translates to:
  /// **'No saved templates'**
  String get noSavedTemplates;

  /// No description provided for @routeWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Routes you save will appear here. Plan a ride and click the bookmark icon to save it for later.'**
  String get routeWillAppear;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @markStops.
  ///
  /// In en, this message translates to:
  /// **'Mark the stops where it will be convenient for you to pick up or drop off passengers.'**
  String get markStops;

  /// No description provided for @waypoints.
  ///
  /// In en, this message translates to:
  /// **'Waypoints'**
  String get waypoints;

  /// No description provided for @waypoint.
  ///
  /// In en, this message translates to:
  /// **'Waypoint'**
  String get waypoint;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @redrawRoute.
  ///
  /// In en, this message translates to:
  /// **'Redraw route'**
  String get redrawRoute;

  /// No description provided for @addWaypoint.
  ///
  /// In en, this message translates to:
  /// **'Add waypoint'**
  String get addWaypoint;

  /// No description provided for @addWaypointsToRedrawAndUpdate.
  ///
  /// In en, this message translates to:
  /// **'Add waypoints to edit the route. To update the route, click \"Redraw route\".'**
  String get addWaypointsToRedrawAndUpdate;

  /// No description provided for @firstWaypointMatchesOrigin.
  ///
  /// In en, this message translates to:
  /// **'The first waypoint cannot be placed at the starting point.'**
  String get firstWaypointMatchesOrigin;

  /// No description provided for @lastWaypointMatchesDestination.
  ///
  /// In en, this message translates to:
  /// **'The last waypoint cannot be placed at the destination.'**
  String get lastWaypointMatchesDestination;

  /// No description provided for @adjacentWaypointsMatch.
  ///
  /// In en, this message translates to:
  /// **'Waypoints {firstWaypointNumber} and {secondWaypointNumber} cannot be placed at the same point.'**
  String adjacentWaypointsMatch(
    Object firstWaypointNumber,
    Object secondWaypointNumber,
  );

  /// No description provided for @deleteWaypoint.
  ///
  /// In en, this message translates to:
  /// **'Delete waypoint {displayIndex}?'**
  String deleteWaypoint(Object displayIndex);

  /// No description provided for @sureToDeleteWaypoint.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove waypoint {displayIndex} from the route?'**
  String sureToDeleteWaypoint(Object displayIndex);

  /// No description provided for @makeSureTheRouteSuitsYou.
  ///
  /// In en, this message translates to:
  /// **'Make sure the route suits you. The route and active stops can be changed.'**
  String get makeSureTheRouteSuitsYou;

  /// No description provided for @serverTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server is not responding. Please check your internet connection.'**
  String get serverTimeout;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'Oops, the internet has gone down. Please check your connection.'**
  String get noInternetConnection;

  /// No description provided for @noStopsFound.
  ///
  /// In en, this message translates to:
  /// **'No stops found'**
  String get noStopsFound;

  /// No description provided for @noStopsDescription.
  ///
  /// In en, this message translates to:
  /// **'There are no public transport stops on this route'**
  String get noStopsDescription;

  /// No description provided for @colorWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colorWhite;

  /// No description provided for @colorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colorBlack;

  /// No description provided for @colorGray.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get colorGray;

  /// No description provided for @colorSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver'**
  String get colorSilver;

  /// No description provided for @colorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// No description provided for @colorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colorBlue;

  /// No description provided for @colorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// No description provided for @colorBrown.
  ///
  /// In en, this message translates to:
  /// **'Brown'**
  String get colorBrown;

  /// No description provided for @colorBeige.
  ///
  /// In en, this message translates to:
  /// **'Beige'**
  String get colorBeige;

  /// No description provided for @colorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get colorYellow;

  /// No description provided for @colorOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// No description provided for @colorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colorPurple;

  /// No description provided for @deleteCar.
  ///
  /// In en, this message translates to:
  /// **'Delete car?'**
  String get deleteCar;

  /// No description provided for @sureToDeleteCar.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {brand} {model}?\nThis action cannot be undone.'**
  String sureToDeleteCar(Object brand, Object model);

  /// No description provided for @scheduleRide.
  ///
  /// In en, this message translates to:
  /// **'Schedule a ride'**
  String get scheduleRide;

  /// No description provided for @chooseCar.
  ///
  /// In en, this message translates to:
  /// **'Choose a car'**
  String get chooseCar;

  /// No description provided for @specifyFixedOrPerKilometerPrice.
  ///
  /// In en, this message translates to:
  /// **'Specify a fixed price or a price per 1 km'**
  String get specifyFixedOrPerKilometerPrice;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @fixedPrice.
  ///
  /// In en, this message translates to:
  /// **'Fixed price'**
  String get fixedPrice;

  /// No description provided for @pricePerKilometer.
  ///
  /// In en, this message translates to:
  /// **'Price per 1 km'**
  String get pricePerKilometer;

  /// No description provided for @allowPriceNegotiation.
  ///
  /// In en, this message translates to:
  /// **'Allow price negotiation'**
  String get allowPriceNegotiation;

  /// No description provided for @priceNegotiationHint.
  ///
  /// In en, this message translates to:
  /// **'Passengers will be able to propose their own price'**
  String get priceNegotiationHint;

  /// No description provided for @describeRideDetails.
  ///
  /// In en, this message translates to:
  /// **'Describe ride details that potential passengers may find useful (optional)'**
  String get describeRideDetails;

  /// No description provided for @rideDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'For example: “Music will be playing during the ride”, “Electronic cigarettes are allowed”'**
  String get rideDescriptionHint;

  /// No description provided for @carWithThisNumber.
  ///
  /// In en, this message translates to:
  /// **'A car with this number has already been added'**
  String get carWithThisNumber;

  /// No description provided for @standardNumberNeedToEnterLatin.
  ///
  /// In en, this message translates to:
  /// **'Standard number needs to be entered in Latin'**
  String get standardNumberNeedToEnterLatin;

  /// No description provided for @incorrectNumberFormat.
  ///
  /// In en, this message translates to:
  /// **'Incorrect number format'**
  String get incorrectNumberFormat;

  /// No description provided for @numberAndSeatClue.
  ///
  /// In en, this message translates to:
  /// **'Only confirmed passengers will see the number.\nSeats — how many passengers you are willing to take.'**
  String get numberAndSeatClue;

  /// No description provided for @addCar.
  ///
  /// In en, this message translates to:
  /// **'Add car'**
  String get addCar;

  /// No description provided for @editCar.
  ///
  /// In en, this message translates to:
  /// **'Edit car'**
  String get editCar;

  /// No description provided for @carEditExistingTripsHint.
  ///
  /// In en, this message translates to:
  /// **'Changes will not affect the car details in trips you have already created.'**
  String get carEditExistingTripsHint;

  /// No description provided for @brand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get brand;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @number.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get number;

  /// No description provided for @seats.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get seats;

  /// No description provided for @bodyColor.
  ///
  /// In en, this message translates to:
  /// **'Body color'**
  String get bodyColor;

  /// No description provided for @anotherCar.
  ///
  /// In en, this message translates to:
  /// **'Another car'**
  String get anotherCar;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get nothingFound;

  /// No description provided for @seatOne.
  ///
  /// In en, this message translates to:
  /// **'seat'**
  String get seatOne;

  /// No description provided for @seatTwo.
  ///
  /// In en, this message translates to:
  /// **'seats'**
  String get seatTwo;

  /// No description provided for @seatFive.
  ///
  /// In en, this message translates to:
  /// **'seats'**
  String get seatFive;

  /// No description provided for @searchPriorities.
  ///
  /// In en, this message translates to:
  /// **'Search priorities'**
  String get searchPriorities;

  /// No description provided for @searchTimePreferencesHint.
  ///
  /// In en, this message translates to:
  /// **'Please set your preferred departure and arrival times. We’ll consider your preferences even if no priority is selected.'**
  String get searchTimePreferencesHint;

  /// No description provided for @chooseMainSearchPriority.
  ///
  /// In en, this message translates to:
  /// **'Choose your main priority'**
  String get chooseMainSearchPriority;

  /// No description provided for @rankSearchPriorities.
  ///
  /// In en, this message translates to:
  /// **'Rank priorities by importance'**
  String get rankSearchPriorities;

  /// No description provided for @noSearchPriority.
  ///
  /// In en, this message translates to:
  /// **'No priority'**
  String get noSearchPriority;

  /// No description provided for @balancedSearchDescription.
  ///
  /// In en, this message translates to:
  /// **'All criteria are equally important'**
  String get balancedSearchDescription;

  /// No description provided for @priorityDeparture.
  ///
  /// In en, this message translates to:
  /// **'Start after'**
  String get priorityDeparture;

  /// No description provided for @priorityArrival.
  ///
  /// In en, this message translates to:
  /// **'Arrive no later than'**
  String get priorityArrival;

  /// No description provided for @priorityWalking.
  ///
  /// In en, this message translates to:
  /// **'Less walking'**
  String get priorityWalking;

  /// No description provided for @priorityPrice.
  ///
  /// In en, this message translates to:
  /// **'Lower cost'**
  String get priorityPrice;

  /// No description provided for @priorityWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Matching weekdays'**
  String get priorityWeekdays;

  /// No description provided for @orderSearchPriorities.
  ///
  /// In en, this message translates to:
  /// **'Set priority order'**
  String get orderSearchPriorities;

  /// No description provided for @resetSearchPriorities.
  ///
  /// In en, this message translates to:
  /// **'Reset priority order'**
  String get resetSearchPriorities;

  /// No description provided for @priorityArrivalDayOffset.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Next day} other{{days} days later}}'**
  String priorityArrivalDayOffset(int days);

  /// No description provided for @movePriorityUp.
  ///
  /// In en, this message translates to:
  /// **'Move priority up'**
  String get movePriorityUp;

  /// No description provided for @movePriorityDown.
  ///
  /// In en, this message translates to:
  /// **'Move priority down'**
  String get movePriorityDown;

  /// No description provided for @routes.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get routes;

  /// No description provided for @tripSearchSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get tripSearchSort;

  /// No description provided for @tripSearchFilter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get tripSearchFilter;

  /// No description provided for @tripSearchTimeFits.
  ///
  /// In en, this message translates to:
  /// **'Departure and arrival fit your requested times'**
  String get tripSearchTimeFits;

  /// No description provided for @tripSearchTimeMismatch.
  ///
  /// In en, this message translates to:
  /// **'Leaves earlier or arrives later than requested'**
  String get tripSearchTimeMismatch;

  /// No description provided for @tripSearchScheduleFits.
  ///
  /// In en, this message translates to:
  /// **'Matches all requested dates'**
  String get tripSearchScheduleFits;

  /// No description provided for @tripSearchScheduleIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Runs on only some of your requested dates'**
  String get tripSearchScheduleIncomplete;

  /// No description provided for @tripSearchScheduleStartsLater.
  ///
  /// In en, this message translates to:
  /// **'First ride starts later than requested'**
  String get tripSearchScheduleStartsLater;

  /// No description provided for @tripSearchIdentityVerificationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Identity verification via Diia is not available yet'**
  String get tripSearchIdentityVerificationUnavailable;

  /// No description provided for @tripSearchNoReviews.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get tripSearchNoReviews;

  /// No description provided for @tripSearchFirstTripOn.
  ///
  /// In en, this message translates to:
  /// **'First ride — {date}'**
  String tripSearchFirstTripOn(String date);

  /// No description provided for @tripSearchAvailableSeats.
  ///
  /// In en, this message translates to:
  /// **'Available passenger seats: {available} of {total}'**
  String tripSearchAvailableSeats(int available, int total);

  /// No description provided for @tripSearchDayOffset.
  ///
  /// In en, this message translates to:
  /// **'+{days}d'**
  String tripSearchDayOffset(int days);

  /// No description provided for @tripSearchByCar.
  ///
  /// In en, this message translates to:
  /// **'By car'**
  String get tripSearchByCar;

  /// No description provided for @tripSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No routes found'**
  String get tripSearchEmpty;

  /// No description provided for @tripSearchEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Try changing the date, time or route in your search.'**
  String get tripSearchEmptyHint;

  /// No description provided for @tripSearchBusy.
  ///
  /// In en, this message translates to:
  /// **'The search service is busy'**
  String get tripSearchBusy;

  /// No description provided for @tripSearchRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests'**
  String get tripSearchRateLimited;

  /// No description provided for @tripSearchLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load more routes'**
  String get tripSearchLoadMoreFailed;

  /// No description provided for @tripSearchRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh search'**
  String get tripSearchRefresh;

  /// No description provided for @tripSearchExpired.
  ///
  /// In en, this message translates to:
  /// **'Search results have expired'**
  String get tripSearchExpired;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'uk'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'uk':
      return AppLocalizationsUk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
