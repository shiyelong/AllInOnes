package models

// Wallet 用户钱包模型
type Wallet struct {
	ID             uint    `json:"id" gorm:"primaryKey"`
	UserID         uint    `json:"user_id" gorm:"uniqueIndex"`
	Balance        float64 `json:"balance" gorm:"default:0"`
	PayPassword    string  `json:"-" gorm:"default:''"`               // 支付密码（加密存储）
	PayPasswordSet bool    `json:"pay_password_set" gorm:"default:0"` // 是否已设置支付密码
	SecurityLevel  int     `json:"security_level" gorm:"default:1"`   // 安全等级：1-低，2-中，3-高
	DailyLimit     float64 `json:"daily_limit" gorm:"default:10000"`  // 每日交易限额
	CreatedAt      int64   `json:"created_at"`
	UpdatedAt      int64   `json:"updated_at"`
}

// Transaction 交易记录模型
type Transaction struct {
	ID          uint    `json:"id" gorm:"primaryKey"`
	UserID      uint    `json:"user_id"`
	Amount      float64 `json:"amount"`
	Balance     float64 `json:"balance"`     // 交易后余额
	Type        string  `json:"type"`        // 交易类型: recharge(充值), withdraw(提现), transfer_in(转入), transfer_out(转出), redpacket_in(收红包), redpacket_out(发红包)
	RelatedID   uint    `json:"related_id"`  // 关联ID，如转账ID或红包ID
	Description string  `json:"description"` // 交易描述
	Status      string  `json:"status"`      // 交易状态: pending(处理中), success(成功), failed(失败)
	CreatedAt   int64   `json:"created_at"`
	UpdatedAt   int64   `json:"updated_at"`
}

// Transfer 转账记录模型
type Transfer struct {
	ID         uint    `json:"id" gorm:"primaryKey"`
	SenderID   uint    `json:"sender_id"`
	ReceiverID uint    `json:"receiver_id"`
	Amount     float64 `json:"amount"`
	Message    string  `json:"message"` // 转账留言
	Status     string  `json:"status"`  // 转账状态: pending(处理中), success(成功), failed(失败)
	CreatedAt  int64   `json:"created_at"`
	UpdatedAt  int64   `json:"updated_at"`
}
