package models

// 游戏信息
type Game struct {
	ID          uint   `json:"id" gorm:"primaryKey"`
	Name        string `json:"name"`
	Description string `json:"description"`
	CoverImage  string `json:"cover_image"`
	IntroVideo  string `json:"intro_video"`
	Type        string `json:"type"` // RPG, FPS, Strategy, etc.
	Price       float64 `json:"price"`
	IsFree      bool   `json:"is_free" gorm:"default:false"`
	DeveloperID uint   `json:"developer_id"`
	Platforms   string `json:"platforms"` // PC, Mobile, Console, 逗号分隔
	Rating      float64 `json:"rating" gorm:"default:0"`
	Downloads   int    `json:"downloads" gorm:"default:0"`
	CreatedAt   int64  `json:"created_at"`
	UpdatedAt   int64  `json:"updated_at"`
}

// 游戏开发者
type GameDeveloper struct {
	ID          uint   `json:"id" gorm:"primaryKey"`
	UserID      uint   `json:"user_id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Logo        string `json:"logo"`
	Website     string `json:"website"`
	Email       string `json:"email"`
	CreatedAt   int64  `json:"created_at"`
	UpdatedAt   int64  `json:"updated_at"`
}

// 用户游戏
type UserGame struct {
	ID        uint   `json:"id" gorm:"primaryKey"`
	UserID    uint   `json:"user_id"`
	GameID    uint   `json:"game_id"`
	Status    string `json:"status"` // purchased, downloaded, installed, playing
	PlayTime  int    `json:"play_time" gorm:"default:0"`
	LastPlayed int64  `json:"last_played" gorm:"default:0"`
	CreatedAt int64  `json:"created_at"`
	UpdatedAt int64  `json:"updated_at"`
}

// 游戏评价
type GameReview struct {
	ID        uint   `json:"id" gorm:"primaryKey"`
	UserID    uint   `json:"user_id"`
	GameID    uint   `json:"game_id"`
	Rating    int    `json:"rating"` // 1-5
	Content   string `json:"content"`
	CreatedAt int64  `json:"created_at"`
	UpdatedAt int64  `json:"updated_at"`
}

// 游戏成就
type GameAchievement struct {
	ID          uint   `json:"id" gorm:"primaryKey"`
	GameID      uint   `json:"game_id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Icon        string `json:"icon"`
	CreatedAt   int64  `json:"created_at"`
}

// 用户游戏成就
type UserGameAchievement struct {
	ID           uint   `json:"id" gorm:"primaryKey"`
	UserID       uint   `json:"user_id"`
	GameID       uint   `json:"game_id"`
	AchievementID uint   `json:"achievement_id"`
	UnlockedAt   int64  `json:"unlocked_at"`
}

// 游戏更新
type GameUpdate struct {
	ID          uint   `json:"id" gorm:"primaryKey"`
	GameID      uint   `json:"game_id"`
	Version     string `json:"version"`
	Description string `json:"description"`
	Size        int64  `json:"size"` // 单位：字节
	CreatedAt   int64  `json:"created_at"`
}

// AI游戏角色
type AIGameCharacter struct {
	ID          uint   `json:"id" gorm:"primaryKey"`
	GameID      uint   `json:"game_id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Avatar      string `json:"avatar"`
	Prompt      string `json:"prompt"` // AI角色的提示词
	CreatedAt   int64  `json:"created_at"`
	UpdatedAt   int64  `json:"updated_at"`
}
