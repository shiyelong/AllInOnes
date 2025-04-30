package models

type FriendRequest struct {
	ID        uint `gorm:"primaryKey"`
	FromID    uint // 申请人
	ToID      uint // 被加人
	Status    int  // 0=待处理, 1=同意, 2=拒绝
	CreatedAt int64
}
