class TestingInstance
  include DataMapper::Resource
  property :id, String, key: true
  property :url, String
  property :name, String
  property :client_id, String
  property :base_url, String

  property :scopes, String
  property :launch_type, String
  property :state, String

  property :conformance_checked, Boolean
  property :oauth_authorize_endpoint, String
  property :oauth_token_endpoint, String
  property :oauth_register_endpoint, String
  property :fhir_format, String

  property :dynamically_registered, Boolean
  property :client_endpoint_key, String, default: proc { SecureRandomBase62.generate(32) }

  property :token, String
  property :patient_id, String

  property :created_at, DateTime, default: proc { DateTime.now }

  has n, :sequence_results

  def latest_results
    self.sequence_results.reduce({}) { |hash, result| hash[result.name] = result if hash[result.name].nil? || hash[result.name].created_at < result.created_at; hash}
  end

  def waiting_on_sequence
    self.sequence_results.first(result: 'wait')
  end
end
