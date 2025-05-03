package models

// Withdraw 提现记录
type Withdraw struct {
	ID         uint    `json:"id" gorm:"primaryKey"`
	UserID     uint    `json:"user_id"`
	BankCardID uint    `json:"bank_card_id"`
	Amount     float64 `json:"amount"`
	Status     string  `json:"status"` // pending, success, failed
	CreatedAt  int64   `json:"created_at"`
	UpdatedAt  int64   `json:"updated_at"`
}
