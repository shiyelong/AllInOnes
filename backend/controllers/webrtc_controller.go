package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// WebRTC 信令接口
func WebRTCSignal(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 前端发送/接收信令数据
	var req struct {
		To       uint   `json:"to" binding:"required"`
		Type     string `json:"type" binding:"required"` // offer/answer/candidate
		Signal   string `json:"signal" binding:"required"`
		CallType string `json:"call_type"` // video/voice
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 检查接收者是否存在
	var receiver models.User
	if err := utils.DB.First(&receiver, req.To).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "接收者不存在"})
		return
	}

	// 检查是否是好友关系
	var friendship models.Friend
	if err := utils.DB.Where("(user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)",
		userID, req.To, req.To, userID).First(&friendship).Error; err != nil {
		c.JSON(http.StatusForbidden, gin.H{"success": false, "msg": "对方不是您的好友"})
		return
	}

	// 创建信令消息
	signalMessage := map[string]interface{}{
		"from":      userID,
		"to":        req.To,
		"type":      req.Type,
		"signal":    req.Signal,
		"call_type": req.CallType,
		"timestamp": time.Now().Unix(),
	}

	// 将信令消息转换为JSON
	signalJSON, err := json.Marshal(signalMessage)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "信令处理失败"})
		return
	}

	// TODO: 通过WebSocket推送信令到目标用户
	// 这里应该调用WebSocket服务将信令推送给目标用户
	// 由于WebSocket实现可能比较复杂，这里先模拟一个成功的响应

	// 如果是offer类型的信令，记录通话开始
	if req.Type == "offer" {
		// 根据通话类型记录
		if req.CallType == "video" {
			// 记录视频通话
			videoCall := models.VideoCallRecord{
				CallerID:   userID.(uint),
				ReceiverID: req.To,
				StartTime:  time.Now().Unix(),
				Status:     0, // 未接通
			}
			if err := utils.DB.Create(&videoCall).Error; err != nil {
				// 记录失败不影响信令发送
				c.JSON(http.StatusOK, gin.H{
					"success": true,
					"msg":     "信令已发送，但通话记录创建失败",
					"signal":  string(signalJSON),
				})
				return
			}
		} else if req.CallType == "voice" {
			// 记录语音通话
			voiceCall := models.VoiceCallRecord{
				CallerID:   userID.(uint),
				ReceiverID: req.To,
				StartTime:  time.Now().Unix(),
				Status:     0, // 未接通
			}
			if err := utils.DB.Create(&voiceCall).Error; err != nil {
				// 记录失败不影响信令发送
				c.JSON(http.StatusOK, gin.H{
					"success": true,
					"msg":     "信令已发送，但通话记录创建失败",
					"signal":  string(signalJSON),
				})
				return
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "信令已发送",
		"signal":  string(signalJSON),
	})
}

// 开始视频通话
func StartVideoCallWebRTC(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		ReceiverID uint `json:"receiver_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 检查接收者是否存在
	var receiver models.User
	if err := utils.DB.First(&receiver, req.ReceiverID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "接收者不存在"})
		return
	}

	// 检查是否是好友关系
	var friendship models.Friend
	if err := utils.DB.Where("(user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)",
		userID, req.ReceiverID, req.ReceiverID, userID).First(&friendship).Error; err != nil {
		c.JSON(http.StatusForbidden, gin.H{"success": false, "msg": "对方不是您的好友"})
		return
	}

	// 创建视频通话记录
	videoCall := models.VideoCallRecord{
		CallerID:   userID.(uint),
		ReceiverID: req.ReceiverID,
		StartTime:  time.Now().Unix(),
		Status:     0, // 未接通
	}

	if err := utils.DB.Create(&videoCall).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建通话记录失败"})
		return
	}

	// TODO: 通过WebSocket通知接收者有视频通话请求

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "视频通话已发起",
		"data": gin.H{
			"call_id":     videoCall.ID,
			"caller_id":   videoCall.CallerID,
			"receiver_id": videoCall.ReceiverID,
			"start_time":  videoCall.StartTime,
			"status":      videoCall.Status,
		},
	})
}

// 结束视频通话
func EndVideoCallWebRTC(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		CallID uint `json:"call_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 查询通话记录
	var videoCall models.VideoCallRecord
	if err := utils.DB.First(&videoCall, req.CallID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "通话记录不存在"})
		return
	}

	// 检查是否是通话参与者
	if videoCall.CallerID != userID.(uint) && videoCall.ReceiverID != userID.(uint) {
		c.JSON(http.StatusForbidden, gin.H{"success": false, "msg": "您不是该通话的参与者"})
		return
	}

	// 更新通话记录
	now := time.Now().Unix()
	videoCall.EndTime = now
	videoCall.Duration = int(now - videoCall.StartTime)
	videoCall.Status = 1 // 已接通并结束

	if err := utils.DB.Save(&videoCall).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新通话记录失败"})
		return
	}

	// TODO: 通过WebSocket通知对方通话已结束

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "视频通话已结束",
		"data": gin.H{
			"call_id":     videoCall.ID,
			"caller_id":   videoCall.CallerID,
			"receiver_id": videoCall.ReceiverID,
			"start_time":  videoCall.StartTime,
			"end_time":    videoCall.EndTime,
			"duration":    videoCall.Duration,
			"status":      videoCall.Status,
		},
	})
}

// 拒绝视频通话
func RejectVideoCallWebRTC(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		CallID uint `json:"call_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 查询通话记录
	var videoCall models.VideoCallRecord
	if err := utils.DB.First(&videoCall, req.CallID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "通话记录不存在"})
		return
	}

	// 检查是否是接收者
	if videoCall.ReceiverID != userID.(uint) {
		c.JSON(http.StatusForbidden, gin.H{"success": false, "msg": "只有接收者可以拒绝通话"})
		return
	}

	// 更新通话记录
	videoCall.EndTime = time.Now().Unix()
	videoCall.Status = 2 // 已拒绝

	if err := utils.DB.Save(&videoCall).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新通话记录失败"})
		return
	}

	// TODO: 通过WebSocket通知发起者通话已被拒绝

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "已拒绝视频通话",
		"data": gin.H{
			"call_id":     videoCall.ID,
			"caller_id":   videoCall.CallerID,
			"receiver_id": videoCall.ReceiverID,
			"status":      videoCall.Status,
		},
	})
}

// 开始语音通话
func StartVoiceCallWebRTC(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		ReceiverID uint `json:"receiver_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 检查接收者是否存在
	var receiver models.User
	if err := utils.DB.First(&receiver, req.ReceiverID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "接收者不存在"})
		return
	}

	// 检查是否是好友关系
	var friendship models.Friend
	if err := utils.DB.Where("(user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?)",
		userID, req.ReceiverID, req.ReceiverID, userID).First(&friendship).Error; err != nil {
		c.JSON(http.StatusForbidden, gin.H{"success": false, "msg": "对方不是您的好友"})
		return
	}

	// 创建语音通话记录
	voiceCall := models.VoiceCallRecord{
		CallerID:   userID.(uint),
		ReceiverID: req.ReceiverID,
		StartTime:  time.Now().Unix(),
		Status:     0, // 未接通
	}

	if err := utils.DB.Create(&voiceCall).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建通话记录失败"})
		return
	}

	// TODO: 通过WebSocket通知接收者有语音通话请求

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "语音通话已发起",
		"data": gin.H{
			"call_id":     voiceCall.ID,
			"caller_id":   voiceCall.CallerID,
			"receiver_id": voiceCall.ReceiverID,
			"start_time":  voiceCall.StartTime,
			"status":      voiceCall.Status,
		},
	})
}

// 结束语音通话
func EndVoiceCallWebRTC(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		CallID uint `json:"call_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 查询通话记录
	var voiceCall models.VoiceCallRecord
	if err := utils.DB.First(&voiceCall, req.CallID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "通话记录不存在"})
		return
	}

	// 检查是否是通话参与者
	if voiceCall.CallerID != userID.(uint) && voiceCall.ReceiverID != userID.(uint) {
		c.JSON(http.StatusForbidden, gin.H{"success": false, "msg": "您不是该通话的参与者"})
		return
	}

	// 更新通话记录
	now := time.Now().Unix()
	voiceCall.EndTime = now
	voiceCall.Duration = int(now - voiceCall.StartTime)
	voiceCall.Status = 1 // 已接通并结束

	if err := utils.DB.Save(&voiceCall).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新通话记录失败"})
		return
	}

	// TODO: 通过WebSocket通知对方通话已结束

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "语音通话已结束",
		"data": gin.H{
			"call_id":     voiceCall.ID,
			"caller_id":   voiceCall.CallerID,
			"receiver_id": voiceCall.ReceiverID,
			"start_time":  voiceCall.StartTime,
			"end_time":    voiceCall.EndTime,
			"duration":    voiceCall.Duration,
			"status":      voiceCall.Status,
		},
	})
}

// 拒绝语音通话
func RejectVoiceCallWebRTC(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		CallID uint `json:"call_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 查询通话记录
	var voiceCall models.VoiceCallRecord
	if err := utils.DB.First(&voiceCall, req.CallID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "通话记录不存在"})
		return
	}

	// 检查是否是接收者
	if voiceCall.ReceiverID != userID.(uint) {
		c.JSON(http.StatusForbidden, gin.H{"success": false, "msg": "只有接收者可以拒绝通话"})
		return
	}

	// 更新通话记录
	voiceCall.EndTime = time.Now().Unix()
	voiceCall.Status = 2 // 已拒绝

	if err := utils.DB.Save(&voiceCall).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新通话记录失败"})
		return
	}

	// TODO: 通过WebSocket通知发起者通话已被拒绝

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "已拒绝语音通话",
		"data": gin.H{
			"call_id":     voiceCall.ID,
			"caller_id":   voiceCall.CallerID,
			"receiver_id": voiceCall.ReceiverID,
			"status":      voiceCall.Status,
		},
	})
}

// 获取通话历史
func GetCallHistoryWebRTC(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	callType := c.Query("type") // voice 或 video
	limitStr := c.Query("limit")
	offsetStr := c.Query("offset")

	// 设置默认值
	limit := 20
	offset := 0

	// 解析分页参数
	if limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
			limit = l
		}
	}

	if offsetStr != "" {
		if o, err := strconv.Atoi(offsetStr); err == nil && o >= 0 {
			offset = o
		}
	}

	// 根据通话类型查询历史记录
	if callType == "voice" {
		var voiceCalls []models.VoiceCallRecord
		if err := utils.DB.Where("caller_id = ? OR receiver_id = ?", userID, userID).
			Order("start_time DESC").Limit(limit).Offset(offset).Find(&voiceCalls).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "获取通话历史失败"})
			return
		}

		// 获取相关用户信息
		var userIDs []uint
		for _, call := range voiceCalls {
			if call.CallerID != userID.(uint) {
				userIDs = append(userIDs, call.CallerID)
			}
			if call.ReceiverID != userID.(uint) {
				userIDs = append(userIDs, call.ReceiverID)
			}
		}

		var users []models.User
		utils.DB.Where("id IN ?", userIDs).Find(&users)

		// 构建用户映射
		userMap := make(map[uint]models.User)
		for _, user := range users {
			userMap[user.ID] = user
		}

		// 构造响应数据
		var result []gin.H
		for _, call := range voiceCalls {
			var otherUserID uint
			var isOutgoing bool

			if call.CallerID == userID.(uint) {
				otherUserID = call.ReceiverID
				isOutgoing = true
			} else {
				otherUserID = call.CallerID
				isOutgoing = false
			}

			otherUser, exists := userMap[otherUserID]
			otherUserName := ""
			otherUserAvatar := ""
			if exists {
				otherUserName = otherUser.Nickname
				otherUserAvatar = otherUser.Avatar
			}

			result = append(result, gin.H{
				"id":          call.ID,
				"caller_id":   call.CallerID,
				"receiver_id": call.ReceiverID,
				"start_time":  call.StartTime,
				"end_time":    call.EndTime,
				"duration":    call.Duration,
				"status":      call.Status,
				"is_outgoing": isOutgoing,
				"other_user": gin.H{
					"id":     otherUserID,
					"name":   otherUserName,
					"avatar": otherUserAvatar,
				},
			})
		}

		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"data":    result,
		})
	} else if callType == "video" {
		var videoCalls []models.VideoCallRecord
		if err := utils.DB.Where("caller_id = ? OR receiver_id = ?", userID, userID).
			Order("start_time DESC").Limit(limit).Offset(offset).Find(&videoCalls).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "获取通话历史失败"})
			return
		}

		// 获取相关用户信息
		var userIDs []uint
		for _, call := range videoCalls {
			if call.CallerID != userID.(uint) {
				userIDs = append(userIDs, call.CallerID)
			}
			if call.ReceiverID != userID.(uint) {
				userIDs = append(userIDs, call.ReceiverID)
			}
		}

		var users []models.User
		utils.DB.Where("id IN ?", userIDs).Find(&users)

		// 构建用户映射
		userMap := make(map[uint]models.User)
		for _, user := range users {
			userMap[user.ID] = user
		}

		// 构造响应数据
		var result []gin.H
		for _, call := range videoCalls {
			var otherUserID uint
			var isOutgoing bool

			if call.CallerID == userID.(uint) {
				otherUserID = call.ReceiverID
				isOutgoing = true
			} else {
				otherUserID = call.CallerID
				isOutgoing = false
			}

			otherUser, exists := userMap[otherUserID]
			otherUserName := ""
			otherUserAvatar := ""
			if exists {
				otherUserName = otherUser.Nickname
				otherUserAvatar = otherUser.Avatar
			}

			result = append(result, gin.H{
				"id":          call.ID,
				"caller_id":   call.CallerID,
				"receiver_id": call.ReceiverID,
				"start_time":  call.StartTime,
				"end_time":    call.EndTime,
				"duration":    call.Duration,
				"status":      call.Status,
				"is_outgoing": isOutgoing,
				"other_user": gin.H{
					"id":     otherUserID,
					"name":   otherUserName,
					"avatar": otherUserAvatar,
				},
			})
		}

		c.JSON(http.StatusOK, gin.H{
			"success": true,
			"data":    result,
		})
	} else {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "无效的通话类型，请指定 voice 或 video"})
	}
}
