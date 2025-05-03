package utils

import (
	"allinone_backend/models"
	"log"
	"time"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

func InitDB() error {
	// 配置GORM日志
	newLogger := logger.New(
		log.New(log.Writer(), "\r\n", log.LstdFlags),
		logger.Config{
			SlowThreshold:             time.Second,
			LogLevel:                  logger.Info,
			IgnoreRecordNotFoundError: true,
			Colorful:                  true,
		},
	)

	db, err := gorm.Open(sqlite.Open("allinone.db"), &gorm.Config{
		Logger: newLogger,
	})
	if err != nil {
		return err
	}

	// 自动迁移表结构
	err = db.AutoMigrate(
		&models.User{},
		&models.ChatMessage{},
		&models.Friend{},
		&models.FriendRequest{},
		&models.RedPacket{},
		&models.RedPacketRecord{},
		&models.Wallet{},
		&models.Transaction{},
		&models.Transfer{},
		&models.HongbaoPayment{},
		// 添加其他模型
	)
	if err != nil {
		return err
	}

	DB = db
	return nil
}

// 事务处理
func Transaction(fn func(tx *gorm.DB) error) error {
	return DB.Transaction(fn)
}
