package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// 用户注册：自动分配纯数字账号（6~12位）
func RegisterUser(c *gin.Context) {
	var req struct {
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	user := models.User{
		Password:  req.Password,
		CreatedAt: time.Now().Unix(),
	}
	if err := db.Create(&user).Error; err != nil {
		c.JSON(500, gin.H{"success": false, "msg": "注册失败"})
		return
	}
	// 纯数字账号生成（如QQ号，100000起步，保证唯一）
	account := strconv.Itoa(100000 + int(user.ID))
	db.Model(&user).Update("Account", account)
	c.JSON(200, gin.H{"success": true, "msg": "注册成功", "account": account, "user_id": user.ID})
}

// 通过账号查找用户ID
func GetUserByAccount(c *gin.Context) {
	account := c.Query("account")
	if account == "" {
		c.JSON(400, gin.H{"success": false, "msg": "参数缺失"})
		return
	}
	db := c.MustGet("db").(*gorm.DB)
	var user models.User
	if err := db.Where("account = ?", account).First(&user).Error; err != nil {
		c.JSON(404, gin.H{"success": false, "msg": "账号不存在"})
		return
	}
	c.JSON(200, gin.H{"success": true, "user_id": user.ID, "account": user.Account})
}

// Register 用户注册
func Register(c *gin.Context) {
	var req struct {
		Account      string `json:"account" binding:"required"`
		Password     string `json:"password" binding:"required"`
		CaptchaID    string `json:"captcha_id" binding:"required"`
		CaptchaValue string `json:"captcha_value" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "请求参数错误",
		})
		return
	}

	// 验证验证码
	if !utils.VerifyCaptcha(req.CaptchaID, req.CaptchaValue) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "验证码错误",
		})
		return
	}

	// 检查用户是否已存在
	var existingUser models.User
	if err := utils.DB.Where("account = ?", req.Account).First(&existingUser).Error; err == nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "账号已存在",
		})
		return
	}

	// 密码加密
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "服务器内部错误",
		})
		return
	}

	// 创建用户
	user := models.User{
		Account:   req.Account,
		Password:  string(hashedPassword),
		Nickname:  req.Account, // 默认昵称与账号相同
		CreatedAt: time.Now().Unix(),
	}

	if err := utils.DB.Create(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "注册失败",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "注册成功",
	})
}

// Login 用户登录
func Login(c *gin.Context) {
	var req struct {
		Account  string `json:"account" binding:"required"`
		Password string `json:"password" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "请求参数错误",
		})
		return
	}

	// 查询用户
	var user models.User
	if err := utils.DB.Where("account = ?", req.Account).First(&user).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "账号或密码错误",
		})
		return
	}

	// 验证密码
	if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "账号或密码错误",
		})
		return
	}

	// 生成JWT
	token, err := utils.GenerateToken(user.ID, user.Account)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "登录失败",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "登录成功",
		"data": gin.H{
			"token": token,
			"user": gin.H{
				"id":       user.ID,
				"account":  user.Account,
				"nickname": user.Nickname,
				"avatar":   user.Avatar,
			},
		},
	})
}

// ValidateToken 验证Token
func ValidateToken(c *gin.Context) {
	authHeader := c.GetHeader("Authorization")
	if authHeader == "" {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"msg":     "未提供token",
		})
		return
	}

	// 解析token
	parts := authHeader[7:] // 去掉"Bearer "前缀
	claims, err := utils.ParseToken(parts)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"msg":     "token无效或已过期",
		})
		return
	}

	// 查询用户
	var user models.User
	if err := utils.DB.First(&user, claims.UserID).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{
			"success": false,
			"msg":     "用户不存在",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "token有效",
		"data": gin.H{
			"user_id":  user.ID,
			"account":  user.Account,
			"nickname": user.Nickname,
			"avatar":   user.Avatar,
		},
	})
}

// GetUserInfo 获取用户信息
func GetUserInfo(c *gin.Context) {
	userID, _ := c.Get("user_id")

	var user models.User
	if err := utils.DB.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"msg":     "用户不存在",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"id":       user.ID,
			"account":  user.Account,
			"nickname": user.Nickname,
			"avatar":   user.Avatar,
			"bio":      user.Bio,
			"gender":   user.Gender,
		},
	})
}

// UpdateUserInfo 更新用户信息
func UpdateUserInfo(c *gin.Context) {
	userID, _ := c.Get("user_id")

	var req struct {
		Nickname string `json:"nickname"`
		Avatar   string `json:"avatar"`
		Bio      string `json:"bio"`
		Gender   string `json:"gender"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "请求参数错误",
		})
		return
	}

	// 查询用户
	var user models.User
	if err := utils.DB.First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"msg":     "用户不存在",
		})
		return
	}

	// 更新用户信息
	updates := map[string]interface{}{}
	if req.Nickname != "" {
		updates["nickname"] = req.Nickname
	}
	if req.Avatar != "" {
		updates["avatar"] = req.Avatar
	}
	if req.Bio != "" {
		updates["bio"] = req.Bio
	}
	if req.Gender != "" {
		updates["gender"] = req.Gender
	}

	if err := utils.DB.Model(&user).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "更新失败",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "更新成功",
		"data": gin.H{
			"id":       user.ID,
			"account":  user.Account,
			"nickname": user.Nickname,
			"avatar":   user.Avatar,
			"bio":      user.Bio,
			"gender":   user.Gender,
		},
	})
}
