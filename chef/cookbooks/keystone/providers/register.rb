#
# Cookbook Name:: keystone
# Provider:: register
#
# Copyright:: 2008-2011, Opscode, Inc <legal@opscode.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

action :add_service do
  # Construct the http object
  http = Net::HTTP.new(new_resource.host, 5001)

  # Fill out the headers
  headers = _build_headers(new_resource.token)

  # Construct the path
  path = '/v2.0/services/'

  # Lets verify that the service does not exist yet
  resp, data = http.request_get(path + new_resource.service_name, headers)
  if resp.is_a?(Net::HTTPNotFound)
    # Service does not exist yet
    body = _build_service_object(new_resource.service_name, new_resource.service_description) 
    resp, data = http.send_request('POST', path, JSON.generate(body), headers)
    if resp.is_a?(Net::HTTPCreated)
      Chef::Log.info("Created keystone service '#{new_resource.service_name}'")
      new_resource.updated_by_last_action(true)
    else
      Chef::Log.error("Unable to create service '#{new_resource.service_name}'")
      Chef::Log.error("Response Code: #{resp.code}")
      Chef::Log.error("Response Message: #{resp.message}")
      new_resource.updated_by_last_action(false)
    end
  elsif resp.is_a?(Net::HTTPOK)
    Chef::Log.info "Service '#{new_resource.service_name}' already exists.. Not creating."
    new_resource.updated_by_last_action(false)
  else
    Chef::Log.error "Unknown response from Keystone Server"
    Chef::Log.error("Response Code: #{resp.code}")
    Chef::Log.error("Response Message: #{resp.message}")
    new_resource.updated_by_last_action(false)
  end
end

action :add_endpoint_template do
  # Construct the http object
  http = Net::HTTP.new(new_resource.host, 5001)

  # Fill out the headers
  headers = _build_headers(new_resource.token)

  # Construct the path
  path = '/v2.0/endpointTemplates/'

  # Lets verify that the endpointTemplate does not exist yet
  resp, data = http.request_get(path, headers) 
  if resp.is_a?(Net::HTTPOK)
      matched_service = false
      data = JSON.parse(data)
      data["endpointTemplates"]["values"].each do |endpoint|
          if endpoint["serviceId"] == new_resource.endpoint_service 
              matched_service = true
          end
      end
      if matched_service
          Chef::Log.info("Already existing keystone endpointTemplate for '#{new_resource.endpoint_service}' - not creating")
          new_resource.updated_by_last_action(false)
      else
          # endpointTemplate does not exist yet
          body = _build_endpoint_template_object(
                 new_resource.endpoint_service,
                 new_resource.endpoint_region, 
                 new_resource.endpoint_adminURL, 
                 new_resource.endpoint_internalURL, 
                 new_resource.endpoint_publicURL, 
                 new_resource.endpoint_global, 
                 new_resource.endpoint_enabled)
          resp, data = http.send_request('POST', path, JSON.generate(body), headers)
          if resp.is_a?(Net::HTTPCreated)
              Chef::Log.info("Created keystone endpointTemplate for '#{new_resource.endpoint_service}'")
              new_resource.updated_by_last_action(true)
          else
              Chef::Log.error("Unable to create endpointTemplate for '#{new_resource.endpoint_service}'")
              Chef::Log.error("Response Code: #{resp.code}")
              Chef::Log.error("Response Message: #{resp.message}")
              new_resource.updated_by_last_action(false)
          end
      end
  else
      Chef::Log.error "Unknown response from Keystone Server"
      Chef::Log.error("Response Code: #{resp.code}")
      Chef::Log.error("Response Message: #{resp.message}")
      new_resource.updated_by_last_action(false)
  end
end

private
def _build_service_object(svc_name, svc_desc)
  svc_obj = Hash.new
  svc_obj.store("id", svc_name)
  svc_obj.store("description", svc_desc)
  ret = Hash.new
  ret.store("service", svc_obj)
  return ret
end

private
def _build_endpoint_template_object(service, region, adminURL, internalURL, publicURL, global=true, enabled=true)
  template_obj = Hash.new
  template_obj.store("serviceId", service)
  template_obj.store("region", region)
  template_obj.store("adminURL", adminURL)
  template_obj.store("internalURL", internalURL)
  template_obj.store("publicURL", publicURL)
  if global
    template_obj.store("global", 1)
  else
    template_obj.store("global", 0)
  end
  if enabled
    template_obj.store("enabled", 1)
  else
    template_obj.store("enabled", 0)
  end
  ret = Hash.new
  ret.store("endpointTemplate", template_obj)
  return ret
end

private
def _build_headers(token)
  ret = Hash.new
  ret.store('X-Auth-Token', token)
  ret.store('Content-type', 'application/json')
  return ret
end
