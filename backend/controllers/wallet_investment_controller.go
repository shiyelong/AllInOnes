package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"math"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// 获取理财产品列表
func GetInvestments(c *gin.Context) {
	// 获取查询参数
	investmentType := c.DefaultQuery("type", "all") // all, fund, stock, bond, etc.
	risk := c.DefaultQuery("risk", "all")           // all, 1, 2, 3, 4, 5
	status := c.DefaultQuery("status", "available") // available, sold_out, closed, all

	utils.Logger.Infof("获取理财产品列表: type=%s, risk=%s, status=%s", investmentType, risk, status)

	db := c.MustGet("db").(*gorm.DB)

	// 构建查询条件
	query := db.Model(&models.Investment{})

	// 按类型筛选
	if investmentType != "all" {
		query = query.Where("type = ?", investmentType)
	}

	// 按风险等级筛选
	if risk != "all" {
		riskLevel, err := strconv.Atoi(risk)
		if err == nil && riskLevel >= 1 && riskLevel <= 5 {
			query = query.Where("risk = ?", riskLevel)
		}
	}

	// 按状态筛选
	if status != "all" {
		query = query.Where("status = ?", status)
	}

	// 查询理财产品
	var investments []models.Investment
	if err := query.Order("created_at DESC").Find(&investments).Error; err != nil {
		utils.Logger.Errorf("查询理财产品失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询理财产品失败"})
		return
	}

	utils.Logger.Infof("获取到理财产品列表: 数量=%d", len(investments))
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取理财产品列表成功",
		"data": gin.H{
			"investments": investments,
		},
	})
}

// 获取理财产品详情
func GetInvestmentDetail(c *gin.Context) {
	// 获取理财产品ID
	investmentID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		utils.Logger.Errorf("理财产品ID无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "理财产品ID无效"})
		return
	}

	utils.Logger.Infof("获取理财产品详情: investmentID=%d", investmentID)

	db := c.MustGet("db").(*gorm.DB)

	// 查询理财产品
	var investment models.Investment
	if err := db.Where("id = ?", investmentID).First(&investment).Error; err != nil {
		utils.Logger.Errorf("查询理财产品失败: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "理财产品不存在"})
		return
	}

	// 查询投资人数和总投资金额
	var investorCount int64
	var totalInvestment float64
	db.Model(&models.UserInvestment{}).Where("investment_id = ?", investmentID).Count(&investorCount)
	db.Model(&models.UserInvestment{}).Where("investment_id = ?", investmentID).Select("COALESCE(SUM(amount), 0) as total").Row().Scan(&totalInvestment)

	// 计算投资进度
	var investmentProgress float64 = 0
	if investment.AvailableAmount > 0 {
		investmentProgress = (totalInvestment / (totalInvestment + investment.AvailableAmount)) * 100
		investmentProgress = math.Round(investmentProgress*100) / 100 // 四舍五入到两位小数
	} else if investment.Status == "sold_out" {
		investmentProgress = 100
	}

	utils.Logger.Infof("获取到理财产品详情: investmentID=%d, 投资人数=%d, 总投资金额=%f", 
		investmentID, investorCount, totalInvestment)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取理财产品详情成功",
		"data": gin.H{
			"investment":         investment,
			"investor_count":     investorCount,
			"total_investment":   totalInvestment,
			"investment_progress": investmentProgress,
		},
	})
}

// 购买理财产品
func PurchaseInvestment(c *gin.Context) {
	var req struct {
		InvestmentID uint    `json:"investment_id" binding:"required"`
		Amount       float64 `json:"amount" binding:"required,gt=0"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("购买理财产品参数错误: %v", err)
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

	utils.Logger.Infof("购买理财产品: userID=%d, investmentID=%d, amount=%f", 
		userID, req.InvestmentID, req.Amount)

	db := c.MustGet("db").(*gorm.DB)

	// 开始事务
	err := db.Transaction(func(tx *gorm.DB) error {
		// 查询理财产品
		var investment models.Investment
		if err := tx.Where("id = ? AND status = 'available'", req.InvestmentID).First(&investment).Error; err != nil {
			utils.Logger.Errorf("查询理财产品失败: %v", err)
			return &utils.AppError{Code: 404, Message: "理财产品不存在或已售罄"}
		}

		// 检查投资金额是否满足最低要求
		if req.Amount < investment.MinInvestment {
			utils.Logger.Errorf("投资金额不满足最低要求: 最低要求=%f, 实际投资=%f", 
				investment.MinInvestment, req.Amount)
			return &utils.AppError{Code: 400, Message: "投资金额不满足最低要求"}
		}

		// 检查投资金额是否超过可投资金额
		if req.Amount > investment.AvailableAmount {
			utils.Logger.Errorf("投资金额超过可投资金额: 可投资金额=%f, 实际投资=%f", 
				investment.AvailableAmount, req.Amount)
			return &utils.AppError{Code: 400, Message: "投资金额超过可投资金额"}
		}

		// 查询钱包
		var wallet models.Wallet
		if err := tx.Where("user_id = ?", userID).First(&wallet).Error; err != nil {
			utils.Logger.Errorf("查询钱包失败: %v", err)
			return err
		}

		// 检查钱包余额是否足够
		if wallet.Balance < req.Amount {
			utils.Logger.Errorf("余额不足: 当前余额=%f, 投资金额=%f", wallet.Balance, req.Amount)
			return &utils.AppError{Code: 400, Message: "余额不足"}
		}

		now := time.Now().Unix()
		var endDate int64 = 0
		if investment.Term > 0 {
			endDate = time.Now().AddDate(0, investment.Term, 0).Unix()
		}

		// 创建用户投资记录
		userInvestment := models.UserInvestment{
			UserID:       userID,
			InvestmentID: req.InvestmentID,
			Amount:       req.Amount,
			StartDate:    now,
			EndDate:      endDate,
			Status:       "active",
			Profit:       0,
			CreatedAt:    now,
			UpdatedAt:    now,
		}
		if err := tx.Create(&userInvestment).Error; err != nil {
			utils.Logger.Errorf("创建用户投资记录失败: %v", err)
			return err
		}

		// 更新理财产品可投资金额
		investment.AvailableAmount -= req.Amount
		investment.UpdatedAt = now
		if investment.AvailableAmount <= 0 {
			investment.Status = "sold_out"
		}
		if err := tx.Save(&investment).Error; err != nil {
			utils.Logger.Errorf("更新理财产品可投资金额失败: %v", err)
			return err
		}

		// 更新钱包余额
		wallet.Balance -= req.Amount
		wallet.UpdatedAt = now
		if err := tx.Save(&wallet).Error; err != nil {
			utils.Logger.Errorf("更新钱包余额失败: %v", err)
			return err
		}

		// 创建交易记录
		transaction := models.Transaction{
			UserID:      userID,
			Amount:      -req.Amount,
			Balance:     wallet.Balance,
			Type:        "investment",
			RelatedID:   userInvestment.ID,
			Description: "购买理财产品：" + investment.Name,
			Status:      "success",
			CreatedAt:   now,
			UpdatedAt:   now,
		}
		if err := tx.Create(&transaction).Error; err != nil {
			utils.Logger.Errorf("创建交易记录失败: %v", err)
			return err
		}

		// 创建交易通知
		if err := createTransactionNotification(tx, userID, "investment", req.Amount, 
			"购买理财产品："+investment.Name); err != nil {
			utils.Logger.Errorf("创建交易通知失败: %v", err)
			// 通知创建失败不影响交易本身
		}

		return nil
	})

	if err != nil {
		if appErr, ok := err.(*utils.AppError); ok {
			utils.Logger.Errorf("购买理财产品失败(应用错误): %s", appErr.Message)
			c.JSON(appErr.Code, gin.H{"success": false, "msg": appErr.Message})
		} else {
			utils.Logger.Errorf("购买理财产品失败(系统错误): %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "购买理财产品失败: " + err.Error()})
		}
		return
	}

	// 查询最新余额
	var wallet models.Wallet
	db.Where("user_id = ?", userID).First(&wallet)

	utils.Logger.Infof("购买理财产品成功: userID=%d, investmentID=%d, amount=%f", 
		userID, req.InvestmentID, req.Amount)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "购买理财产品成功",
		"data": gin.H{
			"new_balance": wallet.Balance,
		},
	})
}

// 获取用户投资列表
func GetUserInvestments(c *gin.Context) {
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
	status := c.DefaultQuery("status", "all") // all, active, completed, withdrawn

	utils.Logger.Infof("获取用户投资列表: userID=%d, status=%s", userID, status)

	db := c.MustGet("db").(*gorm.DB)

	// 构建查询条件
	query := db.Model(&models.UserInvestment{}).Where("user_id = ?", userID)

	// 按状态筛选
	if status != "all" {
		query = query.Where("status = ?", status)
	}

	// 查询用户投资
	var userInvestments []models.UserInvestment
	if err := query.Order("created_at DESC").Find(&userInvestments).Error; err != nil {
		utils.Logger.Errorf("查询用户投资失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询用户投资失败"})
		return
	}

	// 获取每个投资的详细信息
	var investmentsWithDetails []gin.H
	for _, userInvestment := range userInvestments {
		var investment models.Investment
		if err := db.Where("id = ?", userInvestment.InvestmentID).First(&investment).Error; err != nil {
			utils.Logger.Errorf("查询理财产品失败: investmentID=%d, error=%v", 
				userInvestment.InvestmentID, err)
			continue
		}

		// 计算预期收益
		var expectedProfit float64 = 0
		if userInvestment.Status == "active" {
			// 简单计算: 投资金额 * 预期年化收益率 * (投资期限/12)
			if investment.Term > 0 {
				expectedProfit = userInvestment.Amount * (investment.ExpectedReturn / 100) * (float64(investment.Term) / 12)
			} else {
				// 无固定期限，按照一年计算
				expectedProfit = userInvestment.Amount * (investment.ExpectedReturn / 100)
			}
			expectedProfit = math.Round(expectedProfit*100) / 100 // 四舍五入到两位小数
		}

		investmentsWithDetails = append(investmentsWithDetails, gin.H{
			"user_investment":  userInvestment,
			"investment":       investment,
			"expected_profit":  expectedProfit,
		})
	}

	// 计算总投资金额和总收益
	var totalInvestment, totalProfit float64
	for _, item := range investmentsWithDetails {
		userInvestment := item["user_investment"].(models.UserInvestment)
		totalInvestment += userInvestment.Amount
		totalProfit += userInvestment.Profit
	}

	utils.Logger.Infof("获取到用户投资列表: userID=%d, 数量=%d", userID, len(userInvestments))
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取用户投资列表成功",
		"data": gin.H{
			"investments":      investmentsWithDetails,
			"total_investment": totalInvestment,
			"total_profit":     totalProfit,
		},
	})
}

// 获取用户投资详情
func GetUserInvestmentDetail(c *gin.Context) {
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

	// 获取用户投资ID
	userInvestmentID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		utils.Logger.Errorf("用户投资ID无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户投资ID无效"})
		return
	}

	utils.Logger.Infof("获取用户投资详情: userID=%d, userInvestmentID=%d", userID, userInvestmentID)

	db := c.MustGet("db").(*gorm.DB)

	// 查询用户投资
	var userInvestment models.UserInvestment
	if err := db.Where("id = ? AND user_id = ?", userInvestmentID, userID).First(&userInvestment).Error; err != nil {
		utils.Logger.Errorf("查询用户投资失败: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "用户投资不存在"})
		return
	}

	// 查询理财产品
	var investment models.Investment
	if err := db.Where("id = ?", userInvestment.InvestmentID).First(&investment).Error; err != nil {
		utils.Logger.Errorf("查询理财产品失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询理财产品失败"})
		return
	}

	// 计算投资进度和预期收益
	now := time.Now().Unix()
	var progress float64 = 0
	var expectedProfit float64 = 0

	if userInvestment.Status == "active" {
		if userInvestment.EndDate > 0 {
			// 有固定期限
			totalDuration := userInvestment.EndDate - userInvestment.StartDate
			elapsedDuration := now - userInvestment.StartDate
			if totalDuration > 0 {
				progress = float64(elapsedDuration) / float64(totalDuration) * 100
				progress = math.Min(progress, 100) // 确保不超过100%
			}

			// 计算预期收益
			expectedProfit = userInvestment.Amount * (investment.ExpectedReturn / 100) * (float64(investment.Term) / 12)
		} else {
			// 无固定期限，计算已投资时间
			elapsedDuration := now - userInvestment.StartDate
			elapsedMonths := float64(elapsedDuration) / (30 * 24 * 60 * 60) // 简化为30天一个月
			
			// 计算预期收益（按照已投资时间）
			expectedProfit = userInvestment.Amount * (investment.ExpectedReturn / 100) * (elapsedMonths / 12)
		}
		expectedProfit = math.Round(expectedProfit*100) / 100 // 四舍五入到两位小数
	} else if userInvestment.Status == "completed" {
		progress = 100
	}

	// 查询相关交易记录
	var transactions []models.Transaction
	db.Where("user_id = ? AND related_id = ? AND type IN ('investment', 'investment_withdraw', 'investment_profit')", 
		userID, userInvestment.ID).Order("created_at DESC").Find(&transactions)

	utils.Logger.Infof("获取到用户投资详情: userID=%d, userInvestmentID=%d, progress=%f, expectedProfit=%f", 
		userID, userInvestmentID, progress, expectedProfit)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取用户投资详情成功",
		"data": gin.H{
			"user_investment": userInvestment,
			"investment":      investment,
			"progress":        progress,
			"expected_profit": expectedProfit,
			"transactions":    transactions,
		},
	})
}

// 赎回投资
func RedeemInvestment(c *gin.Context) {
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

	// 获取用户投资ID
	userInvestmentID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		utils.Logger.Errorf("用户投资ID无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户投资ID无效"})
		return
	}

	utils.Logger.Infof("赎回投资: userID=%d, userInvestmentID=%d", userID, userInvestmentID)

	db := c.MustGet("db").(*gorm.DB)

	// 开始事务
	err = db.Transaction(func(tx *gorm.DB) error {
		// 查询用户投资
		var userInvestment models.UserInvestment
		if err := tx.Where("id = ? AND user_id = ? AND status = 'active'", userInvestmentID, userID).First(&userInvestment).Error; err != nil {
			utils.Logger.Errorf("查询用户投资失败: %v", err)
			return &utils.AppError{Code: 404, Message: "用户投资不存在或已赎回"}
		}

		// 查询理财产品
		var investment models.Investment
		if err := tx.Where("id = ?", userInvestment.InvestmentID).First(&investment).Error; err != nil {
			utils.Logger.Errorf("查询理财产品失败: %v", err)
			return err
		}

		// 计算投资收益
		now := time.Now().Unix()
		var profit float64 = 0

		if userInvestment.EndDate > 0 {
			// 有固定期限
			if now < userInvestment.EndDate {
				// 提前赎回，收益减半
				elapsedDuration := now - userInvestment.StartDate
				totalDuration := userInvestment.EndDate - userInvestment.StartDate
				if totalDuration > 0 {
					progress := float64(elapsedDuration) / float64(totalDuration)
					profit = userInvestment.Amount * (investment.ExpectedReturn / 100) * (float64(investment.Term) / 12) * progress * 0.5
				}
			} else {
				// 到期赎回，获得全部收益
				profit = userInvestment.Amount * (investment.ExpectedReturn / 100) * (float64(investment.Term) / 12)
			}
		} else {
			// 无固定期限，按照已投资时间计算收益
			elapsedDuration := now - userInvestment.StartDate
			elapsedMonths := float64(elapsedDuration) / (30 * 24 * 60 * 60) // 简化为30天一个月
			profit = userInvestment.Amount * (investment.ExpectedReturn / 100) * (elapsedMonths / 12)
		}

		profit = math.Round(profit*100) / 100 // 四舍五入到两位小数

		// 查询钱包
		var wallet models.Wallet
		if err := tx.Where("user_id = ?", userID).First(&wallet).Error; err != nil {
			utils.Logger.Errorf("查询钱包失败: %v", err)
			return err
		}

		// 更新用户投资状态
		userInvestment.Status = "withdrawn"
		userInvestment.Profit = profit
		userInvestment.UpdatedAt = now
		if err := tx.Save(&userInvestment).Error; err != nil {
			utils.Logger.Errorf("更新用户投资状态失败: %v", err)
			return err
		}

		// 更新理财产品可投资金额（如果产品仍然可用）
		if investment.Status == "available" || investment.Status == "sold_out" {
			investment.AvailableAmount += userInvestment.Amount
			investment.Status = "available" // 重新变为可投资状态
			investment.UpdatedAt = now
			if err := tx.Save(&investment).Error; err != nil {
				utils.Logger.Errorf("更新理财产品可投资金额失败: %v", err)
				return err
			}
		}

		// 更新钱包余额（本金 + 收益）
		totalAmount := userInvestment.Amount + profit
		wallet.Balance += totalAmount
		wallet.UpdatedAt = now
		if err := tx.Save(&wallet).Error; err != nil {
			utils.Logger.Errorf("更新钱包余额失败: %v", err)
			return err
		}

		// 创建交易记录
		transaction := models.Transaction{
			UserID:      userID,
			Amount:      totalAmount,
			Balance:     wallet.Balance,
			Type:        "investment_withdraw",
			RelatedID:   userInvestment.ID,
			Description: "赎回投资：" + investment.Name + "，本金" + strconv.FormatFloat(userInvestment.Amount, 'f', 2, 64) + "元，收益" + strconv.FormatFloat(profit, 'f', 2, 64) + "元",
			Status:      "success",
			CreatedAt:   now,
			UpdatedAt:   now,
		}
		if err := tx.Create(&transaction).Error; err != nil {
			utils.Logger.Errorf("创建交易记录失败: %v", err)
			return err
		}

		// 创建交易通知
		if err := createTransactionNotification(tx, userID, "investment_withdraw", totalAmount, 
			"赎回投资："+investment.Name+"，本金"+strconv.FormatFloat(userInvestment.Amount, 'f', 2, 64)+"元，收益"+strconv.FormatFloat(profit, 'f', 2, 64)+"元"); err != nil {
			utils.Logger.Errorf("创建交易通知失败: %v", err)
			// 通知创建失败不影响交易本身
		}

		return nil
	})

	if err != nil {
		if appErr, ok := err.(*utils.AppError); ok {
			utils.Logger.Errorf("赎回投资失败(应用错误): %s", appErr.Message)
			c.JSON(appErr.Code, gin.H{"success": false, "msg": appErr.Message})
		} else {
			utils.Logger.Errorf("赎回投资失败(系统错误): %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "赎回投资失败: " + err.Error()})
		}
		return
	}

	// 查询最新余额
	var wallet models.Wallet
	db.Where("user_id = ?", userID).First(&wallet)

	utils.Logger.Infof("赎回投资成功: userID=%d, userInvestmentID=%d", userID, userInvestmentID)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "赎回投资成功",
		"data": gin.H{
			"new_balance": wallet.Balance,
		},
	})
}

// 获取投资类型
func GetInvestmentTypes(c *gin.Context) {
	// 预定义的投资类型
	types := []gin.H{
		{"id": "fund", "name": "基金", "icon": "fund"},
		{"id": "stock", "name": "股票", "icon": "stock"},
		{"id": "bond", "name": "债券", "icon": "bond"},
		{"id": "p2p", "name": "P2P", "icon": "p2p"},
		{"id": "insurance", "name": "保险", "icon": "insurance"},
		{"id": "other", "name": "其他", "icon": "other"},
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取投资类型成功",
		"data": gin.H{
			"types": types,
		},
	})
}
