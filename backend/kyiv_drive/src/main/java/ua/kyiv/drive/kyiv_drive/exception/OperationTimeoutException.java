package ua.kyiv.drive.kyiv_drive.exception;

import org.springframework.dao.QueryTimeoutException;
import org.springframework.transaction.TransactionTimedOutException;

import java.net.SocketTimeoutException;
import java.net.http.HttpTimeoutException;
import java.sql.SQLException;
import java.sql.SQLTimeoutException;
import java.sql.SQLTransientConnectionException;

public class OperationTimeoutException extends RuntimeException {
    public OperationTimeoutException() {
        this(null);
    }

    public OperationTimeoutException(Throwable cause) {
        super("Operation deadline exceeded", cause);
    }

    public static void rethrowIfTimeout(Throwable error) {
        if (error instanceof OperationTimeoutException timeout) throw timeout;
        if (causedByTimeout(error)) throw new OperationTimeoutException(error);
    }

    public static boolean causedByTimeout(Throwable error) {
        for (Throwable cause = error; cause != null; cause = cause.getCause()) {
            if (cause instanceof OperationTimeoutException || cause instanceof SocketTimeoutException
                    || cause instanceof HttpTimeoutException || cause instanceof QueryTimeoutException
                    || cause instanceof TransactionTimedOutException || cause instanceof SQLTimeoutException
                    || cause instanceof SQLTransientConnectionException
                    || cause instanceof SQLException sql && "57014".equals(sql.getSQLState())) {
                return true;
            }
        }
        return false;
    }
}
