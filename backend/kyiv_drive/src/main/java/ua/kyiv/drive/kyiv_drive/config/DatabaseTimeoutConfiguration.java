package ua.kyiv.drive.kyiv_drive.config;

import jakarta.persistence.EntityManager;
import jakarta.persistence.EntityManagerFactory;
import org.hibernate.Session;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.boot.transaction.autoconfigure.TransactionManagerCustomizers;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.vendor.HibernateJpaDialect;
import org.springframework.transaction.TransactionDefinition;

import java.sql.SQLException;

@Configuration(proxyBeanMethods = false)
public class DatabaseTimeoutConfiguration {
    @Bean
    JpaTransactionManager transactionManager(EntityManagerFactory entityManagerFactory,
                                             ObjectProvider<TransactionManagerCustomizers> customizers) {
        var manager = new DeadlineTransactionManager();
        manager.setEntityManagerFactory(entityManagerFactory);
        customizers.ifAvailable(value -> value.customize(manager));
        return manager;
    }

    private static class DeadlineTransactionManager extends JpaTransactionManager {
        @Override
        public void afterPropertiesSet() {
            super.afterPropertiesSet();
            // The entity manager factory supplies its default dialect during initialization.
            setJpaDialect(new DeadlineDialect());
        }

        @Override
        protected int determineTimeout(TransactionDefinition definition) {
            int configured = super.determineTimeout(definition);
            var deadline = OperationDeadline.current();
            if (deadline == null) return configured;
            // Hibernate and JDBC transaction timeouts use whole seconds.
            long seconds = (deadline.remainingNanos() + 999_999_999L) / 1_000_000_000L;
            int remaining = (int) Math.min(Integer.MAX_VALUE, seconds);
            return configured == TransactionDefinition.TIMEOUT_DEFAULT ? remaining : Math.min(remaining, configured);
        }
    }

    private static class DeadlineDialect extends HibernateJpaDialect {
        @Override
        public Object beginTransaction(EntityManager entityManager, TransactionDefinition definition) throws SQLException {
            Object transaction = super.beginTransaction(entityManager, definition);
            var deadline = OperationDeadline.current();
            if (deadline == null) return transaction;

            entityManager.unwrap(Session.class).doWork(connection -> {
                long limitMs = OperationDeadline.cap(deadline.sqlLimit()).toMillis();
                if (definition.getTimeout() > 0) limitMs = Math.min(limitMs, definition.getTimeout() * 1000L);
                try (var statement = connection.prepareStatement("SELECT set_config('statement_timeout', ?, true)")) {
                    statement.setString(1, Long.toString(limitMs));
                    statement.execute();
                }
            });
            return transaction;
        }
    }
}
