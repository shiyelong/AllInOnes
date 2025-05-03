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
		SenderID   uint    `json:"sender_id"`
		ReceiverID uint    `json:"receiver_id"`
		Amount     float64 `json:"amount"`
		Message    string  `json:"message"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("转账参数错误: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	utils.Logger.Infof("转账请求: 发送者ID=%d, 接收者ID=%d, 金额=%f, 留言=%s",
		req.SenderID, req.ReceiverID, req.Amount, req.Message)

	// 验证参数
	if req.Amount <= 0 {
		utils.Logger.Errorf("转账金额必须大于0: %f", req.Amount)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "转账金额必须大于0"})
		return
	}

	if req.SenderID == req.ReceiverID {
		utils.Logger.Errorf("不能给自己转账: 发送者ID=%d, 接收者ID=%d", req.SenderID, req.ReceiverID)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "不能给自己转账"})
		return
	}

	// 验证发送者ID与当前登录用户ID是否一致
	userIDStr, _ := c.Get("user_id")
	userID, ok := userIDStr.(uint)
	if !ok || userID != req.SenderID {
		utils.Logger.Errorf("发送者ID与当前登录用户ID不一致: 发送者ID=%d, 当前用户ID=%v", req.SenderID, userIDStr)
		c.JSON(http.StatusForbidden, gin.H{"success": false, "msg": "无权操作他人账户"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 开始事务
	err := db.Transaction(func(tx *gorm.DB) error {
		// 查询发送者钱包
		var senderWallet models.Wallet
		if err := tx.Where("user_id = ?", req.SenderID).First(&senderWallet).Error; err != nil {
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
			SenderID:   req.SenderID,
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
			UserID:      req.SenderID,
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
			Description: "收到用户 " + strconv.Itoa(int(req.SenderID)) + " 的转账",
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
			SenderID:   req.SenderID,
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
			req.SenderID, req.ReceiverID, req.Amount)
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

// 充值（模拟）
func Recharge(c *gin.Context) {
	var req struct {
		UserID uint    `json:"user_id"`
		Amount float64 `json:"amount"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("充值参数错误: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	utils.Logger.Infof("充值请求: 用户ID=%d, 金额=%f", req.UserID, req.Amount)

	// 验证参数
	if req.Amount <= 0 {
		utils.Logger.Errorf("充值金额必须大于0: %f", req.Amount)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "充值金额必须大于0"})
		return
	}

	// 验证用户ID与当前登录用户ID是否一致
	userIDStr, _ := c.Get("user_id")
	userID, ok := userIDStr.(uint)
	if !ok || userID != req.UserID {
		utils.Logger.Errorf("用户ID与当前登录用户ID不一致: 用户ID=%d, 当前用户ID=%v", req.UserID, userIDStr)
		c.JSON(http.StatusForbidden, gin.H{"success": false, "msg": "无权操作他人账户"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 开始事务
	err := db.Transaction(func(tx *gorm.DB) error {
		// 查询或创建钱包
		var wallet models.Wallet
		result := tx.Where("user_id = ?", req.UserID).First(&wallet)
		if result.Error != nil {
			utils.Logger.Infof("钱包不存在，创建新钱包: 用户ID=%d", req.UserID)
			// 如果钱包不存在，创建一个新钱包
			wallet = models.Wallet{
				UserID:    req.UserID,
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

		// 更新钱包余额
		wallet.Balance += req.Amount
		wallet.UpdatedAt = now
		if err := tx.Save(&wallet).Error; err != nil {
			utils.Logger.Errorf("更新钱包余额失败: %v", err)
			return err
		}

		// 创建交易记录
		transaction := models.Transaction{
			UserID:      req.UserID,
			Amount:      req.Amount,
			Balance:     wallet.Balance,
			Type:        "recharge",
			Description: "充值",
			Status:      "success",
			CreatedAt:   now,
			UpdatedAt:   now,
		}
		if err := tx.Create(&transaction).Error; err != nil {
			utils.Logger.Errorf("创建交易记录失败: %v", err)
			return err
		}

		utils.Logger.Infof("充值成功: 用户ID=%d, 金额=%f, 当前余额=%f",
			req.UserID, req.Amount, wallet.Balance)
		return nil
	})

	if err != nil {
		utils.Logger.Errorf("充值失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "充值失败: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "充值成功",
	})
}
