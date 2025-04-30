package models


type Group struct {
	ID        uint           `gorm:"primaryKey" json:"id"`
	Name      string         `json:"name"`
	OwnerID   uint           `json:"owner_id"` // 创建者
	Avatar    string         `json:"avatar"`   // 群头像
	Notice    string         `json:"notice"`   // 群公告
	CreatedAt int64          `json:"created_at"`
	Members   []GroupMember  `gorm:"foreignKey:GroupID" json:"members,omitempty"`
}

type GroupMember struct {
	ID      uint   `gorm:"primaryKey" json:"id"`
	GroupID uint   `json:"group_id"`
	UserID  uint   `json:"user_id"`
	Role    string `json:"role"` // owner, admin, member
}
