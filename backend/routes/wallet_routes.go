package routes

import (
	"allinone_backend/controllers"

	"github.com/gin-gonic/gin"
)

// RegisterWalletRoutes 注册钱包相关路由
func RegisterWalletRoutes(r *gin.RouterGroup) {
	wallet := r.Group("/wallet")
	{
		// 获取钱包信息
		wallet.GET("/info", controllers.GetWalletInfo)

		// 获取交易记录
		wallet.GET("/transactions", controllers.GetTransactions)

		// 充值
		wallet.POST("/recharge", controllers.Recharge)

		// 提现
		wallet.POST("/withdraw", controllers.Withdraw)

		// 转账
		wallet.POST("/transfer", controllers.Transfer)

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
	}
}
