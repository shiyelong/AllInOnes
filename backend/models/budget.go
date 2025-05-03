package models

// Budget 预算模型
type Budget struct {
	ID          uint    `json:"id" gorm:"primaryKey"`
	UserID      uint    `json:"user_id" gorm:"index"`
	Category    string  `json:"category" gorm:"index"` // 预算类别: food, shopping, entertainment, etc.
	Amount      float64 `json:"amount"`                // 预算金额
	Period      string  `json:"period"`                // 预算周期: month, year
	StartDate   int64   `json:"start_date"`            // 开始日期（时间戳）
	EndDate     int64   `json:"end_date"`              // 结束日期（时间戳）
	Description string  `json:"description"`           // 预算描述
	CreatedAt   int64   `json:"created_at"`
	UpdatedAt   int64   `json:"updated_at"`
}
