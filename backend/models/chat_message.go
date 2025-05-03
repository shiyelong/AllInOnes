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
}

// 红包相关模型已移至 red_packet.go

// 语音通话记录
type VoiceCallRecord struct {
	ID         uint  `json:"id" gorm:"primaryKey"`
	CallerID   uint  `json:"caller_id"`
	ReceiverID uint  `json:"receiver_id"`
	StartTime  int64 `json:"start_time"`
	EndTime    int64 `json:"end_time"`
	Duration   int   `json:"duration"` // 通话时长，单位：秒
	Status     int   `json:"status"`   // 0: 未接通, 1: 已接通, 2: 已拒绝, 3: 未接听
}

// 视频通话记录
type VideoCallRecord struct {
	ID         uint  `json:"id" gorm:"primaryKey"`
	CallerID   uint  `json:"caller_id"`
	ReceiverID uint  `json:"receiver_id"`
	StartTime  int64 `json:"start_time"`
	EndTime    int64 `json:"end_time"`
	Duration   int   `json:"duration"` // 通话时长，单位：秒
	Status     int   `json:"status"`   // 0: 未接通, 1: 已接通, 2: 已拒绝, 3: 未接听
}
