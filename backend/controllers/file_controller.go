package controllers

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// 增强版文件上传处理
func UploadFileEnhanced(c *gin.Context) {
	// 获取上传的文件
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "未找到上传文件"})
		return
	}

	// 获取文件类型
	fileType := c.DefaultPostForm("type", "image") // image, voice, video, file

	// 创建上传目录
	uploadDir := fmt.Sprintf("uploads/%s", fileType)
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建上传目录失败"})
		return
	}

	// 生成唯一文件名
	fileExt := filepath.Ext(file.Filename)
	fileName := uuid.New().String() + fileExt
	filePath := filepath.Join(uploadDir, fileName)

	// 保存文件
	if err := c.SaveUploadedFile(file, filePath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "保存文件失败"})
		return
	}

	// 构建文件URL
	fileURL := fmt.Sprintf("/api/static/%s/%s", fileType, fileName)

	// 返回文件信息
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"msg":     "文件上传成功",
		"data": gin.H{
			"url":         fileURL,
			"file_name":   file.Filename,
			"file_size":   file.Size,
			"file_type":   fileType,
			"upload_time": time.Now().Unix(),
		},
	})
}
