require_relative '../../../puppet_x/puppetlabs/aws.rb'

Puppet::Type.type(:ec2_vpc_nat_gateway).provide(:v2, :parent => PuppetX::Puppetlabs::Aws) do
  confine feature: :aws
  confine feature: :retries

  mk_resource_methods
  
  def self.instances()
    regions.collect do |region|
      begin
        gateways = []
        response = ec2_client(region).describe_nat_gateways
        response.nat_gateways.each do |gateway|
          if (gateway.state == "deleting" or gateway.state == "deleted") then next end
          subnet_response = ec2_client(region).describe_subnets(filters: [
            {name: "subnet-id", values: [gateway.subnet_id]}
          ])
          hash = gateway_to_hash(region, gateway, subnet_response.data.subnets.first)
          gateways << new(hash)
        end
        gateways
      rescue Timeout::Error, StandardError => e
        raise PuppetX::Puppetlabs::FetchingAWSDataError.new(region, self.resource_type.name.to_s, e.message)
      end
    end.flatten
  end

  read_only(:nat_gateway_addresses, :subnet, :vpc, :region)

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]  # rubocop:disable Lint/AssignmentInCondition
        resource.provider = prov
      end
    end
  end

  def self.gateway_to_hash(region, gateway, subnet)
    {
      :name       => gateway.nat_gateway_addresses[0].public_ip,
      :id         => gateway.nat_gateway_id,
      :eip_allocation_id         => gateway.nat_gateway_addresses[0].allocation_id,
      :subnet     => name_from_tag(subnet),
      :region     => region,
      :ensure     => :present,
    }
  end

  def exists?
    Puppet.debug("Checking if Nat gateway #{name} exists in #{target_region}")
    @property_hash[:ensure] == :present
  end

  def create
    Puppet.info("Creating Nat gateway #{name} in #{target_region}")
    ec2 = ec2_client(target_region)

    vpc_response = ec2.describe_vpcs(filters: [
      {name: "tag:Name", values: [resource[:vpc]]},
    ])
    fail("Multiple VPCs with name #{resource[:vpc]}") if vpc_response.data.vpcs.count > 1
    fail("No VPCs with name #{resource[:vpc]}") if vpc_response.data.vpcs.empty?
    
    subnet_response = ec2.describe_subnets(filters: [
      {name: "vpc-id", values: [vpc_response.data.vpcs.first.vpc_id]},
      {name: "tag:Name", values: [resource[:subnet]]},
    ])
    fail("Multiple subnets with name #{resource[:subnet]}") if subnet_response.data.subnets.count > 1
    fail("No subnet with name #{resource[:subnet]}") if subnet_response.data.subnets.empty?

    response = ec2.create_nat_gateway(
      subnet_id: subnet_response.data.subnets.first.subnet_id,
      allocation_id: resource[:eip_allocation_id]
    )

    @property_hash[:ensure] = :present
  end

  def destroy
    Puppet.info("Destroying Nat gateway #{name} in #{target_region}")
    ec2_client(target_region).delete_nat_gateway(
      nat_gateway_id: @property_hash[:id]
    )
    @property_hash[:ensure] = :absent
  end
end
