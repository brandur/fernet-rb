#encoding UTF-8
require 'base64'
require 'yajl'
require 'openssl'
require 'date'

module Fernet
  class Verifier
    attr_reader :token, :data
    attr_accessor :ttl, :enforce_ttl

    def initialize(secret)
      @secret      = Secret.new(secret)
      @ttl         = Configuration.ttl
      @enforce_ttl = Configuration.enforce_ttl
    end

    def verify_token(token)
      @token = token
      deconstruct

      if block_given?
        custom_verification = yield self
      else
        custom_verification = true
      end

      @valid = signatures_match? && token_recent_enough? && custom_verification
    end

    def valid?
      @valid
    end

    def inspect
      "#<Fernet::Verifier @secret=[masked] @token=#{@token} @data=#{@data.inspect} @ttl=#{@ttl}>"
    end
    alias to_s inspect

  private
    attr_reader :secret
    def deconstruct
      decoded_token       = Base64.urlsafe_decode64(@token)
      @received_signature = decoded_token[0,64]
      issued_timestamp    = decoded_token[64,8].unpack("Q*").first
      @issued_at          = DateTime.strptime(issued_timestamp.to_s, '%s')
      iv                  = decoded_token[72,16]
      encrypted_data      = decoded_token[88..-1]
      @data = decrypt!(encrypted_data, iv)
      signing_blob = [issued_timestamp].pack("Q") + iv + encrypted_data
      @regenerated_mac = OpenSSL::HMAC.hexdigest('sha256', secret.signing_key, signing_blob)
    end

    def token_recent_enough?
      if enforce_ttl?
        good_till = @issued_at + (ttl.to_f / 24 / 60 / 60)
        good_till > now
      else
        true
      end
    end

    def signatures_match?
      regenerated_bytes = @regenerated_mac.bytes.to_a
      received_bytes    = @received_signature.bytes.to_a
      received_bytes.inject(0) do |accum, byte|
        accum |= byte ^ regenerated_bytes.shift
      end.zero?
    end

    def decrypt!(encrypted_data, iv)
      decipher = OpenSSL::Cipher.new('AES-128-CBC')
      decipher.decrypt
      decipher.iv  = iv
      decipher.key = secret.encryption_key
      decipher.update(encrypted_data) + decipher.final
    end

    def enforce_ttl?
      @enforce_ttl
    end

    def now
      DateTime.now
    end
  end
end
