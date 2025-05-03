package routes

import (
	"github.com/gin-gonic/gin"
)

// RegisterWalletRoutes 注册钱包相关路由
func RegisterWalletRoutes(r *gin.RouterGroup) {
	wallet := r.Group("/wallet")
	{
		// 获取钱包信息
		wallet.GET("/info", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "获取钱包信息成功",
				"data": gin.H{
					"balance":     1000.0,
					"points":      500,
					"card_count":  2,
					"coupon_count": 3,
				},
			})
		})

		// 获取交易记录
		wallet.GET("/transactions", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "获取交易记录成功",
				"data": []gin.H{
					{
						"id":         1,
						"type":       "充值",
						"amount":     100.0,
						"status":     "成功",
						"created_at": 1625123456,
					},
					{
						"id":         2,
						"type":       "消费",
						"amount":     -50.0,
						"status":     "成功",
						"created_at": 1625123457,
					},
				},
			})
		})

		// 充值
		wallet.POST("/recharge", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "充值成功",
				"data": gin.H{
					"transaction_id": 3,
					"amount":         100.0,
					"balance":        1100.0,
				},
			})
		})

		// 提现
		wallet.POST("/withdraw", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"success": true,
				"msg":     "提现申请已提交",
				"data": gin.H{
					"transaction_id": 4,
					"amount":         -100.0,
					"balance":        900.0,
				},
			})
		})
	}
}
