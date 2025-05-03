package models

type User struct {
	ID             uint   `json:"id" gorm:"primaryKey"`
	Account        string `json:"account" gorm:"uniqueIndex"`
	Password       string `json:"password"`
	Email          string `json:"email" gorm:"index"`
	Phone          string `json:"phone" gorm:"index"`
	GeneratedEmail string `json:"generated_email"`
	EmailVerified  bool   `json:"email_verified" gorm:"default:false"`
	PhoneVerified  bool   `json:"phone_verified" gorm:"default:false"`
	Nickname       string `json:"nickname" gorm:"default:''"`
	Avatar         string `json:"avatar" gorm:"default:''"`
	Bio            string `json:"bio" gorm:"default:''"`
	Gender         string `json:"gender" gorm:"default:'未知'"`
	CreatedAt      int64  `json:"created_at"`
	FriendAddMode  int    `json:"friend_add_mode" gorm:"default:1"` // 0=自动同意，1=需验证，2=拒绝所有
}
