package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"math/rand"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

// 创建红包
func CreateRedPacket(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		Amount   float64 `json:"amount" binding:"required"`
		Count    int     `json:"count" binding:"required"`
		Greeting string  `json:"greeting"`
		GroupID  uint    `json:"group_id"`
		UserID   uint    `json:"user_id"` // 单聊时的接收者ID
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 检查参数
	if req.Amount <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "红包金额必须大于0"})
		return
	}

	if req.Count <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "红包数量必须大于0"})
		return
	}

	if req.GroupID == 0 && req.UserID == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "必须指定群组ID或用户ID"})
		return
	}

	// 检查用户余额
	var wallet models.Wallet
	if err := utils.DB.Where("user_id = ?", userID).First(&wallet).Error; err != nil {
		// 如果钱包不存在，创建一个
		wallet = models.Wallet{
			UserID:    userID.(uint),
			Balance:   0,
			CreatedAt: time.Now().Unix(),
			UpdatedAt: time.Now().Unix(),
		}
		utils.DB.Create(&wallet)
	}

	if wallet.Balance < req.Amount {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "余额不足"})
		return
	}

	// 创建红包
	redPacket := models.RedPacket{
		SenderID:        userID.(uint),
		Amount:          req.Amount,
		Count:           req.Count,
		Greeting:        req.Greeting,
		ExpireTime:      time.Now().Add(24 * time.Hour).Unix(), // 24小时后过期
		RemainingAmount: req.Amount,
		RemainingCount:  req.Count,
		CreatedAt:       time.Now().Unix(),
	}

	if err := utils.DB.Create(&redPacket).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建红包失败"})
		return
	}

	// 扣除用户余额
	wallet.Balance -= req.Amount
	wallet.UpdatedAt = time.Now().Unix()
	if err := utils.DB.Save(&wallet).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "扣除余额失败"})
		return
	}

	// 创建交易记录
	transaction := models.Transaction{
		UserID:    userID.(uint),
		Type:      "红包支出",
		Amount:    -req.Amount,
		Balance:   wallet.Balance,
		Status:    "成功",
		CreatedAt: time.Now().Unix(),
	}
	utils.DB.Create(&transaction)

	// 创建红包支付记录
	hongbaoPayment := models.HongbaoPayment{
		SenderID:   userID.(uint),
		ReceiverID: 0, // 红包没有特定接收者
		Amount:     req.Amount,
		Remark:     "发送红包",
		PayMethod:  models.PaymentUnionPay, // 默认使用银联支付
		PayAccount: "",
		Status:     "success",
		TxHash:     "",
		CreatedAt:  time.Now().Unix(),
	}
	utils.DB.Create(&hongbaoPayment)

	// 发送红包消息
	var message models.ChatMessage
	if req.GroupID > 0 {
		// 群聊红包
		message = models.ChatMessage{
			SenderID:  userID.(uint),
			GroupID:   req.GroupID,
			Content:   req.Greeting,
			Type:      "redpacket",
			Extra:     `{"red_packet_id":` + strconv.FormatUint(uint64(redPacket.ID), 10) + `,"amount":` + strconv.FormatFloat(req.Amount, 'f', 2, 64) + `,"count":` + strconv.Itoa(req.Count) + `}`,
			Status:    1,
			CreatedAt: time.Now().Unix(),
		}
	} else {
		// 单聊红包
		message = models.ChatMessage{
			SenderID:   userID.(uint),
			ReceiverID: req.UserID,
			Content:    req.Greeting,
			Type:       "redpacket",
			Extra:      `{"red_packet_id":` + strconv.FormatUint(uint64(redPacket.ID), 10) + `,"amount":` + strconv.FormatFloat(req.Amount, 'f', 2, 64) + `,"count":` + strconv.Itoa(req.Count) + `}`,
			Status:     1,
			CreatedAt:  time.Now().Unix(),
		}
	}

	if err := utils.DB.Create(&message).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "发送红包消息失败"})
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

// 领取红包
func ReceiveRedPacket(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		RedPacketID uint `json:"red_packet_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 查询红包
	var redPacket models.RedPacket
	if err := utils.DB.First(&redPacket, req.RedPacketID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "红包不存在"})
		return
	}

	// 检查红包是否过期
	if redPacket.ExpireTime < time.Now().Unix() {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "红包已过期"})
		return
	}

	// 检查红包是否已领完
	if redPacket.RemainingCount <= 0 || redPacket.RemainingAmount <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "红包已领完"})
		return
	}

	// 检查用户是否已领取过该红包
	var existingRecord models.RedPacketRecord
	if err := utils.DB.Where("red_packet_id = ? AND user_id = ?", req.RedPacketID, userID).First(&existingRecord).Error; err == nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "您已领取过该红包"})
		return
	}

	// 计算领取金额
	var amount float64
	if redPacket.RemainingCount == 1 {
		// 最后一个红包，领取剩余全部金额
		amount = redPacket.RemainingAmount
	} else {
		// 随机金额，使用二倍均值法
		maxAmount := redPacket.RemainingAmount / float64(redPacket.RemainingCount) * 2
		// 随机生成0.01到maxAmount之间的金额，保留两位小数
		amount = float64(rand.Intn(int(maxAmount*100))) / 100
		if amount < 0.01 {
			amount = 0.01
		}
	}

	// 更新红包信息
	redPacket.RemainingAmount -= amount
	redPacket.RemainingCount--
	if err := utils.DB.Save(&redPacket).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新红包信息失败"})
		return
	}

	// 创建领取记录
	record := models.RedPacketRecord{
		RedPacketID: req.RedPacketID,
		UserID:      userID.(uint),
		Amount:      amount,
		CreatedAt:   time.Now().Unix(),
	}
	if err := utils.DB.Create(&record).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建领取记录失败"})
		return
	}

	// 更新用户钱包
	var wallet models.Wallet
	if err := utils.DB.Where("user_id = ?", userID).First(&wallet).Error; err != nil {
		// 如果钱包不存在，创建一个
		wallet = models.Wallet{
			UserID:    userID.(uint),
			Balance:   amount,
			CreatedAt: time.Now().Unix(),
			UpdatedAt: time.Now().Unix(),
		}
		utils.DB.Create(&wallet)
	} else {
		wallet.Balance += amount
		wallet.UpdatedAt = time.Now().Unix()
		utils.DB.Save(&wallet)
	}

	// 创建交易记录
	transaction := models.Transaction{
		UserID:    userID.(uint),
		Type:      "红包收入",
		Amount:    amount,
		Balance:   wallet.Balance,
		Status:    "成功",
		CreatedAt: time.Now().Unix(),
	}
	utils.DB.Create(&transaction)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "领取红包成功",
		"data": gin.H{
			"amount":  amount,
			"balance": wallet.Balance,
		},
	})
}

// 获取红包详情
func GetRedPacketDetail(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 获取红包ID
	redPacketIDStr := c.Param("id")
	redPacketID, err := strconv.ParseUint(redPacketIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "无效的红包ID"})
		return
	}

	// 查询红包
	var redPacket models.RedPacket
	if err := utils.DB.First(&redPacket, redPacketID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "红包不存在"})
		return
	}

	// 查询发送者信息
	var sender models.User
	utils.DB.Select("id, nickname, avatar").First(&sender, redPacket.SenderID)

	// 查询领取记录
	var records []models.RedPacketRecord
	utils.DB.Where("red_packet_id = ?", redPacketID).Order("created_at ASC").Find(&records)

	// 查询领取用户信息
	var userIDs []uint
	for _, record := range records {
		userIDs = append(userIDs, record.UserID)
	}

	var users []models.User
	utils.DB.Where("id IN ?", userIDs).Find(&users)

	// 构建用户映射
	userMap := make(map[uint]models.User)
	for _, user := range users {
		userMap[user.ID] = user
	}

	// 构造领取记录响应
	var recordsResp []gin.H
	for _, record := range records {
		user, exists := userMap[record.UserID]
		nickname := ""
		avatar := ""
		if exists {
			nickname = user.Nickname
			avatar = user.Avatar
		}

		recordsResp = append(recordsResp, gin.H{
			"id":         record.ID,
			"user_id":    record.UserID,
			"nickname":   nickname,
			"avatar":     avatar,
			"amount":     record.Amount,
			"created_at": record.CreatedAt,
			"is_self":    record.UserID == userID.(uint),
		})
	}

	// 检查当前用户是否已领取
	var selfRecord models.RedPacketRecord
	hasReceived := utils.DB.Where("red_packet_id = ? AND user_id = ?", redPacketID, userID).First(&selfRecord).Error == nil

	// 检查红包状态
	status := "active"
	if redPacket.ExpireTime < time.Now().Unix() {
		status = "expired"
	} else if redPacket.RemainingCount <= 0 || redPacket.RemainingAmount <= 0 {
		status = "finished"
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"id":               redPacket.ID,
			"sender_id":        redPacket.SenderID,
			"sender_nickname":  sender.Nickname,
			"sender_avatar":    sender.Avatar,
			"amount":           redPacket.Amount,
			"count":            redPacket.Count,
			"greeting":         redPacket.Greeting,
			"expire_time":      redPacket.ExpireTime,
			"remaining_amount": redPacket.RemainingAmount,
			"remaining_count":  redPacket.RemainingCount,
			"created_at":       redPacket.CreatedAt,
			"status":           status,
			"has_received":     hasReceived,
			"records":          recordsResp,
			"is_sender":        redPacket.SenderID == userID.(uint),
		},
	})
}
