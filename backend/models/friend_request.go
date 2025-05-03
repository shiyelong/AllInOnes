package models

type FriendRequest struct {
	ID         uint   `gorm:"primaryKey"`
	FromID     uint   // 申请人
	ToID       uint   // 被加人
	Status     int    // 0=待处理, 1=同意, 2=拒绝
	Message    string // 验证消息
	SourceType string // 来源类型：search(搜索)、scan(扫码)、recommend(推荐)等
	CreatedAt  int64
}
