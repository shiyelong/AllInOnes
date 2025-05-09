package models

// 语音消息数据模型

type VoiceMessage struct {
	ID         uint   `json:"id" gorm:"primaryKey"`
	SenderID   uint   `json:"sender_id"`
	ReceiverID uint   `json:"receiver_id"`
	GroupID    uint   `json:"group_id"`
	FilePath   string `json:"file_path"` // 服务器上的文件路径
	URL        string `json:"url"`       // 可访问的URL
	Duration   int    `json:"duration"`  // 语音时长（秒）
	Status     int    `json:"status"`    // 0: 发送中, 1: 已发送, 2: 已送达, 3: 已读, 4: 发送失败
	CreatedAt  int64  `json:"created_at"`
}

// WebRTC信令服务器配置
type WebRTCServer struct {
	ID        uint   `json:"id" gorm:"primaryKey"`
	URL       string `json:"url"`        // 信令服务器URL
	Type      string `json:"type"`       // websocket, http
	Status    int    `json:"status"`     // 0: 离线, 1: 在线
	Region    string `json:"region"`     // 服务器区域
	CreatedAt int64  `json:"created_at"` // 创建时间
	UpdatedAt int64  `json:"updated_at"` // 更新时间
}

// TURN/STUN服务器配置
type TurnServer struct {
	ID         uint   `json:"id" gorm:"primaryKey"`
	URL        string `json:"url"`        // 服务器URL
	Username   string `json:"username"`   // 用户名
	Credential string `json:"credential"` // 凭证
	Type       string `json:"type"`       // turn, stun
	Status     int    `json:"status"`     // 0: 离线, 1: 在线
	Region     string `json:"region"`     // 服务器区域
	CreatedAt  int64  `json:"created_at"` // 创建时间
	UpdatedAt  int64  `json:"updated_at"` // 更新时间
}

// 通话质量记录
type CallQualityRecord struct {
	ID           uint    `json:"id" gorm:"primaryKey"`
	CallID       uint    `json:"call_id"`       // 通话ID
	UserID       uint    `json:"user_id"`       // 用户ID
	Timestamp    int64   `json:"timestamp"`     // 记录时间戳
	PacketLoss   float64 `json:"packet_loss"`   // 丢包率
	Jitter       float64 `json:"jitter"`        // 抖动
	Latency      int     `json:"latency"`       // 延迟（毫秒）
	AudioQuality int     `json:"audio_quality"` // 音频质量（1-5）
	VideoQuality int     `json:"video_quality"` // 视频质量（1-5）
	CallType     string  `json:"call_type"`     // voice, video
}
