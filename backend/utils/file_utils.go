package utils

import (
	"os"
	"path/filepath"
)

// GetUploadDir 返回上传文件的目录路径
func GetUploadDir() string {
	// 获取当前工作目录
	dir, err := os.Getwd()
	if err != nil {
		// 如果获取失败，使用默认路径
		return "./uploads"
	}

	// 构建上传目录路径
	uploadDir := filepath.Join(dir, "uploads")

	// 确保目录存在
	if _, err := os.Stat(uploadDir); os.IsNotExist(err) {
		os.MkdirAll(uploadDir, 0755)
	}

	return uploadDir
}

// GetMediaDir 返回媒体文件的目录路径
func GetMediaDir() string {
	uploadDir := GetUploadDir()
	mediaDir := filepath.Join(uploadDir, "media")

	// 确保目录存在
	if _, err := os.Stat(mediaDir); os.IsNotExist(err) {
		os.MkdirAll(mediaDir, 0755)
	}

	return mediaDir
}

// GetImageDir 返回图片文件的目录路径
func GetImageDir() string {
	uploadDir := GetUploadDir()
	imageDir := filepath.Join(uploadDir, "images")

	// 确保目录存在
	if _, err := os.Stat(imageDir); os.IsNotExist(err) {
		os.MkdirAll(imageDir, 0755)
	}

	return imageDir
}

// GetVideoDir 返回视频文件的目录路径
func GetVideoDir() string {
	uploadDir := GetUploadDir()
	videoDir := filepath.Join(uploadDir, "videos")

	// 确保目录存在
	if _, err := os.Stat(videoDir); os.IsNotExist(err) {
		os.MkdirAll(videoDir, 0755)
	}

	return videoDir
}

// GetFileDir 返回一般文件的目录路径
func GetFileDir() string {
	uploadDir := GetUploadDir()
	fileDir := filepath.Join(uploadDir, "files")

	// 确保目录存在
	if _, err := os.Stat(fileDir); os.IsNotExist(err) {
		os.MkdirAll(fileDir, 0755)
	}

	return fileDir
}

// GetAvatarDir 返回头像文件的目录路径
func GetAvatarDir() string {
	uploadDir := GetUploadDir()
	avatarDir := filepath.Join(uploadDir, "avatars")

	// 确保目录存在
	if _, err := os.Stat(avatarDir); os.IsNotExist(err) {
		os.MkdirAll(avatarDir, 0755)
	}

	return avatarDir
}

// EnsureFileExists 确保文件存在，如果不存在则创建
func EnsureFileExists(filePath string) error {
	dir := filepath.Dir(filePath)
	
	// 确保目录存在
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	
	// 检查文件是否存在
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		// 创建空文件
		file, err := os.Create(filePath)
		if err != nil {
			return err
		}
		defer file.Close()
	}
	
	return nil
}
