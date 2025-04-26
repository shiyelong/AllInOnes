package models

type User struct {
	ID       uint   `json:"id" gorm:"primaryKey"`
	Account  string `json:"account" gorm:"uniqueIndex"`
	Password string `json:"password"`
	CreatedAt int64  `json:"created_at"`
}
