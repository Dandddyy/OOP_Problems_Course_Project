package ua.kyiv.drive.kyiv_drive.config;

import ua.kyiv.drive.kyiv_drive.exception.OperationTimeoutException;

import java.time.Duration;
import java.util.concurrent.atomic.AtomicBoolean;

/** Carries a monotonic request budget. Async workers can install the same deadline. */
public final class OperationDeadline {
    private static final ThreadLocal<OperationDeadline> CURRENT = new ThreadLocal<>();
    private final long startedAtNanos;
    private final long expiresAtNanos;
    private final Duration sqlLimit;
    private final AtomicBoolean cancelled;

    public OperationDeadline(long expiresAtNanos, Duration sqlLimit) {
        this(System.nanoTime(), expiresAtNanos, sqlLimit, new AtomicBoolean());
    }

    private OperationDeadline(long startedAtNanos, long expiresAtNanos, Duration sqlLimit, AtomicBoolean cancelled) {
        this.startedAtNanos = startedAtNanos;
        this.expiresAtNanos = expiresAtNanos;
        this.sqlLimit = sqlLimit;
        this.cancelled = cancelled;
    }

    public static OperationDeadline start(Duration budget, Duration sqlLimit) {
        long now = System.nanoTime();
        return new OperationDeadline(now, now + budget.toNanos(), sqlLimit, new AtomicBoolean());
    }

    public OperationDeadline restrict(Duration budget, Duration sqlLimit) {
        return new OperationDeadline(startedAtNanos, Math.min(expiresAtNanos, startedAtNanos + budget.toNanos()),
                sqlLimit.compareTo(this.sqlLimit) < 0 ? sqlLimit : this.sqlLimit, cancelled);
    }

    public long expiresAtNanos() { return expiresAtNanos; }
    public Duration sqlLimit() { return sqlLimit; }
    public void cancel() { cancelled.set(true); }

    public static void check() {
        var deadline = current();
        if (deadline != null) deadline.remainingNanos();
    }

    public static OperationDeadline current() {
        return CURRENT.get();
    }

    public static Scope install(OperationDeadline deadline) {
        OperationDeadline previous = current();
        CURRENT.set(deadline);
        return () -> {
            if (previous == null) CURRENT.remove();
            else CURRENT.set(previous);
        };
    }

    public static Duration cap(Duration maximum) {
        var deadline = current();
        if (deadline == null) return maximum;
        long remaining = deadline.remainingNanos();
        return Duration.ofNanos(Math.min(remaining, maximum.toNanos()));
    }

    public long remainingNanos() {
        long remaining = expiresAtNanos - System.nanoTime();
        if (cancelled.get() || Thread.currentThread().isInterrupted() || remaining < 1_000_000) {
            throw new OperationTimeoutException();
        }
        return remaining;
    }

    public interface Scope extends AutoCloseable {
        @Override
        void close();
    }
}
