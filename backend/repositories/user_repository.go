package repositories

import (
	"gorm.io/gorm"
	"allinone_backend/models"
)

// 用户数据库操作
func CreateUser(db *gorm.DB, user *models.User) error {
	return db.Create(user).Error
}

func GetUserByAccount(db *gorm.DB, account string) (*models.User, error) {
	var user models.User
	err := db.Where("account = ?", account).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}
