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

// 创建预算
func CreateBudget(c *gin.Context) {
	var req struct {
		Category    string  `json:"category" binding:"required"`
		Amount      float64 `json:"amount" binding:"required,gt=0"`
		Period      string  `json:"period" binding:"required"`
		StartDate   int64   `json:"start_date" binding:"required"`
		EndDate     int64   `json:"end_date" binding:"required"`
		Description string  `json:"description"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("创建预算参数错误: %v", err)
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

	// 验证参数
	if req.StartDate >= req.EndDate {
		utils.Logger.Errorf("开始日期必须早于结束日期: start=%d, end=%d", req.StartDate, req.EndDate)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "开始日期必须早于结束日期"})
		return
	}

	if req.Period != "month" && req.Period != "year" {
		utils.Logger.Errorf("预算周期无效: %s", req.Period)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "预算周期无效，只支持 month 或 year"})
		return
	}

	utils.Logger.Infof("创建预算: userID=%d, category=%s, amount=%f, period=%s", 
		userID, req.Category, req.Amount, req.Period)

	db := c.MustGet("db").(*gorm.DB)

	// 检查是否已存在相同类别和时间段的预算
	var existingBudget models.Budget
	result := db.Where("user_id = ? AND category = ? AND ((start_date <= ? AND end_date >= ?) OR (start_date <= ? AND end_date >= ?) OR (start_date >= ? AND end_date <= ?))",
		userID, req.Category, req.StartDate, req.StartDate, req.EndDate, req.EndDate, req.StartDate, req.EndDate).
		First(&existingBudget)
	
	if result.Error == nil {
		utils.Logger.Errorf("已存在相同类别和时间段的预算: id=%d", existingBudget.ID)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "已存在相同类别和时间段的预算"})
		return
	}

	now := time.Now().Unix()

	// 创建预算
	budget := models.Budget{
		UserID:      userID,
		Category:    req.Category,
		Amount:      req.Amount,
		Period:      req.Period,
		StartDate:   req.StartDate,
		EndDate:     req.EndDate,
		Description: req.Description,
		CreatedAt:   now,
		UpdatedAt:   now,
	}

	if err := db.Create(&budget).Error; err != nil {
		utils.Logger.Errorf("创建预算失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建预算失败"})
		return
	}

	utils.Logger.Infof("创建预算成功: id=%d", budget.ID)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "创建预算成功",
		"data": gin.H{
			"budget": budget,
		},
	})
}

// 获取预算列表
func GetBudgets(c *gin.Context) {
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
	period := c.DefaultQuery("period", "all") // all, active, expired
	category := c.Query("category")

	utils.Logger.Infof("获取预算列表: userID=%d, period=%s, category=%s", userID, period, category)

	db := c.MustGet("db").(*gorm.DB)

	// 构建查询条件
	query := db.Model(&models.Budget{}).Where("user_id = ?", userID)

	// 按状态筛选
	now := time.Now().Unix()
	if period == "active" {
		query = query.Where("end_date >= ?", now)
	} else if period == "expired" {
		query = query.Where("end_date < ?", now)
	}

	// 按类别筛选
	if category != "" {
		query = query.Where("category = ?", category)
	}

	// 查询预算
	var budgets []models.Budget
	if err := query.Order("created_at DESC").Find(&budgets).Error; err != nil {
		utils.Logger.Errorf("查询预算失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询预算失败"})
		return
	}

	// 获取每个预算的消费情况
	var budgetsWithSpending []gin.H
	for _, budget := range budgets {
		// 查询该预算类别在预算时间段内的支出总额
		var spending float64
		db.Model(&models.Transaction{}).
			Where("user_id = ? AND amount < 0 AND created_at >= ? AND created_at <= ?", userID, budget.StartDate, budget.EndDate).
			// 这里假设交易记录中有一个category字段，实际中可能需要根据交易类型或描述来判断类别
			Where("type = ? OR description LIKE ?", budget.Category, "%"+budget.Category+"%").
			Select("COALESCE(SUM(ABS(amount)), 0) as total").
			Row().
			Scan(&spending)

		// 计算预算使用百分比
		var percentage float64 = 0
		if budget.Amount > 0 {
			percentage = (spending / budget.Amount) * 100
		}

		// 判断预算状态
		var status string
		if budget.EndDate < now {
			status = "expired"
		} else if percentage >= 100 {
			status = "exceeded"
		} else if percentage >= 80 {
			status = "warning"
		} else {
			status = "normal"
		}

		budgetsWithSpending = append(budgetsWithSpending, gin.H{
			"budget":     budget,
			"spending":   spending,
			"percentage": percentage,
			"status":     status,
			"remaining":  budget.Amount - spending,
		})
	}

	utils.Logger.Infof("获取到预算列表: userID=%d, 数量=%d", userID, len(budgets))
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取预算列表成功",
		"data": gin.H{
			"budgets": budgetsWithSpending,
		},
	})
}

// 获取预算详情
func GetBudgetDetail(c *gin.Context) {
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

	// 获取预算ID
	budgetID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		utils.Logger.Errorf("预算ID无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "预算ID无效"})
		return
	}

	utils.Logger.Infof("获取预算详情: userID=%d, budgetID=%d", userID, budgetID)

	db := c.MustGet("db").(*gorm.DB)

	// 查询预算
	var budget models.Budget
	if err := db.Where("id = ? AND user_id = ?", budgetID, userID).First(&budget).Error; err != nil {
		utils.Logger.Errorf("查询预算失败: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "预算不存在"})
		return
	}

	// 查询该预算类别在预算时间段内的支出总额
	var spending float64
	db.Model(&models.Transaction{}).
		Where("user_id = ? AND amount < 0 AND created_at >= ? AND created_at <= ?", userID, budget.StartDate, budget.EndDate).
		// 这里假设交易记录中有一个category字段，实际中可能需要根据交易类型或描述来判断类别
		Where("type = ? OR description LIKE ?", budget.Category, "%"+budget.Category+"%").
		Select("COALESCE(SUM(ABS(amount)), 0) as total").
		Row().
		Scan(&spending)

	// 计算预算使用百分比
	var percentage float64 = 0
	if budget.Amount > 0 {
		percentage = (spending / budget.Amount) * 100
	}

	// 判断预算状态
	now := time.Now().Unix()
	var status string
	if budget.EndDate < now {
		status = "expired"
	} else if percentage >= 100 {
		status = "exceeded"
	} else if percentage >= 80 {
		status = "warning"
	} else {
		status = "normal"
	}

	// 查询该预算类别在预算时间段内的交易记录
	var transactions []models.Transaction
	db.Where("user_id = ? AND amount < 0 AND created_at >= ? AND created_at <= ?", userID, budget.StartDate, budget.EndDate).
		Where("type = ? OR description LIKE ?", budget.Category, "%"+budget.Category+"%").
		Order("created_at DESC").
		Find(&transactions)

	// 按天统计消费
	var dailySpending []gin.H
	db.Model(&models.Transaction{}).
		Where("user_id = ? AND amount < 0 AND created_at >= ? AND created_at <= ?", userID, budget.StartDate, budget.EndDate).
		Where("type = ? OR description LIKE ?", budget.Category, "%"+budget.Category+"%").
		Select("strftime('%Y-%m-%d', datetime(created_at, 'unixepoch')) as date, COALESCE(SUM(ABS(amount)), 0) as amount").
		Group("date").
		Order("date").
		Scan(&dailySpending)

	utils.Logger.Infof("获取到预算详情: userID=%d, budgetID=%d, 消费金额=%f, 百分比=%f", userID, budgetID, spending, percentage)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取预算详情成功",
		"data": gin.H{
			"budget":          budget,
			"spending":        spending,
			"percentage":      percentage,
			"status":          status,
			"remaining":       budget.Amount - spending,
			"transactions":    transactions,
			"daily_spending":  dailySpending,
		},
	})
}

// 更新预算
func UpdateBudget(c *gin.Context) {
	var req struct {
		Amount      float64 `json:"amount" binding:"required,gt=0"`
		EndDate     int64   `json:"end_date" binding:"required"`
		Description string  `json:"description"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("更新预算参数错误: %v", err)
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

	// 获取预算ID
	budgetID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		utils.Logger.Errorf("预算ID无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "预算ID无效"})
		return
	}

	utils.Logger.Infof("更新预算: userID=%d, budgetID=%d, amount=%f", userID, budgetID, req.Amount)

	db := c.MustGet("db").(*gorm.DB)

	// 查询预算
	var budget models.Budget
	if err := db.Where("id = ? AND user_id = ?", budgetID, userID).First(&budget).Error; err != nil {
		utils.Logger.Errorf("查询预算失败: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "预算不存在"})
		return
	}

	// 验证参数
	now := time.Now().Unix()
	if budget.StartDate >= req.EndDate {
		utils.Logger.Errorf("结束日期必须晚于开始日期: start=%d, end=%d", budget.StartDate, req.EndDate)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "结束日期必须晚于开始日期"})
		return
	}

	// 更新预算
	budget.Amount = req.Amount
	budget.EndDate = req.EndDate
	budget.Description = req.Description
	budget.UpdatedAt = now

	if err := db.Save(&budget).Error; err != nil {
		utils.Logger.Errorf("更新预算失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新预算失败"})
		return
	}

	utils.Logger.Infof("更新预算成功: id=%d", budget.ID)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "更新预算成功",
		"data": gin.H{
			"budget": budget,
		},
	})
}

// 删除预算
func DeleteBudget(c *gin.Context) {
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

	// 获取预算ID
	budgetID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		utils.Logger.Errorf("预算ID无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "预算ID无效"})
		return
	}

	utils.Logger.Infof("删除预算: userID=%d, budgetID=%d", userID, budgetID)

	db := c.MustGet("db").(*gorm.DB)

	// 查询预算
	var budget models.Budget
	if err := db.Where("id = ? AND user_id = ?", budgetID, userID).First(&budget).Error; err != nil {
		utils.Logger.Errorf("查询预算失败: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "预算不存在"})
		return
	}

	// 删除预算
	if err := db.Delete(&budget).Error; err != nil {
		utils.Logger.Errorf("删除预算失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "删除预算失败"})
		return
	}

	utils.Logger.Infof("删除预算成功: id=%d", budget.ID)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "删除预算成功",
	})
}

// 获取预算类别
func GetBudgetCategories(c *gin.Context) {
	// 预定义的预算类别
	categories := []gin.H{
		{"id": "food", "name": "餐饮", "icon": "food"},
		{"id": "shopping", "name": "购物", "icon": "shopping"},
		{"id": "entertainment", "name": "娱乐", "icon": "entertainment"},
		{"id": "transportation", "name": "交通", "icon": "transportation"},
		{"id": "housing", "name": "住房", "icon": "housing"},
		{"id": "utilities", "name": "水电煤", "icon": "utilities"},
		{"id": "healthcare", "name": "医疗", "icon": "healthcare"},
		{"id": "education", "name": "教育", "icon": "education"},
		{"id": "travel", "name": "旅行", "icon": "travel"},
		{"id": "other", "name": "其他", "icon": "other"},
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取预算类别成功",
		"data": gin.H{
			"categories": categories,
		},
	})
}
