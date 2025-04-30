package controllers

import (
	"github.com/gin-gonic/gin"
	"net/http"
)

// WebRTC 信令接口示例
func WebRTCSignal(c *gin.Context) {
	// 前端发送/接收信令数据
	var req struct {
		From   uint   `json:"from"`
		To     uint   `json:"to"`
		Type   string `json:"type"` // offer/answer/candidate
		Signal string `json:"signal"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	// TODO: 推送信令到目标用户（建议用WebSocket）
	c.JSON(http.StatusOK, gin.H{"success": true, "msg": "信令已转发"})
}
