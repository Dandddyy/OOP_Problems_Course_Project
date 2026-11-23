package ua.kyiv.drive.kyiv_drive.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;
import ua.kyiv.drive.kyiv_drive.entity.Template;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TemplateRepository extends JpaRepository<Template, UUID> {
    @Query("SELECT DISTINCT t FROM Template t " +
            "LEFT JOIN FETCH t.templateStops ts " +
            "LEFT JOIN FETCH ts.stop " +
            "WHERE t.userId = :userId AND t.isDriver = :isDriver " +
            "ORDER BY t.createdAt DESC")
    List<Template> findAllByUserIdAndIsDriverWithStops(UUID userId, Boolean isDriver);

    @Query("SELECT DISTINCT t FROM Template t " +
            "LEFT JOIN FETCH t.templateStops ts " +
            "LEFT JOIN FETCH ts.stop " +
            "WHERE t.userId = :userId AND t.requestId = :requestId")
    Optional<Template> findByUserIdAndRequestIdWithStops(UUID userId, UUID requestId);

    long countByUserId(UUID userId);
}
