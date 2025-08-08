output "master_public_ip" {
  description = "Public IP address of the Kubernetes master node"
  value       = aws_instance.K8_master.public_ip
}

output "worker_public_ip" {
  description = "Public IP address of the Kubernetes worker node"
  value       = aws_instance.K8_worker.public_ip
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = aws_subnet.main.id
}