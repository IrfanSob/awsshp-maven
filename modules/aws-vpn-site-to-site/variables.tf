variable "name" {
  description = "Name used to tag the VPN connection and related resources"
  type        = string
}

# --- Customer Gateway ---------------------------------------------------------

variable "create_customer_gateway" {
  description = "Whether to create a customer gateway. Set to false to reuse an existing one"
  type        = bool
  default     = true
}

variable "customer_gateway_id" {
  description = "ID of an existing customer gateway. Required when create_customer_gateway is false"
  type        = string
  default     = null
}

variable "customer_gateway_bgp_asn" {
  description = "The BGP ASN of the customer gateway (on-premises router)"
  type        = number
  default     = 65000
}

variable "customer_gateway_ip_address" {
  description = "Public IP address of the customer gateway. Required when create_customer_gateway is true"
  type        = string
  default     = null
}

variable "customer_gateway_device_name" {
  description = "Name for the customer gateway device"
  type        = string
  default     = null
}

variable "customer_gateway_certificate_arn" {
  description = "ARN of the ACM certificate for a certificate-based customer gateway"
  type        = string
  default     = null
}

# --- Target (choose exactly one) ----------------------------------------------

variable "create_vpn_gateway" {
  description = "Whether to create a Virtual Private Gateway in this module. Mutually exclusive with vpn_gateway_id and transit_gateway_id"
  type        = bool
  default     = false
}

variable "vpn_gateway_vpc_id" {
  description = "VPC ID to attach the created VGW to. Required when create_vpn_gateway is true"
  type        = string
  default     = null
}

variable "vpn_gateway_amazon_side_asn" {
  description = "BGP ASN on the AWS side of the created VGW. Leave null to use the AWS default (64512)"
  type        = number
  default     = null
}

variable "vpn_gateway_availability_zone" {
  description = "Availability Zone for the created VGW (optional)"
  type        = string
  default     = null
}

variable "vpn_gateway_id" {
  description = "ID of an existing Virtual Private Gateway (VGW) to attach the VPN to. Mutually exclusive with create_vpn_gateway and transit_gateway_id"
  type        = string
  default     = null
}

variable "transit_gateway_id" {
  description = "ID of the Transit Gateway (TGW) to attach the VPN to. Mutually exclusive with a VGW target"
  type        = string
  default     = null
}

# --- VPN Connection -----------------------------------------------------------

variable "static_routes_only" {
  description = "Whether the VPN uses static routing only. Set true for static routes, false for BGP dynamic routing"
  type        = bool
  default     = false
}

variable "enable_acceleration" {
  description = "Enable an accelerated Site-to-Site VPN connection (only supported with Transit Gateway targets)"
  type        = bool
  default     = false
}

variable "local_ipv4_network_cidr" {
  description = "IPv4 CIDR on the customer gateway (on-premises) side of the VPN connection"
  type        = string
  default     = "0.0.0.0/0"
}

variable "remote_ipv4_network_cidr" {
  description = "IPv4 CIDR on the AWS side of the VPN connection"
  type        = string
  default     = "0.0.0.0/0"
}

variable "static_routes" {
  description = "List of destination CIDR blocks to add as static routes. Only applied when the target is a Virtual Private Gateway"
  type        = list(string)
  default     = []
}

variable "propagation_route_tables" {
  description = "Route tables to propagate VPN routes into (VGW target only). Map of a static name => route table ID, e.g. { private_app = \"rtb-123\" }"
  type        = map(string)
  default     = {}
}

# --- Tunnel options -----------------------------------------------------------

variable "tunnel1_inside_cidr" {
  description = "The CIDR block of the inside IP addresses for the first VPN tunnel (169.254.0.0/16 range, /30)"
  type        = string
  default     = null
}

variable "tunnel2_inside_cidr" {
  description = "The CIDR block of the inside IP addresses for the second VPN tunnel (169.254.0.0/16 range, /30)"
  type        = string
  default     = null
}

variable "tunnel1_preshared_key" {
  description = "The preshared key of the first VPN tunnel. Leave null to let AWS generate one"
  type        = string
  default     = null
  sensitive   = true
}

variable "tunnel2_preshared_key" {
  description = "The preshared key of the second VPN tunnel. Leave null to let AWS generate one"
  type        = string
  default     = null
  sensitive   = true
}

variable "tunnel1_ike_versions" {
  description = "The IKE versions permitted for the first VPN tunnel (e.g. [\"ikev2\"])"
  type        = list(string)
  default     = []
}

variable "tunnel2_ike_versions" {
  description = "The IKE versions permitted for the second VPN tunnel (e.g. [\"ikev2\"])"
  type        = list(string)
  default     = []
}

variable "tunnel1_startup_action" {
  description = "The action to take when establishing the first tunnel (add or start)"
  type        = string
  default     = "add"
}

variable "tunnel2_startup_action" {
  description = "The action to take when establishing the second tunnel (add or start)"
  type        = string
  default     = "add"
}

# --- Tags ---------------------------------------------------------------------

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
