package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// 获取视频通话记录
func GetVideoCallRecords(c *gin.Context) {
	// 获取当前登录用户ID
	userIDStr, exists := c.Get("user_id")
	if !exists {
		utils.Logger.Errorf("用户ID不存在")
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "请先登录"})
		return
	}

	userID, ok := userIDStr.(uint)
	if !ok {
		utils.Logger.Errorf("用户ID类型转换失败: %v, 类型=%T", userIDStr, userIDStr)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户ID无效"})
		return
	}

	// 获取查询参数
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	callType := c.DefaultQuery("call_type", "all") // all, incoming, outgoing

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize

	utils.Logger.Infof("获取视频通话记录: userID=%d, page=%d, pageSize=%d, callType=%s",
		userID, page, pageSize, callType)

	db := c.MustGet("db").(*gorm.DB)

	// 构建查询条件
	var query *gorm.DB
	if callType == "incoming" {
		query = db.Model(&models.VideoCallRecord{}).Where("receiver_id = ?", userID)
	} else if callType == "outgoing" {
		query = db.Model(&models.VideoCallRecord{}).Where("caller_id = ?", userID)
	} else {
		query = db.Model(&models.VideoCallRecord{}).Where("caller_id = ? OR receiver_id = ?", userID, userID)
	}

	// 查询总数
	var total int64
	query.Count(&total)

	// 查询记录
	var records []models.VideoCallRecord
	query.Order("start_time DESC").Offset(offset).Limit(pageSize).Find(&records)

	// 获取用户信息
	var recordsWithUserInfo []gin.H
	for _, record := range records {
		var otherUserID uint
		var isOutgoing bool
		if record.CallerID == userID {
			otherUserID = record.ReceiverID
			isOutgoing = true
		} else {
			otherUserID = record.CallerID
			isOutgoing = false
		}

		// 查询对方用户信息
		var otherUser models.User
		db.Select("id, account, nickname, avatar").Where("id = ?", otherUserID).First(&otherUser)

		recordsWithUserInfo = append(recordsWithUserInfo, gin.H{
			"id":          record.ID,
			"caller_id":   record.CallerID,
			"receiver_id": record.ReceiverID,
			"start_time":  record.StartTime,
			"end_time":    record.EndTime,
			"duration":    record.Duration,
			"status":      record.Status,
			"is_outgoing": isOutgoing,
			"other_user":  otherUser,
		})
	}

	utils.Logger.Infof("获取到视频通话记录: userID=%d, 总数=%d, 本页数量=%d", userID, total, len(records))
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取视频通话记录成功",
		"data": gin.H{
			"total":     total,
			"page":      page,
			"page_size": pageSize,
			"records":   recordsWithUserInfo,
		},
	})
}

// 获取视频通话详情
func GetVideoCallDetail(c *gin.Context) {
	// 获取当前登录用户ID
	userIDStr, exists := c.Get("user_id")
	if !exists {
		utils.Logger.Errorf("用户ID不存在")
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "请先登录"})
		return
	}

	userID, ok := userIDStr.(uint)
	if !ok {
		utils.Logger.Errorf("用户ID类型转换失败: %v, 类型=%T", userIDStr, userIDStr)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户ID无效"})
		return
	}

	// 获取通话ID
	callID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		utils.Logger.Errorf("通话ID无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "通话ID无效"})
		return
	}

	utils.Logger.Infof("获取视频通话详情: userID=%d, callID=%d", userID, callID)

	db := c.MustGet("db").(*gorm.DB)

	// 查询通话记录
	var record models.VideoCallRecord
	if err := db.Where("id = ? AND (caller_id = ? OR receiver_id = ?)", callID, userID, userID).First(&record).Error; err != nil {
		utils.Logger.Errorf("查询视频通话记录失败: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "通话记录不存在"})
		return
	}

	// 判断是呼出还是呼入
	var otherUserID uint
	var isOutgoing bool
	if record.CallerID == userID {
		otherUserID = record.ReceiverID
		isOutgoing = true
	} else {
		otherUserID = record.CallerID
		isOutgoing = false
	}

	// 查询对方用户信息
	var otherUser models.User
	db.Select("id, account, nickname, avatar").Where("id = ?", otherUserID).First(&otherUser)

	utils.Logger.Infof("获取到视频通话详情: userID=%d, callID=%d", userID, callID)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取视频通话详情成功",
		"data": gin.H{
			"id":          record.ID,
			"caller_id":   record.CallerID,
			"receiver_id": record.ReceiverID,
			"start_time":  record.StartTime,
			"end_time":    record.EndTime,
			"duration":    record.Duration,
			"status":      record.Status,
			"is_outgoing": isOutgoing,
			"other_user":  otherUser,
		},
	})
}

// 发起视频通话
func InitiateVideoCall(c *gin.Context) {
	var req struct {
		ReceiverID uint `json:"receiver_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("发起视频通话参数错误: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 获取当前登录用户ID
	userIDStr, exists := c.Get("user_id")
	if !exists {
		utils.Logger.Errorf("用户ID不存在")
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "请先登录"})
		return
	}

	userID, ok := userIDStr.(uint)
	if !ok {
		utils.Logger.Errorf("用户ID类型转换失败: %v, 类型=%T", userIDStr, userIDStr)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户ID无效"})
		return
	}

	// 检查接收者是否存在
	db := c.MustGet("db").(*gorm.DB)
	var receiver models.User
	if err := db.Select("id").Where("id = ?", req.ReceiverID).First(&receiver).Error; err != nil {
		utils.Logger.Errorf("接收者不存在: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "接收者不存在"})
		return
	}

	// 检查接收者是否在线
	if !utils.WebRTCServer.IsUserOnline(req.ReceiverID) {
		utils.Logger.Errorf("接收者不在线: receiverID=%d", req.ReceiverID)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "接收者不在线"})
		return
	}

	// 创建视频通话记录
	now := time.Now().Unix()
	videoCall := models.VideoCallRecord{
		CallerID:   userID,
		ReceiverID: req.ReceiverID,
		StartTime:  now,
		Status:     0, // 未接通
	}
	if err := db.Create(&videoCall).Error; err != nil {
		utils.Logger.Errorf("创建视频通话记录失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建视频通话记录失败"})
		return
	}

	// 发送通话邀请
	message := map[string]interface{}{
		"type":      "call_invitation",
		"from":      userID,
		"call_type": "video",
		"call_id":   videoCall.ID,
		"timestamp": time.Now().Unix(),
	}

	jsonMessage, err := json.Marshal(message)
	if err != nil {
		utils.Logger.Errorf("序列化视频通话邀请失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "发送视频通话邀请失败"})
		return
	}

	err = utils.WebRTCServer.SendToUser(req.ReceiverID, jsonMessage)
	if err != nil {
		utils.Logger.Errorf("发送视频通话邀请失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "发送视频通话邀请失败"})
		return
	}

	utils.Logger.Infof("发起视频通话成功: callerID=%d, receiverID=%d, callID=%d", userID, req.ReceiverID, videoCall.ID)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "发起视频通话成功",
		"data": gin.H{
			"call_id": videoCall.ID,
		},
	})
}

// 接受视频通话
func HandleAcceptVideoCall(c *gin.Context) {
	var req struct {
		CallID uint `json:"call_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("接受视频通话参数错误: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 获取当前登录用户ID
	userIDStr, exists := c.Get("user_id")
	if !exists {
		utils.Logger.Errorf("用户ID不存在")
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "请先登录"})
		return
	}

	userID, ok := userIDStr.(uint)
	if !ok {
		utils.Logger.Errorf("用户ID类型转换失败: %v, 类型=%T", userIDStr, userIDStr)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户ID无效"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 查询通话记录
	var videoCall models.VideoCallRecord
	if err := db.Where("id = ? AND receiver_id = ? AND status = 0", req.CallID, userID).First(&videoCall).Error; err != nil {
		utils.Logger.Errorf("查询视频通话记录失败: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "通话记录不存在或已接通/拒绝"})
		return
	}

	// 更新通话状态
	videoCall.Status = 1 // 已接通
	if err := db.Save(&videoCall).Error; err != nil {
		utils.Logger.Errorf("更新视频通话状态失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新通话状态失败"})
		return
	}

	// 发送接受通话响应
	err := utils.WebRTCServer.SendCallResponse(userID, videoCall.CallerID, "video", videoCall.ID, "accepted")
	if err != nil {
		utils.Logger.Errorf("发送接受视频通话响应失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "发送接受通话响应失败"})
		return
	}

	utils.Logger.Infof("接受视频通话成功: receiverID=%d, callerID=%d, callID=%d", userID, videoCall.CallerID, videoCall.ID)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "接受视频通话成功",
		"data": gin.H{
			"call_id": videoCall.ID,
		},
	})
}

// 拒绝视频通话
func HandleRejectVideoCall(c *gin.Context) {
	var req struct {
		CallID uint `json:"call_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("拒绝视频通话参数错误: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 获取当前登录用户ID
	userIDStr, exists := c.Get("user_id")
	if !exists {
		utils.Logger.Errorf("用户ID不存在")
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "请先登录"})
		return
	}

	userID, ok := userIDStr.(uint)
	if !ok {
		utils.Logger.Errorf("用户ID类型转换失败: %v, 类型=%T", userIDStr, userIDStr)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户ID无效"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 查询通话记录
	var videoCall models.VideoCallRecord
	if err := db.Where("id = ? AND receiver_id = ? AND status = 0", req.CallID, userID).First(&videoCall).Error; err != nil {
		utils.Logger.Errorf("查询视频通话记录失败: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "通话记录不存在或已接通/拒绝"})
		return
	}

	// 更新通话状态
	now := time.Now().Unix()
	videoCall.Status = 2 // 已拒绝
	videoCall.EndTime = now
	if err := db.Save(&videoCall).Error; err != nil {
		utils.Logger.Errorf("更新视频通话状态失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新通话状态失败"})
		return
	}

	// 发送拒绝通话响应
	err := utils.WebRTCServer.SendCallResponse(userID, videoCall.CallerID, "video", videoCall.ID, "rejected")
	if err != nil {
		utils.Logger.Errorf("发送拒绝视频通话响应失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "发送拒绝通话响应失败"})
		return
	}

	utils.Logger.Infof("拒绝视频通话成功: receiverID=%d, callerID=%d, callID=%d", userID, videoCall.CallerID, videoCall.ID)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "拒绝视频通话成功",
	})
}

// 结束视频通话
func HandleEndVideoCall(c *gin.Context) {
	var req struct {
		CallID uint `json:"call_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("结束视频通话参数错误: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 获取当前登录用户ID
	userIDStr, exists := c.Get("user_id")
	if !exists {
		utils.Logger.Errorf("用户ID不存在")
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "请先登录"})
		return
	}

	userID, ok := userIDStr.(uint)
	if !ok {
		utils.Logger.Errorf("用户ID类型转换失败: %v, 类型=%T", userIDStr, userIDStr)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户ID无效"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 查询通话记录
	var videoCall models.VideoCallRecord
	if err := db.Where("id = ? AND (caller_id = ? OR receiver_id = ?) AND status = 1", req.CallID, userID, userID).First(&videoCall).Error; err != nil {
		utils.Logger.Errorf("查询视频通话记录失败: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "通话记录不存在或未接通"})
		return
	}

	// 更新通话状态
	now := time.Now().Unix()
	videoCall.EndTime = now
	videoCall.Duration = int(now - videoCall.StartTime)
	if err := db.Save(&videoCall).Error; err != nil {
		utils.Logger.Errorf("更新视频通话状态失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新通话状态失败"})
		return
	}

	// 确定对方用户ID
	var otherUserID uint
	if videoCall.CallerID == userID {
		otherUserID = videoCall.ReceiverID
	} else {
		otherUserID = videoCall.CallerID
	}

	// 发送结束通话通知
	err := utils.WebRTCServer.SendCallEnded(userID, otherUserID, "video", videoCall.ID, "normal")
	if err != nil {
		utils.Logger.Errorf("发送结束视频通话通知失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "发送结束通话通知失败"})
		return
	}

	utils.Logger.Infof("结束视频通话成功: userID=%d, otherUserID=%d, callID=%d, duration=%d",
		userID, otherUserID, videoCall.ID, videoCall.Duration)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "结束视频通话成功",
		"data": gin.H{
			"duration": videoCall.Duration,
		},
	})
}

// 获取视频通话统计
func GetVideoCallStats(c *gin.Context) {
	// 获取当前登录用户ID
	userIDStr, exists := c.Get("user_id")
	if !exists {
		utils.Logger.Errorf("用户ID不存在")
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "请先登录"})
		return
	}

	userID, ok := userIDStr.(uint)
	if !ok {
		utils.Logger.Errorf("用户ID类型转换失败: %v, 类型=%T", userIDStr, userIDStr)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户ID无效"})
		return
	}

	utils.Logger.Infof("获取视频通话统计: userID=%d", userID)

	db := c.MustGet("db").(*gorm.DB)

	// 统计总通话次数
	var totalCalls int64
	db.Model(&models.VideoCallRecord{}).Where("caller_id = ? OR receiver_id = ?", userID, userID).Count(&totalCalls)

	// 统计呼出通话次数
	var outgoingCalls int64
	db.Model(&models.VideoCallRecord{}).Where("caller_id = ?", userID).Count(&outgoingCalls)

	// 统计呼入通话次数
	var incomingCalls int64
	db.Model(&models.VideoCallRecord{}).Where("receiver_id = ?", userID).Count(&incomingCalls)

	// 统计已接通通话次数
	var connectedCalls int64
	db.Model(&models.VideoCallRecord{}).Where("(caller_id = ? OR receiver_id = ?) AND status = 1", userID, userID).Count(&connectedCalls)

	// 统计未接通通话次数
	var missedCalls int64
	db.Model(&models.VideoCallRecord{}).Where("receiver_id = ? AND status = 0", userID).Count(&missedCalls)

	// 统计总通话时长
	var totalDuration int64
	db.Model(&models.VideoCallRecord{}).
		Where("(caller_id = ? OR receiver_id = ?) AND status = 1", userID, userID).
		Select("COALESCE(SUM(duration), 0) as total").
		Row().
		Scan(&totalDuration)

	// 统计最近一周通话次数
	now := time.Now().Unix()
	weekAgo := now - 7*24*60*60
	var weekCalls int64
	db.Model(&models.VideoCallRecord{}).
		Where("(caller_id = ? OR receiver_id = ?) AND start_time >= ?", userID, userID, weekAgo).
		Count(&weekCalls)

	// 统计最常联系的用户
	type FrequentContact struct {
		UserID    uint   `json:"user_id"`
		CallCount int64  `json:"call_count"`
		Account   string `json:"account"`
		Nickname  string `json:"nickname"`
		Avatar    string `json:"avatar"`
	}
	var frequentContacts []FrequentContact

	// 查询与当前用户通话最多的用户
	rows, err := db.Raw(`
		SELECT
			CASE
				WHEN caller_id = ? THEN receiver_id
				ELSE caller_id
			END as user_id,
			COUNT(*) as call_count
		FROM video_call_records
		WHERE caller_id = ? OR receiver_id = ?
		GROUP BY user_id
		ORDER BY call_count DESC
		LIMIT 5
	`, userID, userID, userID).Rows()

	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var contact FrequentContact
			rows.Scan(&contact.UserID, &contact.CallCount)

			// 查询用户信息
			var user models.User
			if err := db.Select("id, account, nickname, avatar").Where("id = ?", contact.UserID).First(&user).Error; err == nil {
				contact.Account = user.Account
				contact.Nickname = user.Nickname
				contact.Avatar = user.Avatar
				frequentContacts = append(frequentContacts, contact)
			}
		}
	}

	utils.Logger.Infof("获取到视频通话统计: userID=%d, 总通话次数=%d, 总通话时长=%d", userID, totalCalls, totalDuration)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取视频通话统计成功",
		"data": gin.H{
			"total_calls":       totalCalls,
			"outgoing_calls":    outgoingCalls,
			"incoming_calls":    incomingCalls,
			"connected_calls":   connectedCalls,
			"missed_calls":      missedCalls,
			"total_duration":    totalDuration,
			"week_calls":        weekCalls,
			"frequent_contacts": frequentContacts,
		},
	})
}
