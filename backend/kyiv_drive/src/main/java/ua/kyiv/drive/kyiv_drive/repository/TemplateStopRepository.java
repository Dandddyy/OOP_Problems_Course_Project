package ua.kyiv.drive.kyiv_drive.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import ua.kyiv.drive.kyiv_drive.entity.TemplateStop;

import java.util.UUID;

@Repository
public interface TemplateStopRepository extends JpaRepository<TemplateStop, UUID> {
}
