package models

// 群组
type Group struct {
	ID          uint          `gorm:"primaryKey" json:"id"`
	Name        string        `json:"name"`
	OwnerID     uint          `json:"owner_id"` // 创建者
	Avatar      string        `json:"avatar"`   // 群头像
	Notice      string        `json:"notice"`   // 群公告
	CreatedAt   int64         `json:"created_at"`
	UpdatedAt   int64         `json:"updated_at"`
	MaxMembers  int           `json:"max_members" gorm:"default:200"` // 最大成员数
	Members     []GroupMember `gorm:"foreignKey:GroupID" json:"members,omitempty"`
	Description string        `json:"description"`                  // 群描述
	Type        string        `json:"type" gorm:"default:'normal'"` // normal, work, game, ai
}

// 群成员
type GroupMember struct {
	ID         uint   `gorm:"primaryKey" json:"id"`
	GroupID    uint   `json:"group_id"`
	UserID     uint   `json:"user_id"`
	Role       string `json:"role" gorm:"default:'member'"` // owner, admin, member
	Nickname   string `json:"nickname"`                     // 群内昵称
	JoinedAt   int64  `json:"joined_at"`
	InvitedBy  uint   `json:"invited_by"`
	Muted      bool   `json:"muted" gorm:"default:false"`    // 是否被禁言
	MutedUntil int64  `json:"muted_until" gorm:"default:0"`  // 禁言结束时间
	IsActive   bool   `json:"is_active" gorm:"default:true"` // 是否活跃
	LastActive int64  `json:"last_active" gorm:"default:0"`  // 最后活跃时间
}

// 群邀请
type GroupInvitation struct {
	ID        uint  `gorm:"primaryKey" json:"id"`
	GroupID   uint  `json:"group_id"`
	InviterID uint  `json:"inviter_id"`
	InviteeID uint  `json:"invitee_id"`
	Status    int   `json:"status" gorm:"default:0"` // 0: 待处理, 1: 已接受, 2: 已拒绝
	CreatedAt int64 `json:"created_at"`
	ExpiresAt int64 `json:"expires_at"` // 邀请过期时间
}

// 群公告
type GroupAnnouncement struct {
	ID        uint   `gorm:"primaryKey" json:"id"`
	GroupID   uint   `json:"group_id"`
	CreatorID uint   `json:"creator_id"`
	Content   string `json:"content"`
	CreatedAt int64  `json:"created_at"`
	UpdatedAt int64  `json:"updated_at"`
	PinnedAt  int64  `json:"pinned_at" gorm:"default:0"` // 置顶时间，0表示未置顶
}
