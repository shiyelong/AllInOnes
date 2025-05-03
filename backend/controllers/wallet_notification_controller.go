package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// 创建交易通知
func createTransactionNotification(db *gorm.DB, userID uint, transactionType string, amount float64, description string) error {
	now := time.Now().Unix()
	
	// 构建通知内容
	var title, content string
	
	switch transactionType {
	case "recharge":
		title = "充值成功"
		content = fmt.Sprintf("您已成功充值 %.2f 元。%s", amount, description)
	case "withdraw":
		title = "提现成功"
		content = fmt.Sprintf("您已成功提现 %.2f 元。%s", amount, description)
	case "transfer_in":
		title = "收到转账"
		content = fmt.Sprintf("您收到一笔 %.2f 元的转账。%s", amount, description)
	case "transfer_out":
		title = "转账成功"
		content = fmt.Sprintf("您已成功转出 %.2f 元。%s", amount, description)
	case "redpacket_in":
		title = "收到红包"
		content = fmt.Sprintf("您收到一个 %.2f 元的红包。%s", amount, description)
	case "redpacket_out":
		title = "发出红包"
		content = fmt.Sprintf("您已成功发出 %.2f 元的红包。%s", amount, description)
	default:
		title = "交易通知"
		content = fmt.Sprintf("您有一笔 %.2f 元的交易。%s", amount, description)
	}
	
	// 创建通知
	notification := models.Notification{
		UserID:    userID,
		Title:     title,
		Content:   content,
		Type:      "transaction",
		Status:    "unread",
		CreatedAt: now,
		UpdatedAt: now,
	}
	
	return db.Create(&notification).Error
}

// 获取交易通知
func GetTransactionNotifications(c *gin.Context) {
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
	status := c.Query("status") // 通知状态: unread, read, all

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize

	utils.Logger.Infof("获取交易通知: userID=%d, page=%d, pageSize=%d, status=%s", userID, page, pageSize, status)

	db := c.MustGet("db").(*gorm.DB)

	// 构建查询条件
	query := db.Model(&models.Notification{}).Where("user_id = ? AND type = 'transaction'", userID)

	// 按状态筛选
	if status == "unread" {
		query = query.Where("status = 'unread'")
	} else if status == "read" {
		query = query.Where("status = 'read'")
	}

	// 查询通知总数
	var total int64
	query.Count(&total)

	// 查询通知
	var notifications []models.Notification
	query.Order("created_at DESC").
		Offset(offset).
		Limit(pageSize).
		Find(&notifications)

	utils.Logger.Infof("获取到交易通知: userID=%d, 总数=%d, 本页数量=%d", userID, total, len(notifications))
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取交易通知成功",
		"data": gin.H{
			"total":         total,
			"page":          page,
			"page_size":     pageSize,
			"notifications": notifications,
		},
	})
}

// 标记通知为已读
func MarkNotificationRead(c *gin.Context) {
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

	// 获取通知ID
	notificationID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		utils.Logger.Errorf("通知ID无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "通知ID无效"})
		return
	}

	utils.Logger.Infof("标记通知为已读: userID=%d, notificationID=%d", userID, notificationID)

	db := c.MustGet("db").(*gorm.DB)

	// 查询通知
	var notification models.Notification
	if err := db.Where("id = ? AND user_id = ?", notificationID, userID).First(&notification).Error; err != nil {
		utils.Logger.Errorf("查询通知失败: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "通知不存在"})
		return
	}

	// 更新通知状态
	notification.Status = "read"
	notification.UpdatedAt = time.Now().Unix()
	if err := db.Save(&notification).Error; err != nil {
		utils.Logger.Errorf("更新通知状态失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新通知状态失败"})
		return
	}

	utils.Logger.Infof("标记通知为已读成功: userID=%d, notificationID=%d", userID, notificationID)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "标记通知为已读成功",
	})
}

// 标记所有通知为已读
func MarkAllNotificationsRead(c *gin.Context) {
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

	utils.Logger.Infof("标记所有通知为已读: userID=%d", userID)

	db := c.MustGet("db").(*gorm.DB)

	// 更新所有未读通知状态
	now := time.Now().Unix()
	result := db.Model(&models.Notification{}).
		Where("user_id = ? AND type = 'transaction' AND status = 'unread'", userID).
		Updates(map[string]interface{}{
			"status":     "read",
			"updated_at": now,
		})

	if result.Error != nil {
		utils.Logger.Errorf("更新通知状态失败: %v", result.Error)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新通知状态失败"})
		return
	}

	utils.Logger.Infof("标记所有通知为已读成功: userID=%d, 更新数量=%d", userID, result.RowsAffected)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "标记所有通知为已读成功",
		"data": gin.H{
			"updated_count": result.RowsAffected,
		},
	})
}

// 获取未读通知数量
func GetUnreadNotificationCount(c *gin.Context) {
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

	utils.Logger.Infof("获取未读通知数量: userID=%d", userID)

	db := c.MustGet("db").(*gorm.DB)

	// 查询未读通知数量
	var count int64
	db.Model(&models.Notification{}).
		Where("user_id = ? AND type = 'transaction' AND status = 'unread'", userID).
		Count(&count)

	utils.Logger.Infof("获取到未读通知数量: userID=%d, count=%d", userID, count)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取未读通知数量成功",
		"data": gin.H{
			"unread_count": count,
		},
	})
}
