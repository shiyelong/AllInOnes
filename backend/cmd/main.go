package main

import (
	"allinone_backend/api"
	"allinone_backend/controllers"
	"allinone_backend/utils"
	"log"
	"time"
)

func main() {
	// 初始化数据库
	if err := utils.InitDB(); err != nil {
		log.Fatalf("数据库初始化失败: %v", err)
	}

	// 初始化定时任务
	initScheduledTasks()

	// 启动Web服务器
	r := api.SetupRouter()
	r.Run(":3001")
}

// 初始化定时任务
func initScheduledTasks() {
	// 获取数据库连接
	db, err := utils.GetDB()
	if err != nil {
		log.Fatalf("获取数据库连接失败: %v", err)
	}

	// 添加定期存款结算任务（每小时执行一次）
	utils.SchedulerManager.AddTask("settle_matured_deposits", time.Hour, func() {
		controllers.SettleMaturedDeposits(db)
	})

	// 启动所有定时任务
	utils.SchedulerManager.StartAll()
}
