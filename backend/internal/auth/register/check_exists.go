package register

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

// CheckExistsRequest 检查邮箱/手机号是否存在的请求
type CheckExistsRequest struct {
	Type   string `json:"type" binding:"required"`   // "email" 或 "phone"
	Target string `json:"target" binding:"required"` // 邮箱或手机号
}

// CheckExistsHandler 检查邮箱/手机号是否已注册
func CheckExistsHandler(c *gin.Context) {
	// 支持GET和POST两种方式
	var req CheckExistsRequest

	// 检查请求方法
	if c.Request.Method == "GET" {
		req.Type = c.Query("type")
		req.Target = c.Query("target")
	} else {
		// 尝试从JSON绑定
		if err := c.ShouldBindJSON(&req); err != nil {
			// 如果JSON绑定失败，尝试从表单获取
			req.Type = c.PostForm("type")
			req.Target = c.PostForm("target")

			// 如果表单也没有，检查是否有email或phone参数
			if req.Type == "" || req.Target == "" {
				email := c.PostForm("email")
				if email != "" {
					req.Type = "email"
					req.Target = email
				} else {
					phone := c.PostForm("phone")
					if phone != "" {
						req.Type = "phone"
						req.Target = phone
					}
				}
			}
		}
	}

	// 验证参数
	if req.Type == "" || req.Target == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "参数错误，需要type和target",
		})
		return
	}

	// 验证类型
	if req.Type != "email" && req.Type != "phone" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "类型错误，必须是 email 或 phone",
		})
		return
	}

	// 验证目标格式
	if req.Type == "email" && !utils.ValidateEmail(req.Target) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "邮箱格式不正确",
		})
		return
	}

	if req.Type == "phone" && !utils.ValidatePhone(req.Target) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"msg":     "手机号格式不正确",
		})
		return
	}

	// 检查是否已存在
	var count int64
	var err error

	if req.Type == "email" {
		err = utils.DB.Model(&models.User{}).Where("email = ?", req.Target).Count(&count).Error
	} else {
		err = utils.DB.Model(&models.User{}).Where("phone = ?", req.Target).Count(&count).Error
	}

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"msg":     "数据库查询错误",
		})
		return
	}

	// 返回结果
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"exists": count > 0,
			"type":   req.Type,
			"target": req.Target,
		},
	})
}
