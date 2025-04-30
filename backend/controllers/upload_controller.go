package controllers

import (
	"github.com/gin-gonic/gin"
	"net/http"
	"time"
)

// 文件上传接口，支持图片、视频、语音
func UploadFile(c *gin.Context) {
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "msg": "文件获取失败"})
		return
	}

	filename := time.Now().Format("20060102150405") + "_" + file.Filename
	savePath := "uploads/" + filename
	if err := c.SaveUploadedFile(file, savePath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "msg": "上传失败"})
		return
	}
	url := "/static/" + filename
	c.JSON(http.StatusOK, gin.H{"success": true, "url": url})
}
