--
-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

local core = require("apisix.core")
local http = require("resty.http")
local lrucache = require("resty.lrucache")

local ngx = ngx
local pairs = pairs
local ipairs = ipairs
local type = type
local tonumber = tonumber
local tostring = tostring
local string_format = string.format
local string_match = string.match
local table_insert = table.insert
local ngx_re_match = ngx.re.match

local plugin_name = "openfga-authz"
local cache, cache_err

-- Initialize cache with 200 slots and 300 seconds TTL by default
if not cache_err then
    cache = lrucache.new(200)
end

local schema = {
    type = "object",
    properties = {
        openfga_url = {
            type = "string",
            description = "OpenFGA server URL"
        },
        store_id = {
            type = "string",
            description = "OpenFGA store ID"
        },
        authorization_model_id = {
            type = "string",
            description = "OpenFGA authorization model ID (optional)"
        },
        user_header = {
            type = "string",
            default = "X-User-ID",
            description = "Header name containing user identifier"
        },
        resource_type = {
            type = "string",
            description = "OpenFGA resource type"
        },
        relation_mapping = {
            type = "object",
            description = "Mapping of HTTP methods to OpenFGA relations",
            additionalProperties = {
                type = "string"
            }
        },
        id_location = {
            type = "string",
            enum = {"last_path_segment", "query_param", "header"},
            default = "last_path_segment",
            description = "Where to find the resource ID"
        },
        id_param_name = {
            type = "string",
            description = "Query parameter or header name for resource ID (when id_location is not last_path_segment)"
        },
        cache_ttl = {
            type = "integer",
            default = 300,
            minimum = 0,
            description = "Cache TTL in seconds (0 to disable caching)"
        },
        timeout = {
            type = "integer",
            default = 3000,
            minimum = 1,
            description = "OpenFGA request timeout in milliseconds"
        },
        ssl_verify = {
            type = "boolean",
            default = true,
            description = "Verify SSL certificate when connecting to OpenFGA"
        }
    },
    required = {"openfga_url", "store_id", "resource_type"}
}


local function get_resource_id(conf, ctx)
    if conf.id_location == "last_path_segment" then
        local uri = ctx.var.uri
        local match = ngx_re_match(uri, [[\d+$]], "jo")
        if match then
            return match[0]
        end
        -- If no numeric ID, try to get the last segment
        local segments = core.string.split(uri, "/")
        return segments[#segments]
    elseif conf.id_location == "query_param" then
        if not conf.id_param_name then
            return nil
        end
        return ctx.var["arg_" .. conf.id_param_name]
    elseif conf.id_location == "header" then
        if not conf.id_param_name then
            return nil
        end
        return core.request.header(ctx, conf.id_param_name)
    end
    return nil
end


local function get_relation(conf, method)
    if conf.relation_mapping and conf.relation_mapping[method] then
        return conf.relation_mapping[method]
    end
    
    -- Default mappings
    local default_mappings = {
        GET = "reader",
        POST = "writer",
        PUT = "writer",
        PATCH = "writer",
        DELETE = "admin"
    }
    
    return default_mappings[method] or "reader"
end


local function check_authorization(conf, user, resource_type, resource_id, relation)
    local httpc = http.new()
    httpc:set_timeout(conf.timeout)
    
    local url = conf.openfga_url .. "/stores/" .. conf.store_id .. "/check"
    
    local request_body = {
        tuple_key = {
            user = user,
            relation = relation,
            object = resource_type .. ":" .. resource_id
        }
    }
    
    if conf.authorization_model_id then
        request_body.authorization_model_id = conf.authorization_model_id
    end
    
    local body = core.json.encode(request_body)
    
    core.log.info("OpenFGA check request: ", body)
    
    local res, err = httpc:request_uri(url, {
        method = "POST",
        body = body,
        headers = {
            ["Content-Type"] = "application/json",
        },
        ssl_verify = conf.ssl_verify
    })
    
    if not res then
        core.log.error("Failed to check authorization: ", err)
        return false, "OpenFGA request failed: " .. (err or "unknown error")
    end
    
    if res.status ~= 200 then
        core.log.error("OpenFGA returned non-200 status: ", res.status, " body: ", res.body)
        return false, "OpenFGA check failed with status: " .. res.status
    end
    
    local response_body, decode_err = core.json.decode(res.body)
    if not response_body then
        core.log.error("Failed to decode OpenFGA response: ", decode_err)
        return false, "Invalid OpenFGA response"
    end
    
    core.log.info("OpenFGA check response: allowed=", response_body.allowed)
    
    return response_body.allowed == true, nil
end


function _M.check_schema(conf)
    return core.schema.check(schema, conf)
end


function _M.access(conf, ctx)
    -- Extract user from header
    local user = core.request.header(ctx, conf.user_header)
    if not user then
        core.log.error("User header not found: ", conf.user_header)
        return 401, {message = "Unauthorized: User header not found"}
    end
    
    -- Get resource ID
    local resource_id = get_resource_id(conf, ctx)
    if not resource_id then
        core.log.error("Resource ID not found")
        return 400, {message = "Bad Request: Resource ID not found"}
    end
    
    -- Get relation based on HTTP method
    local method = ctx.var.request_method
    local relation = get_relation(conf, method)
    
    core.log.info("Checking authorization for user=", user, 
                  " resource=", conf.resource_type, ":", resource_id,
                  " relation=", relation)
    
    -- Check cache if enabled
    local cache_key
    if conf.cache_ttl > 0 and cache then
        cache_key = string_format("%s:%s:%s:%s", user, conf.resource_type, resource_id, relation)
        local cached_result = cache:get(cache_key)
        if cached_result ~= nil then
            core.log.info("Cache hit for key: ", cache_key, " result: ", cached_result)
            if not cached_result then
                return 403, {message = "Forbidden: Access denied"}
            end
            return
        end
    end
    
    -- Check authorization with OpenFGA
    local allowed, err = check_authorization(conf, user, conf.resource_type, resource_id, relation)
    
    -- Update cache if enabled
    if conf.cache_ttl > 0 and cache and cache_key then
        cache:set(cache_key, allowed, conf.cache_ttl)
    end
    
    if err then
        core.log.error("Authorization check error: ", err)
        return 500, {message = "Internal Server Error: " .. err}
    end
    
    if not allowed then
        core.log.warn("Access denied for user=", user, 
                      " resource=", conf.resource_type, ":", resource_id,
                      " relation=", relation)
        return 403, {message = "Forbidden: Access denied"}
    end
    
    core.log.info("Access granted for user=", user, 
                  " resource=", conf.resource_type, ":", resource_id,
                  " relation=", relation)
end


local _M = {
    version = 0.1,
    priority = 2555,
    name = plugin_name,
    schema = schema
}


return _M
