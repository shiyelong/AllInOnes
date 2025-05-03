package controllers

import (
	"allinone_backend/models"
	"allinone_backend/utils"
	"time"

	"gorm.io/gorm"
)

// 结算到期的定期存款
func SettleMaturedDeposits(db *gorm.DB) {
	// 获取当前时间
	now := time.Now().Unix()

	// 查询所有到期的定期存款
	var deposits []models.Deposit
	if err := db.Where("status = ? AND end_date <= ?", "active", now).Find(&deposits).Error; err != nil {
		utils.Logger.Errorf("查询到期定期存款失败: %v", err)
		return
	}

	utils.Logger.Infof("找到 %d 个到期的定期存款", len(deposits))

	// 处理每个到期的定期存款
	for _, deposit := range deposits {
		// 开始事务
		err := utils.Transaction(func(tx *gorm.DB) error {
			// 查询用户钱包
			var wallet models.Wallet
			if err := tx.Where("user_id = ?", deposit.UserID).First(&wallet).Error; err != nil {
				utils.Logger.Errorf("查询用户钱包失败: userID=%d, error=%v", deposit.UserID, err)
				return err
			}

			// 计算本金和利息总额
			totalAmount := deposit.Amount + deposit.Interest

			// 更新钱包余额
			wallet.Balance += totalAmount
			if err := tx.Save(&wallet).Error; err != nil {
				utils.Logger.Errorf("更新钱包余额失败: userID=%d, error=%v", deposit.UserID, err)
				return err
			}

			// 更新定期存款状态
			deposit.Status = "matured"
			if err := tx.Save(&deposit).Error; err != nil {
				utils.Logger.Errorf("更新定期存款状态失败: depositID=%d, error=%v", deposit.ID, err)
				return err
			}

			// 创建交易记录
			transaction := models.Transaction{
				UserID:      deposit.UserID,
				Amount:      totalAmount,
				Balance:     wallet.Balance,
				Type:        "deposit_matured",
				RelatedID:   deposit.ID,
				Description: "定期存款到期，本金和利息已返还",
				Status:      "success",
				CreatedAt:   now,
				UpdatedAt:   now,
			}
			if err := tx.Create(&transaction).Error; err != nil {
				utils.Logger.Errorf("创建交易记录失败: userID=%d, error=%v", deposit.UserID, err)
				return err
			}

			// 创建通知
			notification := models.Notification{
				UserID:    deposit.UserID,
				Title:     "定期存款到期",
				Content:   "您的定期存款已到期，本金和利息已返还到您的钱包。本金：" + utils.FormatMoney(deposit.Amount) + "，利息：" + utils.FormatMoney(deposit.Interest),
				Type:      "transaction",
				Status:    "unread",
				CreatedAt: now,
				UpdatedAt: now,
			}
			if err := tx.Create(&notification).Error; err != nil {
				utils.Logger.Errorf("创建通知失败: userID=%d, error=%v", deposit.UserID, err)
				return err
			}

			return nil
		})

		if err != nil {
			utils.Logger.Errorf("结算定期存款失败: depositID=%d, error=%v", deposit.ID, err)
		} else {
			utils.Logger.Infof("成功结算定期存款: depositID=%d, userID=%d, 本金=%.2f, 利息=%.2f", 
				deposit.ID, deposit.UserID, deposit.Amount, deposit.Interest)
		}
	}
}
