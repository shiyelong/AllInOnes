package models

// 银行卡验证记录
type BankCardVerification struct {
	ID               uint   `json:"id" gorm:"primaryKey"`
	UserID           uint   `json:"user_id"`
	CardNumber       string `json:"card_number"`
	CardholderName   string `json:"cardholder_name"`
	PhoneNumber      string `json:"phone_number"`
	VerificationCode string `json:"-"` // 不返回给前端
	Status           string `json:"status"`
	CreatedAt        int64  `json:"created_at"`
	ExpiresAt        int64  `json:"expires_at"`
	VerifiedAt       int64  `json:"verified_at,omitempty"`
}
