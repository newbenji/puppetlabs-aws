Puppet::Type.newtype(:ec2_vpc_nat_gateway) do
  @doc = 'Type representing an AWS VPC nat gateways.'

  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the customer gateway.'
    validate do |value|
      fail 'nat gateways must have a name' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:eip_allocation_id, namevar: true) do
    desc 'The allocation id for the elastic ip.'
    validate do |value|
      fail 'nat gateways must have an allocation id' if value == ''
      fail 'name should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:subnet, namevar: true) do
    desc 'The subnet to which the nat gateway should be attached.'
    validate do |value|
      fail 'nat gateways must have a subnet' if value == ''
      fail 'subnet should be a String' unless value.is_a?(String)
    end
  end

  newproperty(:vpc) do
    desc 'The vpc to assign this nat gateway to.'
    validate do |value|
      fail 'vpc should be a String' unless value.is_a?(String)
    end
  end
  
  newproperty(:region) do
    desc 'The region in which to launch the customer gateway.'
    validate do |value|
      fail 'region should not contain spaces' if value =~ /\s/
      fail 'region should be a String' unless value.is_a?(String)
    end
  end
  
end
