package main

import (
	"log"
	"net/http"
	"nolocus/handler"
)

func main() {
	http.HandleFunc("/upload", handler.UploadHandler)
	log.Println("📡 Go API running on http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
