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

// 获取钱包信息
func GetWalletInfo(c *gin.Context) {
	userIDStr, _ := c.Get("user_id")
	utils.Logger.Infof("获取钱包信息: userIDStr=%v, 类型=%T", userIDStr, userIDStr)

	userID, ok := userIDStr.(uint)
	if !ok {
		utils.Logger.Errorf("用户ID类型转换失败: %v, 类型=%T", userIDStr, userIDStr)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户ID无效"})
		return
	}

	utils.Logger.Infof("获取钱包信息: userID=%d", userID)
	db := c.MustGet("db").(*gorm.DB)

	// 查询或创建钱包
	var wallet models.Wallet
	result := db.Where("user_id = ?", userID).First(&wallet)
	if result.Error != nil {
		utils.Logger.Infof("钱包不存在，创建新钱包: userID=%d", userID)
		// 如果钱包不存在，创建一个新钱包
		wallet = models.Wallet{
			UserID:    userID,
			Balance:   0,
			CreatedAt: time.Now().Unix(),
			UpdatedAt: time.Now().Unix(),
		}
		db.Create(&wallet)
	}

	utils.Logger.Infof("钱包信息: userID=%d, walletID=%d, balance=%f", userID, wallet.ID, wallet.Balance)
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取钱包信息成功",
		"data": gin.H{
			"wallet_id": wallet.ID,
			"balance":   wallet.Balance,
		},
	})
}

// 获取交易记录
func GetTransactions(c *gin.Context) {
	userIDStr, _ := c.Get("user_id")
	utils.Logger.Infof("获取交易记录: userIDStr=%v, 类型=%T", userIDStr, userIDStr)

	userID, ok := userIDStr.(uint)
	if !ok {
		utils.Logger.Errorf("用户ID类型转换失败: %v, 类型=%T", userIDStr, userIDStr)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户ID无效"})
		return
	}

	// 分页参数
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))
	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}
	offset := (page - 1) * pageSize

	utils.Logger.Infof("获取交易记录: userID=%d, page=%d, pageSize=%d", userID, page, pageSize)
	db := c.MustGet("db").(*gorm.DB)

	// 查询交易记录总数
	var total int64
	db.Model(&models.Transaction{}).Where("user_id = ?", userID).Count(&total)

	// 查询交易记录
	var transactions []models.Transaction
	db.Where("user_id = ?", userID).
		Order("created_at DESC").
		Offset(offset).
		Limit(pageSize).
		Find(&transactions)

	utils.Logger.Infof("获取到交易记录: userID=%d, 总数=%d, 本页数量=%d", userID, total, len(transactions))
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

// 转账
func Transfer(c *gin.Context) {
	var req struct {
		ReceiverID uint    `json:"receiver_id"`
		Amount     float64 `json:"amount"`
		Message    string  `json:"message"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("转账参数错误: %v", err)
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

	utils.Logger.Infof("转账请求: 发送者ID=%d, 接收者ID=%d, 金额=%f, 留言=%s",
		userID, req.ReceiverID, req.Amount, req.Message)

	// 验证参数
	if req.Amount <= 0 {
		utils.Logger.Errorf("转账金额必须大于0: %f", req.Amount)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "转账金额必须大于0"})
		return
	}

	if userID == req.ReceiverID {
		utils.Logger.Errorf("不能给自己转账: 发送者ID=%d, 接收者ID=%d", userID, req.ReceiverID)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "不能给自己转账"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 开始事务
	err := db.Transaction(func(tx *gorm.DB) error {
		// 查询发送者钱包
		var senderWallet models.Wallet
		if err := tx.Where("user_id = ?", userID).First(&senderWallet).Error; err != nil {
			utils.Logger.Errorf("查询发送者钱包失败: %v", err)
			return err
		}

		// 检查余额是否足够
		if senderWallet.Balance < req.Amount {
			utils.Logger.Errorf("余额不足: 当前余额=%f, 转账金额=%f", senderWallet.Balance, req.Amount)
			return &utils.AppError{Code: 400, Message: "余额不足"}
		}

		// 查询或创建接收者钱包
		var receiverWallet models.Wallet
		result := tx.Where("user_id = ?", req.ReceiverID).First(&receiverWallet)
		if result.Error != nil {
			utils.Logger.Infof("接收者钱包不存在，创建新钱包: 接收者ID=%d", req.ReceiverID)
			// 如果接收者钱包不存在，创建一个新钱包
			receiverWallet = models.Wallet{
				UserID:    req.ReceiverID,
				Balance:   0,
				CreatedAt: time.Now().Unix(),
				UpdatedAt: time.Now().Unix(),
			}
			if err := tx.Create(&receiverWallet).Error; err != nil {
				utils.Logger.Errorf("创建接收者钱包失败: %v", err)
				return err
			}
		}

		now := time.Now().Unix()

		// 创建转账记录
		transfer := models.Transfer{
			SenderID:   userID,
			ReceiverID: req.ReceiverID,
			Amount:     req.Amount,
			Message:    req.Message,
			Status:     "success",
			CreatedAt:  now,
			UpdatedAt:  now,
		}
		if err := tx.Create(&transfer).Error; err != nil {
			utils.Logger.Errorf("创建转账记录失败: %v", err)
			return err
		}

		// 更新发送者钱包余额
		senderWallet.Balance -= req.Amount
		senderWallet.UpdatedAt = now
		if err := tx.Save(&senderWallet).Error; err != nil {
			utils.Logger.Errorf("更新发送者钱包余额失败: %v", err)
			return err
		}

		// 更新接收者钱包余额
		receiverWallet.Balance += req.Amount
		receiverWallet.UpdatedAt = now
		if err := tx.Save(&receiverWallet).Error; err != nil {
			utils.Logger.Errorf("更新接收者钱包余额失败: %v", err)
			return err
		}

		// 创建发送者交易记录
		senderTransaction := models.Transaction{
			UserID:      userID,
			Amount:      -req.Amount,
			Balance:     senderWallet.Balance,
			Type:        "transfer_out",
			RelatedID:   transfer.ID,
			Description: "转账给用户 " + strconv.Itoa(int(req.ReceiverID)),
			Status:      "success",
			CreatedAt:   now,
			UpdatedAt:   now,
		}
		if err := tx.Create(&senderTransaction).Error; err != nil {
			utils.Logger.Errorf("创建发送者交易记录失败: %v", err)
			return err
		}

		// 创建接收者交易记录
		receiverTransaction := models.Transaction{
			UserID:      req.ReceiverID,
			Amount:      req.Amount,
			Balance:     receiverWallet.Balance,
			Type:        "transfer_in",
			RelatedID:   transfer.ID,
			Description: "收到用户 " + strconv.Itoa(int(userID)) + " 的转账",
			Status:      "success",
			CreatedAt:   now,
			UpdatedAt:   now,
		}
		if err := tx.Create(&receiverTransaction).Error; err != nil {
			utils.Logger.Errorf("创建接收者交易记录失败: %v", err)
			return err
		}

		// 创建转账消息
		message := models.ChatMessage{
			SenderID:   userID,
			ReceiverID: req.ReceiverID,
			Content:    req.Message,
			Type:       "transfer",
			Extra:      `{"amount": ` + strconv.FormatFloat(req.Amount, 'f', 2, 64) + `}`,
			Status:     1,
			CreatedAt:  now,
		}
		if err := tx.Create(&message).Error; err != nil {
			utils.Logger.Errorf("创建转账消息失败: %v", err)
			return err
		}

		utils.Logger.Infof("转账成功: 发送者ID=%d, 接收者ID=%d, 金额=%f",
			userID, req.ReceiverID, req.Amount)

		// 创建发送者交易通知
		senderDescription := "转账给用户 " + strconv.Itoa(int(req.ReceiverID))
		if err := createTransactionNotification(tx, userID, "transfer_out", req.Amount, senderDescription); err != nil {
			utils.Logger.Errorf("创建发送者交易通知失败: %v", err)
			// 通知创建失败不影响交易本身
		}

		// 创建接收者交易通知
		receiverDescription := "收到用户 " + strconv.Itoa(int(userID)) + " 的转账"
		if err := createTransactionNotification(tx, req.ReceiverID, "transfer_in", req.Amount, receiverDescription); err != nil {
			utils.Logger.Errorf("创建接收者交易通知失败: %v", err)
			// 通知创建失败不影响交易本身
		}

		return nil
	})

	if err != nil {
		if appErr, ok := err.(*utils.AppError); ok {
			utils.Logger.Errorf("转账失败(应用错误): %s", appErr.Message)
			c.JSON(appErr.Code, gin.H{"success": false, "msg": appErr.Message})
		} else {
			utils.Logger.Errorf("转账失败(系统错误): %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "转账失败: " + err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "转账成功",
	})
}

// 充值
func Recharge(c *gin.Context) {
	var req struct {
		BankCardID    uint    `json:"bank_card_id"`
		Amount        float64 `json:"amount"`
		PaymentMethod string  `json:"payment_method"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("充值参数错误: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 验证参数
	if req.Amount <= 0 {
		utils.Logger.Errorf("充值金额必须大于0: %f", req.Amount)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "充值金额必须大于0"})
		return
	}

	// 验证支付方式
	if req.PaymentMethod != "bank_card" && req.PaymentMethod != "crypto" {
		utils.Logger.Errorf("支付方式无效: %s", req.PaymentMethod)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "支付方式无效"})
		return
	}

	// 获取当前登录用户ID
	userIDStr, _ := c.Get("user_id")
	userID, ok := userIDStr.(uint)
	if !ok {
		utils.Logger.Errorf("用户ID类型转换失败: %v, 类型=%T", userIDStr, userIDStr)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户ID无效"})
		return
	}

	utils.Logger.Infof("充值请求: 用户ID=%d, 银行卡ID=%d, 金额=%f, 支付方式=%s", userID, req.BankCardID, req.Amount, req.PaymentMethod)

	db := c.MustGet("db").(*gorm.DB)

	// 验证银行卡是否属于当前用户
	var bankCard models.BankCard
	if req.PaymentMethod == "bank_card" {
		if err := db.Where("id = ? AND user_id = ?", req.BankCardID, userID).First(&bankCard).Error; err != nil {
			utils.Logger.Errorf("银行卡不存在或不属于当前用户: 银行卡ID=%d, 用户ID=%d, 错误=%v", req.BankCardID, userID, err)
			c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "银行卡不存在或不属于当前用户"})
			return
		}
	}

	// 开始事务
	err := db.Transaction(func(tx *gorm.DB) error {
		// 查询或创建钱包
		var wallet models.Wallet
		result := tx.Where("user_id = ?", userID).First(&wallet)
		if result.Error != nil {
			utils.Logger.Infof("钱包不存在，创建新钱包: 用户ID=%d", userID)
			// 如果钱包不存在，创建一个新钱包
			wallet = models.Wallet{
				UserID:    userID,
				Balance:   0,
				CreatedAt: time.Now().Unix(),
				UpdatedAt: time.Now().Unix(),
			}
			if err := tx.Create(&wallet).Error; err != nil {
				utils.Logger.Errorf("创建钱包失败: %v", err)
				return err
			}
		}

		now := time.Now().Unix()

		// 创建充值记录
		recharge := models.Recharge{
			UserID:        userID,
			BankCardID:    req.BankCardID,
			Amount:        req.Amount,
			Status:        "success",
			PaymentMethod: req.PaymentMethod,
			CreatedAt:     now,
			UpdatedAt:     now,
		}
		if err := tx.Create(&recharge).Error; err != nil {
			utils.Logger.Errorf("创建充值记录失败: %v", err)
			return err
		}

		// 更新钱包余额
		wallet.Balance += req.Amount
		wallet.UpdatedAt = now
		if err := tx.Save(&wallet).Error; err != nil {
			utils.Logger.Errorf("更新钱包余额失败: %v", err)
			return err
		}

		// 创建交易记录
		description := ""
		if req.PaymentMethod == "bank_card" {
			description = "从银行卡充值 (" + bankCard.CardNumber[len(bankCard.CardNumber)-4:] + ")"
		} else {
			description = "从虚拟货币充值"
		}

		transaction := models.Transaction{
			UserID:      userID,
			Amount:      req.Amount,
			Balance:     wallet.Balance,
			Type:        "recharge",
			RelatedID:   recharge.ID,
			Description: description,
			Status:      "success",
			CreatedAt:   now,
			UpdatedAt:   now,
		}
		if err := tx.Create(&transaction).Error; err != nil {
			utils.Logger.Errorf("创建交易记录失败: %v", err)
			return err
		}

		utils.Logger.Infof("充值成功: 用户ID=%d, 银行卡ID=%d, 金额=%f, 当前余额=%f",
			userID, req.BankCardID, req.Amount, wallet.Balance)

		// 创建交易通知
		if err := createTransactionNotification(tx, userID, "recharge", req.Amount, description); err != nil {
			utils.Logger.Errorf("创建交易通知失败: %v", err)
			// 通知创建失败不影响交易本身
		}

		return nil
	})

	if err != nil {
		utils.Logger.Errorf("充值失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "充值失败: " + err.Error()})
		return
	}

	// 查询最新余额
	var wallet models.Wallet
	db.Where("user_id = ?", userID).First(&wallet)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "充值成功",
		"data": gin.H{
			"new_balance": wallet.Balance,
		},
	})
}

// 提现
func Withdraw(c *gin.Context) {
	var req struct {
		BankCardID uint    `json:"bank_card_id"`
		Amount     float64 `json:"amount"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("提现参数错误: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 验证参数
	if req.Amount <= 0 {
		utils.Logger.Errorf("提现金额必须大于0: %f", req.Amount)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "提现金额必须大于0"})
		return
	}

	// 获取当前登录用户ID
	userIDStr, _ := c.Get("user_id")
	userID, ok := userIDStr.(uint)
	if !ok {
		utils.Logger.Errorf("用户ID类型转换失败: %v, 类型=%T", userIDStr, userIDStr)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "用户ID无效"})
		return
	}

	utils.Logger.Infof("提现请求: 用户ID=%d, 银行卡ID=%d, 金额=%f", userID, req.BankCardID, req.Amount)

	db := c.MustGet("db").(*gorm.DB)

	// 验证银行卡是否属于当前用户
	var bankCard models.BankCard
	if err := db.Where("id = ? AND user_id = ?", req.BankCardID, userID).First(&bankCard).Error; err != nil {
		utils.Logger.Errorf("银行卡不存在或不属于当前用户: 银行卡ID=%d, 用户ID=%d, 错误=%v", req.BankCardID, userID, err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "银行卡不存在或不属于当前用户"})
		return
	}

	// 开始事务
	err := db.Transaction(func(tx *gorm.DB) error {
		// 查询钱包
		var wallet models.Wallet
		if err := tx.Where("user_id = ?", userID).First(&wallet).Error; err != nil {
			utils.Logger.Errorf("查询钱包失败: %v", err)
			return err
		}

		// 检查余额是否足够
		if wallet.Balance < req.Amount {
			utils.Logger.Errorf("余额不足: 当前余额=%f, 提现金额=%f", wallet.Balance, req.Amount)
			return &utils.AppError{Code: 400, Message: "余额不足"}
		}

		now := time.Now().Unix()

		// 创建提现记录
		withdraw := models.Withdraw{
			UserID:     userID,
			BankCardID: req.BankCardID,
			Amount:     req.Amount,
			Status:     "success",
			CreatedAt:  now,
			UpdatedAt:  now,
		}
		if err := tx.Create(&withdraw).Error; err != nil {
			utils.Logger.Errorf("创建提现记录失败: %v", err)
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
			Type:        "withdraw",
			RelatedID:   withdraw.ID,
			Description: "提现到银行卡 (" + bankCard.CardNumber[len(bankCard.CardNumber)-4:] + ")",
			Status:      "success",
			CreatedAt:   now,
			UpdatedAt:   now,
		}
		if err := tx.Create(&transaction).Error; err != nil {
			utils.Logger.Errorf("创建交易记录失败: %v", err)
			return err
		}

		utils.Logger.Infof("提现成功: 用户ID=%d, 银行卡ID=%d, 金额=%f, 当前余额=%f",
			userID, req.BankCardID, req.Amount, wallet.Balance)

		// 创建交易通知
		description := "提现到银行卡 (" + bankCard.CardNumber[len(bankCard.CardNumber)-4:] + ")"
		if err := createTransactionNotification(tx, userID, "withdraw", req.Amount, description); err != nil {
			utils.Logger.Errorf("创建交易通知失败: %v", err)
			// 通知创建失败不影响交易本身
		}

		return nil
	})

	if err != nil {
		if appErr, ok := err.(*utils.AppError); ok {
			utils.Logger.Errorf("提现失败(应用错误): %s", appErr.Message)
			c.JSON(appErr.Code, gin.H{"success": false, "msg": appErr.Message})
		} else {
			utils.Logger.Errorf("提现失败(系统错误): %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "提现失败: " + err.Error()})
		}
		return
	}

	// 查询最新余额
	var wallet models.Wallet
	db.Where("user_id = ?", userID).First(&wallet)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "提现成功",
		"data": gin.H{
			"new_balance": wallet.Balance,
		},
	})
}
