#!/bin/bash
set -e

INPUT_DIR="/workspace/input"
OUTPUT_DIR="/workspace/output"

echo "Downloading input from s3://$S3_BUCKET/$S3_INPUT_PREFIX"
mkdir -p $INPUT_DIR $OUTPUT_DIR
aws s3 cp s3://$S3_BUCKET/$S3_INPUT_PREFIX $INPUT_DIR --recursive

echo "Running Meshroom"
meshroom_batch -i $INPUT_DIR -o $OUTPUT_DIR

echo "Uploading result to s3://$S3_BUCKET/$S3_OUTPUT_PREFIX"
aws s3 cp $OUTPUT_DIR s3://$S3_BUCKET/$S3_OUTPUT_PREFIX --recursive

echo "Done."
