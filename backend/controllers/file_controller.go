package controllers

import (
	"fmt"
	"log"
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
		log.Printf("未找到上传文件: %v", err)
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "未找到上传文件"})
		return
	}

	// 获取文件类型
	fileType := c.DefaultPostForm("type", "image") // image, voice, video, file
	log.Printf("上传文件类型: %s, 文件名: %s, 大小: %d", fileType, file.Filename, file.Size)

	// 创建上传目录 - 确保目录存在
	// 修正：使用uploads目录作为根目录，与其他上传保持一致
	uploadDir := fmt.Sprintf("uploads/%s", fileType)
	log.Printf("尝试创建上传目录: %s", uploadDir)

	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		log.Printf("创建上传目录失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "创建上传目录失败"})
		return
	}

	// 生成唯一文件名
	fileExt := filepath.Ext(file.Filename)
	fileName := uuid.New().String() + fileExt
	filePath := filepath.Join(uploadDir, fileName)
	log.Printf("保存文件路径: %s", filePath)

	// 保存文件
	if err := c.SaveUploadedFile(file, filePath); err != nil {
		log.Printf("保存文件失败: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "保存文件失败"})
		return
	}

	// 构建文件URL - 修正URL路径
	// 修正：使用正确的URL路径格式
	fileURL := fmt.Sprintf("/%s/%s", uploadDir, fileName)
	log.Printf("文件上传成功，URL: %s", fileURL)

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
