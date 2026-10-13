output "vpn_gateway_id" {
  description = "ID of the Virtual Private Gateway used by the VPN connection (created or provided)"
  value       = local.vpn_gateway_id
}

output "vpn_connection_id" {
  description = "ID of the Site-to-Site VPN connection"
  value       = aws_vpn_connection.this.id
}

output "vpn_connection_arn" {
  description = "ARN of the Site-to-Site VPN connection"
  value       = aws_vpn_connection.this.arn
}

output "customer_gateway_id" {
  description = "ID of the customer gateway used by the VPN connection"
  value       = local.customer_gateway_id
}

output "tunnel1_address" {
  description = "Public IP address of the first VPN tunnel (AWS side)"
  value       = aws_vpn_connection.this.tunnel1_address
}

output "tunnel2_address" {
  description = "Public IP address of the second VPN tunnel (AWS side)"
  value       = aws_vpn_connection.this.tunnel2_address
}

output "tunnel1_cgw_inside_address" {
  description = "Inside IP address of the customer gateway for the first tunnel"
  value       = aws_vpn_connection.this.tunnel1_cgw_inside_address
}

output "tunnel2_cgw_inside_address" {
  description = "Inside IP address of the customer gateway for the second tunnel"
  value       = aws_vpn_connection.this.tunnel2_cgw_inside_address
}

output "tunnel1_vgw_inside_address" {
  description = "Inside IP address of the VPN gateway for the first tunnel"
  value       = aws_vpn_connection.this.tunnel1_vgw_inside_address
}

output "tunnel2_vgw_inside_address" {
  description = "Inside IP address of the VPN gateway for the second tunnel"
  value       = aws_vpn_connection.this.tunnel2_vgw_inside_address
}

output "tunnel1_preshared_key" {
  description = "Preshared key of the first VPN tunnel"
  value       = aws_vpn_connection.this.tunnel1_preshared_key
  sensitive   = true
}

output "tunnel2_preshared_key" {
  description = "Preshared key of the second VPN tunnel"
  value       = aws_vpn_connection.this.tunnel2_preshared_key
  sensitive   = true
}
