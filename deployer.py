#!/usr/bin/python
import os
from fabric.api import run, env, local, execute, task
from fabric.context_managers import shell_env, show
from fabric.state import output
import argparse
import yaml
from yaml import Loader, Dumper

def create_chef_repo(context):
    repo_dir = context['chefRepo']
    local('chef generate repo {0}'.format(repo_dir))
    local('mkdir -p {0}/.chef'.format(context['chefRepo']))
    local("echo 'chef_repo_path  \"{0}\"' > {0}/.chef/client.rb".format(context['chefRepo']))


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
              'operation': args.operation}
    # Add in config file
    with open(args.config) as config_file:
        config_file = yaml.load(config_file)
    # Add in profile
    profile = config_file['profiles'][args.profile]
    config.update(profile)
    # Add in creds
    config.update(config_file['credentials'][profile['credentials']])
    return config

def deploy(context):
    recipe_path = os.path.abspath("{0}/recipe.rb".format(context['application']))
    with show('debug'):
        with shell_env(**context):
            local('chef-client -z {0} -c {1}/.chef/client.rb'.format(recipe_path, context['chefRepo']))

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('application')
    parser.add_argument('-p', '--profile', default='default')
    parser.add_argument('-c', '--config', default='config.yml')
    parser.add_argument('--debug', action='store_true', default=False)
    parser.add_argument('--operation', default='create')
    args = parser.parse_args()
    context = read_configuration(args)
    create_chef_repo(context)
    download_cookbook_deps(context)
    deploy(context)
