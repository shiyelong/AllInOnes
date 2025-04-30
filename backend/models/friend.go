package models

type Friend struct {
	ID        uint `gorm:"primaryKey"`
	UserID    uint
	FriendID  uint
	CreatedAt int64
	Blocked   int  `gorm:"default:0"` // 0=未屏蔽，1=屏蔽
}
