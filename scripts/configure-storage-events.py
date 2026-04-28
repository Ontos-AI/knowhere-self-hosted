#!/usr/bin/env python3
"""Configure local S3-compatible upload events for Knowhere self-hosted."""

from __future__ import annotations

import os
import sys

import boto3
from botocore.client import BaseClient
from botocore.exceptions import ClientError


def getEndpointUrl() -> str:
    return os.getenv("SELF_HOSTED_AWS_ENDPOINT_URL") or os.getenv("S3_ENDPOINT_URL", "")


def getRegionName() -> str:
    return os.getenv("S3_REGION", "") or "us-west-1"


def createClient(serviceName: str) -> BaseClient:
    clientOptions: dict[str, object] = {
        "service_name": serviceName,
        "aws_access_key_id": os.getenv("S3_ACCESS_KEY_ID", ""),
        "aws_secret_access_key": os.getenv("S3_SECRET_ACCESS_KEY", ""),
        "region_name": getRegionName(),
    }

    endpointUrl = getEndpointUrl()
    if endpointUrl:
        clientOptions["endpoint_url"] = endpointUrl

    if os.getenv("S3_USE_SSL", "false").lower() not in {"1", "true", "yes", "on"}:
        clientOptions["use_ssl"] = False

    return boto3.client(**clientOptions)


def getBucketNames() -> list[str]:
    bucketNames = [
        os.getenv("S3_BUCKET_NAME", ""),
        os.getenv("S3_UPLOADS_BUCKET", ""),
        os.getenv("S3_RESULTS_BUCKET", ""),
    ]
    return sorted({bucketName for bucketName in bucketNames if bucketName})


def ensureBucket(s3Client: BaseClient, bucketName: str) -> None:
    try:
        s3Client.head_bucket(Bucket=bucketName)
        print(f"Bucket already exists: {bucketName}")
    except ClientError:
        createOptions: dict[str, object] = {"Bucket": bucketName}
        regionName = getRegionName()
        if regionName and regionName != "us-east-1":
            createOptions["CreateBucketConfiguration"] = {
                "LocationConstraint": regionName
            }
        s3Client.create_bucket(**createOptions)
        print(f"Created bucket: {bucketName}")


def getCorsAllowedOrigins() -> list[str]:
    configuredOrigins = os.getenv("SELF_HOSTED_STORAGE_CORS_ALLOWED_ORIGINS", "")
    if configuredOrigins:
        return [
            origin.strip()
            for origin in configuredOrigins.split(",")
            if origin.strip()
        ]

    origins = {
        "http://localhost:3000",
        "http://localhost:5005",
        os.getenv("DASHBOARD_PUBLIC_URL", ""),
    }
    dashboardHostPort = os.getenv("DASHBOARD_HOST_PORT", "")
    apiHostPort = os.getenv("API_HOST_PORT", "")
    if dashboardHostPort:
        origins.add(f"http://localhost:{dashboardHostPort}")
    if apiHostPort:
        origins.add(f"http://localhost:{apiHostPort}")
    return sorted(origin for origin in origins if origin)


def configureBucketCors(s3Client: BaseClient, bucketName: str) -> None:
    allowedOrigins = getCorsAllowedOrigins()
    if not allowedOrigins:
        return

    s3Client.put_bucket_cors(
        Bucket=bucketName,
        CORSConfiguration={
            "CORSRules": [
                {
                    "AllowedHeaders": ["*"],
                    "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
                    "AllowedOrigins": allowedOrigins,
                    "ExposeHeaders": ["ETag", "x-amz-meta-*"],
                    "MaxAgeSeconds": 3000,
                }
            ]
        },
    )
    print(f"Configured CORS for bucket: {bucketName}")


def ensureTopic(snsClient: BaseClient) -> str:
    topicName = os.getenv("SELF_HOSTED_S3_EVENT_TOPIC_NAME", "")
    if not topicName:
        raise ValueError("SELF_HOSTED_S3_EVENT_TOPIC_NAME must not be empty")

    response = snsClient.create_topic(Name=topicName)
    topicArn = response["TopicArn"]
    print(f"Ensured SNS topic: {topicArn}")
    return topicArn


def configureUploadNotification(
    s3Client: BaseClient, bucketName: str, topicArn: str
) -> None:
    s3Client.put_bucket_notification_configuration(
        Bucket=bucketName,
        NotificationConfiguration={
            "TopicConfigurations": [
                {
                    "Id": "knowhere-upload-events",
                    "TopicArn": topicArn,
                    "Events": [
                        "s3:ObjectCreated:Put",
                        "s3:ObjectCreated:Post",
                        "s3:ObjectCreated:CompleteMultipartUpload",
                    ],
                    "Filter": {
                        "Key": {
                            "FilterRules": [
                                {"Name": "prefix", "Value": "uploads/"}
                            ]
                        }
                    },
                }
            ]
        },
    )
    print(f"Configured upload notifications for bucket: {bucketName}")


def ensureSubscription(snsClient: BaseClient, topicArn: str) -> None:
    webhookUrl = os.getenv("SELF_HOSTED_S3_EVENT_WEBHOOK_URL", "")
    if not webhookUrl:
        raise ValueError("SELF_HOSTED_S3_EVENT_WEBHOOK_URL must not be empty")

    paginator = snsClient.get_paginator("list_subscriptions_by_topic")
    for page in paginator.paginate(TopicArn=topicArn):
        for subscription in page.get("Subscriptions", []):
            if subscription.get("Endpoint") == webhookUrl:
                print(f"SNS subscription already exists: {webhookUrl}")
                return

    snsClient.subscribe(
        TopicArn=topicArn,
        Protocol="http",
        Endpoint=webhookUrl,
        ReturnSubscriptionArn=True,
    )
    print(f"Created SNS subscription: {webhookUrl}")


def main() -> int:
    s3Client = createClient("s3")
    snsClient = createClient("sns")
    bucketNames = getBucketNames()
    uploadsBucket = os.getenv("S3_UPLOADS_BUCKET") or os.getenv("S3_BUCKET_NAME", "")

    for bucketName in bucketNames:
        ensureBucket(s3Client, bucketName)

    for bucketName in bucketNames:
        configureBucketCors(s3Client, bucketName)

    topicArn = ensureTopic(snsClient)
    if uploadsBucket:
        configureUploadNotification(s3Client, uploadsBucket, topicArn)
    ensureSubscription(snsClient, topicArn)
    return 0


if __name__ == "__main__":
    sys.exit(main())
