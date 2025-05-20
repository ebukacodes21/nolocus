package handler

import (
	"fmt"
	"mime/multipart"
	"net/http"
	"path/filepath"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
)

const (
	bucketName = "nolocus-bucket"
	region     = "us-east-1"
	profile    = "peerbill"
)

func UploadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	userID := r.FormValue("userId")
	if userID == "" {
		http.Error(w, "missing user ID", http.StatusBadRequest)
		return
	}

	err := r.ParseMultipartForm(50 << 20) // Max 50 MB
	if err != nil {
		http.Error(w, "failed to parse form: "+err.Error(), http.StatusBadRequest)
		return
	}

	files := r.MultipartForm.File["photos"]
	if len(files) == 0 {
		http.Error(w, "no photos uploaded", http.StatusBadRequest)
		return
	}

	jobID := "job-" + time.Now().Format("20060102150405")
	sess, err := session.NewSessionWithOptions(session.Options{
		Profile: profile,
		Config:  aws.Config{Region: aws.String(region)},
	})
	if err != nil {
		http.Error(w, "AWS session error: "+err.Error(), http.StatusInternalServerError)
		return
	}
	s3Client := s3.New(sess)

	s3InputPrefix := fmt.Sprintf("uploads/%s/%s/", userID, jobID)
	for _, fileHeader := range files {
		if err := uploadToS3(s3Client, s3InputPrefix, fileHeader); err != nil {
			http.Error(w, "S3 upload error: "+err.Error(), http.StatusInternalServerError)
			return
		}
	}

	// Submit AWS Batch Meshroom job

	fmt.Fprintf(w, "Upload complete. Job %s submitted for user %s\n", jobID, userID)
}

func uploadToS3(s3Client *s3.S3, prefix string, fh *multipart.FileHeader) error {
	file, err := fh.Open()
	if err != nil {
		return err
	}
	defer file.Close()

	key := filepath.Join(prefix, fh.Filename)
	_, err = s3Client.PutObject(&s3.PutObjectInput{
		Bucket: aws.String(bucketName),
		Key:    aws.String(key),
		Body:   file,
		ACL:    aws.String("private"),
	})
	return err
}
