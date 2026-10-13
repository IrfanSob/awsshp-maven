output "key_pair_names" {
  value = {
    for k, v in aws_key_pair.this : k => v.key_name
  }
}

output "private_keys_pem" {
  value = {
    for k, v in tls_private_key.this : k => v.private_key_pem
  }
  sensitive = true
}

output "public_keys_openssh" {
  value = {
    for k, v in tls_private_key.this : k => v.public_key_openssh
  }
}

output "instance_ids" {
  value = {
    for k, v in aws_instance.this : k => v.id
  }
}

output "instance_arns" {
  value = {
    for k, v in aws_instance.this : k => v.arn
  }
}

output "private_ips" {
  value = {
    for k, v in aws_instance.this : k => v.private_ip
  }
}

output "public_ips" {
  value = {
    for k, v in aws_instance.this : k => v.public_ip
  }
}

output "private_dns" {
  value = {
    for k, v in aws_instance.this : k => v.private_dns
  }
}

output "public_dns" {
  value = {
    for k, v in aws_instance.this : k => v.public_dns
  }
}

output "availability_zones" {
  value = {
    for k, v in aws_instance.this : k => v.availability_zone
  }
}

output "ebs_volume_ids" {
  value = {
    for k, v in aws_ebs_volume.this : k => v.id
  }
}

output "iam_role_name" {
  value = one(aws_iam_role.this[*].name)
}

output "iam_role_arn" {
  value = one(aws_iam_role.this[*].arn)
}

output "iam_instance_profile_name" {
  description = "Instance profile attached to the instances. Pass this into other calls of this module as existing_iam_instance_profile_name"
  value       = local.default_instance_profile
}

output "iam_instance_profile_arn" {
  value = one(aws_iam_instance_profile.this[*].arn)
}

output "ssh_private_key_s3_paths" {
  value = {
    for k, v in aws_s3_object.private_key :
    k => "s3://${v.bucket}/${v.key}"
  }
}

output "ssh_public_key_s3_paths" {
  value = {
    for k, v in aws_s3_object.public_key :
    k => "s3://${v.bucket}/${v.key}"
  }
}