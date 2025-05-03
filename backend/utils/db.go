package utils

import (
	"allinone_backend/models"
	"fmt"
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
		// 用户相关
		&models.User{},
		&models.UserSettings{},
		&models.UserDevice{},
		&models.AISettings{},

		// 聊天相关
		&models.ChatMessage{},
		&models.VoiceCallRecord{},
		&models.VideoCallRecord{},
		&models.AIChatMessage{},

		// 好友相关
		&models.Friend{},
		&models.FriendRequest{},

		// 群组相关
		&models.Group{},
		&models.GroupMember{},
		&models.GroupInvitation{},
		&models.GroupAnnouncement{},
		&models.ChatGroupExt{},

		// 钱包相关
		&models.RedPacket{},
		&models.RedPacketRecord{},
		&models.Wallet{},
		&models.Transaction{},
		&models.Transfer{},
		&models.HongbaoPayment{},
		&models.BankCard{},
		&models.BankCardVerification{},
		&models.CryptoWallet{},
		&models.CryptoTransaction{},
		&models.Recharge{},
		&models.Withdraw{},
		&models.Notification{},
		&models.Budget{},
		&models.Deposit{},
		&models.Investment{},
		&models.UserInvestment{},

		// 多语言支持
		&models.LanguagePack{},
		&models.UserLanguagePack{},

		// 游戏相关
		&models.Game{},
		&models.GameDeveloper{},
		&models.UserGame{},
		&models.GameReview{},
		&models.GameAchievement{},
		&models.UserGameAchievement{},
		&models.GameUpdate{},
		&models.AIGameCharacter{},
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

// 获取数据库连接
func GetDB() (*gorm.DB, error) {
	if DB == nil {
		Logger.Error("数据库未初始化")
		return nil, fmt.Errorf("数据库未初始化")
	}
	return DB, nil
}
