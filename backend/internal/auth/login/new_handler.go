package login

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"net/http"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
)

type NewLoginRequest struct {
	Account   string `json:"account"`
	Password  string `json:"password"`
	LoginType string `json:"login_type"` // "account", "phone", "email"
}

// 新的登录处理函数，支持账号、手机号和邮箱登录
func NewLoginHandler(c *gin.Context) {
	var req NewLoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 根据登录类型查询用户
	var user models.User
	var err error

	switch req.LoginType {
	case "account":
		// 通过账号查询
		err = utils.DB.Where("account = ?", req.Account).First(&user).Error
	case "phone":
		// 通过手机号查询
		err = utils.DB.Where("phone = ?", req.Account).First(&user).Error
	case "email":
		// 通过邮箱查询
		err = utils.DB.Where("email = ?", req.Account).First(&user).Error
	default:
		// 默认通过账号查询
		err = utils.DB.Where("account = ?", req.Account).First(&user).Error
	}

	// 用户不存在或密码错误
	if err != nil || bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)) != nil {
		c.JSON(http.StatusOK, gin.H{"success": false, "msg": "账号或密码错误"})
		return
	}

	// 生成JWT
	token, err := utils.GenerateToken(user.ID, user.Account)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "生成token失败"})
		return
	}

	// 返回用户信息
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "登录成功",
		"data": gin.H{
			"token": token,
			"user": gin.H{
				"id":              user.ID,
				"account":         user.Account,
				"nickname":        user.Nickname,
				"avatar":          user.Avatar,
				"email":           user.Email,
				"phone":           user.Phone,
				"generated_email": user.GeneratedEmail,
			},
		},
	})
}
