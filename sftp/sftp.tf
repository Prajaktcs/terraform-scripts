# Step 1 Create s3 bucket
resource "aws_s3_bucket" "sftp-server-bucket_1" {
  bucket = "sftp-server-bucket-1"

  tags = {
    Name = "sftp_server_bucket"
  }
}


# Step 2 Create IAM role for the sftp server. Create 1 for write only and 1 for read and write

resource "aws_iam_role" "sftp-write-user" {
    name = "tf-write-transfer-user-iam-role"

    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "transfer.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "sftp-write-user" {
    name = "tf-test-transfer-user-iam-policy"
    role = "${aws_iam_role.sftp-write-user.id}"
    policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        { 
            "Sid": "AllowListingOfUserFolder",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.sftp-server-bucket_1.bucket}"
            ]
        },
        {
            "Sid": "AllowWriteToS3",
            "Effect": "Allow",
            "Action": [
              "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::${aws_s3_bucket.sftp-server-bucket_1.bucket}/*"
        }
    ]
}
POLICY
}

# Step 3 Creating the transfer server and the policy for logging
resource "aws_iam_role" "sftp-server-logs" {
    name = "tf-transfer-server-iam-role-logs"

    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "transfer.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}
resource "aws_iam_role_policy" "sftp-server-logs" {
    name = "tf-sftp-server-logs"
    role = "${aws_iam_role.sftp-server-logs.id}"
    policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Sid": "AllowFullAccesstoCloudWatchLogs",
        "Effect": "Allow",
        "Action": [
            "logs:*"
        ],
        "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_transfer_server" "sftp-server" {
  identity_provider_type = "SERVICE_MANAGED"
  logging_role = "${aws_iam_role.sftp-server-logs.arn}"


  tags = {
    NAME   = "tf-acc-transfer-server"
  }
}

# Step 4 Create the write user
resource "aws_transfer_user" "write-sftp-user" {
    server_id      = "${aws_transfer_server.sftp-server.id}"
    user_name      = "writesftpserver"
    role           = "${aws_iam_role.sftp-write-user.arn}"
    home_directory = "/${aws_s3_bucket.sftp-server-bucket_1.bucket}"
}

resource "aws_transfer_ssh_key" "write-sftp-user" {
    server_id = "${aws_transfer_server.sftp-server.id}"
    user_name = "${aws_transfer_user.write-sftp-user.user_name}"
    body      = "public_key"
}

