package services

import (
	"gorm.io/gorm"
	"allinone_backend/models"
	"allinone_backend/repositories"
)

func RegisterUser(db *gorm.DB, account, password string) error {
	user := &models.User{Account: account, Password: password}
	return repositories.CreateUser(db, user)
}

func LoginUser(db *gorm.DB, account, password string) (*models.User, error) {
	user, err := repositories.GetUserByAccount(db, account)
	if err != nil {
		return nil, err
	}
	if user.Password != password {
		return nil, gorm.ErrRecordNotFound
	}
	return user, nil
}
