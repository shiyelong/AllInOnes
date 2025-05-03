package controllers

import (
	"allinone_backend/models"
	"encoding/json"
	"math"
	"math/rand"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// 发送红包
func SendRedPacket(c *gin.Context) {
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

	// 创建红包
	db := c.MustGet("db").(*gorm.DB)
	redPacket := models.RedPacket{
		SenderID:        req.SenderID,
		Amount:          req.Amount,
		Count:           req.Count,
		Greeting:        req.Greeting,
		ExpireTime:      time.Now().Add(24 * time.Hour).Unix(), // 24小时后过期
		CreatedAt:       time.Now().Unix(),
		RemainingAmount: req.Amount,
		RemainingCount:  req.Count,
	}
	if err := db.Create(&redPacket).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建红包失败"})
		return
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
		CreatedAt:  time.Now().Unix(),
	}
	if err := db.Create(&message).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建消息失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "红包发送成功",
		"data": gin.H{
			"red_packet_id": redPacket.ID,
			"message_id":    message.ID,
		},
	})
}

// 抢红包
func GrabRedPacket(c *gin.Context) {
	var req struct {
		RedPacketID uint `json:"red_packet_id"`
		UserID      uint `json:"user_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)
	var redPacket models.RedPacket
	if err := db.First(&redPacket, req.RedPacketID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "红包不存在"})
		return
	}

	// 检查红包是否过期
	if time.Now().Unix() > redPacket.ExpireTime {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "红包已过期"})
		return
	}

	// 检查红包是否已抢完
	if redPacket.RemainingCount <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "红包已抢完"})
		return
	}

	// 检查用户是否已经抢过
	var count int64
	db.Model(&models.RedPacketRecord{}).Where("red_packet_id = ? AND user_id = ?", req.RedPacketID, req.UserID).Count(&count)
	if count > 0 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "您已经抢过这个红包了"})
		return
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

	// 更新红包信息
	db.Model(&redPacket).Updates(map[string]interface{}{
		"remaining_amount": redPacket.RemainingAmount - amount,
		"remaining_count":  redPacket.RemainingCount - 1,
	})

	// 创建抢红包记录
	record := models.RedPacketRecord{
		RedPacketID: req.RedPacketID,
		UserID:      req.UserID,
		Amount:      amount,
		CreatedAt:   time.Now().Unix(),
	}
	if err := db.Create(&record).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建记录失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "抢红包成功",
		"data": gin.H{
			"amount":      amount,
			"record_id":   record.ID,
			"create_time": record.CreatedAt,
		},
	})
}

// 获取红包详情
func GetRedPacketDetail(c *gin.Context) {
	redPacketIDStr := c.Query("id")
	redPacketID, err := strconv.Atoi(redPacketIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)
	var redPacket models.RedPacket
	if err := db.First(&redPacket, redPacketID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "红包不存在"})
		return
	}

	// 获取发送者信息
	var sender models.User
	db.First(&sender, redPacket.SenderID)

	// 获取抢红包记录
	var records []models.RedPacketRecord
	db.Where("red_packet_id = ?", redPacketID).Order("created_at asc").Find(&records)

	// 构建记录响应
	var recordsResp []gin.H
	var totalGrabbed float64
	for _, record := range records {
		var user models.User
		db.First(&user, record.UserID)
		recordsResp = append(recordsResp, gin.H{
			"user_id":    record.UserID,
			"nickname":   user.Nickname,
			"avatar":     user.Avatar,
			"amount":     record.Amount,
			"created_at": record.CreatedAt,
			"is_best":    false, // 后面会更新
		})
		totalGrabbed += record.Amount
	}

	// 找出手气最佳
	if len(recordsResp) > 0 {
		bestIndex := 0
		bestAmount := recordsResp[0]["amount"].(float64)
		for i, record := range recordsResp {
			if record["amount"].(float64) > bestAmount {
				bestAmount = record["amount"].(float64)
				bestIndex = i
			}
		}
		recordsResp[bestIndex]["is_best"] = true
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"red_packet": gin.H{
				"id":               redPacket.ID,
				"sender_id":        redPacket.SenderID,
				"sender_nickname":  sender.Nickname,
				"sender_avatar":    sender.Avatar,
				"amount":           redPacket.Amount,
				"count":            redPacket.Count,
				"greeting":         redPacket.Greeting,
				"expire_time":      redPacket.ExpireTime,
				"created_at":       redPacket.CreatedAt,
				"remaining_amount": redPacket.RemainingAmount,
				"remaining_count":  redPacket.RemainingCount,
				"total_grabbed":    totalGrabbed,
				"is_expired":       time.Now().Unix() > redPacket.ExpireTime,
				"is_finished":      redPacket.RemainingCount == 0,
			},
			"records": recordsResp,
		},
	})
}
