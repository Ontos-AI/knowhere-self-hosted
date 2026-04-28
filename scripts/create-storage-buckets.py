#!/usr/bin/env python3
"""Create local S3-compatible buckets required by Knowhere."""

from __future__ import annotations

import os
import sys

import boto3
from botocore.exceptions import ClientError


def getBucketNames() -> list[str]:
    bucketNames = [
        os.getenv("S3_BUCKET_NAME", ""),
        os.getenv("S3_UPLOADS_BUCKET", ""),
        os.getenv("S3_RESULTS_BUCKET", ""),
    ]
    return sorted({bucketName for bucketName in bucketNames if bucketName})


def createClient():
    clientOptions: dict[str, object] = {
        "service_name": "s3",
        "aws_access_key_id": os.getenv("S3_ACCESS_KEY_ID", ""),
        "aws_secret_access_key": os.getenv("S3_SECRET_ACCESS_KEY", ""),
    }

    endpointUrl = os.getenv("S3_ENDPOINT_URL", "")
    if endpointUrl:
        clientOptions["endpoint_url"] = endpointUrl

    regionName = os.getenv("S3_REGION", "")
    if regionName:
        clientOptions["region_name"] = regionName

    if os.getenv("S3_USE_SSL", "false").lower() not in {"1", "true", "yes", "on"}:
        clientOptions["use_ssl"] = False

    return boto3.client(**clientOptions)


def main() -> int:
    client = createClient()
    regionName = os.getenv("S3_REGION", "")

    for bucketName in getBucketNames():
        try:
            client.head_bucket(Bucket=bucketName)
            print(f"Bucket already exists: {bucketName}")
        except ClientError:
            createOptions: dict[str, object] = {"Bucket": bucketName}
            if regionName and regionName != "us-east-1":
                createOptions["CreateBucketConfiguration"] = {
                    "LocationConstraint": regionName
                }

            client.create_bucket(**createOptions)
            print(f"Created bucket: {bucketName}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
