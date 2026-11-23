package ua.kyiv.drive.kyiv_drive.service.execution;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Tags;
import io.micrometer.core.instrument.binder.jvm.ExecutorServiceMetrics;
import jakarta.annotation.PreDestroy;
import org.slf4j.MDC;
import org.springframework.context.i18n.LocaleContext;
import org.springframework.context.i18n.LocaleContextHolder;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.async.DeferredResult;
import ua.kyiv.drive.kyiv_drive.config.ExecutionProperties;
import ua.kyiv.drive.kyiv_drive.config.OperationDeadline;
import ua.kyiv.drive.kyiv_drive.config.TimeoutProperties;
import ua.kyiv.drive.kyiv_drive.exception.OperationBusyException;
import ua.kyiv.drive.kyiv_drive.exception.OperationTimeoutException;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.ScheduledThreadPoolExecutor;
import java.util.concurrent.SynchronousQueue;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;

@Component
public class OperationExecutor implements AutoCloseable {
    private final Map<String, ThreadPoolExecutor> pools = new LinkedHashMap<>();
    private final Map<String, ExecutionProperties.PoolLimits> poolLimits;
    private final TimeoutProperties timeouts;
    private final MeterRegistry meters;
    private final Set<Task<?>> tasks = ConcurrentHashMap.newKeySet();
    private volatile boolean closed;
    private final ScheduledThreadPoolExecutor deadlines = new ScheduledThreadPoolExecutor(1,
            Thread.ofPlatform().daemon().name("operation-deadlines").factory());

    public OperationExecutor(ExecutionProperties properties, TimeoutProperties timeouts, MeterRegistry meters) {
        this.poolLimits = properties.resolvedPools();
        this.timeouts = timeouts;
        this.meters = meters;
        deadlines.setRemoveOnCancelPolicy(true);
        poolLimits.forEach((name, limits) -> {
            BlockingQueue<Runnable> queue = limits.queueCapacity() == 0 || limits.queueWait().isZero()
                    ? new SynchronousQueue<>(true) : new ArrayBlockingQueue<>(limits.queueCapacity(), true);
            int workers = limits.workers();
            var pool = new ThreadPoolExecutor(workers, workers, 30, TimeUnit.SECONDS, queue,
                    Thread.ofPlatform().daemon().name("operation-" + name + "-", 0).factory(),
                    new ThreadPoolExecutor.AbortPolicy());
            new ExecutorServiceMetrics(pool, name, Tags.empty()).bindTo(meters);
            pools.put(name, pool);
        });
    }

    public <T> DeferredResult<T> execute(OperationPlan<T> plan) {
        if (closed) throw new OperationBusyException();
        var profile = plan.profile();
        var current = OperationDeadline.current();
        var deadline = current == null
                ? OperationDeadline.start(profile.budget(timeouts), profile.sqlLimit(timeouts))
                : current.restrict(profile.budget(timeouts), profile.sqlLimit(timeouts));
        var result = new DeferredResult<T>(Math.max(1, TimeUnit.NANOSECONDS.toMillis(deadline.remainingNanos())));
        if (profile.pool() == null) {
            try (var ignored = OperationDeadline.install(deadline)) {
                T value = plan.action().get();
                OperationDeadline.check();
                result.setResult(value);
            }
            return result;
        }
        var pool = pools.get(profile.pool());
        if (pool == null) throw new IllegalStateException("Missing execution pool " + profile.pool());
        var task = new Task<>(plan, deadline, result, pool);
        result.onTimeout(() -> task.abort(new OperationTimeoutException(), "execution_timeout"));
        result.onError(error -> task.abort(error, "client_error"));
        result.onCompletion(() -> task.abort(new OperationTimeoutException(), "request_completed"));
        task.submit();
        return result;
    }

    private final class Task<T> implements Runnable {
        private final OperationPlan<T> plan;
        private final OperationDeadline deadline;
        private final DeferredResult<T> result;
        private final ThreadPoolExecutor pool;
        private final long submittedAt = System.nanoTime();
        private final LocaleContext locale = LocaleContextHolder.getLocaleContext();
        private final Map<String, String> logging = MDC.getCopyOfContextMap();
        private final SecurityContext security = SecurityContextHolder.createEmptyContext();
        private ScheduledFuture<?> queueTimeout;
        private ScheduledFuture<?> operationTimeout;
        private Thread runner;
        private boolean terminal;
        private boolean started;

        private Task(OperationPlan<T> plan, OperationDeadline deadline, DeferredResult<T> result, ThreadPoolExecutor pool) {
            this.plan = plan;
            this.deadline = deadline;
            this.result = result;
            this.pool = pool;
            security.setAuthentication(SecurityContextHolder.getContext().getAuthentication());
        }

        private synchronized void submit() {
            tasks.add(this);
            if (closed) {
                abort(new OperationBusyException(), "shutdown");
                return;
            }
            try {
                operationTimeout = deadlines.schedule(
                        () -> abort(new OperationTimeoutException(), "execution_timeout"),
                        deadline.remainingNanos(), TimeUnit.NANOSECONDS);
                var limits = poolLimits.get(plan.profile().pool());
                if (limits.queueCapacity() > 0 && !limits.queueWait().isZero()) {
                    queueTimeout = deadlines.schedule(this::queueExpired, limits.queueWait().toNanos(), TimeUnit.NANOSECONDS);
                }
                pool.execute(this);
            } catch (RejectedExecutionException failure) {
                abort(new OperationBusyException(), pool.isShutdown() || deadlines.isShutdown() ? "shutdown" : "queue_full");
            } catch (OperationTimeoutException failure) {
                abort(failure, "execution_timeout");
            }
        }

        private synchronized void queueExpired() {
            if (!started) abort(new OperationBusyException(), "queue_timeout");
        }

        @Override
        public void run() {
            synchronized (this) {
                if (terminal) return;
                started = true;
                runner = Thread.currentThread();
                if (queueTimeout != null) queueTimeout.cancel(false);
                recordQueue("started");
            }
            var previousLocale = LocaleContextHolder.getLocaleContext();
            var previousSecurity = SecurityContextHolder.getContext();
            var previousLogging = MDC.getCopyOfContextMap();
            try (var ignored = OperationDeadline.install(deadline)) {
                LocaleContextHolder.setLocaleContext(locale);
                SecurityContextHolder.setContext(security);
                setLogging(logging);
                OperationDeadline.check();
                T value = plan.action().get();
                OperationDeadline.check();
                complete(value, null);
            } catch (Throwable failure) {
                complete(null, failure);
                if (failure instanceof Error error) throw error;
            } finally {
                LocaleContextHolder.setLocaleContext(previousLocale);
                SecurityContextHolder.setContext(previousSecurity);
                setLogging(previousLogging);
                synchronized (this) { runner = null; }
            }
        }

        private synchronized void complete(T value, Throwable failure) {
            if (terminal) return;
            try {
                deadline.remainingNanos();
            } catch (OperationTimeoutException timeout) {
                abort(timeout, "execution_timeout");
                return;
            }
            terminal = true;
            cancelTimers();
            if (failure == null) result.setResult(value);
            else result.setErrorResult(failure);
        }

        private synchronized void abort(Throwable failure, String reason) {
            if (terminal) return;
            terminal = true;
            deadline.cancel();
            if (runner != null) runner.interrupt();
            else {
                pool.remove(this);
                recordQueue(reason);
            }
            meters.counter("kyivdrive.executor.rejections", "name", plan.profile().pool(), "reason", reason).increment();
            cancelTimers();
            result.setErrorResult(failure);
        }

        private void recordQueue(String outcome) {
            meters.timer("kyivdrive.executor.queue.wait", "name", plan.profile().pool(), "outcome", outcome)
                    .record(System.nanoTime() - submittedAt, TimeUnit.NANOSECONDS);
        }

        private void cancelTimers() {
            if (queueTimeout != null) queueTimeout.cancel(false);
            if (operationTimeout != null) operationTimeout.cancel(false);
            tasks.remove(this);
        }
    }

    private static void setLogging(Map<String, String> context) {
        if (context == null) MDC.clear();
        else MDC.setContextMap(context);
    }

    @PreDestroy
    @Override
    public void close() {
        closed = true;
        pools.values().forEach(ThreadPoolExecutor::shutdownNow);
        tasks.forEach(task -> task.abort(new OperationBusyException(), "shutdown"));
        deadlines.shutdownNow();
    }
}
