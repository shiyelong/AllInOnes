package utils

import (
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"allinone_backend/models"
)

var DB *gorm.DB

func InitDB() error {
	db, err := gorm.Open(sqlite.Open("allinone.db"), &gorm.Config{})
	if err != nil {
		return err
	}
	// 自动迁移表结构
	err = db.AutoMigrate(
		&models.User{},
		&models.ChatMessage{},
	)
	if err != nil {
		return err
	}
	DB = db
	return nil
}
