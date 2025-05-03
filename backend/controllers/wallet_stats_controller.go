package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// 获取钱包概览
func GetWalletOverview(c *gin.Context) {
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

	utils.Logger.Infof("获取钱包概览: userID=%d", userID)

	db := c.MustGet("db").(*gorm.DB)

	// 查询钱包信息
	var wallet models.Wallet
	if err := db.Where("user_id = ?", userID).First(&wallet).Error; err != nil {
		utils.Logger.Errorf("查询钱包失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询钱包失败"})
		return
	}

	// 获取今日收支
	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location()).Unix()
	todayEnd := time.Date(now.Year(), now.Month(), now.Day(), 23, 59, 59, 999999999, now.Location()).Unix()

	// 今日收入
	var todayIncome float64
	db.Model(&models.Transaction{}).
		Where("user_id = ? AND amount > 0 AND created_at >= ? AND created_at <= ?", userID, todayStart, todayEnd).
		Select("COALESCE(SUM(amount), 0) as total").
		Row().
		Scan(&todayIncome)

	// 今日支出
	var todayExpense float64
	db.Model(&models.Transaction{}).
		Where("user_id = ? AND amount < 0 AND created_at >= ? AND created_at <= ?", userID, todayStart, todayEnd).
		Select("COALESCE(SUM(ABS(amount)), 0) as total").
		Row().
		Scan(&todayExpense)

	// 获取本月收支
	monthStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location()).Unix()
	monthEnd := time.Date(now.Year(), now.Month()+1, 0, 23, 59, 59, 999999999, now.Location()).Unix()

	// 本月收入
	var monthIncome float64
	db.Model(&models.Transaction{}).
		Where("user_id = ? AND amount > 0 AND created_at >= ? AND created_at <= ?", userID, monthStart, monthEnd).
		Select("COALESCE(SUM(amount), 0) as total").
		Row().
		Scan(&monthIncome)

	// 本月支出
	var monthExpense float64
	db.Model(&models.Transaction{}).
		Where("user_id = ? AND amount < 0 AND created_at >= ? AND created_at <= ?", userID, monthStart, monthEnd).
		Select("COALESCE(SUM(ABS(amount)), 0) as total").
		Row().
		Scan(&monthExpense)

	// 获取最近交易记录
	var recentTransactions []models.Transaction
	db.Where("user_id = ?", userID).
		Order("created_at DESC").
		Limit(5).
		Find(&recentTransactions)

	// 获取银行卡数量
	var bankCardCount int64
	db.Model(&models.BankCard{}).Where("user_id = ?", userID).Count(&bankCardCount)

	// 获取虚拟货币钱包数量
	var cryptoWalletCount int64
	db.Model(&models.CryptoWallet{}).Where("user_id = ?", userID).Count(&cryptoWalletCount)

	utils.Logger.Infof("获取到钱包概览: userID=%d, 余额=%f, 今日收入=%f, 今日支出=%f, 本月收入=%f, 本月支出=%f",
		userID, wallet.Balance, todayIncome, todayExpense, monthIncome, monthExpense)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取钱包概览成功",
		"data": gin.H{
			"balance":             wallet.Balance,
			"today_income":        todayIncome,
			"today_expense":       todayExpense,
			"month_income":        monthIncome,
			"month_expense":       monthExpense,
			"recent_transactions": recentTransactions,
			"bank_card_count":     bankCardCount,
			"crypto_wallet_count": cryptoWalletCount,
			"security_level":      wallet.SecurityLevel,
			"pay_password_set":    wallet.PayPasswordSet,
		},
	})
}

// 获取收支趋势
func GetIncomeTrend(c *gin.Context) {
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
	period := c.DefaultQuery("period", "month")  // day, week, month, year
	groupBy := c.DefaultQuery("group_by", "day") // day, week, month

	utils.Logger.Infof("获取收支趋势: userID=%d, period=%s, groupBy=%s", userID, period, groupBy)

	db := c.MustGet("db").(*gorm.DB)

	// 设置时间范围
	var startTime, endTime int64
	now := time.Now()
	endTime = now.Unix()

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

	// 构建查询
	query := db.Model(&models.Transaction{}).
		Where("user_id = ? AND created_at >= ? AND created_at <= ?", userID, startTime, endTime)

	// 根据分组方式构建SQL
	var groupFormat string
	switch groupBy {
	case "day":
		groupFormat = "%Y-%m-%d"
	case "week":
		groupFormat = "%Y-%W" // 年-周数
	case "month":
		groupFormat = "%Y-%m"
	default:
		groupFormat = "%Y-%m-%d" // 默认按天分组
	}

	// 按时间分组统计收支
	var trends []struct {
		Date    string  `json:"date"`
		Income  float64 `json:"income"`
		Expense float64 `json:"expense"`
	}

	// 使用SQLite的strftime函数进行日期格式化和分组
	query.Select("strftime('" + groupFormat + "', datetime(created_at, 'unixepoch')) as date, " +
		"COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 0) as income, " +
		"COALESCE(SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END), 0) as expense").
		Group("date").
		Order("date").
		Scan(&trends)

	utils.Logger.Infof("获取到收支趋势: userID=%d, 数据点数量=%d", userID, len(trends))
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取收支趋势成功",
		"data": gin.H{
			"period":     period,
			"group_by":   groupBy,
			"start_time": startTime,
			"end_time":   endTime,
			"trends":     trends,
		},
	})
}

// 获取收支分类统计
func GetCategoryStats(c *gin.Context) {
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
	period := c.DefaultQuery("period", "month")     // day, week, month, year
	direction := c.DefaultQuery("direction", "all") // income, expense, all

	utils.Logger.Infof("获取收支分类统计: userID=%d, period=%s, direction=%s", userID, period, direction)

	db := c.MustGet("db").(*gorm.DB)

	// 设置时间范围
	var startTime, endTime int64
	now := time.Now()
	endTime = now.Unix()

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

	// 构建查询
	query := db.Model(&models.Transaction{}).
		Where("user_id = ? AND created_at >= ? AND created_at <= ?", userID, startTime, endTime)

	// 根据收支方向筛选
	switch direction {
	case "income":
		query = query.Where("amount > 0")
	case "expense":
		query = query.Where("amount < 0")
	}

	// 按交易类型分组统计
	var typeStats []struct {
		Type   string  `json:"type"`
		Amount float64 `json:"amount"`
		Count  int     `json:"count"`
	}

	if direction == "expense" {
		query.Select("type, COALESCE(SUM(ABS(amount)), 0) as amount, COUNT(*) as count").
			Group("type").
			Order("amount DESC").
			Scan(&typeStats)
	} else {
		query.Select("type, COALESCE(SUM(amount), 0) as amount, COUNT(*) as count").
			Group("type").
			Order("amount DESC").
			Scan(&typeStats)
	}

	utils.Logger.Infof("获取到收支分类统计: userID=%d, 分类数量=%d", userID, len(typeStats))
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取收支分类统计成功",
		"data": gin.H{
			"period":     period,
			"direction":  direction,
			"start_time": startTime,
			"end_time":   endTime,
			"type_stats": typeStats,
		},
	})
}

// 获取钱包健康度
func GetWalletHealth(c *gin.Context) {
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

	utils.Logger.Infof("获取钱包健康度: userID=%d", userID)

	db := c.MustGet("db").(*gorm.DB)

	// 查询钱包信息
	var wallet models.Wallet
	if err := db.Where("user_id = ?", userID).First(&wallet).Error; err != nil {
		utils.Logger.Errorf("查询钱包失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询钱包失败"})
		return
	}

	// 计算安全得分（满分100分）
	var securityScore int = 0

	// 1. 是否设置支付密码（30分）
	if wallet.PayPasswordSet {
		securityScore += 30
	}

	// 2. 安全等级（最高30分）
	securityScore += wallet.SecurityLevel * 10

	// 3. 是否绑定银行卡（20分）
	var bankCardCount int64
	db.Model(&models.BankCard{}).Where("user_id = ?", userID).Count(&bankCardCount)
	if bankCardCount > 0 {
		securityScore += 20
	}

	// 4. 是否有交易记录（10分）
	var transactionCount int64
	db.Model(&models.Transaction{}).Where("user_id = ?", userID).Count(&transactionCount)
	if transactionCount > 0 {
		securityScore += 10
	}

	// 5. 是否设置每日限额（10分）
	if wallet.DailyLimit < 10000 { // 默认限额是10000，如果小于默认值，说明用户主动设置了
		securityScore += 10
	}

	// 计算消费健康度
	// 获取最近一个月的收支情况
	now := time.Now()
	monthStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location()).Unix()
	monthEnd := time.Date(now.Year(), now.Month()+1, 0, 23, 59, 59, 999999999, now.Location()).Unix()

	// 本月收入
	var monthIncome float64
	db.Model(&models.Transaction{}).
		Where("user_id = ? AND amount > 0 AND created_at >= ? AND created_at <= ?", userID, monthStart, monthEnd).
		Select("COALESCE(SUM(amount), 0) as total").
		Row().
		Scan(&monthIncome)

	// 本月支出
	var monthExpense float64
	db.Model(&models.Transaction{}).
		Where("user_id = ? AND amount < 0 AND created_at >= ? AND created_at <= ?", userID, monthStart, monthEnd).
		Select("COALESCE(SUM(ABS(amount)), 0) as total").
		Row().
		Scan(&monthExpense)

	// 计算收支比率
	var incomeExpenseRatio float64 = 0
	if monthExpense > 0 {
		incomeExpenseRatio = monthIncome / monthExpense
	} else {
		incomeExpenseRatio = 999 // 如果没有支出，设置一个很大的值
	}

	// 计算消费健康得分（满分100分）
	var consumptionScore int = 0

	// 1. 收支比率（最高50分）
	if incomeExpenseRatio >= 2 {
		consumptionScore += 50 // 收入是支出的2倍以上，满分
	} else if incomeExpenseRatio >= 1.5 {
		consumptionScore += 40 // 收入是支出的1.5倍以上
	} else if incomeExpenseRatio >= 1.2 {
		consumptionScore += 30 // 收入是支出的1.2倍以上
	} else if incomeExpenseRatio >= 1 {
		consumptionScore += 20 // 收入等于或略高于支出
	} else if incomeExpenseRatio >= 0.8 {
		consumptionScore += 10 // 收入略低于支出
	}

	// 2. 交易频率（最高30分）
	if transactionCount >= 30 {
		consumptionScore += 30 // 交易非常活跃
	} else if transactionCount >= 20 {
		consumptionScore += 25
	} else if transactionCount >= 10 {
		consumptionScore += 20
	} else if transactionCount >= 5 {
		consumptionScore += 15
	} else if transactionCount > 0 {
		consumptionScore += 10
	}

	// 3. 余额状况（最高20分）
	if wallet.Balance >= monthExpense*3 {
		consumptionScore += 20 // 余额可以覆盖3个月以上的支出
	} else if wallet.Balance >= monthExpense*2 {
		consumptionScore += 15 // 余额可以覆盖2个月以上的支出
	} else if wallet.Balance >= monthExpense {
		consumptionScore += 10 // 余额可以覆盖1个月的支出
	} else if wallet.Balance > 0 {
		consumptionScore += 5 // 有余额但不足以覆盖1个月支出
	}

	// 生成健康建议
	var suggestions []string

	// 安全建议
	if !wallet.PayPasswordSet {
		suggestions = append(suggestions, "建议设置支付密码，提高账户安全性")
	}
	if wallet.SecurityLevel < 3 {
		suggestions = append(suggestions, "建议提高安全等级，增强账户保护")
	}
	if bankCardCount == 0 {
		suggestions = append(suggestions, "建议绑定银行卡，方便资金管理")
	}
	if wallet.DailyLimit >= 10000 {
		suggestions = append(suggestions, "建议设置合理的每日交易限额，降低风险")
	}

	// 消费建议
	if incomeExpenseRatio < 1 {
		suggestions = append(suggestions, "当前支出大于收入，建议控制支出或增加收入")
	}
	if wallet.Balance < monthExpense && monthExpense > 0 {
		suggestions = append(suggestions, "当前余额不足以覆盖一个月的支出，建议增加储蓄")
	}

	utils.Logger.Infof("获取到钱包健康度: userID=%d, 安全得分=%d, 消费健康得分=%d", userID, securityScore, consumptionScore)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取钱包健康度成功",
		"data": gin.H{
			"security_score":       securityScore,
			"consumption_score":    consumptionScore,
			"overall_score":        (securityScore + consumptionScore) / 2,
			"income_expense_ratio": incomeExpenseRatio,
			"month_income":         monthIncome,
			"month_expense":        monthExpense,
			"balance":              wallet.Balance,
			"suggestions":          suggestions,
		},
	})
}
