package ua.kyiv.drive.kyiv_drive.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import ua.kyiv.drive.kyiv_drive.entity.CarModel;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CarModelRepository extends JpaRepository<CarModel, UUID> {
    List<CarModel> findByBrandIdAndIsVerifiedTrueOrderByNameAsc(UUID brandId);
    Optional<CarModel> findByBrandIdAndNameIgnoreCase(UUID brandId, String name);
}
