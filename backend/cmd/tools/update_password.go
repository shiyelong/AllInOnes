package main

import (
	"database/sql"
	"fmt"
	"os"

	_ "github.com/mattn/go-sqlite3"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	if len(os.Args) < 3 {
		fmt.Println("Usage: go run update_password.go <account> <password>")
		os.Exit(1)
	}

	account := os.Args[1]
	password := os.Args[2]

	// 生成密码哈希
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		fmt.Printf("Error hashing password: %v\n", err)
		os.Exit(1)
	}

	// 连接数据库
	db, err := sql.Open("sqlite3", "allinone.db")
	if err != nil {
		fmt.Printf("Error opening database: %v\n", err)
		os.Exit(1)
	}
	defer db.Close()

	// 更新密码
	_, err = db.Exec("UPDATE users SET password = ? WHERE account = ?", string(hashedPassword), account)
	if err != nil {
		fmt.Printf("Error updating password: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Password updated for account %s\n", account)
	fmt.Printf("New hashed password: %s\n", hashedPassword)
}
