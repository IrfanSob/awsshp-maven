# Log Group
resource "aws_cloudwatch_log_group" "this" {
  name              = var.log_group_name
  retention_in_days = var.retention_days

  tags = merge(var.tags, {
    Name = var.log_group_name
  })
}

# IAM Role for VPC Flow Logs
data "aws_iam_policy_document" "assume_role" {
  statement {
    sid    = "VPCFlowLogsAssumeRole"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "this" {
  name               = "VPCFlowLogsRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "write_logs" {
  statement {
    sid    = "AllowFlowLogsToWrite"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "flow-logs-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.write_logs.json
}

# VPC Flow Logs
resource "aws_flow_log" "this" {
  vpc_id               = var.vpc_id
  traffic_type         = var.traffic_type
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.this.arn
  iam_role_arn         = aws_iam_role.this.arn

  tags = merge(var.tags, {
    Name = "${var.flow_log_name}"
  })
}