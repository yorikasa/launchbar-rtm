#!/usr/bin/ruby
# -*- coding: utf-8 -*-
require 'net/http'
require 'digest/md5'
require 'rexml/document'

class Parser

    def initialize(xml)
        @doc = REXML::Document.new(xml)
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
    
    def authenticate()
        if File.exist?('/Users/yuki/dev/rtm/keys')
            open('/Users/yuki/dev/rtm/keys', 'r') do |file|
                @api_key = file.gets.chomp()
                @shared = file.gets.chomp()
                @frob = file.gets.chomp()
                @token = file.gets.chomp()

                params = {'method'=>'rtm.auth.checkToken', 'auth_token'=>@token}
                resp = request(params)
                # p resp
                # 通用しなかったらtoken発行し直し...の手続きをあとで書く
                return
            end
        end

        # 1. Frob
        resp = self.request({'method' => 'rtm.auth.getFrob'})
        parser = Parser.new(resp)
        @frob = parser.frob

        # 2. User Confirmation
        puts auth_request({"perms" => "delete", "frob" => @frob})
        puts "Have you done?"
        while STDIN.getc
            break
        end
        
        # 3. Token
        resp = self.request({'method' => 'rtm.auth.getToken', 'frob' => @frob})
        parser = Parser.new(resp)
        @token = parser.token

        open('data.txt', 'w+') do |file|
            file.puts @frob
            file.puts @token
        end 
    end

    def create_timeline
        resp = self.request({'method' => 'rtm.timelines.create'})
        parser = Parser.new(resp)
        return parser.timeline
    end
    
    def add_task
        create_timeline()
        resp = self.request({'method' => 'rtm.tasks.add',
                                'timeline' => create_timeline,
                                'name' => ARGV.join(' ').strip(),
                                'parse' => 1})
    end
    
end


req = Request.new
req.authenticate
req.add_task

# if ARGV.length > 0
#     # add to rtm
# else
#     # authentication
# end
