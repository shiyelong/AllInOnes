package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"encoding/base64"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// 上传头像（Base64格式）
func UploadAvatar(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		AvatarBase64 string `json:"avatar_base64" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 检查Base64数据
	if !strings.HasPrefix(req.AvatarBase64, "data:image/") {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "无效的图片格式"})
		return
	}

	// 解析Base64数据
	commaIndex := strings.Index(req.AvatarBase64, ",")
	if commaIndex == -1 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "无效的Base64数据"})
		return
	}

	// 获取MIME类型
	mimeType := req.AvatarBase64[5:commaIndex]
	if !strings.HasPrefix(mimeType, "image/") {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "只支持图片格式"})
		return
	}

	// 获取文件扩展名
	var fileExt string
	switch mimeType {
	case "image/jpeg":
		fileExt = ".jpg"
	case "image/png":
		fileExt = ".png"
	case "image/gif":
		fileExt = ".gif"
	case "image/webp":
		fileExt = ".webp"
	default:
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "不支持的图片格式"})
		return
	}

	// 解码Base64数据
	base64Data := req.AvatarBase64[commaIndex+1:]
	imageData, err := base64.StdEncoding.DecodeString(base64Data)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "Base64解码失败"})
		return
	}

	// 创建上传目录
	uploadDir := "uploads/avatars"
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建上传目录失败"})
		return
	}

	// 生成唯一文件名
	fileName := fmt.Sprintf("%s_%d%s", uuid.New().String(), time.Now().Unix(), fileExt)
	filePath := filepath.Join(uploadDir, fileName)

	// 保存文件
	if err := os.WriteFile(filePath, imageData, 0644); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "保存文件失败"})
		return
	}

	// 更新用户头像
	avatarURL := "/uploads/avatars/" + fileName
	if err := utils.DB.Model(&models.User{}).Where("id = ?", userID).Update("avatar", avatarURL).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新头像失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "头像上传成功",
		"data": gin.H{
			"avatar_url": avatarURL,
		},
	})
}

// 上传头像（文件上传）
func UploadAvatarFile(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 获取上传的文件
	file, err := c.FormFile("avatar")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "未找到上传文件"})
		return
	}

	// 检查文件类型
	contentType := file.Header.Get("Content-Type")
	if !strings.HasPrefix(contentType, "image/") {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "只支持图片格式"})
		return
	}

	// 获取文件扩展名
	var fileExt string
	switch contentType {
	case "image/jpeg":
		fileExt = ".jpg"
	case "image/png":
		fileExt = ".png"
	case "image/gif":
		fileExt = ".gif"
	case "image/webp":
		fileExt = ".webp"
	default:
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "不支持的图片格式"})
		return
	}

	// 创建上传目录
	uploadDir := "uploads/avatars"
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建上传目录失败"})
		return
	}

	// 生成唯一文件名
	fileName := fmt.Sprintf("%s_%d%s", uuid.New().String(), time.Now().Unix(), fileExt)
	filePath := filepath.Join(uploadDir, fileName)

	// 保存文件
	if err := c.SaveUploadedFile(file, filePath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "保存文件失败"})
		return
	}

	// 更新用户头像
	avatarURL := "/uploads/avatars/" + fileName
	if err := utils.DB.Model(&models.User{}).Where("id = ?", userID).Update("avatar", avatarURL).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新头像失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "头像上传成功",
		"data": gin.H{
			"avatar_url": avatarURL,
		},
	})
}

// 更新用户昵称
func UpdateNickname(c *gin.Context) {
	// 获取当前用户ID
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "msg": "未授权"})
		return
	}

	// 解析请求参数
	var req struct {
		Nickname string `json:"nickname" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "参数错误"})
		return
	}

	// 检查昵称长度
	if len(req.Nickname) < 2 || len(req.Nickname) > 20 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "昵称长度应在2-20个字符之间"})
		return
	}

	// 更新用户昵称
	if err := utils.DB.Model(&models.User{}).Where("id = ?", userID).Update("nickname", req.Nickname).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "更新昵称失败"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "昵称更新成功",
		"data": gin.H{
			"nickname": req.Nickname,
		},
	})
}

// 获取用户头像
func GetUserAvatar(c *gin.Context) {
	// 获取用户ID
	userIDStr := c.Param("id")
	userID, err := strconv.ParseUint(userIDStr, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "无效的用户ID"})
		return
	}

	// 查询用户
	var user models.User
	if err := utils.DB.Select("avatar").First(&user, userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "msg": "用户不存在"})
		return
	}

	// 返回头像URL
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"avatar_url": user.Avatar,
		},
	})
}
