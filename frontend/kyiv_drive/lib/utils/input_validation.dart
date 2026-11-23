abstract final class InputValidation {
  static const int minimumAddressSearchCharacters = 4;
  static const int maximumCarCatalogNameLength = 50;

  static final RegExp _addressSearchCharacter = RegExp(
    r'[\p{L}\p{N}]',
    unicode: true,
  );

  static final RegExp personName = RegExp(
    r"^[\p{L}\p{M}]+(?:[ '’‘ʼ＇‐‑‒–—―-][\p{L}\p{M}]+)*$",
    unicode: true,
  );

  static final RegExp personNameCharacter = RegExp(
    r"[\p{L}\p{M} '’‘ʼ＇‐‑‒–—―-]",
    unicode: true,
  );

  static final RegExp leadingOrRepeatedPersonNameSeparator = RegExp(
    r"^[ '’‘ʼ＇‐‑‒–—―-]+|(?<=[ '’‘ʼ＇‐‑‒–—―-])[ '’‘ʼ＇‐‑‒–—―-]",
    unicode: true,
  );

  static final RegExp email = RegExp(
    r'^(?=.{1,64}@)[A-Za-z0-9_%+-]+(?:\.[A-Za-z0-9_%+-]+)*@'
    r'(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+'
    r'(?:[A-Za-z]{2,63}|xn--[A-Za-z0-9-]{2,59})$',
    caseSensitive: false,
  );

  static final RegExp emailCharacter = RegExp(r'[A-Za-z0-9@._%+-]');

  static final RegExp password = RegExp(
    r'^(?=.*\p{Lu})(?=.*\p{Ll})(?=.*\p{Nd})(?:[\u200C\u200D]|[^\p{C}]){6,100}$',
    unicode: true,
  );

  static final RegExp disallowedPasswordCharacters = RegExp(
    r'(?![\u200C\u200D])\p{C}',
    unicode: true,
  );

  static final RegExp disallowedAddressCharacters = RegExp(
    r'\p{C}',
    unicode: true,
  );

  static final RegExp carModelCharacter = RegExp(
    r"[\p{L}\p{M}\p{N}.:/+#!&(),'’‘ʼ＇ ‐‑‒–—―-]",
    unicode: true,
  );

  static final RegExp carModel = RegExp(
    r"^[\p{L}\p{M}\p{N}.:/+#!&(),'’‘ʼ＇ ‐‑‒–—―-]+$",
    unicode: true,
  );

  // MVS Order No. 166, section III and annex 5 (16 December 2025).
  // https://zakon.rada.gov.ua/laws/show/z0353-21
  // Keep in sync with backend InputValidation.CAR_PLATE_NUMBER.
  static const String _carPlatePrefix = r'(?:[ABCEHIKMOPTX]{2}|DI|PD|ED|DC)';
  static const String _carPlateSeries =
      r'(?:[ABCEHIKMOPTXYZ]{2}|[YZ][A-PR-VX-Z]|U[A-PR-UXY]|Q[A-UXY]'
      r'|A[DFGJLNRSUVYZ]|B[DFGJLNQR]|T[DFGJLNRSUVYZ])';

  static final RegExp standardCarPlate = RegExp(
    '^$_carPlatePrefix[0-9]{4}$_carPlateSeries\$',
  );

  // Format incomplete plates too, using the same prefixes and series.
  static final RegExp standardCarPlateProgress = RegExp(
    '^$_carPlatePrefix[0-9]{0,4}(?:$_carPlateSeries|[ABCEHIKMOPTXYZUQ])?\$',
  );

  static String filterPersonNameInput(String value) {
    final allowedCharacters = personNameCharacter
        .allMatches(value)
        .map((match) => match.group(0)!)
        .join();
    return allowedCharacters.replaceAll(
      leadingOrRepeatedPersonNameSeparator,
      '',
    );
  }

  static int countAddressSearchCharacters(String value) {
    return _addressSearchCharacter.allMatches(value).length;
  }
}
