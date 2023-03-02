#!/bin/bash
yum update -y
cd /tmp
sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
echo "ssm done"

PROMETHEUS_VERSION="2.2.1"
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar -xzvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROMETHEUS_VERSION}.linux-amd64/
# if you just want to start prometheus as root
#./prometheus --config.file=prometheus.yml

# create user
useradd --no-create-home --shell /bin/false prometheus 

# create directories
mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus

# set ownership
chown prometheus:prometheus /etc/prometheus
chown prometheus:prometheus /var/lib/prometheus

# copy binaries
cp prometheus /usr/local/bin/
cp promtool /usr/local/bin/

chown prometheus:prometheus /usr/local/bin/prometheus
chown prometheus:prometheus /usr/local/bin/promtool

# copy config
cp -r consoles /etc/prometheus
cp -r console_libraries /etc/prometheus
#cp /tmp/prometheus.yml /etc/prometheus/prometheus.yml

cat <<EOF >>/etc/prometheus/token
$kubernetes_cluster_token
EOF

cat <<EOF >>/etc/prometheus/prometheus.yml
global:
  scrape_interval:     15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.


alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'kubernetes-pods'
    scrape_interval: '15s'
    scrape_timeout: '10s'
    metrics_path: '/metrics'
    scheme: 'http'
    kubernetes_sd_configs:
      - api_server: '$kubernetes_cluster_endpoint'
        role: 'pod'
        bearer_token_file: '/etc/prometheus/token'
        tls_config:
          insecure_skip_verify: true
    bearer_token_file: '/etc/prometheus/token'
    tls_config:
      insecure_skip_verify: true
    relabel_configs:
      - source_labels: ['__meta_kubernetes_pod_annotation_prometheus_io_scrape']
        action: 'keep'
        regex: true
      - source_labels: ['__meta_kubernetes_pod_annotation_prometheus_io_path']
        action: 'replace'
        target_label: '__metrics_path__'
        regex: '(.+)'
      - source_labels: ['__address__', '__meta_kubernetes_pod_annotation_prometheus_io_port']
        separator: ;
        regex: '([^:]+)(?::\d+)?;(\d+)'
        target_label: '__address__'
        replacement: '\$1:\$2'
        action: 'replace'
      - separator: ;
        regex: '__meta_kubernetes_pod_label_(.+)'
        replacement: '\$1'
        action: 'labelmap'
      - source_labels: ['__meta_kubernetes_namespace']
        separator: ;
        regex: '(.*)'
        target_label: 'kubernetes_namespace'
        replacement: '\$1'
        action: 'replace'
      - source_labels: ['__meta_kubernetes_pod_name']
        separator: ;
        regex: '(.*)'
        target_label: 'kubernetes_pods'
        replacement: '\$1'

      - source_labels: ['__meta_kubernetes_pod_container_name']
        separator: ;
        regex: '(.*)'
        target_label: 'kubernetes_container'
        replacement: '\$1'
        action: 'replace'

  # Scrape config for kubernetes service endpoints.
  - job_name: 'kubernetes-service-endpoints'
    kubernetes_sd_configs:
      - api_server: '$kubernetes_cluster_endpoint'
        role: 'endpoints'
        bearer_token_file: '/etc/prometheus/token'
        tls_config:
          insecure_skip_verify: true
    bearer_token_file: '/etc/prometheus/token'
    tls_config:
      insecure_skip_verify: true
    relabel_configs:
      # Check for the prometheus.io/scrape=true annotation.
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      # Check for the prometheus.io/port=<port> annotation.
      - source_labels: [__address__,
                        __meta_kubernetes_service_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        # A google/re2 regex, matching addresses with or without default ports.
        # NB: this will not work with IPv6 addresses. But, atm, kubernetes uses
        # IPv4 addresses for internal network and GCE doesn not support IPv6.
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: \$1:\$2
      # Copy all service labels from kubernetes to the Prometheus metrics.
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      # Add the kubernetes namespace as a Prometheus label.
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      # Add the kubernetes service name as a Prometheus label.
      - source_labels: [__meta_kubernetes_service_name]
        action: replace
        target_label: kubernetes_service
      - source_labels: [__meta_kubernetes_pod_name]
        separator: ;
        regex: (.*)
        target_label: pod
        replacement: \$1
        action: replace
      - source_labels: [__meta_kubernetes_pod_container_name]
        separator: ;
        regex: (.*)
        target_label: container
        replacement: \$1
        action: replace

          #- source_labels: [__meta_kubernetes_endpoints_name]
          #regex: 'kube-dns'
          #action: drop
          #target_label: node-exporter

          #- source_labels: [__meta_kubernetes_endpoints_name]
          #regex: 'node-exporter'
          #action: keep
          #target_label: node-exporter

          #- source_labels: [__meta_kubernetes_endpoints_name]
          #regex: (.*kube-state-metrics)
          #action: keep
          #target_label: kube-state-metrics
EOF

chown -R prometheus:prometheus /etc/prometheus/consoles
chown -R prometheus:prometheus /etc/prometheus/console_libraries

# setup systemd
echo '[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/prometheus.service

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus
echo "prometheus done"