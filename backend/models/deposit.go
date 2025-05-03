package models

// Deposit 定期存款模型
type Deposit struct {
	ID           uint    `json:"id" gorm:"primaryKey"`
	UserID       uint    `json:"user_id" gorm:"index"`
	Amount       float64 `json:"amount"`                // 存款金额
	InterestRate float64 `json:"interest_rate"`         // 年利率（百分比）
	Term         int     `json:"term"`                  // 存款期限（月）
	StartDate    int64   `json:"start_date"`            // 开始日期（时间戳）
	EndDate      int64   `json:"end_date"`              // 结束日期（时间戳）
	Status       string  `json:"status" gorm:"index"`   // 状态: active, completed, withdrawn
	Interest     float64 `json:"interest"`              // 预计利息
	CreatedAt    int64   `json:"created_at"`
	UpdatedAt    int64   `json:"updated_at"`
}

// Investment 理财产品模型
type Investment struct {
	ID              uint    `json:"id" gorm:"primaryKey"`
	Name            string  `json:"name"`                       // 产品名称
	Description     string  `json:"description"`                // 产品描述
	Type            string  `json:"type" gorm:"index"`          // 产品类型: fund, stock, bond, etc.
	ExpectedReturn  float64 `json:"expected_return"`            // 预期年化收益率（百分比）
	MinInvestment   float64 `json:"min_investment"`             // 最低投资金额
	Risk            int     `json:"risk"`                       // 风险等级: 1-5
	Term            int     `json:"term"`                       // 投资期限（月），0表示无固定期限
	AvailableAmount float64 `json:"available_amount"`           // 可投资金额
	Status          string  `json:"status" gorm:"index"`        // 状态: available, sold_out, closed
	CreatedAt       int64   `json:"created_at"`
	UpdatedAt       int64   `json:"updated_at"`
}

// UserInvestment 用户投资记录模型
type UserInvestment struct {
	ID           uint    `json:"id" gorm:"primaryKey"`
	UserID       uint    `json:"user_id" gorm:"index"`
	InvestmentID uint    `json:"investment_id" gorm:"index"`
	Amount       float64 `json:"amount"`                // 投资金额
	StartDate    int64   `json:"start_date"`            // 开始日期（时间戳）
	EndDate      int64   `json:"end_date"`              // 结束日期（时间戳），0表示无固定期限
	Status       string  `json:"status" gorm:"index"`   // 状态: active, completed, withdrawn
	Profit       float64 `json:"profit"`                // 已获利润
	CreatedAt    int64   `json:"created_at"`
	UpdatedAt    int64   `json:"updated_at"`
}
