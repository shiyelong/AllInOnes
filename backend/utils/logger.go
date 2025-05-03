package utils

import (
	"log"
	"os"
)

// Logger 全局日志对象
var Logger = NewLogger()

// AppLogger 应用日志结构
type AppLogger struct {
	infoLogger  *log.Logger
	errorLogger *log.Logger
	debugLogger *log.Logger
}

// NewLogger 创建新的日志对象
func NewLogger() *AppLogger {
	return &AppLogger{
		infoLogger:  log.New(os.Stdout, "[INFO] ", log.LstdFlags),
		errorLogger: log.New(os.Stderr, "[ERROR] ", log.LstdFlags),
		debugLogger: log.New(os.Stdout, "[DEBUG] ", log.LstdFlags),
	}
}

// Info 记录信息日志
func (l *AppLogger) Info(v ...interface{}) {
	l.infoLogger.Println(v...)
}

// Infof 记录格式化信息日志
func (l *AppLogger) Infof(format string, v ...interface{}) {
	l.infoLogger.Printf(format, v...)
}

// Error 记录错误日志
func (l *AppLogger) Error(v ...interface{}) {
	l.errorLogger.Println(v...)
}

// Errorf 记录格式化错误日志
func (l *AppLogger) Errorf(format string, v ...interface{}) {
	l.errorLogger.Printf(format, v...)
}

// Debug 记录调试日志
func (l *AppLogger) Debug(v ...interface{}) {
	l.debugLogger.Println(v...)
}

// Debugf 记录格式化调试日志
func (l *AppLogger) Debugf(format string, v ...interface{}) {
	l.debugLogger.Printf(format, v...)
}
