package ua.kyiv.drive.kyiv_drive.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import ua.kyiv.drive.kyiv_drive.entity.CarBrand;

import java.util.List;
import java.util.UUID;

@Repository
public interface CarBrandRepository extends JpaRepository<CarBrand, UUID> {
    List<CarBrand> findAllByOrderByNameAsc();
}
