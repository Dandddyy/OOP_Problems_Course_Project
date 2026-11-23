package ua.kyiv.drive.kyiv_drive.service.execution;

import java.util.function.Supplier;

/** Keeps cache lookup and validation separate from admission to a bounded worker pool. */
public record OperationPlan<T>(OperationProfile profile, Supplier<T> action) {
    public static <T> OperationPlan<T> cached(Supplier<T> action) {
        return new OperationPlan<>(OperationProfile.STANDARD, action);
    }
}
