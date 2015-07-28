#!/usr/bin/python
import os
from fabric.api import run, env, local, execute, task
from fabric.context_managers import shell_env, show, lcd
from fabric.state import output
import argparse
import yaml
from yaml import Loader, Dumper

def create_chef_repo(context):
    repo_dir = context['chefRepo']
    local('chef generate repo {0}'.format(repo_dir))
    local('mkdir -p {0}/.chef'.format(context['chefRepo']))
    local("echo 'chef_repo_path  \"{0}\"' > {0}/.chef/client.rb".format(context['chefRepo']))
    local("echo 'log_level :info' >> {0}/.chef/client.rb".format(context['chefRepo']))
#    local("echo 'ssl_verify_mode :verify_none' >> {0}/.chef/client.rb".format(context['chefRepo']))

def download_cookbook_deps(context):
    """
    Install all necessary cookbooks

    :param context: Current context for the CLI run
    :type context: dict
    """
    local('berks vendor --berksfile={0}/Berksfile {1}/cookbooks'.format(context['application'],
                                                                  context['chefRepo']))

def read_configuration(args):
    """
    Read in YAML configuration and add to context

    :param context: Current context for the CLI run
    :type context: dict
    :rtype: dict
    """
    config = {'chefRepo': os.path.abspath('./chef-repo'),
              'keyName': args.application,
              'application': args.application,
              'operation': args.operation,
              'accessKey': os.getenv('AWS_ACCESS_KEY'),
              'secretKey': os.getenv('AWS_SECRET_KEY'),
              'ec2Endpoint': os.getenv('EC2_URL'),
              'iamEndpoint': os.getenv('AWS_IAM_URL')
              }
    # Add in config file
    with open(args.config) as config_file:
        config_file = yaml.load(config_file)
    # Add in profile
    profile = config_file['profiles'][args.profile]
    config.update(profile)
    if not config['accessKey'] or not config['secretKey']:
        print 'Unable to find access or secret key.'
        print 'Please set the AWS_ACCESS_KEY and AWS_SECRET_KEY env variables.'
        exit(1)
    # Add in creds if they are in the profile
    if 'endpoints' in profile:
        config.update(config_file['endpoints'][profile['endpoints']])
    return config

def run_chef_client(context, recipes):
    with shell_env(**context):
        local('chef-client -c {0}/.chef/client.rb -z {1}'.format(context['chefRepo'], ' '.join(recipes)))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('application')
    parser.add_argument('-p', '--profile', default='default')
    parser.add_argument('-c', '--config', default='config.yml')
    parser.add_argument('--debug', action='store_true', default=False)
    parser.add_argument('-o', '--operation', default='create')
    parser.add_argument('-r', '--run', default='uptime', required=False)
    args = parser.parse_args()
    context = read_configuration(args)
    if args.operation == 'create':
        recipes = [os.path.abspath("common/configure.rb"),
                   os.path.abspath("common/stage.rb"),
                   os.path.abspath("{0}/recipe.rb".format(context['application']))]
        create_chef_repo(context)
        download_cookbook_deps(context)
        run_chef_client(context, recipes)
    elif args.operation == 'execute':
        app_name = context['application']
        with lcd(context['chefRepo']):
            environment_name = app_name + '-' + args.profile
            key_file = '.chef/keys/' + environment_name
            knife_command = 'knife ssh -z -x root -i {0} chef_environment:{1} "{2}"'.format(key_file, environment_name, args.run)
            local(knife_command)
    elif args.operation == 'destroy':
        recipes = [os.path.abspath("common/configure.rb"),
                   os.path.abspath("common/destroy.rb")]
        run_chef_client(context, recipes)
