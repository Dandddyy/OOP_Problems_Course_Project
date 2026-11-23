package ua.kyiv.drive.kyiv_drive.repository;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import ua.kyiv.drive.kyiv_drive.entity.StopImportChange;

import java.util.UUID;

public interface StopImportChangeRepository extends JpaRepository<StopImportChange, UUID> {

    Page<StopImportChange> findAllByImportId(UUID importId, Pageable pageable);
}
