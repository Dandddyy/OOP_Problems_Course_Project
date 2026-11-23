package ua.kyiv.drive.kyiv_drive.repository;

import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.Lock;
import ua.kyiv.drive.kyiv_drive.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {
    @Query("SELECT u FROM User u WHERE u.lastActivity < :date AND u.isActive = true")
    List<User> findByRecentActivityBefore(LocalDate date);

    User findByEmail(String email);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT u FROM User u WHERE u.id = :id")
    java.util.Optional<User> findByIdForUpdate(@Param("id") UUID id);
}
