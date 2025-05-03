package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// 设置支付密码
func SetPayPassword(c *gin.Context) {
	var req struct {
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("设置支付密码参数错误: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 验证密码强度
	if len(req.Password) < 6 {
		utils.Logger.Errorf("支付密码长度不足: %d", len(req.Password))
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "支付密码长度不能少于6位"})
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

	// 加密密码
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		utils.Logger.Errorf("密码加密失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "密码加密失败"})
		return
	}

	db := c.MustGet("db").(*gorm.DB)

	// 查询或创建钱包
	var wallet models.Wallet
	result := db.Where("user_id = ?", userID).First(&wallet)
	if result.Error != nil {
		utils.Logger.Infof("钱包不存在，创建新钱包: 用户ID=%d", userID)
		// 如果钱包不存在，创建一个新钱包
		wallet = models.Wallet{
			UserID:         userID,
			Balance:        0,
			PayPassword:    string(hashedPassword),
			PayPasswordSet: true,
			SecurityLevel:  1,
			DailyLimit:     10000,
			CreatedAt:      time.Now().Unix(),
			UpdatedAt:      time.Now().Unix(),
		}
		if err := db.Create(&wallet).Error; err != nil {
			utils.Logger.Errorf("创建钱包失败: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建钱包失败"})
			return
		}
	} else {
		// 更新支付密码
		wallet.PayPassword = string(hashedPassword)
		wallet.PayPasswordSet = true
		wallet.UpdatedAt = time.Now().Unix()
		if err := db.Save(&wallet).Error; err != nil {
			utils.Logger.Errorf("更新支付密码失败: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新支付密码失败"})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "支付密码设置成功",
	})
}

// 验证支付密码
func VerifyPayPassword(c *gin.Context) {
	var req struct {
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("验证支付密码参数错误: %v", err)
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

	db := c.MustGet("db").(*gorm.DB)

	// 查询钱包
	var wallet models.Wallet
	if err := db.Where("user_id = ?", userID).First(&wallet).Error; err != nil {
		utils.Logger.Errorf("查询钱包失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询钱包失败"})
		return
	}

	// 检查是否已设置支付密码
	if !wallet.PayPasswordSet {
		utils.Logger.Errorf("用户未设置支付密码: 用户ID=%d", userID)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "请先设置支付密码"})
		return
	}

	// 验证密码
	err := bcrypt.CompareHashAndPassword([]byte(wallet.PayPassword), []byte(req.Password))
	if err != nil {
		utils.Logger.Errorf("支付密码验证失败: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "支付密码错误"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "支付密码验证成功",
	})
}

// 修改支付密码
func UpdatePayPassword(c *gin.Context) {
	var req struct {
		OldPassword string `json:"old_password"`
		NewPassword string `json:"new_password"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("修改支付密码参数错误: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 验证新密码强度
	if len(req.NewPassword) < 6 {
		utils.Logger.Errorf("新支付密码长度不足: %d", len(req.NewPassword))
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "支付密码长度不能少于6位"})
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

	db := c.MustGet("db").(*gorm.DB)

	// 查询钱包
	var wallet models.Wallet
	if err := db.Where("user_id = ?", userID).First(&wallet).Error; err != nil {
		utils.Logger.Errorf("查询钱包失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询钱包失败"})
		return
	}

	// 检查是否已设置支付密码
	if !wallet.PayPasswordSet {
		utils.Logger.Errorf("用户未设置支付密码: 用户ID=%d", userID)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "请先设置支付密码"})
		return
	}

	// 验证旧密码
	err := bcrypt.CompareHashAndPassword([]byte(wallet.PayPassword), []byte(req.OldPassword))
	if err != nil {
		utils.Logger.Errorf("旧支付密码验证失败: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "旧支付密码错误"})
		return
	}

	// 加密新密码
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		utils.Logger.Errorf("新密码加密失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "密码加密失败"})
		return
	}

	// 更新支付密码
	wallet.PayPassword = string(hashedPassword)
	wallet.UpdatedAt = time.Now().Unix()
	if err := db.Save(&wallet).Error; err != nil {
		utils.Logger.Errorf("更新支付密码失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新支付密码失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "支付密码修改成功",
	})
}

// 设置安全等级
func SetSecurityLevel(c *gin.Context) {
	var req struct {
		SecurityLevel int `json:"security_level"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("设置安全等级参数错误: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 验证安全等级
	if req.SecurityLevel < 1 || req.SecurityLevel > 3 {
		utils.Logger.Errorf("安全等级无效: %d", req.SecurityLevel)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "安全等级无效，应为1-3"})
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

	db := c.MustGet("db").(*gorm.DB)

	// 查询钱包
	var wallet models.Wallet
	result := db.Where("user_id = ?", userID).First(&wallet)
	if result.Error != nil {
		utils.Logger.Errorf("查询钱包失败: %v", result.Error)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询钱包失败"})
		return
	}

	// 更新安全等级
	wallet.SecurityLevel = req.SecurityLevel
	wallet.UpdatedAt = time.Now().Unix()
	if err := db.Save(&wallet).Error; err != nil {
		utils.Logger.Errorf("更新安全等级失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新安全等级失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "安全等级设置成功",
	})
}

// 设置每日交易限额
func SetDailyLimit(c *gin.Context) {
	var req struct {
		DailyLimit float64 `json:"daily_limit"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.Logger.Errorf("设置每日交易限额参数错误: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 验证限额
	if req.DailyLimit <= 0 {
		utils.Logger.Errorf("每日交易限额无效: %f", req.DailyLimit)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "每日交易限额必须大于0"})
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

	db := c.MustGet("db").(*gorm.DB)

	// 查询钱包
	var wallet models.Wallet
	result := db.Where("user_id = ?", userID).First(&wallet)
	if result.Error != nil {
		utils.Logger.Errorf("查询钱包失败: %v", result.Error)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询钱包失败"})
		return
	}

	// 更新每日交易限额
	wallet.DailyLimit = req.DailyLimit
	wallet.UpdatedAt = time.Now().Unix()
	if err := db.Save(&wallet).Error; err != nil {
		utils.Logger.Errorf("更新每日交易限额失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新每日交易限额失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "每日交易限额设置成功",
	})
}

// 获取钱包安全设置
func GetWalletSecurity(c *gin.Context) {
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

	db := c.MustGet("db").(*gorm.DB)

	// 查询钱包
	var wallet models.Wallet
	result := db.Where("user_id = ?", userID).First(&wallet)
	if result.Error != nil {
		utils.Logger.Errorf("查询钱包失败: %v", result.Error)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "查询钱包失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "获取钱包安全设置成功",
		"data": gin.H{
			"pay_password_set": wallet.PayPasswordSet,
			"security_level":   wallet.SecurityLevel,
			"daily_limit":      wallet.DailyLimit,
		},
	})
}
