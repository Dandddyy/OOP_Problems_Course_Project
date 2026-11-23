package ua.kyiv.drive.kyiv_drive.repository;

import java.util.UUID;

public interface StopFractionProjection {
    UUID getId();
    String getName();
    Double getLat();
    Double getLon();
    Double getRouteFraction();
}