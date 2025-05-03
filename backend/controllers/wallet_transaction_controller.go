package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// 获取交易记录（高级筛选）
func GetTransactionsAdvanced(c *gin.Context) {
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
	transactionType := c.Query("type") // 交易类型: recharge, withdraw, transfer_in, transfer_out, redpacket_in, redpacket_out
	startTimeStr := c.Query("start_time")
	endTimeStr := c.Query("end_time")
	minAmount := c.Query("min_amount")
	maxAmount := c.Query("max_amount")
	status := c.Query("status") // 交易状态: pending, success, failed

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize

	utils.Logger.Infof("获取交易记录(高级筛选): userID=%d, page=%d, pageSize=%d, type=%s, startTime=%s, endTime=%s, minAmount=%s, maxAmount=%s, status=%s",
		userID, page, pageSize, transactionType, startTimeStr, endTimeStr, minAmount, maxAmount, status)

	db := c.MustGet("db").(*gorm.DB)

	// 构建查询条件
	query := db.Model(&models.Transaction{}).Where("user_id = ?", userID)

	// 按交易类型筛选
	if transactionType != "" {
		query = query.Where("type = ?", transactionType)
	}

	// 按时间范围筛选
	if startTimeStr != "" {
		startTime, err := strconv.ParseInt(startTimeStr, 10, 64)
		if err == nil {
			query = query.Where("created_at >= ?", startTime)
		}
	}
	if endTimeStr != "" {
		endTime, err := strconv.ParseInt(endTimeStr, 10, 64)
		if err == nil {
			query = query.Where("created_at <= ?", endTime)
		}
	}

	// 按金额范围筛选
	if minAmount != "" {
		minAmountFloat, err := strconv.ParseFloat(minAmount, 64)
		if err == nil {
			query = query.Where("ABS(amount) >= ?", minAmountFloat)
		}
	}
	if maxAmount != "" {
		maxAmountFloat, err := strconv.ParseFloat(maxAmount, 64)
		if err == nil {
			query = query.Where("ABS(amount) <= ?", maxAmountFloat)
		}
	}

	// 按状态筛选
	if status != "" {
		query = query.Where("status = ?", status)
	}

	// 查询交易记录总数
	var total int64
	query.Count(&total)

	// 查询交易记录
	var transactions []models.Transaction
	query.Order("created_at DESC").
		Offset(offset).
		Limit(pageSize).
		Find(&transactions)

	utils.Logger.Infof("获取到交易记录(高级筛选): userID=%d, 总数=%d, 本页数量=%d", userID, total, len(transactions))
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取交易记录成功",
		"data": gin.H{
			"total":        total,
			"page":         page,
			"page_size":    pageSize,
			"transactions": transactions,
		},
	})
}

// 获取交易统计
func GetTransactionStats(c *gin.Context) {
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
	period := c.DefaultQuery("period", "month") // day, week, month, year
	startTimeStr := c.Query("start_time")
	endTimeStr := c.Query("end_time")

	utils.Logger.Infof("获取交易统计: userID=%d, period=%s, startTime=%s, endTime=%s",
		userID, period, startTimeStr, endTimeStr)

	db := c.MustGet("db").(*gorm.DB)

	// 构建查询条件
	query := db.Model(&models.Transaction{}).Where("user_id = ?", userID)

	// 设置默认时间范围
	var startTime, endTime int64
	now := time.Now()
	endTime = now.Unix()

	if startTimeStr != "" && endTimeStr != "" {
		// 如果提供了明确的时间范围，使用提供的范围
		startTime, _ = strconv.ParseInt(startTimeStr, 10, 64)
		endTime, _ = strconv.ParseInt(endTimeStr, 10, 64)
	} else {
		// 否则根据周期设置默认范围
		switch period {
		case "day":
			startTime = now.Add(-24 * time.Hour).Unix()
		case "week":
			startTime = now.Add(-7 * 24 * time.Hour).Unix()
		case "month":
			startTime = now.Add(-30 * 24 * time.Hour).Unix()
		case "year":
			startTime = now.Add(-365 * 24 * time.Hour).Unix()
		default:
			startTime = now.Add(-30 * 24 * time.Hour).Unix() // 默认为一个月
		}
	}

	query = query.Where("created_at >= ? AND created_at <= ?", startTime, endTime)

	// 计算总收入（正数金额）
	var totalIncome float64
	query.Where("amount > 0").Select("COALESCE(SUM(amount), 0) as total").Row().Scan(&totalIncome)

	// 计算总支出（负数金额的绝对值）
	var totalExpense float64
	query.Where("amount < 0").Select("COALESCE(SUM(ABS(amount)), 0) as total").Row().Scan(&totalExpense)

	// 按类型统计交易数量
	var typeStats []struct {
		Type  string `json:"type"`
		Count int    `json:"count"`
	}
	query.Select("type, COUNT(*) as count").Group("type").Scan(&typeStats)

	// 按天统计交易金额
	var dailyStats []struct {
		Date   string  `json:"date"`
		Income float64 `json:"income"`
		Expense float64 `json:"expense"`
	}

	// 这里简化处理，实际应根据数据库类型使用适当的日期函数
	// 对于SQLite，可以使用strftime函数
	query.Select("strftime('%Y-%m-%d', datetime(created_at, 'unixepoch')) as date, " +
		"COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 0) as income, " +
		"COALESCE(SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END), 0) as expense").
		Group("date").
		Order("date").
		Scan(&dailyStats)

	utils.Logger.Infof("获取到交易统计: userID=%d, 总收入=%f, 总支出=%f", userID, totalIncome, totalExpense)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取交易统计成功",
		"data": gin.H{
			"period":        period,
			"start_time":    startTime,
			"end_time":      endTime,
			"total_income":  totalIncome,
			"total_expense": totalExpense,
			"type_stats":    typeStats,
			"daily_stats":   dailyStats,
		},
	})
}

// 获取交易详情
func GetTransactionDetail(c *gin.Context) {
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

	// 获取交易ID
	transactionID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		utils.Logger.Errorf("交易ID无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "交易ID无效"})
		return
	}

	utils.Logger.Infof("获取交易详情: userID=%d, transactionID=%d", userID, transactionID)

	db := c.MustGet("db").(*gorm.DB)

	// 查询交易记录
	var transaction models.Transaction
	if err := db.Where("id = ? AND user_id = ?", transactionID, userID).First(&transaction).Error; err != nil {
		utils.Logger.Errorf("查询交易记录失败: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "交易记录不存在"})
		return
	}

	// 根据交易类型获取相关详情
	var relatedData interface{}
	switch transaction.Type {
	case "recharge":
		var recharge models.Recharge
		if err := db.Where("id = ?", transaction.RelatedID).First(&recharge).Error; err == nil {
			// 如果是银行卡充值，获取银行卡信息
			if recharge.PaymentMethod == "bank_card" {
				var bankCard models.BankCard
				if err := db.Where("id = ?", recharge.BankCardID).First(&bankCard).Error; err == nil {
					relatedData = gin.H{
						"recharge":   recharge,
						"bank_card":  bankCard,
					}
				} else {
					relatedData = recharge
				}
			} else {
				relatedData = recharge
			}
		}
	case "withdraw":
		var withdraw models.Withdraw
		if err := db.Where("id = ?", transaction.RelatedID).First(&withdraw).Error; err == nil {
			// 获取银行卡信息
			var bankCard models.BankCard
			if err := db.Where("id = ?", withdraw.BankCardID).First(&bankCard).Error; err == nil {
				relatedData = gin.H{
					"withdraw":   withdraw,
					"bank_card":  bankCard,
				}
			} else {
				relatedData = withdraw
			}
		}
	case "transfer_in", "transfer_out":
		var transfer models.Transfer
		if err := db.Where("id = ?", transaction.RelatedID).First(&transfer).Error; err == nil {
			// 获取对方用户信息
			var otherUserID uint
			if transaction.Type == "transfer_in" {
				otherUserID = transfer.SenderID
			} else {
				otherUserID = transfer.ReceiverID
			}
			
			var otherUser models.User
			if err := db.Select("id, account, nickname, avatar").Where("id = ?", otherUserID).First(&otherUser).Error; err == nil {
				relatedData = gin.H{
					"transfer":   transfer,
					"other_user": otherUser,
				}
			} else {
				relatedData = transfer
			}
		}
	case "redpacket_in", "redpacket_out":
		var redPacket models.RedPacket
		if err := db.Where("id = ?", transaction.RelatedID).First(&redPacket).Error; err == nil {
			// 获取红包记录
			var records []models.RedPacketRecord
			db.Where("red_packet_id = ?", redPacket.ID).Find(&records)
			
			relatedData = gin.H{
				"red_packet": redPacket,
				"records":    records,
			}
		}
	}

	utils.Logger.Infof("获取到交易详情: userID=%d, transactionID=%d, type=%s", userID, transactionID, transaction.Type)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取交易详情成功",
		"data": gin.H{
			"transaction": transaction,
			"related":     relatedData,
		},
	})
}
