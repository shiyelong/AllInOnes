package main

import (
	"allinone_backend/api"
	"allinone_backend/utils"
	"log"
)

func main() {
	if err := utils.InitDB(); err != nil {
		log.Fatalf("数据库初始化失败: %v", err)
	}
	r := api.SetupRouter()
	r.Run(":3001")
}
