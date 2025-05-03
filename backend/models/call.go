package models

// VoiceCallRecord 语音通话记录模型
type VoiceCallRecord struct {
	ID         uint   `json:"id" gorm:"primaryKey"`
	CallerID   uint   `json:"caller_id" gorm:"index"`
	ReceiverID uint   `json:"receiver_id" gorm:"index"`
	StartTime  int64  `json:"start_time"`
	EndTime    int64  `json:"end_time"`
	Duration   int    `json:"duration"` // 通话时长（秒）
	Status     int    `json:"status"`   // 0: 未接通, 1: 已接通, 2: 已拒绝, 3: 未接听
}

// VideoCallRecord 视频通话记录模型
type VideoCallRecord struct {
	ID         uint   `json:"id" gorm:"primaryKey"`
	CallerID   uint   `json:"caller_id" gorm:"index"`
	ReceiverID uint   `json:"receiver_id" gorm:"index"`
	StartTime  int64  `json:"start_time"`
	EndTime    int64  `json:"end_time"`
	Duration   int    `json:"duration"` // 通话时长（秒）
	Status     int    `json:"status"`   // 0: 未接通, 1: 已接通, 2: 已拒绝, 3: 未接听
}
