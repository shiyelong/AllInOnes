package captcha

import (
	"net/http"
	"github.com/gin-gonic/gin"
)

func GetCaptcha(c *gin.Context) {
	id, b64s := GenerateCaptcha()
	c.JSON(http.StatusOK, gin.H{
		"id":  id,
		"img": b64s,
	})
}

func VerifyCaptchaHandler(c *gin.Context) {
	var req struct {
		ID    string `json:"id"`
		Value string `json:"value"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}
	ok := VerifyCaptcha(req.ID, req.Value)
	if !ok {
		c.JSON(http.StatusOK, gin.H{"success": false, "msg": "验证码错误"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}
