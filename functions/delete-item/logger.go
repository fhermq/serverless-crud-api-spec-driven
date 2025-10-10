package main

import (
	"encoding/json"
	"fmt"
	"os"
	"time"
)

// LogLevel represents the severity level of a log entry
type LogLevel string

const (
	DEBUG LogLevel = "DEBUG"
	INFO  LogLevel = "INFO"
	WARN  LogLevel = "WARN"
	ERROR LogLevel = "ERROR"
)

// LogContext represents the context information for logging
type LogContext struct {
	RequestID    string `json:"requestId,omitempty"`
	FunctionName string `json:"functionName,omitempty"`
	Operation    string `json:"operation,omitempty"`
}

// Logger provides structured logging functionality
type Logger struct {
	context  LogContext
	logLevel LogLevel
}

// LogEntry represents a structured log entry
type LogEntry struct {
	Timestamp string                 `json:"timestamp"`
	Level     LogLevel               `json:"level"`
	Message   string                 `json:"message"`
	Context   LogContext             `json:"context"`
	Meta      map[string]interface{} `json:"meta,omitempty"`
	Error     *ErrorInfo             `json:"error,omitempty"`
}

// ErrorInfo represents error information in logs
type ErrorInfo struct {
	Name    string `json:"name"`
	Message string `json:"message"`
	Stack   string `json:"stack,omitempty"`
}

// NewLogger creates a new logger with the given context
func NewLogger(context LogContext, logLevel LogLevel) *Logger {
	if logLevel == "" {
		logLevel = INFO
	}
	return &Logger{
		context:  context,
		logLevel: logLevel,
	}
}

// shouldLog determines if a message should be logged based on level
func (l *Logger) shouldLog(level LogLevel) bool {
	levels := map[LogLevel]int{
		DEBUG: 0,
		INFO:  1,
		WARN:  2,
		ERROR: 3,
	}
	return levels[level] >= levels[l.logLevel]
}

// log writes a structured log entry
func (l *Logger) log(level LogLevel, message string, meta map[string]interface{}, err error) {
	if !l.shouldLog(level) {
		return
	}

	entry := LogEntry{
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Level:     level,
		Message:   message,
		Context:   l.context,
		Meta:      meta,
	}

	if err != nil {
		entry.Error = &ErrorInfo{
			Name:    "Error",
			Message: err.Error(),
		}
	}

	jsonLog, _ := json.Marshal(entry)
	fmt.Println(string(jsonLog))
}

// Debug logs a debug message
func (l *Logger) Debug(message string, meta map[string]interface{}) {
	l.log(DEBUG, message, meta, nil)
}

// Info logs an info message
func (l *Logger) Info(message string, meta map[string]interface{}) {
	l.log(INFO, message, meta, nil)
}

// Warn logs a warning message
func (l *Logger) Warn(message string, meta map[string]interface{}) {
	l.log(WARN, message, meta, nil)
}

// Error logs an error message
func (l *Logger) Error(message string, err error, meta map[string]interface{}) {
	l.log(ERROR, message, meta, err)
}

// WithContext creates a new logger with additional context
func (l *Logger) WithContext(additionalContext LogContext) *Logger {
	newContext := l.context
	if additionalContext.RequestID != "" {
		newContext.RequestID = additionalContext.RequestID
	}
	if additionalContext.FunctionName != "" {
		newContext.FunctionName = additionalContext.FunctionName
	}
	if additionalContext.Operation != "" {
		newContext.Operation = additionalContext.Operation
	}

	return &Logger{
		context:  newContext,
		logLevel: l.logLevel,
	}
}

// LogDatabaseOperation logs a database operation with timing
func (l *Logger) LogDatabaseOperation(operation, table string, key map[string]interface{}, duration time.Duration) {
	meta := map[string]interface{}{
		"type":      "database",
		"operation": operation,
		"table":     table,
		"duration":  fmt.Sprintf("%dms", duration.Milliseconds()),
	}
	if key != nil {
		meta["key"] = key
	}
	l.Debug(fmt.Sprintf("DynamoDB %s", operation), meta)
}

// CreateRequestLogger creates a logger with request context
func CreateRequestLogger(requestID string, additionalContext LogContext) *Logger {
	context := LogContext{
		RequestID:    requestID,
		FunctionName: additionalContext.FunctionName,
		Operation:    additionalContext.Operation,
	}

	// Get log level from environment or default to INFO
	logLevel := INFO
	if envLevel := getEnvLogLevel(); envLevel != "" {
		logLevel = envLevel
	}

	return NewLogger(context, logLevel)
}

// getEnvLogLevel gets log level from environment variable
func getEnvLogLevel() LogLevel {
	switch os.Getenv("LOG_LEVEL") {
	case "DEBUG":
		return DEBUG
	case "INFO":
		return INFO
	case "WARN":
		return WARN
	case "ERROR":
		return ERROR
	default:
		return INFO
	}
}