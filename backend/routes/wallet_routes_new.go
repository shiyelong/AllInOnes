package routes

import (
	"allinone_backend/controllers"
	"allinone_backend/middleware"

	"github.com/gin-gonic/gin"
)

// RegisterWalletRoutesNew 注册钱包相关路由（新版）
func RegisterWalletRoutesNew(r *gin.RouterGroup) {
	wallet := r.Group("/wallet")
	wallet.Use(middleware.JWTAuth()) // 确保所有钱包相关API都需要认证
	{
		// 获取钱包信息
		wallet.GET("/info", controllers.GetWalletInfo)

		// 获取交易记录
		wallet.GET("/transactions", controllers.GetTransactions)

		// 转账
		wallet.POST("/transfer", controllers.Transfer)

		// 充值（模拟）
		wallet.POST("/recharge", controllers.Recharge)
	}
}
