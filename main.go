package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
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
	runpodAPI  = "https://api.runpod.io/v1/jobs"
	apiKey     = "your_runpod_api_key" // TODO: replace
)

func uploadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	userID := r.FormValue("user") // Assume passed in form field
	if userID == "" {
		http.Error(w, "missing user ID", http.StatusBadRequest)
		return
	}

	err := r.ParseMultipartForm(50 << 20) // 50MB max
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
	uploadPrefix := fmt.Sprintf("uploads/%s/%s/", userID, jobID)

	sess, err := session.NewSessionWithOptions(session.Options{
		Profile: profile,
		Config:  aws.Config{Region: aws.String(region)},
	})
	if err != nil {
		http.Error(w, "AWS session error: "+err.Error(), http.StatusInternalServerError)
		return
	}
	s3Client := s3.New(sess)

	for _, fileHeader := range files {
		if err := uploadToS3(s3Client, uploadPrefix, fileHeader); err != nil {
			http.Error(w, "S3 upload error: "+err.Error(), http.StatusInternalServerError)
			return
		}
	}

	if err := submitRunPodJob(userID, jobID); err != nil {
		http.Error(w, "RunPod job error: "+err.Error(), http.StatusInternalServerError)
		return
	}

	fmt.Fprintf(w, "Job %s submitted successfully for user %s\n", jobID, userID)
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

func submitRunPodJob(userID, jobID string) error {
	inputPrefix := fmt.Sprintf("uploads/%s/%s/", userID, jobID)
	outputPrefix := fmt.Sprintf("outputs/%s/%s/", userID, jobID)

	payload := map[string]interface{}{
		"jobId":     fmt.Sprintf("meshroom-%s", jobID),
		"container": "your-docker-image-uri", // TODO: replace with image
		"command":   []string{"/entrypoint.sh"},
		"env": map[string]string{
			"S3_BUCKET":        bucketName,
			"S3_INPUT_PREFIX":  inputPrefix,
			"S3_OUTPUT_PREFIX": outputPrefix,
		},
	}

	jsonBody, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", runpodAPI, bytes.NewBuffer(jsonBody))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusAccepted {
		return fmt.Errorf("RunPod job failed: %s", resp.Status)
	}

	log.Printf("RunPod job submitted: user=%s, job=%s", userID, jobID)
	return nil
}

func main() {
	http.HandleFunc("/upload", uploadHandler)
	log.Println("Go API running on http://localhost:8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
