/**
 * Logging utilities for Lambda functions
 */

export enum LogLevel {
  DEBUG = 'DEBUG',
  INFO = 'INFO',
  WARN = 'WARN',
  ERROR = 'ERROR'
}

export interface LogContext {
  requestId?: string;
  functionName?: string;
  userId?: string;
  itemId?: string;
  [key: string]: any;
}

export class Logger {
  private context: LogContext;
  private logLevel: LogLevel;

  constructor(context: LogContext = {}, logLevel: LogLevel = LogLevel.INFO) {
    this.context = context;
    this.logLevel = logLevel;
  }

  private shouldLog(level: LogLevel): boolean {
    const levels = [LogLevel.DEBUG, LogLevel.INFO, LogLevel.WARN, LogLevel.ERROR];
    return levels.indexOf(level) >= levels.indexOf(this.logLevel);
  }

  private formatMessage(level: LogLevel, message: string, meta?: any): string {
    const timestamp = new Date().toISOString();
    const logEntry = {
      timestamp,
      level,
      message,
      context: this.context,
      ...(meta && { meta })
    };
    return JSON.stringify(logEntry);
  }

  debug(message: string, meta?: any): void {
    if (this.shouldLog(LogLevel.DEBUG)) {
      console.log(this.formatMessage(LogLevel.DEBUG, message, meta));
    }
  }

  info(message: string, meta?: any): void {
    if (this.shouldLog(LogLevel.INFO)) {
      console.log(this.formatMessage(LogLevel.INFO, message, meta));
    }
  }

  warn(message: string, meta?: any): void {
    if (this.shouldLog(LogLevel.WARN)) {
      console.warn(this.formatMessage(LogLevel.WARN, message, meta));
    }
  }

  error(message: string, error?: Error, meta?: any): void {
    if (this.shouldLog(LogLevel.ERROR)) {
      const errorMeta = {
        ...meta,
        ...(error && {
          error: {
            name: error.name,
            message: error.message,
            stack: error.stack
          }
        })
      };
      console.error(this.formatMessage(LogLevel.ERROR, message, errorMeta));
    }
  }

  withContext(additionalContext: LogContext): Logger {
    return new Logger({ ...this.context, ...additionalContext }, this.logLevel);
  }

  setLogLevel(level: LogLevel): void {
    this.logLevel = level;
  }
}

// Default logger instance
export const logger = new Logger({
  functionName: process.env.AWS_LAMBDA_FUNCTION_NAME,
}, process.env.LOG_LEVEL as LogLevel || LogLevel.INFO);

// Helper function to create a logger with request context
export function createRequestLogger(requestId: string, additionalContext: LogContext = {}): Logger {
  return logger.withContext({ requestId, ...additionalContext });
}