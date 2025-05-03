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

// 创建定期存款
func CreateDeposit(c *gin.Context) {
	var req struct {
		Amount       float64 `json:"amount" binding:"required,gt=0"`
		Term         int     `json:"term" binding:"required,gt=0"`
		InterestRate float64 `json:"interest_rate" binding:"required,gt=0"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("创建定期存款参数错误: %v", err)
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

	utils.Logger.Infof("创建定期存款: userID=%d, amount=%f, term=%d, interestRate=%f",
		userID, req.Amount, req.Term, req.InterestRate)

	db := c.MustGet("db").(*gorm.DB)

	// 检查钱包余额是否足够
	var wallet models.Wallet
	if err := db.Where("user_id = ?", userID).First(&wallet).Error; err != nil {
		utils.Logger.Errorf("查询钱包失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询钱包失败"})
		return
	}

	if wallet.Balance < req.Amount {
		utils.Logger.Errorf("余额不足: 当前余额=%f, 存款金额=%f", wallet.Balance, req.Amount)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "余额不足"})
		return
	}

	// 开始事务
	err := db.Transaction(func(tx *gorm.DB) error {
		now := time.Now()
		startDate := now.Unix()
		endDate := now.AddDate(0, req.Term, 0).Unix()

		// 计算预计利息
		// 简单计算: 本金 * 年利率 * (月数/12)
		interest := req.Amount * (req.InterestRate / 100) * (float64(req.Term) / 12)
		interest = math.Round(interest*100) / 100 // 四舍五入到两位小数

		// 创建定期存款记录
		deposit := models.Deposit{
			UserID:       userID,
			Amount:       req.Amount,
			InterestRate: req.InterestRate,
			Term:         req.Term,
			StartDate:    startDate,
			EndDate:      endDate,
			Status:       "active",
			Interest:     interest,
			CreatedAt:    startDate,
			UpdatedAt:    startDate,
		}

		if err := tx.Create(&deposit).Error; err != nil {
			utils.Logger.Errorf("创建定期存款记录失败: %v", err)
			return err
		}

		// 更新钱包余额
		wallet.Balance -= req.Amount
		wallet.UpdatedAt = startDate
		if err := tx.Save(&wallet).Error; err != nil {
			utils.Logger.Errorf("更新钱包余额失败: %v", err)
			return err
		}

		// 创建交易记录
		transaction := models.Transaction{
			UserID:      userID,
			Amount:      -req.Amount,
			Balance:     wallet.Balance,
			Type:        "deposit",
			RelatedID:   deposit.ID,
			Description: "创建定期存款，期限" + strconv.Itoa(req.Term) + "个月",
			Status:      "success",
			CreatedAt:   startDate,
			UpdatedAt:   startDate,
		}
		if err := tx.Create(&transaction).Error; err != nil {
			utils.Logger.Errorf("创建交易记录失败: %v", err)
			return err
		}

		// 创建交易通知
		if err := createTransactionNotification(tx, userID, "deposit", req.Amount,
			"创建定期存款，期限"+strconv.Itoa(req.Term)+"个月"); err != nil {
			utils.Logger.Errorf("创建交易通知失败: %v", err)
			// 通知创建失败不影响交易本身
		}

		return nil
	})

	if err != nil {
		utils.Logger.Errorf("创建定期存款失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建定期存款失败: " + err.Error()})
		return
	}

	// 查询最新余额
	db.Where("user_id = ?", userID).First(&wallet)

	utils.Logger.Infof("创建定期存款成功: userID=%d, amount=%f, term=%d", userID, req.Amount, req.Term)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "创建定期存款成功",
		"data": gin.H{
			"new_balance": wallet.Balance,
		},
	})
}

// 获取定期存款列表
func GetDeposits(c *gin.Context) {
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

	utils.Logger.Infof("获取定期存款列表: userID=%d, status=%s", userID, status)

	db := c.MustGet("db").(*gorm.DB)

	// 构建查询条件
	query := db.Model(&models.Deposit{}).Where("user_id = ?", userID)

	// 按状态筛选
	if status != "all" {
		query = query.Where("status = ?", status)
	}

	// 查询定期存款
	var deposits []models.Deposit
	if err := query.Order("created_at DESC").Find(&deposits).Error; err != nil {
		utils.Logger.Errorf("查询定期存款失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询定期存款失败"})
		return
	}

	// 计算总金额和总利息
	var totalAmount, totalInterest float64
	for _, deposit := range deposits {
		totalAmount += deposit.Amount
		totalInterest += deposit.Interest
	}

	utils.Logger.Infof("获取到定期存款列表: userID=%d, 数量=%d", userID, len(deposits))
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取定期存款列表成功",
		"data": gin.H{
			"deposits":       deposits,
			"total_amount":   totalAmount,
			"total_interest": totalInterest,
		},
	})
}

// 获取定期存款详情
func GetDepositDetail(c *gin.Context) {
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

	// 获取定期存款ID
	depositID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		utils.Logger.Errorf("定期存款ID无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "定期存款ID无效"})
		return
	}

	utils.Logger.Infof("获取定期存款详情: userID=%d, depositID=%d", userID, depositID)

	db := c.MustGet("db").(*gorm.DB)

	// 查询定期存款
	var deposit models.Deposit
	if err := db.Where("id = ? AND user_id = ?", depositID, userID).First(&deposit).Error; err != nil {
		utils.Logger.Errorf("查询定期存款失败: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "定期存款不存在"})
		return
	}

	// 计算当前已经过的时间和进度
	now := time.Now().Unix()
	var progress float64 = 0
	var currentInterest float64 = 0
	var daysElapsed int64 = 0

	if deposit.Status == "active" {
		totalDuration := deposit.EndDate - deposit.StartDate
		elapsedDuration := now - deposit.StartDate
		if totalDuration > 0 {
			progress = float64(elapsedDuration) / float64(totalDuration) * 100
			progress = math.Min(progress, 100) // 确保不超过100%
		}

		// 计算已经过的天数
		daysElapsed = elapsedDuration / (24 * 60 * 60)

		// 计算当前已经获得的利息（按比例）
		if progress > 0 {
			currentInterest = deposit.Interest * (progress / 100)
			currentInterest = math.Round(currentInterest*100) / 100 // 四舍五入到两位小数
		}
	} else if deposit.Status == "completed" {
		progress = 100
		currentInterest = deposit.Interest
		daysElapsed = (deposit.EndDate - deposit.StartDate) / (24 * 60 * 60)
	}

	// 查询相关交易记录
	var transactions []models.Transaction
	db.Where("user_id = ? AND related_id = ? AND type IN ('deposit', 'deposit_withdraw', 'deposit_interest')",
		userID, deposit.ID).Order("created_at DESC").Find(&transactions)

	utils.Logger.Infof("获取到定期存款详情: userID=%d, depositID=%d, progress=%f, currentInterest=%f",
		userID, depositID, progress, currentInterest)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取定期存款详情成功",
		"data": gin.H{
			"deposit":          deposit,
			"progress":         progress,
			"current_interest": currentInterest,
			"days_elapsed":     daysElapsed,
			"transactions":     transactions,
		},
	})
}

// 提前支取定期存款
func WithdrawDeposit(c *gin.Context) {
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

	// 获取定期存款ID
	depositID, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		utils.Logger.Errorf("定期存款ID无效: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "定期存款ID无效"})
		return
	}

	utils.Logger.Infof("提前支取定期存款: userID=%d, depositID=%d", userID, depositID)

	db := c.MustGet("db").(*gorm.DB)

	// 开始事务
	err = db.Transaction(func(tx *gorm.DB) error {
		// 查询定期存款
		var deposit models.Deposit
		if err := tx.Where("id = ? AND user_id = ? AND status = 'active'", depositID, userID).First(&deposit).Error; err != nil {
			utils.Logger.Errorf("查询定期存款失败: %v", err)
			return &utils.AppError{Code: 404, Message: "定期存款不存在或已结束"}
		}

		// 计算当前已经过的时间和进度
		now := time.Now().Unix()
		totalDuration := deposit.EndDate - deposit.StartDate
		elapsedDuration := now - deposit.StartDate
		var progress float64 = 0
		if totalDuration > 0 {
			progress = float64(elapsedDuration) / float64(totalDuration) * 100
			progress = math.Min(progress, 100) // 确保不超过100%
		}

		// 计算当前已经获得的利息（按比例，但有惩罚）
		// 提前支取通常只能获得部分利息，这里简化为获得按比例计算的利息的一半
		var actualInterest float64 = 0
		if progress > 0 {
			actualInterest = deposit.Interest * (progress / 100) * 0.5
			actualInterest = math.Round(actualInterest*100) / 100 // 四舍五入到两位小数
		}

		// 查询钱包
		var wallet models.Wallet
		if err := tx.Where("user_id = ?", userID).First(&wallet).Error; err != nil {
			utils.Logger.Errorf("查询钱包失败: %v", err)
			return err
		}

		// 更新定期存款状态
		deposit.Status = "withdrawn"
		deposit.UpdatedAt = now
		if err := tx.Save(&deposit).Error; err != nil {
			utils.Logger.Errorf("更新定期存款状态失败: %v", err)
			return err
		}

		// 更新钱包余额（本金 + 实际利息）
		totalAmount := deposit.Amount + actualInterest
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
			Type:        "deposit_withdraw",
			RelatedID:   deposit.ID,
			Description: "提前支取定期存款，本金" + strconv.FormatFloat(deposit.Amount, 'f', 2, 64) + "元，利息" + strconv.FormatFloat(actualInterest, 'f', 2, 64) + "元",
			Status:      "success",
			CreatedAt:   now,
			UpdatedAt:   now,
		}
		if err := tx.Create(&transaction).Error; err != nil {
			utils.Logger.Errorf("创建交易记录失败: %v", err)
			return err
		}

		// 创建交易通知
		if err := createTransactionNotification(tx, userID, "deposit_withdraw", totalAmount,
			"提前支取定期存款，本金"+strconv.FormatFloat(deposit.Amount, 'f', 2, 64)+"元，利息"+strconv.FormatFloat(actualInterest, 'f', 2, 64)+"元"); err != nil {
			utils.Logger.Errorf("创建交易通知失败: %v", err)
			// 通知创建失败不影响交易本身
		}

		return nil
	})

	if err != nil {
		if appErr, ok := err.(*utils.AppError); ok {
			utils.Logger.Errorf("提前支取定期存款失败(应用错误): %s", appErr.Message)
			c.JSON(appErr.Code, gin.H{"success": false, "msg": appErr.Message})
		} else {
			utils.Logger.Errorf("提前支取定期存款失败(系统错误): %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "提前支取定期存款失败: " + err.Error()})
		}
		return
	}

	// 查询最新余额
	var wallet models.Wallet
	db.Where("user_id = ?", userID).First(&wallet)

	utils.Logger.Infof("提前支取定期存款成功: userID=%d, depositID=%d", userID, depositID)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "提前支取定期存款成功",
		"data": gin.H{
			"new_balance": wallet.Balance,
		},
	})
}

// 到期自动结算定期存款（定时任务调用）
// 注意：此函数已移至 deposit_settlement.go
