user_data = <<-EOF
  #!/bin/bash
  set -x

  apt update -y
  apt install -y unzip wget

  wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
  dpkg -i amazon-cloudwatch-agent.deb

  cat > /opt/aws/amazon-cloudwatch-agent/bin/config.json << EOT
  {
      "agent": {
          "metrics_collection_interval": 60,
          "logfile": "/var/log/amazon-cloudwatch-agent.log"
      },
      "logs": {
          "logs_collected": {
              "files": {
                  "collect_list": [
                      {
                          "file_path": "/var/log/syslog",
                          "log_group_name": "/ec2/k8s-instance-syslog",
                          "log_stream_name": "{instance_id}-syslog",
                          "timezone": "UTC"
                      },
                      {
                          "file_path": "/var/log/amazon-cloudwatch-agent.log",
                          "log_group_name": "/ec2/amazon-cloudwatch-agent",
                          "log_stream_name": "{instance_id}-agent-log",
                          "timezone": "UTC"
                      }
                  ]
              }
          }
      },
      "metrics": {
          "append_dimensions": {
              "InstanceId": "{instance_id}"
          },
          "metrics_collected": {
              "cpu": { "measurement": ["usage_system", "usage_user", "usage_idle"], "metrics_collection_interval": 60 },
              "mem": { "measurement": ["mem_used_percent"], "metrics_collection_interval": 60 },
              "disk": { "measurement": ["used_percent"], "metrics_collection_interval": 60 }
          }
      }
  }
  EOT

  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s

  systemctl enable amazon-cloudwatch-agent
  systemctl start amazon-cloudwatch-agent

  # Show last 100 lines of CloudWatch agent logs for debugging
  journalctl -u amazon-cloudwatch-agent -n 100 --no-pager

EOF
