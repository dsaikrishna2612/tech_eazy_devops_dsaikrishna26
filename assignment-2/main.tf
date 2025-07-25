##############################
# IAM Role 1: Read-only on S3
##############################
resource "aws_iam_role" "s3_readonly_role" {
  name = "s3-readonly-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "s3_readonly_policy" {
  name = "s3-readonly-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "readonly_attach" {
  role       = aws_iam_role.s3_readonly_role.name
  policy_arn = aws_iam_policy.s3_readonly_policy.arn
}

resource "aws_iam_instance_profile" "readonly_instance_profile" {
  name = "readonly-instance-profile"
  role = aws_iam_role.s3_readonly_role.name
}

##############################
# IAM Role 2: Full access for logs
##############################
resource "aws_iam_role" "s3_fullaccess_role" {
  name = "s3-fullaccess-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "s3_fullaccess_policy" {
  name = "s3-fullaccess-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fullaccess_attach" {
  role       = aws_iam_role.s3_fullaccess_role.name
  policy_arn = aws_iam_policy.s3_fullaccess_policy.arn
}

##############################
# S3 Bucket (private)
##############################
resource "aws_s3_bucket" "private_bucket" {
  bucket = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_acl" "private_acl" {
  bucket = aws_s3_bucket.private_bucket.id
  acl    = "private"
}

##############################
# S3 Lifecycle Rule
##############################
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.private_bucket.id

  rule {
    id     = "delete-logs"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    expiration {
      days = 7
    }
  }
}

##############################
# EC2 Instance (attached with read-only role)
##############################
resource "aws_instance" "devops_instance" {
  ami                    = var.instance_ami
  instance_type          = var.instance_type
  key_name = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.readonly_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y aws-cli
              chmod +x /home/ec2-user/upload-logs.sh
              cp /home/ec2-user/upload-logs.sh /usr/local/bin/upload-logs.sh

              # Create systemd service to upload logs on shutdown
              echo "[Unit]
              Description=Upload logs to S3 on shutdown

              [Service]
              Type=oneshot
              ExecStart=/usr/local/bin/upload-logs.sh
              RemainAfterExit=yes

              [Install]
              WantedBy=multi-user.target" > /etc/systemd/system/upload-logs.service

              systemctl enable upload-logs.service
              EOF

  tags = {
    Name = "DevOpsInstance"
  }
}
