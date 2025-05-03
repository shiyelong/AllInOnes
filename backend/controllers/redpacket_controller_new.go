package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"encoding/json"
	"math"
	"math/rand"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// 发送红包（集成钱包系统）
func SendRedPacketWithWallet(c *gin.Context) {
	var req struct {
		SenderID   uint    `json:"sender_id"`
		ReceiverID uint    `json:"receiver_id"`
		GroupID    uint    `json:"group_id"`
		Amount     float64 `json:"amount"`
		Count      int     `json:"count"`
		Greeting   string  `json:"greeting"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 验证参数
	if req.Amount <= 0 || req.Count <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "金额和数量必须大于0"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 开始事务
	err := db.Transaction(func(tx *gorm.DB) error {
		// 查询发送者钱包
		var senderWallet models.Wallet
		if err := tx.Where("user_id = ?", req.SenderID).First(&senderWallet).Error; err != nil {
			// 如果钱包不存在，创建一个新钱包
			senderWallet = models.Wallet{
				UserID:    req.SenderID,
				Balance:   0,
				CreatedAt: time.Now().Unix(),
				UpdatedAt: time.Now().Unix(),
			}
			if err := tx.Create(&senderWallet).Error; err != nil {
				return err
			}
		}

		// 检查余额是否足够
		if senderWallet.Balance < req.Amount {
			return &utils.AppError{Code: 400, Message: "余额不足"}
		}

		now := time.Now().Unix()

		// 创建红包
		redPacket := models.RedPacket{
			SenderID:        req.SenderID,
			Amount:          req.Amount,
			Count:           req.Count,
			Greeting:        req.Greeting,
			ExpireTime:      now + 86400, // 24小时后过期
			CreatedAt:       now,
			RemainingAmount: req.Amount,
			RemainingCount:  req.Count,
		}
		if err := tx.Create(&redPacket).Error; err != nil {
			return err
		}

		// 更新发送者钱包余额
		senderWallet.Balance -= req.Amount
		senderWallet.UpdatedAt = now
		if err := tx.Save(&senderWallet).Error; err != nil {
			return err
		}

		// 创建发送者交易记录
		senderTransaction := models.Transaction{
			UserID:      req.SenderID,
			Amount:      -req.Amount,
			Balance:     senderWallet.Balance,
			Type:        "redpacket_out",
			RelatedID:   redPacket.ID,
			Description: "发红包",
			Status:      "success",
			CreatedAt:   now,
			UpdatedAt:   now,
		}
		if err := tx.Create(&senderTransaction).Error; err != nil {
			return err
		}

		// 创建红包消息
		extra, _ := json.Marshal(map[string]interface{}{
			"red_packet_id": redPacket.ID,
			"amount":        redPacket.Amount,
			"count":         redPacket.Count,
			"greeting":      redPacket.Greeting,
		})

		message := models.ChatMessage{
			SenderID:   req.SenderID,
			ReceiverID: req.ReceiverID,
			GroupID:    req.GroupID,
			Content:    req.Greeting,
			Type:       "redpacket",
			Extra:      string(extra),
			Status:     1,
			CreatedAt:  now,
		}
		if err := tx.Create(&message).Error; err != nil {
			return err
		}

		return nil
	})

	if err != nil {
		if appErr, ok := err.(*utils.AppError); ok {
			c.JSON(appErr.Code, gin.H{"success": false, "msg": appErr.Message})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "发送红包失败: " + err.Error()})
		}
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "红包发送成功",
	})
}

// 抢红包（集成钱包系统）
func GrabRedPacketWithWallet(c *gin.Context) {
	var req struct {
		RedPacketID uint `json:"red_packet_id"`
		UserID      uint `json:"user_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 开始事务
	err := db.Transaction(func(tx *gorm.DB) error {
		// 查询红包
		var redPacket models.RedPacket
		if err := tx.First(&redPacket, req.RedPacketID).Error; err != nil {
			return &utils.AppError{Code: 404, Message: "红包不存在"}
		}

		// 检查红包是否过期
		if time.Now().Unix() > redPacket.ExpireTime {
			return &utils.AppError{Code: 400, Message: "红包已过期"}
		}

		// 检查红包是否已抢完
		if redPacket.RemainingCount <= 0 {
			return &utils.AppError{Code: 400, Message: "红包已抢完"}
		}

		// 检查用户是否已经抢过
		var count int64
		tx.Model(&models.RedPacketRecord{}).Where("red_packet_id = ? AND user_id = ?", req.RedPacketID, req.UserID).Count(&count)
		if count > 0 {
			return &utils.AppError{Code: 400, Message: "您已经抢过这个红包了"}
		}

		// 计算抢到的金额
		var amount float64
		if redPacket.RemainingCount == 1 {
			// 最后一个，直接拿走剩余金额
			amount = redPacket.RemainingAmount
		} else {
			// 随机金额，但保证剩余的人也能抢到
			r := rand.New(rand.NewSource(time.Now().UnixNano()))
			maxAmount := redPacket.RemainingAmount * 0.7 // 最多抢走剩余金额的70%
			amount = math.Round(r.Float64()*maxAmount*100) / 100
			if amount < 0.01 {
				amount = 0.01 // 最少0.01元
			}
		}

		now := time.Now().Unix()

		// 更新红包信息
		redPacket.RemainingAmount -= amount
		redPacket.RemainingCount--
		if err := tx.Save(&redPacket).Error; err != nil {
			return err
		}

		// 创建抢红包记录
		record := models.RedPacketRecord{
			RedPacketID: req.RedPacketID,
			UserID:      req.UserID,
			Amount:      amount,
			CreatedAt:   now,
		}
		if err := tx.Create(&record).Error; err != nil {
			return err
		}

		// 查询或创建接收者钱包
		var receiverWallet models.Wallet
		result := tx.Where("user_id = ?", req.UserID).First(&receiverWallet)
		if result.Error != nil {
			// 如果接收者钱包不存在，创建一个新钱包
			receiverWallet = models.Wallet{
				UserID:    req.UserID,
				Balance:   0,
				CreatedAt: now,
				UpdatedAt: now,
			}
			if err := tx.Create(&receiverWallet).Error; err != nil {
				return err
			}
		}

		// 更新接收者钱包余额
		receiverWallet.Balance += amount
		receiverWallet.UpdatedAt = now
		if err := tx.Save(&receiverWallet).Error; err != nil {
			return err
		}

		// 创建接收者交易记录
		receiverTransaction := models.Transaction{
			UserID:      req.UserID,
			Amount:      amount,
			Balance:     receiverWallet.Balance,
			Type:        "redpacket_in",
			RelatedID:   redPacket.ID,
			Description: "抢红包",
			Status:      "success",
			CreatedAt:   now,
			UpdatedAt:   now,
		}
		if err := tx.Create(&receiverTransaction).Error; err != nil {
			return err
		}

		return nil
	})

	if err != nil {
		if appErr, ok := err.(*utils.AppError); ok {
			c.JSON(appErr.Code, gin.H{"success": false, "msg": appErr.Message})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "抢红包失败: " + err.Error()})
		}
		return
	}

	// 查询抢到的金额
	var record models.RedPacketRecord
	db.Where("red_packet_id = ? AND user_id = ?", req.RedPacketID, req.UserID).First(&record)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "抢红包成功",
		"data": gin.H{
			"amount":      record.Amount,
			"record_id":   record.ID,
			"create_time": record.CreatedAt,
		},
	})
}
