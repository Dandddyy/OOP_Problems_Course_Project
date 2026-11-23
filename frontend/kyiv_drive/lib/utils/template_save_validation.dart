import '../core/constants/route_policy.dart';
import '../l10n/app_localizations.dart';

String? validateTemplateSave({
  required int stopCount,
  required AppLocalizations localizations,
}) {
  if (stopCount > RoutePolicy.maximumStops) {
    return localizations.routeTooManyStops(RoutePolicy.maximumStops);
  }
  return null;
}
