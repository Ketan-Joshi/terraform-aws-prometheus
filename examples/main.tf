module "prometheus" {
    source = "git::https://github.com/Ketan-Joshi/terraform-aws-prometheus.git"
    instance_type_prometheus = "t3.medium"
    volume_size_prometheus = "30"
    pem_key_name = "prometheus"
    environment = "qa"
    vpc_cidr_block = ""
    vpc_id = ""
    kubernetes_cluster_endpoint = ""
    kubernetes_cluster_token = ""
}