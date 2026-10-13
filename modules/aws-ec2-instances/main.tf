
# IAM Role for EC2
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.create_iam_role ? 1 : 0

  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = merge(var.tags, var.iam_role_tags)
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.create_iam_role ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count = var.create_iam_role ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "this" {
  count = var.create_iam_role ? 1 : 0

  name = var.iam_instance_profile_name
  role = aws_iam_role.this[0].name
  tags = merge(var.tags, var.iam_instance_profile_tags)
}

locals {
  # Instance profile applied to instances that do not specify their own.
  # Created here when create_iam_role is true, otherwise supplied by the caller.
  default_instance_profile = try(
    coalesce(
      one(aws_iam_instance_profile.this[*].name),
      var.existing_iam_instance_profile_name
    ),
    null
  )
}

# Key Pair
resource "tls_private_key" "this" {
  for_each = {
    for k, v in var.instances : k => v
    if try(v.create_key_pair, false)
  }

  algorithm = try(each.value.key_algorithm, "RSA")
  rsa_bits  = try(each.value.rsa_bits, 4096)
}

resource "aws_key_pair" "this" {
  for_each = {
    for k, v in var.instances : k => v
    if try(v.create_key_pair, false)
  }

  key_name   = try(each.value.key_pair_name, "${each.key}-keypair")
  public_key = tls_private_key.this[each.key].public_key_openssh

  tags = merge(
    var.tags,
    try(each.value.tags, {}),
    {
      Name = try(each.value.key_pair_name, "${each.key}-keypair")
    }
  )
}

# EC2 Instances
resource "aws_instance" "this" {
  for_each = var.instances

  ami                         = each.value.ami_id
  instance_type               = each.value.instance_type
  subnet_id                   = each.value.subnet_id
  vpc_security_group_ids      = each.value.security_group_ids
  key_name                    = try(each.value.create_key_pair, false) ? aws_key_pair.this[each.key].key_name : try(each.value.key_name, null)
  iam_instance_profile        = try(coalesce(try(each.value.iam_instance_profile, null), local.default_instance_profile), null)
  associate_public_ip_address = each.value.associate_public_ip_address
  availability_zone           = try(each.value.availability_zone, null)
  user_data                   = try(each.value.user_data, null)
  user_data_base64            = try(each.value.user_data_base64, null)
  ebs_optimized               = try(each.value.ebs_optimized, null)
  monitoring                  = try(each.value.monitoring, false)
  disable_api_termination     = try(each.value.disable_api_termination, false)
  source_dest_check           = try(each.value.source_dest_check, true)

  root_block_device {
    volume_type           = try(each.value.root_block_device.volume_type, "gp3")
    volume_size           = try(each.value.root_block_device.volume_size, 20)
    encrypted             = try(each.value.root_block_device.encrypted, true)
    kms_key_id            = try(each.value.root_block_device.kms_key_id, null)
    delete_on_termination = try(each.value.root_block_device.delete_on_termination, true)
    iops                  = try(each.value.root_block_device.iops, null)
    throughput            = try(each.value.root_block_device.throughput, null)

    tags = merge(
      var.tags,
      try(each.value.tags, {}),
      {
        Name = "${each.key}-root-volume"
      }
    )
  }

  metadata_options {
    http_endpoint               = try(each.value.metadata_options.http_endpoint, "enabled")
    http_tokens                 = try(each.value.metadata_options.http_tokens, "required")
    http_put_response_hop_limit = try(each.value.metadata_options.http_put_response_hop_limit, 2)
    instance_metadata_tags      = try(each.value.metadata_options.instance_metadata_tags, "enabled")
  }

  tags = merge(
    var.tags,
    {
      Name = each.key
    },
    try(each.value.tags, {})
  )

  depends_on = [
    aws_iam_instance_profile.this
  ]
}

# Additional EBS Volumes
resource "aws_ebs_volume" "this" {
  for_each = {
    for volume in flatten([
      for instance_name, instance in var.instances : [
        for idx, ebs in coalesce(try(instance.ebs_volumes, null), []) : {
          key               = "${instance_name}-${idx}"
          instance_name     = instance_name
          availability_zone = try(instance.availability_zone, null)
          subnet_id         = instance.subnet_id
          size              = ebs.size
          type              = try(ebs.type, "gp3")
          encrypted         = try(ebs.encrypted, true)
          kms_key_id        = try(ebs.kms_key_id, null)
          iops              = try(ebs.iops, null)
          throughput        = try(ebs.throughput, null)
          tags              = try(ebs.tags, {})
        }
      ]
    ]) : volume.key => volume
  }

  availability_zone = each.value.availability_zone != null ? each.value.availability_zone : data.aws_subnet.selected[each.key].availability_zone
  size              = each.value.size
  type              = each.value.type
  encrypted         = each.value.encrypted
  kms_key_id        = each.value.kms_key_id
  iops              = each.value.iops
  throughput        = each.value.throughput

  tags = merge(
    var.tags,
    each.value.tags,
    {
      Name = "${each.value.instance_name}-ebs-${split("-", each.key)[length(split("-", each.key)) - 1]}"
    }
  )
}

data "aws_subnet" "selected" {
  for_each = {
    for volume in flatten([
      for instance_name, instance in var.instances : [
        for idx, ebs in coalesce(try(instance.ebs_volumes, null), []) : {
          key       = "${instance_name}-${idx}"
          subnet_id = instance.subnet_id
        }
      ]
    ]) : volume.key => volume
    if try(volume.subnet_id, null) != null
  }

  id = each.value.subnet_id
}

resource "aws_volume_attachment" "this" {
  for_each = {
    for attachment in flatten([
      for instance_name, instance in var.instances : [
        for idx, ebs in coalesce(try(instance.ebs_volumes, null), []) : {
          key           = "${instance_name}-${idx}"
          instance_name = instance_name
          device_name   = ebs.device_name
        }
      ]
    ]) : attachment.key => attachment
  }

  device_name = each.value.device_name
  volume_id   = aws_ebs_volume.this[each.key].id
  instance_id = aws_instance.this[each.value.instance_name].id

  force_detach = false
}

# Store Private & Public Keys in S3
resource "aws_s3_object" "private_key" {
  for_each = var.store_key_in_s3 && var.ssh_key_bucket != null ? tls_private_key.this : {}

  bucket = var.ssh_key_bucket
  key    = "${var.ssh_key_prefix}/${each.key}.pem"

  content = each.value.private_key_pem

  server_side_encryption = var.ssh_key_kms_key_id != null ? "aws:kms" : "AES256"
  kms_key_id             = var.ssh_key_kms_key_id

  content_type = "text/plain"

  tags = merge(
    var.tags,
    {
      Name = "${each.key}-private-key"
    }
  )
}

resource "aws_s3_object" "public_key" {
  for_each = var.store_key_in_s3 && var.ssh_key_bucket != null ? tls_private_key.this : {}

  bucket = var.ssh_key_bucket
  key    = "${var.ssh_key_prefix}/${each.key}.pub"

  content = each.value.public_key_openssh

  server_side_encryption = var.ssh_key_kms_key_id != null ? "aws:kms" : "AES256"
  kms_key_id             = var.ssh_key_kms_key_id

  content_type = "text/plain"

  tags = merge(
    var.tags,
    {
      Name = "${each.key}-public-key"
    }
  )
}