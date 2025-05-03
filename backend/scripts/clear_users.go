package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// 用户模型（简化版，只需要包含必要的字段用于删除）
type User struct {
	ID uint `gorm:"primaryKey"`
}

// 好友关系模型
type Friend struct {
	ID uint `gorm:"primaryKey"`
}

// 好友请求模型
type FriendRequest struct {
	ID uint `gorm:"primaryKey"`
}

// 聊天消息模型
type ChatMessage struct {
	ID uint `gorm:"primaryKey"`
}

// 红包模型
type RedPacket struct {
	ID uint `gorm:"primaryKey"`
}

// 红包记录模型
type RedPacketRecord struct {
	ID uint `gorm:"primaryKey"`
}

// 钱包模型
type Wallet struct {
	ID uint `gorm:"primaryKey"`
}

// 交易记录模型
type Transaction struct {
	ID uint `gorm:"primaryKey"`
}

// 转账记录模型
type Transfer struct {
	ID uint `gorm:"primaryKey"`
}

// 红包支付模型
type HongbaoPayment struct {
	ID uint `gorm:"primaryKey"`
}

func main() {
	// 获取当前工作目录
	currentDir, err := os.Getwd()
	if err != nil {
		log.Fatalf("获取当前工作目录失败: %v", err)
	}

	// 构建数据库文件路径（假设脚本在backend目录下运行）
	dbPath := filepath.Join(currentDir, "allinone.db")
	
	// 检查数据库文件是否存在
	if _, err := os.Stat(dbPath); os.IsNotExist(err) {
		// 尝试向上一级目录查找
		dbPath = filepath.Join(filepath.Dir(currentDir), "allinone.db")
		if _, err := os.Stat(dbPath); os.IsNotExist(err) {
			log.Fatalf("数据库文件不存在: %v", err)
		}
	}

	fmt.Printf("正在连接数据库: %s\n", dbPath)

	// 配置GORM日志
	newLogger := logger.New(
		log.New(os.Stdout, "\r\n", log.LstdFlags),
		logger.Config{
			LogLevel: logger.Info,
			Colorful: true,
		},
	)

	// 连接数据库
	db, err := gorm.Open(sqlite.Open(dbPath), &gorm.Config{
		Logger: newLogger,
	})
	if err != nil {
		log.Fatalf("连接数据库失败: %v", err)
	}

	fmt.Println("成功连接到数据库")
	fmt.Println("开始清除所有用户数据...")

	// 使用事务确保数据一致性
	err = db.Transaction(func(tx *gorm.DB) error {
		// 清除与用户相关的所有数据
		// 注意：删除顺序很重要，需要先删除依赖于用户的数据

		// 1. 删除聊天消息
		if err := tx.Exec("DELETE FROM chat_messages").Error; err != nil {
			fmt.Printf("删除聊天消息失败: %v\n", err)
			return err
		}
		fmt.Println("已清除所有聊天消息")

		// 2. 删除好友请求
		if err := tx.Exec("DELETE FROM friend_requests").Error; err != nil {
			fmt.Printf("删除好友请求失败: %v\n", err)
			return err
		}
		fmt.Println("已清除所有好友请求")

		// 3. 删除好友关系
		if err := tx.Exec("DELETE FROM friends").Error; err != nil {
			fmt.Printf("删除好友关系失败: %v\n", err)
			return err
		}
		fmt.Println("已清除所有好友关系")

		// 4. 删除红包记录
		if err := tx.Exec("DELETE FROM red_packet_records").Error; err != nil {
			fmt.Printf("删除红包记录失败: %v\n", err)
			return err
		}
		fmt.Println("已清除所有红包记录")

		// 5. 删除红包
		if err := tx.Exec("DELETE FROM red_packets").Error; err != nil {
			fmt.Printf("删除红包失败: %v\n", err)
			return err
		}
		fmt.Println("已清除所有红包")

		// 6. 删除交易记录
		if err := tx.Exec("DELETE FROM transactions").Error; err != nil {
			fmt.Printf("删除交易记录失败: %v\n", err)
			return err
		}
		fmt.Println("已清除所有交易记录")

		// 7. 删除转账记录
		if err := tx.Exec("DELETE FROM transfers").Error; err != nil {
			fmt.Printf("删除转账记录失败: %v\n", err)
			return err
		}
		fmt.Println("已清除所有转账记录")

		// 8. 删除红包支付
		if err := tx.Exec("DELETE FROM hongbao_payments").Error; err != nil {
			fmt.Printf("删除红包支付失败: %v\n", err)
			return err
		}
		fmt.Println("已清除所有红包支付")

		// 9. 删除钱包
		if err := tx.Exec("DELETE FROM wallets").Error; err != nil {
			fmt.Printf("删除钱包失败: %v\n", err)
			return err
		}
		fmt.Println("已清除所有钱包")

		// 10. 最后删除用户
		if err := tx.Exec("DELETE FROM users").Error; err != nil {
			fmt.Printf("删除用户失败: %v\n", err)
			return err
		}
		fmt.Println("已清除所有用户")

		return nil
	})

	if err != nil {
		log.Fatalf("清除数据失败: %v", err)
	}

	fmt.Println("所有用户数据已成功清除！")
}
