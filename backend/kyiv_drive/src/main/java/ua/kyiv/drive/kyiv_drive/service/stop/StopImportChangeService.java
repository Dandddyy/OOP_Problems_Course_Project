package ua.kyiv.drive.kyiv_drive.service.stop;

import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportChangeDTO;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportChangeSnapshotDTO;
import ua.kyiv.drive.kyiv_drive.dto.stop.StopImportChangesPageDTO;
import ua.kyiv.drive.kyiv_drive.entity.Stop;
import ua.kyiv.drive.kyiv_drive.entity.StopImport;
import ua.kyiv.drive.kyiv_drive.entity.StopImportChange;
import ua.kyiv.drive.kyiv_drive.exception.ResourceNotFoundException;
import ua.kyiv.drive.kyiv_drive.repository.StopImportChangeRepository;
import ua.kyiv.drive.kyiv_drive.repository.StopImportRepository;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class StopImportChangeService {

    private final StopImportChangeRepository stopImportChangeRepository;
    private final StopImportRepository stopImportRepository;

    @Transactional(propagation = Propagation.MANDATORY)
    void recordChanges(
            StopImport stopImport,
            List<StopImportChangeDraft> drafts,
            Map<Long, Stop> affectedStops
    ) {
        if (drafts.isEmpty()) {
            stopImport.setChangesRecorded(true);
            return;
        }

        List<StopImportChange> changes = drafts.stream()
                .map(draft -> toEntity(stopImport.getId(), draft, affectedStops))
                .toList();
        stopImportChangeRepository.saveAll(changes);
        stopImport.setChangesRecorded(true);
    }

    @Transactional(readOnly = true)
    public StopImportChangesPageDTO getChanges(UUID importId, int page, int size) {
        StopImport stopImport = stopImportRepository.findById(importId)
                .orElseThrow(() -> new ResourceNotFoundException("Stop import was not found."));
        PageRequest pageRequest = PageRequest.of(
                page,
                size,
                Sort.by("osmId").ascending()
                        .and(Sort.by("changeType").ascending())
                        .and(Sort.by("id").ascending())
        );
        Page<StopImportChange> result = stopImportChangeRepository.findAllByImportId(importId, pageRequest);

        return new StopImportChangesPageDTO(
                importId,
                stopImport.getCatalogVersion(),
                stopImport.isChangesRecorded(),
                result.getContent().stream().map(this::toDTO).toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements(),
                result.getTotalPages()
        );
    }

    private StopImportChange toEntity(
            UUID importId,
            StopImportChangeDraft draft,
            Map<Long, Stop> affectedStops
    ) {
        UUID stopId = draft.stopId();
        if (stopId == null) {
            Stop stop = affectedStops.get(draft.osmId());
            if (stop == null || stop.getId() == null) {
                throw new IllegalStateException("Cannot resolve imported stop for change journal.");
            }
            stopId = stop.getId();
        }

        StopImportChange change = new StopImportChange();
        change.setImportId(importId);
        change.setStopId(stopId);
        change.setOsmId(draft.osmId());
        change.setChangeType(draft.changeType());
        copyBefore(draft.before(), change);
        copyAfter(draft.after(), change);
        return change;
    }

    private void copyBefore(StopImportChangeSnapshot snapshot, StopImportChange change) {
        if (snapshot == null) {
            return;
        }
        change.setOldName(snapshot.name());
        change.setOldLat(snapshot.lat());
        change.setOldLon(snapshot.lon());
        change.setOldActive(snapshot.active());
    }

    private void copyAfter(StopImportChangeSnapshot snapshot, StopImportChange change) {
        if (snapshot == null) {
            return;
        }
        change.setNewName(snapshot.name());
        change.setNewLat(snapshot.lat());
        change.setNewLon(snapshot.lon());
        change.setNewActive(snapshot.active());
    }

    private StopImportChangeDTO toDTO(StopImportChange change) {
        return new StopImportChangeDTO(
                change.getId(),
                change.getStopId(),
                change.getOsmId(),
                change.getChangeType(),
                snapshot(change.getOldName(), change.getOldLat(), change.getOldLon(), change.getOldActive()),
                snapshot(change.getNewName(), change.getNewLat(), change.getNewLon(), change.getNewActive()),
                change.getCreatedAt()
        );
    }

    private StopImportChangeSnapshotDTO snapshot(String name, Double lat, Double lon, Boolean active) {
        if (name == null && lat == null && lon == null && active == null) {
            return null;
        }
        return new StopImportChangeSnapshotDTO(name, lat, lon, active);
    }
}
