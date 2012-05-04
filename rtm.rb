#!/usr/bin/ruby
# -*- coding: utf-8 -*-
require 'net/http'
require 'digest/md5'
require 'rexml/document'

KEY_LOCATION = '/Users/yuki/dev/rtm/keys'

class Parser

    def initialize(xml)
        @doc = REXML::Document.new(xml)
    end

    def status
        if @doc.root.attributes['stat'] == 'ok'
            return 1
        else
            return nil
        end
    end

    def frob
        return @doc.root.elements['frob'].text
    end

    def token
        return @doc.root.elements['auth/token'].text
    end
    
    def timeline
        return @doc.root.elements['timeline'].text
    end
    
end


class Request

    def add_sign(params)
        params_flat =  params.sort.join
        api_sig = Digest::MD5.hexdigest(@shared + params_flat)
        params['api_sig'] = api_sig
        return params
    end

    def request(params)
        url = "http://api.rememberthemilk.com/services/rest/"
        params['api_key'] = @api_key
        params['auth_token'] = @token
        params = add_sign(params)

        response = Net::HTTP.post_form(URI.parse(url), params)
        return response.body
    end

    def auth_request(params)
        url = "http://api.rememberthemilk.com/services/auth/"
        params['api_key'] = @api_key
        params = add_sign(params)

        goto = url + "?" + params.map{|k,v| k + "=" + v}.join("&")
        `open /Applications/Safari.app '#{goto}'`
    end

    def auth_confirm
        # 1.1 Get Frob
        resp = self.request({'method' => 'rtm.auth.getFrob'})
        parser = Parser.new(resp)
        @frob = parser.frob
        open(KEY_LOCATION, 'a') do |file|
            file.puts
            file.puts @frob
        end

        # 1.2 User Confirmation
        puts auth_request({"perms" => "write", "frob" => @frob})
    end

    def authenticate(frob=nil)
        # First time, this script needs you to authorize.
        # So you have to execute the script twice.

        if not frob
            auth_confirm()
            return
        end
                        
        # 2 Get Token
        resp = self.request({'method' => 'rtm.auth.getToken', 'frob' => @frob})
        parser = Parser.new(resp)
        @token = parser.token

        open(KEY_LOCATION, 'a') do |file|
            file.puts @token
        end
    end
    
    def auth_check()
        if File.exist?(KEY_LOCATION)
            keys = []
            open(KEY_LOCATION, 'r') do |file|
                keys = file.read.split(/\s+/)
            end
            # check if already authenticated
            if keys.length == 2
                # assume there's not frob and token (First time)
                @api_key, @shared = keys
                authenticate()
                return nil
            elsif keys.length == 3
                # assume there's not token (Second time)
                @api_key, @shared, @frob = keys
                authenticate("frob exists")
            elsif keys.length == 4
                # Authenticated (Third time and after)
                @api_key, @shared, @frob, @token = keys
            else
                return nil
            end

            # check if auth_token is valid
            resp = request({'method'=>'rtm.auth.checkToken'})
            parser = Parser.new(resp)
            if not parser.status
                open(KEY_LOCATION, 'w') do |file|
                    file.puts @api_key
                    file.puts @shared
                end
                authenticate()
                return nil
            end
            return 'ok'
        else
            puts 'You have to first create a file named "keys"'
            puts 'and put API KEY and Shared Secret.'
        end
    end

    def create_timeline
        resp = self.request({'method' => 'rtm.timelines.create'})
        parser = Parser.new(resp)
        return parser.timeline
    end
    
    def add_task(task_name)
        create_timeline()
        resp = self.request({'method' => 'rtm.tasks.add',
                                'timeline' => create_timeline,
                                'name' => task_name,
                                'parse' => 1})
    end
    
end

if ARGV.length > 0
    task_name = ARGV.join(' ').strip()
else
    printf('Task: ')
    task_name = gets
end

req = Request.new
if req.auth_check
    req.add_task(task_name)
end

