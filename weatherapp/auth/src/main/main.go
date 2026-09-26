package main

import (
	"database/sql"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/abohmeed/auth/authdb"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	_ "github.com/go-sql-driver/mysql"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

// Everything that was hard-coded in 2021 (the JWT secret, the root user)
// now comes from the environment.
var (
	dbHost     = os.Getenv("DB_HOST")
	dbUser     = os.Getenv("DB_USER")
	dbPassword = os.Getenv("DB_PASSWORD")
	secretKey  = os.Getenv("JWT_SECRET")
	db         *sql.DB
)

type Token struct {
	Role        string `json:"role"`
	Email       string `json:"email"`
	TokenString string `json:"token"`
}

func main() {
	for name, value := range map[string]string{"DB_HOST": dbHost, "DB_USER": dbUser, "DB_PASSWORD": dbPassword, "JWT_SECRET": secretKey} {
		if value == "" {
			log.Fatalf("%s is not set", name)
		}
	}
	// One connection pool for the whole process (2021 opened a new one per request).
	db = authdb.Connect(dbUser, dbPassword, dbHost)
	authdb.WaitForDB(db)
	if err := authdb.CreateTables(db); err != nil {
		log.Fatalf("could not create the users table: %v", err)
	}
	router := gin.Default()
	corsConfig := cors.DefaultConfig()
	corsConfig.AllowOrigins = []string{"*"}
	corsConfig.AddAllowMethods("OPTIONS")
	router.Use(cors.New(corsConfig))
	router.GET("/", health)
	router.POST("/users/:id", loginUser)
	router.POST("/users", createUser)
	if err := router.Run(":8080"); err != nil {
		log.Fatal(err)
	}
}

type UserCreds struct {
	Username string `json:"user_name"`
	Password string `json:"user_password"`
}

func health(c *gin.Context) {
	if err := db.Ping(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not connect to the database"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": "The auth is running"})
}

func loginUser(c *gin.Context) {
	var uc UserCreds
	if err := c.ShouldBindJSON(&uc); err != nil {
		log.Println("Received invalid JSON for user login")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Incorrect or invalid JSON"})
		return
	}
	u, err := authdb.GetUserByName(uc.Username, db)
	if err != nil {
		log.Println(err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not read the user. Please check the logs"})
		return
	}
	if u == (authdb.User{}) || bcrypt.CompareHashAndPassword([]byte(u.Password), []byte(uc.Password)) != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": "Bad credentials"})
		return
	}
	token, err := GenerateJWT(u.Name)
	if err != nil {
		log.Printf("Error while generating the token: %s", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Could not generate token"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"JWT": token})
}

func createUser(c *gin.Context) {
	var u authdb.User
	if err := c.ShouldBindJSON(&u); err != nil || u.Name == "" || u.Password == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "user_name and user_password are required"})
		return
	}
	result, err := authdb.CreateUser(db, u)
	if err != nil {
		log.Println(err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error while adding the user. Please check the logs"})
		return
	}
	if !result {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"error": "User already exists"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": "User added successfully"})
}

func GenerateJWT(userName string) (string, error) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"authorized": true,
		"username":   userName,
		"exp":        time.Now().Add(30 * time.Minute).Unix(),
	})
	return token.SignedString([]byte(secretKey))
}
