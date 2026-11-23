package ua.kyiv.drive.kyiv_drive.repository;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import ua.kyiv.drive.kyiv_drive.entity.Car;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CarRepository extends JpaRepository<Car, UUID> {
    @Query("SELECT c FROM Car c JOIN FETCH c.model m JOIN FETCH m.brand WHERE c.ownerId = :ownerId AND c.isDeleted = false")
    List<Car> findActiveCarsByOwnerIdWithDetails(UUID ownerId);

    Optional<Car> findByOwnerIdAndPlateNumberAndIsDeletedFalse(UUID ownerId, String plateNumber);

    long countByOwnerIdAndIsDeletedFalse(UUID ownerId);

    Optional<Car> findByIdAndOwnerIdAndIsDeletedFalse(UUID id, UUID ownerId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT c FROM Car c WHERE c.id = :id")
    Optional<Car> findByIdForUpdate(@Param("id") UUID id);
}
