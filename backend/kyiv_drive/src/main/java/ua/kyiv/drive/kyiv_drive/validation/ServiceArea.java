package ua.kyiv.drive.kyiv_drive.validation;

public final class ServiceArea {

    public static final double MIN_LATITUDE = 50.08;
    public static final double MAX_LATITUDE = 50.75;
    public static final double MIN_LONGITUDE = 30.08;
    public static final double MAX_LONGITUDE = 31.02;

    public static final String MIN_LATITUDE_TEXT = "50.08";
    public static final String MAX_LATITUDE_TEXT = "50.75";
    public static final String MIN_LONGITUDE_TEXT = "30.08";
    public static final String MAX_LONGITUDE_TEXT = "31.02";

    private ServiceArea() {
        throw new IllegalStateException("Utility class");
    }

    public static boolean contains(Double latitude, Double longitude) {
        return latitude != null
                && longitude != null
                && Double.isFinite(latitude)
                && Double.isFinite(longitude)
                && latitude >= MIN_LATITUDE
                && latitude <= MAX_LATITUDE
                && longitude >= MIN_LONGITUDE
                && longitude <= MAX_LONGITUDE;
    }
}
