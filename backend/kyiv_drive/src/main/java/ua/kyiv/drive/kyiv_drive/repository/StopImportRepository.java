package ua.kyiv.drive.kyiv_drive.repository;

import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import ua.kyiv.drive.kyiv_drive.entity.StopImport;
import ua.kyiv.drive.kyiv_drive.entity.StopImportStatus;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface StopImportRepository extends JpaRepository<StopImport, UUID> {

    List<StopImport> findAllByOrderByPreviewedAtDesc(Pageable pageable);

    Optional<StopImport> findFirstByStatusAndCatalogVersionIsNotNullOrderByCatalogVersionDesc(
            StopImportStatus status
    );

    @Query(value = "SELECT nextval('stop_catalog_version_seq')", nativeQuery = true)
    long nextCatalogVersion();

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT i FROM StopImport i WHERE i.id = :id")
    Optional<StopImport> findByIdForUpdate(@Param("id") UUID id);
}
