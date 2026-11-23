package ua.kyiv.drive.kyiv_drive.validation;

import java.text.Normalizer;

public final class InputValidation {

    public static final int MAX_ADDRESS_PART_LENGTH = 100;
    public static final int MAX_CAR_CATALOG_NAME_LENGTH = 50;

    public static final String ADDRESS_SEARCH_TEXT = "^[^\\p{C}]+$";
    public static final String ADDRESS_SEARCH_MINIMUM =
            "^(?=(?:.*[\\p{L}\\p{N}]){4}).+$";
    public static final String ADDRESS_PART = "^[^\\p{C}|]+$";
    public static final String OPTIONAL_ADDRESS_PART = "^[^\\p{C}|]*$";

    public static final String PERSON_NAME =
            "^[\\p{L}\\p{M}]+(?:[ '’‘ʼ＇‐‑‒–—―-][\\p{L}\\p{M}]+)*$";

    public static final String EMAIL =
            "^(?=.{1,64}@)[A-Za-z0-9_%+-]+(?:\\.[A-Za-z0-9_%+-]+)*@" +
            "(?=.{1,253}$)(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+" +
            "(?:[A-Za-z]{2,63}|xn--[A-Za-z0-9-]{2,59})$";

    public static final String PASSWORD =
            "^(?=.*\\p{Lu})(?=.*\\p{Ll})(?=.*\\p{Nd})(?:[\\u200C\\u200D]|[^\\p{C}]){6,100}$";

    public static final String CAR_MODEL_NAME =
            "^[\\p{L}\\p{M}\\p{N}.:/+#!&(),'’‘ʼ＇ ‐‑‒–—―-]+$";

    // MVS Order No. 166, section III and annex 5 (revision of 16 December 2025).
    // https://zakon.rada.gov.ua/laws/show/z0353-21
    // Keep in sync with Flutter InputValidation, including its input mask.
    private static final String CAR_PLATE_PREFIX = "(?:[ABCEHIKMOPTX]{2}|DI|PD|ED|DC)";
    private static final String CAR_PLATE_SERIES =
            "(?:[ABCEHIKMOPTXYZ]{2}|[YZ][A-PR-VX-Z]|U[A-PR-UXY]|Q[A-UXY]"
            + "|A[DFGJLNRSUVYZ]|B[DFGJLNQR]|T[DFGJLNRSUVYZ])";
    public static final String CAR_PLATE_NUMBER =
            "^(?:" + CAR_PLATE_PREFIX + "[0-9]{4}" + CAR_PLATE_SERIES
            + "|(?![A-ZА-ЯІЇЄҐ]{2}[0-9]{4}[A-ZА-ЯІЇЄҐ]{2})"
            + "(?=(?:.*[A-ZА-ЯІЇЄҐ]){2})[A-ZА-ЯІЇЄҐ0-9]{3,8})$";

    private InputValidation() {
        throw new IllegalStateException("Utility class");
    }

    public static String normalizeAddressSearchText(String value) {
        return normalizeAddressText(value, false, Integer.MAX_VALUE);
    }

    public static String normalizeAddressPart(String value) {
        return normalizeAddressText(value, true, MAX_ADDRESS_PART_LENGTH);
    }

    private static String normalizeAddressText(String value, boolean replaceStorageDelimiter, int maxLength) {
        if (value == null) {
            return null;
        }

        String normalized = Normalizer.normalize(value, Normalizer.Form.NFC);
        StringBuilder result = new StringBuilder(normalized.length());
        boolean previousWasSpace = false;

        for (int index = 0; index < normalized.length(); ) {
            int codePoint = normalized.codePointAt(index);
            index += Character.charCount(codePoint);

            if (Character.isWhitespace(codePoint) || Character.isSpaceChar(codePoint)) {
                if (!previousWasSpace && !result.isEmpty()) {
                    result.append(' ');
                    previousWasSpace = true;
                }
                continue;
            }

            if (replaceStorageDelimiter && codePoint == '|') {
                result.append('/');
                previousWasSpace = false;
                continue;
            }

            if (isUnsupportedControlCodePoint(codePoint)) {
                continue;
            }

            result.appendCodePoint(codePoint);
            previousWasSpace = false;
        }

        String cleaned = result.toString().strip();
        if (cleaned.isEmpty()) {
            return null;
        }

        if (cleaned.length() <= maxLength) {
            return cleaned;
        }

        int endIndex = maxLength;
        if (Character.isHighSurrogate(cleaned.charAt(endIndex - 1))) {
            endIndex--;
        }
        return cleaned.substring(0, endIndex).stripTrailing();
    }

    private static boolean isUnsupportedControlCodePoint(int codePoint) {
        int type = Character.getType(codePoint);
        return type == Character.CONTROL
                || type == Character.FORMAT
                || type == Character.PRIVATE_USE
                || type == Character.SURROGATE
                || type == Character.UNASSIGNED;
    }
}
