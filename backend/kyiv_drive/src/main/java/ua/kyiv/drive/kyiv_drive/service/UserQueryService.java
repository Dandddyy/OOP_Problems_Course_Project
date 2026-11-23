package ua.kyiv.drive.kyiv_drive.service;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import ua.kyiv.drive.kyiv_drive.dto.user.CurrentUserResponseDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.SessionContextDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.UserDTO;
import ua.kyiv.drive.kyiv_drive.dto.user.UserRatingResponseDTO;
import ua.kyiv.drive.kyiv_drive.entity.User;
import ua.kyiv.drive.kyiv_drive.entity.UserSession;
import ua.kyiv.drive.kyiv_drive.exception.SessionNotActiveException;
import ua.kyiv.drive.kyiv_drive.mapper.CurrentUserMapper;
import ua.kyiv.drive.kyiv_drive.mapper.UserMapper;
import ua.kyiv.drive.kyiv_drive.repository.UserRepository;
import ua.kyiv.drive.kyiv_drive.repository.UserSessionRepository;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UserQueryService {

    private final UserRepository userRepository;
    private final UserSessionRepository sessionRepository;
    private final UserMapper mapper;
    private final CurrentUserMapper currentUserMapper;
    private final Clock clock;

    public UserRatingResponseDTO getUserRating(UUID userId) {
        User user = getUser(userId);
        return new UserRatingResponseDTO(
                user.getName(),
                user.getAvatarUrl(),
                user.getRating(),
                user.getRatingCount()
        );
    }

    public CurrentUserResponseDTO getCurrentUser(UUID userId, UUID sessionId) {
        if (sessionId == null) {
            throw new SessionNotActiveException();
        }

        UserSession session = sessionRepository.findByIdAndUser_Id(sessionId, userId)
                .filter(candidate -> !candidate.isExpiredAt(clock.instant()))
                .filter(candidate -> candidate.getUser().getIsActive())
                .orElseThrow(SessionNotActiveException::new);
        return new CurrentUserResponseDTO(
                new SessionContextDTO(session.getId(), session.getCurrentMode()),
                currentUserMapper.toDTO(session.getUser())
        );
    }

    public List<UserDTO> getInactiveUsers() {
        return userRepository.findByRecentActivityBefore(LocalDate.now().minusYears(5)).stream()
                .map(mapper::toDTO)
                .toList();
    }

    private User getUser(UUID userId) {
        return userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));
    }
}
