package models


type User struct {
	ID       uint   `json:"id" gorm:"primaryKey"`
	Account  string `json:"account" gorm:"uniqueIndex"`
	Password string `json:"password"`
	CreatedAt int64  `json:"created_at"`
	FriendAddMode int `json:"friend_add_mode" gorm:"default:0"` // 0=自动同意，1=需验证
}
