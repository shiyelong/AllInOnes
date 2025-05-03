package controllers

import (
	"allinone_backend/models"
	"bytes"
	"fmt"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// 好友/联系人相关接口
// 获取好友列表
func GetFriends(c *gin.Context) {
	userIDStr := c.Query("user_id")
	// 如果没有提供user_id，尝试从当前登录用户获取
	if userIDStr == "" {
		if userID, exists := c.Get("user_id"); exists {
			userIDStr = fmt.Sprintf("%v", userID)
		}
	}

	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "无效的用户ID"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)
	var friends []models.Friend
	db.Where("user_id = ?", userID).Find(&friends)

	var resp []gin.H
	for _, f := range friends {
		// 获取好友的详细信息
		var friendUser models.User
		if err := db.First(&friendUser, f.FriendID).Error; err != nil {
			// 如果找不到好友信息，跳过
			continue
		}

		resp = append(resp, gin.H{
			"friend_id":  f.FriendID,
			"created_at": f.CreatedAt,
			"blocked":    f.Blocked,
			"account":    friendUser.Account,
			"nickname":   friendUser.Nickname,
			"avatar":     friendUser.Avatar,
			"gender":     friendUser.Gender,
			"email":      friendUser.Email,
		})
	}

	c.JSON(200, gin.H{"success": true, "data": resp})
}

// 屏蔽好友
func BlockFriend(c *gin.Context) {
	var req struct {
		UserID   uint `json:"user_id"`
		FriendID uint `json:"friend_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	var friend models.Friend
	if err := db.Where("user_id = ? AND friend_id = ?", req.UserID, req.FriendID).First(&friend).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "好友关系不存在"})
		return
	}
	friend.Blocked = 1
	db.Save(&friend)
	c.JSON(200, gin.H{"success": true, "msg": "已屏蔽该好友"})
}

// 取消屏蔽
func UnblockFriend(c *gin.Context) {
	var req struct {
		UserID   uint `json:"user_id"`
		FriendID uint `json:"friend_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	var friend models.Friend
	if err := db.Where("user_id = ? AND friend_id = ?", req.UserID, req.FriendID).First(&friend).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "好友关系不存在"})
		return
	}
	friend.Blocked = 0
	db.Save(&friend)
	c.JSON(200, gin.H{"success": true, "msg": "已取消屏蔽"})
}

// 添加好友
func AddFriend(c *gin.Context) {
	// 打印请求体
	body, _ := c.GetRawData()
	c.Request.Body = io.NopCloser(bytes.NewBuffer(body))
	fmt.Printf("请求体: %s\n", string(body))

	// 使用字符串类型接收ID，然后转换
	var req struct {
		UserID     string `json:"user_id"`
		FriendID   string `json:"friend_id"`
		Message    string `json:"message"`     // 添加好友时的验证消息
		SourceType string `json:"source_type"` // 来源类型：search(搜索)、scan(扫码)、recommend(推荐)等
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误: " + err.Error()})
		return
	}

	// 打印解析后的请求数据
	fmt.Printf("解析后的请求数据: UserID=%s, FriendID=%s, Message=%s, SourceType=%s\n",
		req.UserID, req.FriendID, req.Message, req.SourceType)

	// 转换ID为uint
	userIDUint, err := strconv.ParseUint(req.UserID, 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "用户ID格式错误"})
		return
	}
	userID := uint(userIDUint)

	friendIDUint, err := strconv.ParseUint(req.FriendID, 10, 32)
	if err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "好友ID格式错误"})
		return
	}
	friendID := uint(friendIDUint)

	// 验证用户ID
	if userID == friendID {
		c.JSON(400, gin.H{"success": false, "msg": "不能添加自己为好友"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 检查是否已经是好友
	var existingFriend models.Friend
	if err := db.Where("user_id = ? AND friend_id = ?", userID, friendID).First(&existingFriend).Error; err == nil {
		c.JSON(400, gin.H{"success": false, "msg": "对方已经是您的好友"})
		return
	}

	// 检查是否已经发送过请求且未处理
	var existingRequest models.FriendRequest
	if err := db.Where("from_id = ? AND to_id = ? AND status = 0", userID, friendID).First(&existingRequest).Error; err == nil {
		c.JSON(400, gin.H{"success": false, "msg": "您已经发送过好友请求，请等待对方处理"})
		return
	}

	// 检查是否有被拒绝的请求，如果有，更新为新的请求
	var rejectedRequest models.FriendRequest
	if err := db.Where("from_id = ? AND to_id = ? AND status = 2", userID, friendID).Order("created_at DESC").First(&rejectedRequest).Error; err == nil {
		// 找到了被拒绝的请求，将其更新为新的待处理请求
		db.Model(&rejectedRequest).Updates(map[string]any{
			"status":     0, // 更新为待处理状态
			"message":    req.Message,
			"created_at": time.Now().Unix(),
		})

		c.JSON(200, gin.H{
			"success":       true,
			"msg":           "好友请求已重新发送，等待对方同意",
			"auto_accepted": false,
		})
		return
	}

	// 获取目标用户信息
	var targetUser models.User
	if err := db.First(&targetUser, friendID).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "目标用户不存在"})
		return
	}

	// 获取请求用户信息（用于通知）
	var fromUser models.User
	if err := db.First(&fromUser, userID).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "请求用户不存在"})
		return
	}

	// 根据目标用户的好友添加模式处理
	switch targetUser.FriendAddMode {
	case 0: // 自动同意
		// 直接加好友（互加）
		db.Create(&models.Friend{UserID: userID, FriendID: friendID, CreatedAt: time.Now().Unix()})
		db.Create(&models.Friend{UserID: friendID, FriendID: userID, CreatedAt: time.Now().Unix()})

		// 创建一条已自动同意的好友请求记录（用于历史记录）
		db.Create(&models.FriendRequest{
			FromID:     userID,
			ToID:       friendID,
			Status:     1, // 已同意
			Message:    req.Message,
			SourceType: req.SourceType,
			CreatedAt:  time.Now().Unix(),
		})

		c.JSON(200, gin.H{
			"success":       true,
			"msg":           "已自动添加为好友",
			"auto_accepted": true,
		})
		return

	case 1: // 需要验证
		// 写入好友请求表
		db.Create(&models.FriendRequest{
			FromID:     userID,
			ToID:       friendID,
			Status:     0, // 待处理
			Message:    req.Message,
			SourceType: req.SourceType,
			CreatedAt:  time.Now().Unix(),
		})

		c.JSON(200, gin.H{
			"success":       true,
			"msg":           "好友请求已发送，等待对方同意",
			"auto_accepted": false,
		})
		return

	case 2: // 拒绝所有
		// 创建一条已拒绝的好友请求记录（用于历史记录）
		db.Create(&models.FriendRequest{
			FromID:     userID,
			ToID:       friendID,
			Status:     2, // 已拒绝
			Message:    req.Message,
			SourceType: req.SourceType,
			CreatedAt:  time.Now().Unix(),
		})

		c.JSON(200, gin.H{
			"success":       false,
			"msg":           "对方设置了拒绝所有好友申请",
			"auto_rejected": true,
		})
		return

	default:
		c.JSON(400, gin.H{"success": false, "msg": "未知的好友添加模式"})
		return
	}
}

// 查询加好友方式
func GetFriendAddMode(c *gin.Context) {
	userIDStr := c.Query("user_id")
	userID, _ := strconv.Atoi(userIDStr)
	db := c.MustGet("db").(*gorm.DB)
	var user models.User
	if err := db.First(&user, userID).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "用户不存在"})
		return
	}
	c.JSON(200, gin.H{"success": true, "data": gin.H{"mode": user.FriendAddMode}})
}

// 设置加好友方式
func SetFriendAddMode(c *gin.Context) {
	var req struct {
		UserID uint `json:"user_id"`
		Mode   int  `json:"mode"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	if err := db.Model(&models.User{}).Where("id = ?", req.UserID).Update("friend_add_mode", req.Mode).Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "设置失败"})
		return
	}
	c.JSON(200, gin.H{"success": true, "msg": "设置成功"})
}

// 查询我的好友请求
func GetFriendRequests(c *gin.Context) {
	userIDStr := c.Query("user_id")
	userID, _ := strconv.Atoi(userIDStr)

	// 获取请求类型：received(收到的)、sent(发送的)、all(所有)
	requestType := c.DefaultQuery("type", "received")

	// 获取状态过滤：pending(待处理)、accepted(已接受)、rejected(已拒绝)、all(所有)
	statusFilter := c.DefaultQuery("status", "pending")

	db := c.MustGet("db").(*gorm.DB)

	// 构建查询条件
	query := db

	// 根据请求类型筛选
	switch requestType {
	case "received":
		query = query.Where("to_id = ?", userID)
	case "sent":
		query = query.Where("from_id = ?", userID)
	case "all":
		query = query.Where("to_id = ? OR from_id = ?", userID, userID)
	default:
		query = query.Where("to_id = ?", userID) // 默认查看收到的请求
	}

	// 根据状态筛选
	switch statusFilter {
	case "pending":
		query = query.Where("status = 0")
	case "accepted":
		query = query.Where("status = 1")
	case "rejected":
		query = query.Where("status = 2")
	case "all":
		// 不添加状态过滤
	default:
		query = query.Where("status = 0") // 默认只看待处理的
	}

	// 按时间倒序排列
	query = query.Order("created_at DESC")

	// 执行查询
	var reqs []models.FriendRequest
	query.Find(&reqs)

	// 构建响应，包含用户信息
	var resp []gin.H
	for _, req := range reqs {
		// 获取发送者信息
		var fromUser models.User
		if err := db.First(&fromUser, req.FromID).Error; err != nil {
			continue // 跳过找不到用户的请求
		}

		// 获取接收者信息
		var toUser models.User
		if err := db.First(&toUser, req.ToID).Error; err != nil {
			continue // 跳过找不到用户的请求
		}

		// 构建响应
		resp = append(resp, gin.H{
			"id":          req.ID,
			"from_id":     req.FromID,
			"to_id":       req.ToID,
			"status":      req.Status,
			"message":     req.Message,
			"source_type": req.SourceType,
			"created_at":  req.CreatedAt,
			"from_user": gin.H{
				"id":       fromUser.ID,
				"account":  fromUser.Account,
				"nickname": fromUser.Nickname,
				"avatar":   fromUser.Avatar,
				"gender":   fromUser.Gender,
			},
			"to_user": gin.H{
				"id":       toUser.ID,
				"account":  toUser.Account,
				"nickname": toUser.Nickname,
				"avatar":   toUser.Avatar,
				"gender":   toUser.Gender,
			},
			"is_received": req.ToID == uint(userID),
			"is_sent":     req.FromID == uint(userID),
		})
	}

	c.JSON(200, gin.H{
		"success": true,
		"data":    resp,
		"total":   len(resp),
	})
}

// 同意好友请求
func AgreeFriendRequest(c *gin.Context) {
	var req struct {
		RequestID uint   `json:"request_id"`
		UserID    string `json:"user_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	var fr models.FriendRequest
	if err := db.First(&fr, req.RequestID).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "请求不存在"})
		return
	}
	if fr.Status != 0 {
		c.JSON(400, gin.H{"success": false, "msg": "请求已处理"})
		return
	}
	db.Model(&fr).Update("status", 1)
	db.Create(&models.Friend{UserID: fr.FromID, FriendID: fr.ToID, CreatedAt: time.Now().Unix()})
	db.Create(&models.Friend{UserID: fr.ToID, FriendID: fr.FromID, CreatedAt: time.Now().Unix()})
	c.JSON(200, gin.H{"success": true, "msg": "已同意好友请求"})
}

// 拒绝好友请求
func RejectFriendRequest(c *gin.Context) {
	var req struct {
		RequestID uint   `json:"request_id"`
		UserID    string `json:"user_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	var fr models.FriendRequest
	if err := db.First(&fr, req.RequestID).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "请求不存在"})
		return
	}
	if fr.Status != 0 {
		c.JSON(400, gin.H{"success": false, "msg": "请求已处理"})
		return
	}
	db.Model(&fr).Update("status", 2) // 2表示拒绝
	c.JSON(200, gin.H{"success": true, "msg": "已拒绝好友请求"})
}

// 批量同意好友请求
func BatchAgreeFriendRequests(c *gin.Context) {
	var req struct {
		UserID     string   `json:"user_id"`
		RequestIDs []string `json:"request_ids"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	if len(req.RequestIDs) == 0 {
		c.JSON(400, gin.H{"success": false, "msg": "请求ID列表不能为空"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 转换请求ID为uint切片
	var requestIDs []uint
	for _, idStr := range req.RequestIDs {
		id, err := strconv.ParseUint(idStr, 10, 32)
		if err != nil {
			continue
		}
		requestIDs = append(requestIDs, uint(id))
	}

	if len(requestIDs) == 0 {
		c.JSON(400, gin.H{"success": false, "msg": "无有效的请求ID"})
		return
	}

	// 查询所有待处理的请求
	var requests []models.FriendRequest
	if err := db.Where("id IN ? AND status = 0", requestIDs).Find(&requests).Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "查询请求失败"})
		return
	}

	if len(requests) == 0 {
		c.JSON(400, gin.H{"success": false, "msg": "没有找到待处理的请求"})
		return
	}

	// 开始事务
	tx := db.Begin()

	successCount := 0
	for _, fr := range requests {
		// 更新请求状态为已同意
		if err := tx.Model(&fr).Update("status", 1).Error; err != nil {
			tx.Rollback()
			c.JSON(500, gin.H{"success": false, "msg": "处理请求失败"})
			return
		}

		// 创建好友关系（双向）
		if err := tx.Create(&models.Friend{UserID: fr.FromID, FriendID: fr.ToID, CreatedAt: time.Now().Unix()}).Error; err != nil {
			tx.Rollback()
			c.JSON(500, gin.H{"success": false, "msg": "创建好友关系失败"})
			return
		}

		if err := tx.Create(&models.Friend{UserID: fr.ToID, FriendID: fr.FromID, CreatedAt: time.Now().Unix()}).Error; err != nil {
			tx.Rollback()
			c.JSON(500, gin.H{"success": false, "msg": "创建好友关系失败"})
			return
		}

		successCount++
	}

	// 提交事务
	if err := tx.Commit().Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "提交事务失败"})
		return
	}

	c.JSON(200, gin.H{
		"success": true,
		"msg":     fmt.Sprintf("已同意 %d 个好友请求", successCount),
		"count":   successCount,
	})
}

// 批量拒绝好友请求
func BatchRejectFriendRequests(c *gin.Context) {
	var req struct {
		UserID     string   `json:"user_id"`
		RequestIDs []string `json:"request_ids"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	if len(req.RequestIDs) == 0 {
		c.JSON(400, gin.H{"success": false, "msg": "请求ID列表不能为空"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 转换请求ID为uint切片
	var requestIDs []uint
	for _, idStr := range req.RequestIDs {
		id, err := strconv.ParseUint(idStr, 10, 32)
		if err != nil {
			continue
		}
		requestIDs = append(requestIDs, uint(id))
	}

	if len(requestIDs) == 0 {
		c.JSON(400, gin.H{"success": false, "msg": "无有效的请求ID"})
		return
	}

	// 查询所有待处理的请求
	var requests []models.FriendRequest
	if err := db.Where("id IN ? AND status = 0", requestIDs).Find(&requests).Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "查询请求失败"})
		return
	}

	if len(requests) == 0 {
		c.JSON(400, gin.H{"success": false, "msg": "没有找到待处理的请求"})
		return
	}

	// 开始事务
	tx := db.Begin()

	successCount := 0
	for _, fr := range requests {
		// 更新请求状态为已拒绝
		if err := tx.Model(&fr).Update("status", 2).Error; err != nil {
			tx.Rollback()
			c.JSON(500, gin.H{"success": false, "msg": "处理请求失败"})
			return
		}
		successCount++
	}

	// 提交事务
	if err := tx.Commit().Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "提交事务失败"})
		return
	}

	c.JSON(200, gin.H{
		"success": true,
		"msg":     fmt.Sprintf("已拒绝 %d 个好友请求", successCount),
		"count":   successCount,
	})
}

// 搜索用户
func SearchUsers(c *gin.Context) {
	keyword := c.Query("keyword")
	if keyword == "" {
		c.JSON(400, gin.H{"success": false, "msg": "搜索关键词不能为空"})
		return
	}

	// 获取当前用户ID（用于检查好友关系）
	currentUserIDStr := c.Query("current_user_id")
	var currentUserID uint = 0
	if currentUserIDStr != "" {
		id, err := strconv.Atoi(currentUserIDStr)
		if err == nil {
			currentUserID = uint(id)
		}
	}

	db := c.MustGet("db").(*gorm.DB)
	var users []models.User

	// 创建一个map来存储已经找到的用户ID，避免重复
	foundUserIDs := make(map[uint]bool)

	// 尝试按账号精确查找
	if _, err := strconv.Atoi(keyword); err == nil {
		var accountUsers []models.User
		db.Where("account = ?", keyword).Find(&accountUsers)

		for _, u := range accountUsers {
			if !foundUserIDs[u.ID] {
				users = append(users, u)
				foundUserIDs[u.ID] = true
			}
		}
	}

	// 同时尝试按昵称模糊查找
	var nicknameUsers []models.User
	db.Where("nickname LIKE ?", "%"+keyword+"%").Limit(20).Find(&nicknameUsers)

	for _, u := range nicknameUsers {
		if !foundUserIDs[u.ID] {
			users = append(users, u)
			foundUserIDs[u.ID] = true
		}
	}

	// 如果是邮箱格式，尝试按邮箱查找
	if strings.Contains(keyword, "@") {
		var emailUsers []models.User
		db.Where("email = ? OR generated_email = ?", keyword, keyword).Find(&emailUsers)

		for _, u := range emailUsers {
			if !foundUserIDs[u.ID] {
				users = append(users, u)
				foundUserIDs[u.ID] = true
			}
		}
	}

	// 尝试按手机号查找
	var phoneUsers []models.User
	db.Where("phone = ?", keyword).Find(&phoneUsers)

	for _, u := range phoneUsers {
		if !foundUserIDs[u.ID] {
			users = append(users, u)
			foundUserIDs[u.ID] = true
		}
	}

	// 构建响应，不返回敏感信息
	var resp []gin.H
	for _, u := range users {
		// 检查是否已经是好友（如果提供了当前用户ID）
		isFriend := false
		if currentUserID > 0 {
			var friend models.Friend
			if err := db.Where("user_id = ? AND friend_id = ?", currentUserID, u.ID).First(&friend).Error; err == nil {
				isFriend = true
			}
		}

		// 检查是否有待处理的好友请求
		hasPendingRequest := false
		if currentUserID > 0 {
			var request models.FriendRequest
			if err := db.Where("(from_id = ? AND to_id = ?) OR (from_id = ? AND to_id = ?) AND status = 0",
				currentUserID, u.ID, u.ID, currentUserID).First(&request).Error; err == nil {
				hasPendingRequest = true
			}
		}

		resp = append(resp, gin.H{
			"id":                  u.ID,
			"account":             u.Account,
			"nickname":            u.Nickname,
			"avatar":              u.Avatar,
			"gender":              u.Gender,
			"is_friend":           isFriend,
			"has_pending_request": hasPendingRequest,
			"friend_add_mode":     u.FriendAddMode,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    resp,
		"total":   len(resp),
	})
}
