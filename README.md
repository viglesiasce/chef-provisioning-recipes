chef-provisioning-recipes
=========================

Recipes for provisioning software stacks using Chef Provisioning

## Installation
1.  Install [ChefDK](https://downloads.chef.io/chef-dk/)  ```curl -L https://www.opscode.com/chef/install.sh | sudo bash -s -- -P chefdk```
2.  ```easy_install fabric PyYaml```
3.  ```git clone https://github.com/viglesiasce/chef-provisioning-recipes```

## Configuration
The config file is a YAML formatted dictionary with the following structure.
By default the tool uses the config.yml found in the current working directory.
The default profile is used when no command line option is passed to the deployer.

The image should be [Ubuntu Trusty](https://cloud-images.ubuntu.com/trusty/current/) with at least 5GB of free space on the root file system.

The following environment variables can be used instead of hardcoding
credentials:

EC2_URL
AWS_IAM_URL
AWS_ACCESS_KEY
AWS_SECRET_KEY

```
profiles:
  default: # name of the profile
    credentials: default  # credentials/endpoints to use from below
    imageId: emi-5B295ED1 # image to use
    sshUsername: root # user to login to image as
    instanceType: m1.small # instance type to launch
credentials:
  default: # name of credentials
    accessKey: XXXXXXXXXXXXXXXXXXX
    secretKey: YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
    ec2Endpoint: 'http://compute.home' # only necessary for Euca
    iamEndpoint: 'http://euare.home' # only necessary for Euca
    region: eucalyptus # only necessary for AWS
```

## Deployment and Destroyment
### Deploy
In order to deploy a cluster run the deployer script with the name of the cluster
you would like to deploy and the profile you'd like to use to deploy it:

```
./deployer.py mesos -p myCloud
```

You should now be able to login to your instances with the keys found in ```./chef-repo/.chef/keys```.

### Destroy
To destroy the cluster you currently have deployed, use the --operation flag and
set it to 'destroy'. For example:

```
./deployer.py mesos -p myCloud --operation destroy
```
