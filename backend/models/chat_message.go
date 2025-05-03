package models

// 聊天消息数据模型

type ChatMessage struct {
	ID         uint   `json:"id" gorm:"primaryKey"`
	SenderID   uint   `json:"sender_id"`
	ReceiverID uint   `json:"receiver_id"`
	GroupID    uint   `json:"group_id"`
	Content    string `json:"content"`
	Type       string `json:"type"`   // text, image, voice, video, file, location, redpacket, emoticon
	Extra      string `json:"extra"`  // 额外信息，JSON格式，根据不同类型有不同内容
	Status     int    `json:"status"` // 0: 发送中, 1: 已发送, 2: 已送达, 3: 已读, 4: 发送失败
	CreatedAt  int64  `json:"created_at"`
	// 新增字段
	MentionedUsers string `json:"mentioned_users"` // 被@的用户ID，逗号分隔
	TranslatedText string `json:"translated_text"` // 翻译后的文本
	SourceLanguage string `json:"source_language"` // 源语言
	TargetLanguage string `json:"target_language"` // 目标语言
}

// 红包相关模型已移至 red_packet.go
// 通话记录相关模型已移至 call.go

// 群组聊天扩展
type ChatGroupExt struct {
	ID          uint   `json:"id" gorm:"primaryKey"`
	GroupID     uint   `json:"group_id"`
	Description string `json:"description"`
	UpdatedAt   int64  `json:"updated_at"`
	Settings    string `json:"settings"` // JSON格式，存储群组设置
}

// AI聊天记录
type AIChatMessage struct {
	ID        uint   `json:"id" gorm:"primaryKey"`
	UserID    uint   `json:"user_id"`
	Content   string `json:"content"`
	Response  string `json:"response"`
	CreatedAt int64  `json:"created_at"`
	Type      string `json:"type"` // personal, group, game
	GroupID   uint   `json:"group_id"`
}

// 虚拟货币账户
type CryptoWallet struct {
	ID           uint    `json:"id" gorm:"primaryKey"`
	UserID       uint    `json:"user_id"`
	CurrencyType string  `json:"currency_type"` // BTC, ETH, USDT, etc.
	Address      string  `json:"address"`
	Balance      float64 `json:"balance"`
	CreatedAt    int64   `json:"created_at"`
	UpdatedAt    int64   `json:"updated_at"`
}

// 虚拟货币交易记录
type CryptoTransaction struct {
	ID          uint    `json:"id" gorm:"primaryKey"`
	WalletID    uint    `json:"wallet_id"`
	UserID      uint    `json:"user_id"`
	Type        string  `json:"type"` // deposit, withdraw, transfer
	Amount      float64 `json:"amount"`
	Fee         float64 `json:"fee"`
	Status      int     `json:"status"` // 0: pending, 1: completed, 2: failed
	TxHash      string  `json:"tx_hash"`
	FromAddress string  `json:"from_address"`
	ToAddress   string  `json:"to_address"`
	CreatedAt   int64   `json:"created_at"`
	CompletedAt int64   `json:"completed_at"`
}
