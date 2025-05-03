package models

// Recharge 充值记录
type Recharge struct {
	ID            uint    `json:"id" gorm:"primaryKey"`
	UserID        uint    `json:"user_id"`
	BankCardID    uint    `json:"bank_card_id"`
	Amount        float64 `json:"amount"`
	Status        string  `json:"status"`         // pending, success, failed
	PaymentMethod string  `json:"payment_method"` // bank_card, crypto, etc.
	CreatedAt     int64   `json:"created_at"`
	UpdatedAt     int64   `json:"updated_at"`
}

// TableName 设置表名
func (Recharge) TableName() string {
	return "recharges"
}
