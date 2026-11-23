package ua.kyiv.drive.kyiv_drive.validation;

public final class StopImportPolicy {
    public static final int MAX_HISTORY_LIMIT = 100;
    public static final int MAX_CHANGE_PAGE_SIZE = 200;

    private StopImportPolicy() {
        throw new IllegalStateException("Utility class");
    }
}
