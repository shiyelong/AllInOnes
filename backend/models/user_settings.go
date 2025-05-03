package models

// 用户设置
type UserSettings struct {
	ID                uint   `json:"id" gorm:"primaryKey"`
	UserID            uint   `json:"user_id" gorm:"uniqueIndex"`
	Language          string `json:"language" gorm:"default:'zh_CN'"` // 语言设置
	Theme             string `json:"theme" gorm:"default:'light'"`    // 主题设置
	FontSize          int    `json:"font_size" gorm:"default:14"`     // 字体大小
	NotificationSound bool   `json:"notification_sound" gorm:"default:true"`
	MessagePreview    bool   `json:"message_preview" gorm:"default:true"`
	AutoTranslate     bool   `json:"auto_translate" gorm:"default:false"`
	DefaultCurrency   string `json:"default_currency" gorm:"default:'CNY'"`
	TimeFormat        string `json:"time_format" gorm:"default:'24h'"`
	DateFormat        string `json:"date_format" gorm:"default:'yyyy-MM-dd'"`
	CreatedAt         int64  `json:"created_at"`
	UpdatedAt         int64  `json:"updated_at"`
}

// 语言包
type LanguagePack struct {
	ID        uint   `json:"id" gorm:"primaryKey"`
	LangCode  string `json:"lang_code" gorm:"uniqueIndex"` // zh_CN, en_US, etc.
	Name      string `json:"name"`                         // 中文, English, etc.
	Content   string `json:"content"`                      // JSON格式，存储所有翻译文本
	CreatedAt int64  `json:"created_at"`
	UpdatedAt int64  `json:"updated_at"`
}

// 用户自定义语言包
type UserLanguagePack struct {
	ID        uint   `json:"id" gorm:"primaryKey"`
	UserID    uint   `json:"user_id"`
	LangCode  string `json:"lang_code"`
	Content   string `json:"content"` // JSON格式，存储用户自定义的翻译文本
	CreatedAt int64  `json:"created_at"`
	UpdatedAt int64  `json:"updated_at"`
}

// AI设置
type AISettings struct {
	ID              uint   `json:"id" gorm:"primaryKey"`
	UserID          uint   `json:"user_id" gorm:"uniqueIndex"`
	AIModel         string `json:"ai_model" gorm:"default:'gpt-3.5-turbo'"` // 使用的AI模型
	Temperature     float64 `json:"temperature" gorm:"default:0.7"`         // 创造性参数
	MaxTokens       int    `json:"max_tokens" gorm:"default:2000"`          // 最大token数
	PersonalPrompt  string `json:"personal_prompt"`                         // 个人AI助手的提示词
	GroupPrompt     string `json:"group_prompt"`                            // 群组AI助手的提示词
	GamePrompt      string `json:"game_prompt"`                             // 游戏AI助手的提示词
	CreatedAt       int64  `json:"created_at"`
	UpdatedAt       int64  `json:"updated_at"`
}

// 设备信息
type UserDevice struct {
	ID           uint   `json:"id" gorm:"primaryKey"`
	UserID       uint   `json:"user_id"`
	DeviceID     string `json:"device_id" gorm:"uniqueIndex"`
	DeviceType   string `json:"device_type"` // ios, android, windows, macos, linux, web
	DeviceName   string `json:"device_name"`
	DeviceModel  string `json:"device_model"`
	OSVersion    string `json:"os_version"`
	AppVersion   string `json:"app_version"`
	LastLoginAt  int64  `json:"last_login_at"`
	LastActiveAt int64  `json:"last_active_at"`
	IPAddress    string `json:"ip_address"`
	UserAgent    string `json:"user_agent"`
	IsActive     bool   `json:"is_active" gorm:"default:true"`
	CreatedAt    int64  `json:"created_at"`
}
