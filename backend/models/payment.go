package models

type PaymentChannel string

const (
	PaymentUnionPay         PaymentChannel = "unionpay"
	PaymentBitcoin          PaymentChannel = "bitcoin"
	PaymentEthereum         PaymentChannel = "ethereum"
	PaymentInternationalCard PaymentChannel = "international_card"
)

type HongbaoPayment struct {
	ID         uint           `gorm:"primaryKey" json:"id"`
	SenderID   uint           `json:"sender_id"`
	ReceiverID uint           `json:"receiver_id"`
	Amount     float64        `json:"amount"`
	Remark     string         `json:"remark"`
	PayMethod  PaymentChannel `json:"pay_method"`
	PayAccount string         `json:"pay_account"`
	Status     string         `json:"status"` // pending, success, failed
	TxHash     string         `json:"tx_hash"` // 区块链交易hash或第三方流水号
	CreatedAt  int64          `json:"created_at"`
}
