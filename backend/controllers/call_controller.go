package controllers

import (
	"allinone_backend/models"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// 开始语音通话
func StartVoiceCall(c *gin.Context) {
	var req struct {
		CallerID   uint `json:"caller_id"`
		ReceiverID uint `json:"receiver_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)
	
	// 创建通话记录
	call := models.VoiceCallRecord{
		CallerID:   req.CallerID,
		ReceiverID: req.ReceiverID,
		StartTime:  time.Now().Unix(),
		Status:     0, // 未接通
	}
	if err := db.Create(&call).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建通话记录失败"})
		return
	}

	// 返回通话ID和信令服务器信息
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "已发起语音通话",
		"data": gin.H{
			"call_id":      call.ID,
			"signaling":    "wss://signaling.allinone.com/ws",
			"stun_servers": []string{"stun:stun.l.google.com:19302"},
			"turn_servers": []string{"turn:turn.allinone.com:3478"},
		},
	})
}

// 结束语音通话
func EndVoiceCall(c *gin.Context) {
	var req struct {
		CallID uint `json:"call_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)
	var call models.VoiceCallRecord
	if err := db.First(&call, req.CallID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "通话记录不存在"})
		return
	}

	// 更新通话记录
	endTime := time.Now().Unix()
	duration := int(endTime - call.StartTime)
	db.Model(&call).Updates(map[string]interface{}{
		"end_time": endTime,
		"duration": duration,
		"status":   1, // 已接通
	})

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "通话已结束",
		"data": gin.H{
			"call_id":  call.ID,
			"duration": duration,
		},
	})
}

// 拒绝语音通话
func RejectVoiceCall(c *gin.Context) {
	var req struct {
		CallID uint `json:"call_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)
	var call models.VoiceCallRecord
	if err := db.First(&call, req.CallID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "通话记录不存在"})
		return
	}

	// 更新通话记录
	endTime := time.Now().Unix()
	db.Model(&call).Updates(map[string]interface{}{
		"end_time": endTime,
		"duration": 0,
		"status":   2, // 已拒绝
	})

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "已拒绝通话",
	})
}

// 开始视频通话
func StartVideoCall(c *gin.Context) {
	var req struct {
		CallerID   uint `json:"caller_id"`
		ReceiverID uint `json:"receiver_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)
	
	// 创建通话记录
	call := models.VideoCallRecord{
		CallerID:   req.CallerID,
		ReceiverID: req.ReceiverID,
		StartTime:  time.Now().Unix(),
		Status:     0, // 未接通
	}
	if err := db.Create(&call).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建通话记录失败"})
		return
	}

	// 返回通话ID和信令服务器信息
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "已发起视频通话",
		"data": gin.H{
			"call_id":      call.ID,
			"signaling":    "wss://signaling.allinone.com/ws",
			"stun_servers": []string{"stun:stun.l.google.com:19302"},
			"turn_servers": []string{"turn:turn.allinone.com:3478"},
		},
	})
}

// 结束视频通话
func EndVideoCall(c *gin.Context) {
	var req struct {
		CallID uint `json:"call_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)
	var call models.VideoCallRecord
	if err := db.First(&call, req.CallID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "通话记录不存在"})
		return
	}

	// 更新通话记录
	endTime := time.Now().Unix()
	duration := int(endTime - call.StartTime)
	db.Model(&call).Updates(map[string]interface{}{
		"end_time": endTime,
		"duration": duration,
		"status":   1, // 已接通
	})

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "通话已结束",
		"data": gin.H{
			"call_id":  call.ID,
			"duration": duration,
		},
	})
}

// 拒绝视频通话
func RejectVideoCall(c *gin.Context) {
	var req struct {
		CallID uint `json:"call_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)
	var call models.VideoCallRecord
	if err := db.First(&call, req.CallID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "通话记录不存在"})
		return
	}

	// 更新通话记录
	endTime := time.Now().Unix()
	db.Model(&call).Updates(map[string]interface{}{
		"end_time": endTime,
		"duration": 0,
		"status":   2, // 已拒绝
	})

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "已拒绝通话",
	})
}

// 获取通话历史
func GetCallHistory(c *gin.Context) {
	userIDStr := c.Query("user_id")
	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	typeStr := c.DefaultQuery("type", "all") // all, voice, video
	
	db := c.MustGet("db").(*gorm.DB)
	
	// 获取语音通话记录
	var voiceCalls []models.VoiceCallRecord
	var videoCalls []models.VideoCallRecord
	
	if typeStr == "all" || typeStr == "voice" {
		db.Where("caller_id = ? OR receiver_id = ?", userID, userID).
			Order("start_time desc").
			Limit(50).
			Find(&voiceCalls)
	}
	
	if typeStr == "all" || typeStr == "video" {
		db.Where("caller_id = ? OR receiver_id = ?", userID, userID).
			Order("start_time desc").
			Limit(50).
			Find(&videoCalls)
	}
	
	// 构建响应
	var voiceResp []gin.H
	for _, call := range voiceCalls {
		var peerID uint
		var isOutgoing bool
		if call.CallerID == uint(userID) {
			peerID = call.ReceiverID
			isOutgoing = true
		} else {
			peerID = call.CallerID
			isOutgoing = false
		}
		
		var peer models.User
		db.First(&peer, peerID)
		
		voiceResp = append(voiceResp, gin.H{
			"id":         call.ID,
			"peer_id":    peerID,
			"peer_name":  peer.Nickname,
			"peer_avatar": peer.Avatar,
			"start_time": call.StartTime,
			"end_time":   call.EndTime,
			"duration":   call.Duration,
			"status":     call.Status,
			"is_outgoing": isOutgoing,
			"type":       "voice",
		})
	}
	
	var videoResp []gin.H
	for _, call := range videoCalls {
		var peerID uint
		var isOutgoing bool
		if call.CallerID == uint(userID) {
			peerID = call.ReceiverID
			isOutgoing = true
		} else {
			peerID = call.CallerID
			isOutgoing = false
		}
		
		var peer models.User
		db.First(&peer, peerID)
		
		videoResp = append(videoResp, gin.H{
			"id":         call.ID,
			"peer_id":    peerID,
			"peer_name":  peer.Nickname,
			"peer_avatar": peer.Avatar,
			"start_time": call.StartTime,
			"end_time":   call.EndTime,
			"duration":   call.Duration,
			"status":     call.Status,
			"is_outgoing": isOutgoing,
			"type":       "video",
		})
	}
	
	// 合并并按时间排序
	var allCalls []gin.H
	allCalls = append(allCalls, voiceResp...)
	allCalls = append(allCalls, videoResp...)
	
	// 简单的冒泡排序，按开始时间降序排列
	for i := 0; i < len(allCalls)-1; i++ {
		for j := 0; j < len(allCalls)-i-1; j++ {
			if allCalls[j]["start_time"].(int64) < allCalls[j+1]["start_time"].(int64) {
				allCalls[j], allCalls[j+1] = allCalls[j+1], allCalls[j]
			}
		}
	}
	
	var result []gin.H
	if typeStr == "voice" {
		result = voiceResp
	} else if typeStr == "video" {
		result = videoResp
	} else {
		result = allCalls
	}
	
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    result,
	})
}
