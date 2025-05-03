package models

// RedPacket 红包模型
type RedPacket struct {
	ID              uint    `json:"id" gorm:"primaryKey"`
	SenderID        uint    `json:"sender_id"`
	Amount          float64 `json:"amount"`
	Count           int     `json:"count"`
	Greeting        string  `json:"greeting"`
	ExpireTime      int64   `json:"expire_time"`
	RemainingAmount float64 `json:"remaining_amount"`
	RemainingCount  int     `json:"remaining_count"`
	CreatedAt       int64   `json:"created_at"`
}

// RedPacketRecord 红包领取记录模型
type RedPacketRecord struct {
	ID          uint    `json:"id" gorm:"primaryKey"`
	RedPacketID uint    `json:"red_packet_id"`
	UserID      uint    `json:"user_id"`
	Amount      float64 `json:"amount"`
	CreatedAt   int64   `json:"created_at"`
}
