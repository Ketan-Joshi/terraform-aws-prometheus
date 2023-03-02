module "prometheus" {
    source = "git::https://github.com/Ketan-Joshi/terraform-aws-prometheus.git"
    instance_type_prometheus = "t3.medium"
    volume_size_prometheus = "30"
    key_name = "nw-prometheus"
    environment = "qa"
    vpc_cidr_block = ""
    vpc_id = ""
    kubernetes_cluster_endpoint = "https://AC9A1CE44BEBE2F279819A6C6FA5EB8C.sk1.us-east-1.eks.amazonaws.com"
    kubernetes_cluster_token = ""
}