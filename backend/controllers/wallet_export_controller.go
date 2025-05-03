package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// 导出交易记录为CSV
func ExportTransactionsCSV(c *gin.Context) {
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
	startTimeStr := c.DefaultQuery("start_time", "")
	endTimeStr := c.DefaultQuery("end_time", "")
	transactionType := c.DefaultQuery("type", "")

	utils.Logger.Infof("导出交易记录CSV: userID=%d, startTime=%s, endTime=%s, type=%s", 
		userID, startTimeStr, endTimeStr, transactionType)

	db := c.MustGet("db").(*gorm.DB)

	// 构建查询条件
	query := db.Model(&models.Transaction{}).Where("user_id = ?", userID)

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

	// 按交易类型筛选
	if transactionType != "" {
		query = query.Where("type = ?", transactionType)
	}

	// 查询交易记录
	var transactions []models.Transaction
	if err := query.Order("created_at DESC").Find(&transactions).Error; err != nil {
		utils.Logger.Errorf("查询交易记录失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询交易记录失败"})
		return
	}

	// 创建临时文件
	now := time.Now()
	fileName := fmt.Sprintf("transactions_%d_%s.csv", userID, now.Format("20060102150405"))
	filePath := filepath.Join(os.TempDir(), fileName)

	file, err := os.Create(filePath)
	if err != nil {
		utils.Logger.Errorf("创建CSV文件失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建CSV文件失败"})
		return
	}
	defer file.Close()

	// 写入UTF-8 BOM，以便Excel正确识别中文
	file.Write([]byte{0xEF, 0xBB, 0xBF})

	// 创建CSV写入器
	writer := csv.NewWriter(file)
	defer writer.Flush()

	// 写入CSV头
	headers := []string{"交易ID", "交易类型", "金额", "余额", "描述", "状态", "交易时间"}
	if err := writer.Write(headers); err != nil {
		utils.Logger.Errorf("写入CSV头失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "写入CSV头失败"})
		return
	}

	// 写入交易记录
	for _, transaction := range transactions {
		// 将时间戳转换为可读时间
		transactionTime := time.Unix(transaction.CreatedAt, 0).Format("2006-01-02 15:04:05")
		
		// 将交易类型转换为中文
		var typeText string
		switch transaction.Type {
		case "recharge":
			typeText = "充值"
		case "withdraw":
			typeText = "提现"
		case "transfer_in":
			typeText = "转入"
		case "transfer_out":
			typeText = "转出"
		case "redpacket_in":
			typeText = "收红包"
		case "redpacket_out":
			typeText = "发红包"
		case "deposit":
			typeText = "定期存款"
		case "deposit_withdraw":
			typeText = "提前支取存款"
		case "deposit_interest":
			typeText = "存款利息"
		case "investment":
			typeText = "购买理财"
		case "investment_withdraw":
			typeText = "赎回理财"
		case "investment_profit":
			typeText = "理财收益"
		default:
			typeText = transaction.Type
		}

		record := []string{
			strconv.FormatUint(uint64(transaction.ID), 10),
			typeText,
			strconv.FormatFloat(transaction.Amount, 'f', 2, 64),
			strconv.FormatFloat(transaction.Balance, 'f', 2, 64),
			transaction.Description,
			transaction.Status,
			transactionTime,
		}

		if err := writer.Write(record); err != nil {
			utils.Logger.Errorf("写入CSV记录失败: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "写入CSV记录失败"})
			return
		}
	}

	// 设置响应头
	c.Header("Content-Description", "File Transfer")
	c.Header("Content-Disposition", "attachment; filename="+fileName)
	c.Header("Content-Type", "text/csv")
	c.Header("Content-Transfer-Encoding", "binary")
	c.Header("Expires", "0")
	c.Header("Cache-Control", "must-revalidate")
	c.Header("Pragma", "public")

	// 发送文件
	c.File(filePath)

	// 记录日志
	utils.Logger.Infof("导出交易记录CSV成功: userID=%d, 记录数=%d, 文件名=%s", 
		userID, len(transactions), fileName)
}

// 导出交易记录为JSON
func ExportTransactionsJSON(c *gin.Context) {
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
	startTimeStr := c.DefaultQuery("start_time", "")
	endTimeStr := c.DefaultQuery("end_time", "")
	transactionType := c.DefaultQuery("type", "")

	utils.Logger.Infof("导出交易记录JSON: userID=%d, startTime=%s, endTime=%s, type=%s", 
		userID, startTimeStr, endTimeStr, transactionType)

	db := c.MustGet("db").(*gorm.DB)

	// 构建查询条件
	query := db.Model(&models.Transaction{}).Where("user_id = ?", userID)

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

	// 按交易类型筛选
	if transactionType != "" {
		query = query.Where("type = ?", transactionType)
	}

	// 查询交易记录
	var transactions []models.Transaction
	if err := query.Order("created_at DESC").Find(&transactions).Error; err != nil {
		utils.Logger.Errorf("查询交易记录失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询交易记录失败"})
		return
	}

	// 创建临时文件
	now := time.Now()
	fileName := fmt.Sprintf("transactions_%d_%s.json", userID, now.Format("20060102150405"))
	filePath := filepath.Join(os.TempDir(), fileName)

	file, err := os.Create(filePath)
	if err != nil {
		utils.Logger.Errorf("创建JSON文件失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建JSON文件失败"})
		return
	}
	defer file.Close()

	// 将交易记录转换为JSON格式
	jsonData, err := json.MarshalIndent(transactions, "", "  ")
	if err != nil {
		utils.Logger.Errorf("转换JSON失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "转换JSON失败"})
		return
	}

	// 写入JSON文件
	if _, err := file.Write(jsonData); err != nil {
		utils.Logger.Errorf("写入JSON文件失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "写入JSON文件失败"})
		return
	}

	// 设置响应头
	c.Header("Content-Description", "File Transfer")
	c.Header("Content-Disposition", "attachment; filename="+fileName)
	c.Header("Content-Type", "application/json")
	c.Header("Content-Transfer-Encoding", "binary")
	c.Header("Expires", "0")
	c.Header("Cache-Control", "must-revalidate")
	c.Header("Pragma", "public")

	// 发送文件
	c.File(filePath)

	// 记录日志
	utils.Logger.Infof("导出交易记录JSON成功: userID=%d, 记录数=%d, 文件名=%s", 
		userID, len(transactions), fileName)
}

// 导出账单月报
func ExportMonthlyStatement(c *gin.Context) {
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
	yearStr := c.DefaultQuery("year", strconv.Itoa(time.Now().Year()))
	monthStr := c.DefaultQuery("month", strconv.Itoa(int(time.Now().Month())))

	year, err := strconv.Atoi(yearStr)
	if err != nil {
		utils.Logger.Errorf("年份参数无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "年份参数无效"})
		return
	}

	month, err := strconv.Atoi(monthStr)
	if err != nil || month < 1 || month > 12 {
		utils.Logger.Errorf("月份参数无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "月份参数无效"})
		return
	}

	utils.Logger.Infof("导出账单月报: userID=%d, year=%d, month=%d", userID, year, month)

	db := c.MustGet("db").(*gorm.DB)

	// 计算月份的开始和结束时间
	startTime := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, time.Local).Unix()
	endTime := time.Date(year, time.Month(month+1), 0, 23, 59, 59, 999999999, time.Local).Unix()

	// 查询用户信息
	var user models.User
	if err := db.Select("id, account, nickname").Where("id = ?", userID).First(&user).Error; err != nil {
		utils.Logger.Errorf("查询用户信息失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询用户信息失败"})
		return
	}

	// 查询钱包信息
	var wallet models.Wallet
	if err := db.Where("user_id = ?", userID).First(&wallet).Error; err != nil {
		utils.Logger.Errorf("查询钱包信息失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询钱包信息失败"})
		return
	}

	// 查询月初余额（找到月初前最后一笔交易的余额）
	var initialBalance float64
	var lastTransaction models.Transaction
	if err := db.Where("user_id = ? AND created_at < ?", userID, startTime).
		Order("created_at DESC").First(&lastTransaction).Error; err == nil {
		initialBalance = lastTransaction.Balance
	}

	// 查询月末余额（找到月末最后一笔交易的余额）
	var finalBalance float64 = initialBalance
	var lastMonthTransaction models.Transaction
	if err := db.Where("user_id = ? AND created_at <= ?", userID, endTime).
		Order("created_at DESC").First(&lastMonthTransaction).Error; err == nil {
		finalBalance = lastMonthTransaction.Balance
	}

	// 查询月内所有交易
	var transactions []models.Transaction
	if err := db.Where("user_id = ? AND created_at >= ? AND created_at <= ?", userID, startTime, endTime).
		Order("created_at").Find(&transactions).Error; err != nil {
		utils.Logger.Errorf("查询交易记录失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询交易记录失败"})
		return
	}

	// 计算月内总收入和总支出
	var totalIncome, totalExpense float64
	for _, transaction := range transactions {
		if transaction.Amount > 0 {
			totalIncome += transaction.Amount
		} else {
			totalExpense += -transaction.Amount
		}
	}

	// 按交易类型统计
	typeStats := make(map[string]float64)
	for _, transaction := range transactions {
		if transaction.Amount < 0 {
			typeStats[transaction.Type] += -transaction.Amount
		}
	}

	// 创建临时文件
	fileName := fmt.Sprintf("monthly_statement_%d_%d_%02d.csv", userID, year, month)
	filePath := filepath.Join(os.TempDir(), fileName)

	file, err := os.Create(filePath)
	if err != nil {
		utils.Logger.Errorf("创建CSV文件失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建CSV文件失败"})
		return
	}
	defer file.Close()

	// 写入UTF-8 BOM，以便Excel正确识别中文
	file.Write([]byte{0xEF, 0xBB, 0xBF})

	// 创建CSV写入器
	writer := csv.NewWriter(file)
	defer writer.Flush()

	// 写入账单头部信息
	writer.Write([]string{"账单月报"})
	writer.Write([]string{"账户", user.Account})
	writer.Write([]string{"用户名", user.Nickname})
	writer.Write([]string{"账单周期", fmt.Sprintf("%d年%d月", year, month)})
	writer.Write([]string{"生成时间", time.Now().Format("2006-01-02 15:04:05")})
	writer.Write([]string{})

	// 写入账单摘要
	writer.Write([]string{"账单摘要"})
	writer.Write([]string{"月初余额", strconv.FormatFloat(initialBalance, 'f', 2, 64)})
	writer.Write([]string{"月末余额", strconv.FormatFloat(finalBalance, 'f', 2, 64)})
	writer.Write([]string{"月内收入", strconv.FormatFloat(totalIncome, 'f', 2, 64)})
	writer.Write([]string{"月内支出", strconv.FormatFloat(totalExpense, 'f', 2, 64)})
	writer.Write([]string{"净收入", strconv.FormatFloat(totalIncome-totalExpense, 'f', 2, 64)})
	writer.Write([]string{})

	// 写入支出分类统计
	writer.Write([]string{"支出分类统计"})
	for typeName, amount := range typeStats {
		// 将交易类型转换为中文
		var typeText string
		switch typeName {
		case "recharge":
			typeText = "充值"
		case "withdraw":
			typeText = "提现"
		case "transfer_in":
			typeText = "转入"
		case "transfer_out":
			typeText = "转出"
		case "redpacket_in":
			typeText = "收红包"
		case "redpacket_out":
			typeText = "发红包"
		case "deposit":
			typeText = "定期存款"
		case "deposit_withdraw":
			typeText = "提前支取存款"
		case "deposit_interest":
			typeText = "存款利息"
		case "investment":
			typeText = "购买理财"
		case "investment_withdraw":
			typeText = "赎回理财"
		case "investment_profit":
			typeText = "理财收益"
		default:
			typeText = typeName
		}
		writer.Write([]string{typeText, strconv.FormatFloat(amount, 'f', 2, 64)})
	}
	writer.Write([]string{})

	// 写入交易明细
	writer.Write([]string{"交易明细"})
	writer.Write([]string{"交易时间", "交易类型", "金额", "余额", "描述", "状态"})
	for _, transaction := range transactions {
		// 将时间戳转换为可读时间
		transactionTime := time.Unix(transaction.CreatedAt, 0).Format("2006-01-02 15:04:05")
		
		// 将交易类型转换为中文
		var typeText string
		switch transaction.Type {
		case "recharge":
			typeText = "充值"
		case "withdraw":
			typeText = "提现"
		case "transfer_in":
			typeText = "转入"
		case "transfer_out":
			typeText = "转出"
		case "redpacket_in":
			typeText = "收红包"
		case "redpacket_out":
			typeText = "发红包"
		case "deposit":
			typeText = "定期存款"
		case "deposit_withdraw":
			typeText = "提前支取存款"
		case "deposit_interest":
			typeText = "存款利息"
		case "investment":
			typeText = "购买理财"
		case "investment_withdraw":
			typeText = "赎回理财"
		case "investment_profit":
			typeText = "理财收益"
		default:
			typeText = transaction.Type
		}

		writer.Write([]string{
			transactionTime,
			typeText,
			strconv.FormatFloat(transaction.Amount, 'f', 2, 64),
			strconv.FormatFloat(transaction.Balance, 'f', 2, 64),
			transaction.Description,
			transaction.Status,
		})
	}

	// 设置响应头
	c.Header("Content-Description", "File Transfer")
	c.Header("Content-Disposition", "attachment; filename="+fileName)
	c.Header("Content-Type", "text/csv")
	c.Header("Content-Transfer-Encoding", "binary")
	c.Header("Expires", "0")
	c.Header("Cache-Control", "must-revalidate")
	c.Header("Pragma", "public")

	// 发送文件
	c.File(filePath)

	// 记录日志
	utils.Logger.Infof("导出账单月报成功: userID=%d, year=%d, month=%d, 交易数=%d", 
		userID, year, month, len(transactions))
}
