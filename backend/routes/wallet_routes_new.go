package routes

import (
	"allinone_backend/controllers"
	"allinone_backend/middleware"

	"github.com/gin-gonic/gin"
)

// RegisterWalletRoutesNew 注册钱包相关路由
func RegisterWalletRoutesNew(r *gin.RouterGroup) {
	wallet := r.Group("/wallet")
	wallet.Use(middleware.JWTAuth()) // 确保所有钱包相关API都需要认证
	{
		// 获取钱包信息
		wallet.GET("/info", controllers.GetWalletInfo)
		wallet.GET("/overview", controllers.GetWalletOverview)
		wallet.GET("/income-trend", controllers.GetIncomeTrend)
		wallet.GET("/category-stats", controllers.GetCategoryStats)
		wallet.GET("/health", controllers.GetWalletHealth)

		// 获取交易记录
		wallet.GET("/transactions", controllers.GetTransactions)
		wallet.GET("/transactions/advanced", controllers.GetTransactionsAdvanced)
		wallet.GET("/transactions/stats", controllers.GetTransactionStats)
		wallet.GET("/transactions/:id", controllers.GetTransactionDetail)

		// 转账
		wallet.POST("/transfer", controllers.Transfer)

		// 充值
		wallet.POST("/recharge", controllers.Recharge)

		// 提现
		wallet.POST("/withdraw", controllers.Withdraw)

		// 银行卡相关
		bankCard := wallet.Group("/bank-card")
		{
			bankCard.POST("", controllers.AddBankCard)
			bankCard.GET("", controllers.GetBankCards)
			bankCard.DELETE("/:id", controllers.DeleteBankCard)
			bankCard.PUT("/:id/default", controllers.SetDefaultBankCard)

			// 银行卡验证
			bankCard.POST("/verify", controllers.InitiateBankCardVerification)
			bankCard.POST("/verify/confirm", controllers.ConfirmBankCardVerification)
		}

		// 兼容旧版API已经在上面注册过了，不需要重复注册

		// 虚拟货币相关
		crypto := wallet.Group("/crypto")
		{
			crypto.POST("", controllers.AddCryptoWallet)
			crypto.GET("", controllers.GetCryptoWallets)
			crypto.DELETE("/:id", controllers.DeleteCryptoWallet)
			crypto.POST("/deposit", controllers.DepositCrypto)
			crypto.POST("/withdraw", controllers.WithdrawCrypto)
			crypto.GET("/transactions", controllers.GetCryptoTransactions)
		}

		// 钱包安全设置相关
		security := wallet.Group("/security")
		{
			security.GET("", controllers.GetWalletSecurity)
			security.POST("/pay-password", controllers.SetPayPassword)
			security.POST("/verify-pay-password", controllers.VerifyPayPassword)
			security.PUT("/pay-password", controllers.UpdatePayPassword)
			security.PUT("/security-level", controllers.SetSecurityLevel)
			security.PUT("/daily-limit", controllers.SetDailyLimit)
		}

		// 通知相关
		notification := wallet.Group("/notifications")
		{
			notification.GET("", controllers.GetTransactionNotifications)
			notification.GET("/unread-count", controllers.GetUnreadNotificationCount)
			notification.PUT("/:id/read", controllers.MarkNotificationRead)
			notification.PUT("/read-all", controllers.MarkAllNotificationsRead)
		}

		// 预算相关
		budget := wallet.Group("/budget")
		{
			budget.POST("", controllers.CreateBudget)
			budget.GET("", controllers.GetBudgets)
			budget.GET("/categories", controllers.GetBudgetCategories)
			budget.GET("/:id", controllers.GetBudgetDetail)
			budget.PUT("/:id", controllers.UpdateBudget)
			budget.DELETE("/:id", controllers.DeleteBudget)
		}

		// 定期存款相关
		deposit := wallet.Group("/deposit")
		{
			deposit.POST("", controllers.CreateDeposit)
			deposit.GET("", controllers.GetDeposits)
			deposit.GET("/:id", controllers.GetDepositDetail)
			deposit.POST("/:id/withdraw", controllers.WithdrawDeposit)
		}

		// 理财产品相关
		investment := wallet.Group("/investment")
		{
			investment.GET("", controllers.GetInvestments)
			investment.GET("/types", controllers.GetInvestmentTypes)
			investment.GET("/:id", controllers.GetInvestmentDetail)
			investment.POST("/purchase", controllers.PurchaseInvestment)
			investment.GET("/user", controllers.GetUserInvestments)
			investment.GET("/user/:id", controllers.GetUserInvestmentDetail)
			investment.POST("/user/:id/redeem", controllers.RedeemInvestment)
		}

		// 账单导出相关
		export := wallet.Group("/export")
		{
			export.GET("/transactions/csv", controllers.ExportTransactionsCSV)
			export.GET("/transactions/json", controllers.ExportTransactionsJSON)
			export.GET("/monthly-statement", controllers.ExportMonthlyStatement)
		}
	}
}
