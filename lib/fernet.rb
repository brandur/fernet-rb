require 'fernet/version'
require 'fernet/generator'
require 'fernet/verifier'
require 'fernet/secret'
require 'fernet/configuration'

if RUBY_VERSION == '1.8.7'
  require 'shim/base64'
end

Fernet::Configuration.run

module Fernet
  def self.generate(secret, &block)
    Generator.new(secret).generate(&block)
  end

  def self.verify(secret, token, &block)
    Verifier.new(secret).verify_token(token, &block)
  end

  def self.verifier(secret, token)
    Verifier.new(secret).tap do |v|
      v.verify_token(token)
    end
  end
end
