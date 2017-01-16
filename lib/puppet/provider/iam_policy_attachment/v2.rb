require_relative '../../../puppet_x/puppetlabs/aws.rb'
require_relative '../../../puppet_x/puppetlabs/iam_policy'

Puppet::Type.type(:iam_policy_attachment).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do

  confine feature: :aws
  mk_resource_methods

  def self.instances
    Puppet.debug('Discovering IAM policy attachments')
    policies = PuppetX::Puppetlabs::Iam_policy.get_policies

    # There is an opportunity to poorly match the instance to the resource when
    # the name is requested.  IAM policy names generated by the user need to be
    # unique amongst other policies defined by the user, but not need be unique
    # against the built in AWS policies.  This means a user can generate a
    # policy by the same name as the built in AWS policy.  To avoid this
    # situation, here we discover all policies that have conflicting names.
    # Here we build a map to capture the information on duplicate names to
    # provide simple lookup later.

    policy_names = {}
    policies.collect {|policy|
      unless policy_names.keys.include? policy.policy_name
        policy_names[policy.policy_name] = []
      end
      policy_names[policy.policy_name] << policy.arn
    }

    policies.collect do |policy|

      # Check if we have multiple policies by the same name, skipping instance
      # creation of the built-in if found.

      if policy_names[policy.policy_name].size > 1
        if policy.arn =~ /^arn:aws:iam::aws:policy\/.*$/
          Puppet.info("Skipping built-in policy #{policy.policy_name} instance due to conflicting name")
          next
        end
      end

      response = iam_client.list_entities_for_policy({
        policy_arn: policy.arn,
      })

      user_names = response.policy_users.collect {|user| user.user_name }
      group_names = response.policy_groups.collect {|group| group.group_name }
      role_names = response.policy_roles.collect {|role| role.role_name }

      new({
        name: policy.policy_name,
        users: user_names,
        groups: group_names,
        roles: role_names,
        arn: policy.arn,
      })
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      # Skipped instances return a nil object, check here for sanity
      next if prov.is_a? NilClass
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def users=(value)
    Array(value).flatten.each {|user|
      unless @property_hash[:users].include? user
        Puppet.info("Attaching user #{user} to policy #{resource[:name]}")
        iam_client.attach_user_policy({
          policy_arn: @property_hash[:arn],
          user_name: user,
        })
      end
    }

    @property_hash[:users].each {|user|
      unless Array(value).flatten.include? user
        Puppet.info("Detaching user #{user} from policy #{resource[:name]}")
        iam_client.detach_user_policy({
          policy_arn: @property_hash[:arn],
          user_name: user,
        })
      end
    }
  end

  def groups=(value)
    Array(value).flatten.each {|group|
      unless @property_hash[:groups].include? group
        Puppet.info("Attaching group #{group} to policy #{resource[:name]}")
        iam_client.attach_group_policy({
          policy_arn: @property_hash[:arn],
          group_name: group,
        })
      end
    }

    @property_hash[:groups].each {|group|
      unless Array(value).flatten.include? group
        Puppet.info("Detaching group #{group} from policy #{resource[:name]}")
        iam_client.detach_group_policy({
          policy_arn: @property_hash[:arn],
          group_name: group,
        })
      end
    }
  end

  def roles=(value)
    Array(value).flatten.each {|role|
      unless @property_hash[:roles].include? role
        Puppet.info("Attaching role #{role} to policy #{resource[:name]}")
        iam_client.attach_role_policy({
          policy_arn: @property_hash[:arn],
          role_name: role,
        })
      end
    }

    @property_hash[:roles].each {|role|
      unless Array(value).flatten.include? role
        Puppet.info("Detaching role #{role} from policy #{resource[:name]}")
       # iam_client.detach_role_policy({
       #   policy_arn: @property_hash[:arn],
       #   role_name: role,
       # })
      end
    }
  end

end
