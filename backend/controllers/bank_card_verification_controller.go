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

// 初始化银行卡验证
func InitiateBankCardVerification(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		CardNumber     string `json:"card_number" binding:"required"`
		CardholderName string `json:"cardholder_name" binding:"required"`
		PhoneNumber    string `json:"phone_number" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 检查卡号格式
	if !utils.IsValidCardNumber(req.CardNumber) {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "无效的银行卡号"})
		return
	}

	// 检查手机号是否为15210888310（用户提供的测试手机号）
	if req.PhoneNumber != "15210888310" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "请使用15210888310手机号进行测试",
		})
		return
	}

	// 生成验证码
	rand.Seed(time.Now().UnixNano())
	verificationCode := strconv.Itoa(100000 + rand.Intn(900000)) // 6位数字验证码

	// 创建验证记录
	verification := models.BankCardVerification{
		UserID:           userID.(uint),
		CardNumber:       req.CardNumber,
		CardholderName:   req.CardholderName,
		PhoneNumber:      req.PhoneNumber,
		VerificationCode: verificationCode,
		Status:           "pending",
		CreatedAt:        time.Now().Unix(),
		ExpiresAt:        time.Now().Add(10 * time.Minute).Unix(), // 10分钟有效期
	}

	if err := utils.DB.Create(&verification).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建验证记录失败"})
		return
	}

	// 模拟发送短信验证码
	// 在实际应用中，这里应该调用短信服务发送验证码
	// 但在测试环境中，我们直接返回验证码
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "验证码已发送",
		"data": gin.H{
			"verification_id": verification.ID,
			"code":           verificationCode, // 注意：实际应用中不应返回验证码
		},
	})
}

// 确认银行卡验证
func ConfirmBankCardVerification(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		VerificationID uint   `json:"verification_id" binding:"required"`
		Code           string `json:"code" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 查询验证记录
	var verification models.BankCardVerification
	if err := utils.DB.Where("id = ? AND user_id = ?", req.VerificationID, userID).First(&verification).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "验证记录不存在"})
		return
	}

	// 检查验证码是否过期
	if verification.ExpiresAt < time.Now().Unix() {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "验证码已过期"})
		return
	}

	// 检查验证码是否正确
	if verification.VerificationCode != req.Code {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "验证码错误"})
		return
	}

	// 更新验证状态
	verification.Status = "verified"
	if err := utils.DB.Save(&verification).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新验证状态失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "银行卡验证成功",
		"data": gin.H{
			"card_number":     verification.CardNumber,
			"cardholder_name": verification.CardholderName,
			"phone_number":    verification.PhoneNumber,
		},
	})
}
