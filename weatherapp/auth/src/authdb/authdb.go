package authdb

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	"golang.org/x/crypto/bcrypt"
)

type User struct {
	ID       int    `json:"user_id"`
	Name     string `json:"user_name"`
	Password string `json:"user_password"`
}

// Connect opens a connection pool to the "auth" database. The database and
// the application user are created by MySQL itself (MYSQL_DATABASE /
// MYSQL_USER), so the app no longer needs root.
func Connect(dbUser string, dbPassword string, dbHost string) *sql.DB {
	db, err := sql.Open("mysql", fmt.Sprintf("%s:%s@tcp(%s:3306)/auth", dbUser, dbPassword, dbHost))
	if err != nil {
		log.Fatalf("invalid database settings: %v", err)
	}
	return db
}

// WaitForDB blocks until MySQL answers. On Kubernetes the auth pod can start
// before MySQL is ready; in 2021 it crashed and relied on restarts instead.
func WaitForDB(db *sql.DB) {
	for {
		err := db.Ping()
		if err == nil {
			return
		}
		log.Printf("waiting for the database: %v", err)
		time.Sleep(3 * time.Second)
	}
}

func CreateTables(db *sql.DB) error {
	_, err := db.Exec("CREATE TABLE IF NOT EXISTS users (user_id int AUTO_INCREMENT, user_name char(50) NOT NULL, user_password char(128), PRIMARY KEY(user_id));")
	return err
}

// InsertUser stores a bcrypt hash (2021 stored an unsalted MD5) and uses a
// parameterised query (2021 built the SQL with fmt.Sprintf).
func InsertUser(db *sql.DB, user User) error {
	hash, err := bcrypt.GenerateFromPassword([]byte(user.Password), bcrypt.DefaultCost)
	if err != nil {
		return err
	}
	_, err = db.Exec("INSERT INTO users (user_name, user_password) VALUES (?, ?)", user.Name, string(hash))
	return err
}

func GetUserByName(userName string, db *sql.DB) (User, error) {
	var user User
	err := db.QueryRow("SELECT user_id, user_name, user_password FROM users WHERE user_name = ?", userName).
		Scan(&user.ID, &user.Name, &user.Password)
	if err == sql.ErrNoRows {
		return User{}, nil
	}
	return user, err
}

func CreateUser(db *sql.DB, u User) (bool, error) {
	user, err := GetUserByName(u.Name, db)
	if err != nil {
		return false, err
	}
	if user != (User{}) {
		return false, nil
	}
	if err := InsertUser(db, u); err != nil {
		return false, err
	}
	return true, nil
}
