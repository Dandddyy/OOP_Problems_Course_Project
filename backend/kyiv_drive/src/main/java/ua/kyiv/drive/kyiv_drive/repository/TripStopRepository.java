package ua.kyiv.drive.kyiv_drive.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import ua.kyiv.drive.kyiv_drive.entity.TripStop;

import java.util.UUID;

@Repository
public interface TripStopRepository extends JpaRepository<TripStop, UUID> {
}
