# Cybus Ansible Docker Image

Docker Image for deploying Cybus Connectware and Connectware Agents elsewhere incl. AWS.

Contains Ansible, the Cybus Connectware Ansible Collection, AWS CLI and Boto libraries, 
Docker-in-Docker, docker-compose and some tools recognized as useful in practice.
with Ansible, AWS CLI, DinD, Docker-Compose and Cybus Ansible Collection


# Objective

Create a docker image to support provisioning of Cybus Connectware or Connectware Agents
using Ansible. 
Contains the [Cybus Ansible Galaxy Collection](https://galaxy.ansible.com/cybus/connectware),
uses [Cytopia/ansible:aws](https://github.com/cytopia/docker-ansible/blob/master/Dockerfiles/Dockerfile-aws)
as a base image and supports provisioning with dynamic host lists based on AWS resources.

# Build

To build the image manually execute (optionally set build-args as listed on top of the Dockerfile):

```
docker build --no-cache -t jforge/ansible-aws-cybus .
```

Test proper docker and docker-compose availability:

```
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  jforge/ansible-aws-cybus:latest \
  /bin/sh -c "docker version && docker-compose version"
```

# Usage

Define a proper playbook and provide a cybus license key in order to be able to
download the required docker image for a Connectware or Connectware Agent instance.

```
docker run --rm -v $(pwd):/data \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -e CONNECTWARE_LICENSE=${CONNECTWARE_LICENSE} \
   jforge/ansible-aws-cybus:latest \
  ansible-playbook $PLAYBOOK_FILE
```

Or in case of a Cybus infrastructure twin profile defined in some `$INFRASTRUCTURE_DEFINITION_FILE`:
which is used to create host lists dynamically:

```
docker run --rm -v $(pwd):/data \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $INFRASTRUCTURE_DEFINITION_FILE:/data/infrastructure.yml \
  -e CONNECTWARE_LICENSE=$CONNECTWARE_LICENSE \
  -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
  jforge/ansible-aws-cybus:latest \
  ansible-playbook $PLAYBOOK_FILE
```

## Example playbook for Connectware provisioning

```
# Ansible Playbook for Connectware deployment onto a prepared EC2 instance.
- name: Build Inventory for Connectware instances
  hosts: localhost
  tasks:
    - name: "Include variables from infrastructure definition file"
      include_vars:
        file: "/data/infrastructure.yml"
        name: infrastructure_info
    - name: "Gather Cybus EC2 facts for Connectware deployment"
      ec2_instance_info:
        region: eu-central-1
        filters:
          tag:aws:cloudformation:stack-name: '{{ infrastructure_info.hosts.selectors[0].value }}'
          instance-state-name: 'running'
      register: ec2_instances_json
    - name: "Adding hosts from EC2 instance filter"
      add_host:
        name: '{{ item.public_ip_address }}'
        groups: [ ec2_hosts ]
        ansible_connection: ssh
        ansible_port: 22
        ansible_user: ubuntu
        ansible_ssh_private_key_file: /data/.keystore/ssh_private_key.pem
        ansible_ssh_extra_args: "-o StrictHostKeyChecking=no"
        ansible_become: true
      with_items: '{{ ec2_instances_json.instances }}'

- name: Connectware Infrastructure Twin Playbook
  hosts: ec2_hosts
  vars:
    CONNECTWARE_VERSION: 1.0.22
    CONNECTWARE_PASSWORD: admin
    CONNECTWARE_LICENSE: "{{ lookup('env','CONNECTWARE_LICENSE') }}"
  tasks:
    - name: "Install connectware"
      include_role:
        name: cybus.connectware.started
      vars:
        CONNECTWARE_INSTALL_PATH: /opt/connectware
    - name: "Install service aws-iot-greengrass-connection"
      include_role:
        name: cybus.connectware.service_present
      vars:
        CONNECTWARE_SERVICE_ID: AWS_IoT_Greengrass_Connection
        CONNECTWARE_SERVICE_ENABLE: no
        CONNECTWARE_SERVICE_COMMISSIONING_FILE: aws-iot-greengrass-connectware-service.yml
        CONNECTWARE_SERVICE_PARAMETERS:
          Greengrass_Core_Endpoint_Address: your_accounts_aws_iot_endpoint-ats.iot.eu-central-1.amazonaws.com
          machineTopic: machineData
```

## Example playbook for Connectware Agent provisioning

```
- name: Connectware Agent Local
  hosts: localhost
  vars:
    CONNECTWARE_LICENSE: "{{ lookup('env','CONNECTWARE_LICENSE') }}"
    CONNECTWARE_AGENT_ABSENT_KEEP_VOLUMES: yes
  tasks:
    - name: Undeploy Connectware Agent
      include_role:
        name: cybus.connectware.agent_absent
      vars:
        CONNECTWARE_AGENT_COMPOSE_FILE_PATH: local-agent
    - name: Deploy Connectware Agent
      include_role:
        name: cybus.connectware.agent_started
      vars:
        CONNECTWARE_AGENT_COMPOSE_FILE_PATH: local-agent
```

## Example content of an infrastructure profile
 
Use static hosts or any strategy for dynamic host lists with this image.

This example is used at Cybus for some use cases to get access to ec2 instances 
dynamically deployed on-demand.
It simply provides some yaml to identify EC2 instances by AWS CDK stack names:

```
hosts:
  type: "aws-ec2"
  selectors:
    - vpc: "public"
      artifact: "connectware"
      type: "Filter"
      key: "tag:aws:cloudformation:stack-name"
      value: "Connectware-My-IIot-Gateway"
    - vpc: "private"
      artifact: "connectware agent"
      type: "Filter"
      key: "tag:aws:cloudformation:stack-name"
      value: "Connectware-My-Agent"
```

# References

- [Cybus](https://cybus.io)
- [Cybus Ansible Galaxy Collection](https://galaxy.ansible.com/cybus/connectware)
- [Cytopia Ansible Docker Images](https://hub.docker.com/r/cytopia/ansible)
 