package models

// 银行卡信息
type BankCard struct {
	ID             uint   `json:"id" gorm:"primaryKey"`
	UserID         uint   `json:"user_id"`
	CardNumber     string `json:"card_number"`
	BankName       string `json:"bank_name"`
	CardholderName string `json:"cardholder_name"`
	ExpiryDate     string `json:"expiry_date,omitempty"` // 只有信用卡需要有效期
	CardType       string `json:"card_type"`             // debit, credit
	Country        string `json:"country"`
	IsDefault      bool   `json:"is_default"`
	CreatedAt      int64  `json:"created_at"`
	VerifiedAt     int64  `json:"verified_at"` // 验证时间
}
