package controllers

import (
	"net/http"
	"runtime"
	"time"

	"github.com/gin-gonic/gin"
)

// HealthCheck 健康检查API
// 返回服务器状态信息，用于监控和部署检查
func HealthCheck(c *gin.Context) {
	// 获取系统信息
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	// 构造响应
	c.JSON(http.StatusOK, gin.H{
		"status":    "ok",
		"timestamp": time.Now().Unix(),
		"version":   "1.0.0",
		"system": gin.H{
			"go_version":    runtime.Version(),
			"goroutines":    runtime.NumGoroutine(),
			"cpu_cores":     runtime.NumCPU(),
			"memory_alloc":  m.Alloc,
			"memory_sys":    m.Sys,
			"memory_total":  m.TotalAlloc,
			"memory_gc_num": m.NumGC,
		},
	})
}
