resource "tls_private_key" "ssh_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "ssh_key" {
  key_name   = var.pem_key_name
  public_key = tls_private_key.ssh_private_key.public_key_openssh
  provisioner "local-exec" { # This will create the pem where the terraform will run!!
    command = "rm -f ./${var.pem_key_name}.pem && echo '${tls_private_key.ssh_private_key.private_key_pem}' > ./${var.pem_key_name}.pem && chmod 400 ${var.pem_key_name}.pem"
  }
}
data "template_file" "userdata" {
  template = file("${path.module}/prometheus.sh")
  vars = {
    kube_cluster_endpoint     = var.kube_cluster_endpoint
    kube_cluster_token        = var.kube_cluster_token
  }
}
resource "aws_instance" "prometheus" {
  ami = "ami-0b5eea76982371e91"
  instance_type = var.instance_type_prometheus
  user_data = data.template_file.userdata.rendered
  key_name = var.pem_key_name
  subnet_id = var.subnet_id
  disable_api_termination = true
  iam_instance_profile = aws_iam_instance_profile.rds_log_instance_profile.name
  vpc_security_group_ids = [aws_security_group.prometheus_sg.id]
  # associate_public_ip_address = true
  ebs_block_device {
    device_name = "/dev/xvda"
    volume_size = var.volume_size_prometheus
  }
  depends_on = [
    aws_key_pair.ssh_key,aws_iam_role.rds_log
  ]
  tags = {
    Name = "nw-social-monitoring-${var.environment}"
  }
}
resource "aws_security_group" "prometheus_sg" {
  name = "nw-social-monitoring-${var.environment}-sg"
  vpc_id =  var.vpc_id
  ingress {
    description = "ingress rules"
    cidr_blocks = [var.vpc_cidr_block]
    from_port = 22
    protocol = "tcp"
    to_port = 22
  }
  ingress {
    description = "ingress rules"
    cidr_blocks = [var.vpc_cidr_block,"182.71.160.184/29","61.12.91.216/29"]
    from_port = 9090
    protocol = "tcp"
    to_port = 9090
  }
  egress {
    description = "egress rules"
    cidr_blocks = [ "0.0.0.0/0" ]
    from_port = 0
    protocol = "-1"
    to_port = 0
  }
  tags = {
    Name = "nw-social-monitoring-${var.environment}-sg"
  }
}
resource "aws_iam_role" "rds_log" {
  name = "rds_log-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
    {
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }
   ]
  })
}
resource "aws_iam_role_policy_attachment" "rds_log_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess"
  role = aws_iam_role.rds_log.name
}
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  role = aws_iam_role.rds_log.name
}
resource "aws_iam_policy" "rds_log_policy" {
  name    = "rds_log_policy-${var.environment}"
  description = "Policy for RDS logs access"
  policy   = jsonencode({
    Version = "2012-10-17",
    Statement = [
    {
      Sid = "AllowReadingMetricsFromCloudWatch",
      Effect = "Allow",
      Action = [
        "cloudwatch:DescribeAlarmsForMetric",
        "cloudwatch:DescribeAlarmHistory",
        "cloudwatch:DescribeAlarms",
        "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricData",
        "cloudwatch:GetInsightRuleReport"
      ],
      Resource = "*"
    },
    {
      Sid = "AllowReadingLogsFromCloudWatch",
      Effect = "Allow",
      Action = [
        "logs:DescribeLogGroups",
        "logs:GetLogGroupFields",
        "logs:StartQuery",
        "logs:StopQuery",
        "logs:GetQueryResults",
        "logs:GetLogEvents"
     ],
      Resource = "*"
    },
    {
      Sid = "AllowReadingTagsInstancesRegionsFromEC2",
      Effect = "Allow",
      Action = [
        "ec2:DescribeTags",
        "ec2:DescribeInstances",
        "ec2:DescribeRegions"
     ],
      Resource = "*"
    },
    {
      Sid = "AllowReadingResourcesForTags",
      Effect = "Allow",
      Action = "tag:GetResources",
      Resource = "*"
    }
   ]
  })
}
resource "aws_iam_policy_attachment" "rds_log_policy_attachment" {
  policy_arn = aws_iam_policy.rds_log_policy.arn
  roles   = [aws_iam_role.rds_log.name]
}
resource "aws_iam_instance_profile" "rds_log_instance_profile" {
  name = "rds_log_instance_profile-${var.environment}"
  roles = [aws_iam_role.rds_log.name]
}
resource "aws_instance" "example" {
 ami      = "ami-0c55b159cbfafe1f0"
 instance_type = "t2.micro"

 iam_instance_profile = aws_iam_instance_profile.rds_log_instance_profile.name
}