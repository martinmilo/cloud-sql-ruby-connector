# frozen_string_literal: true

RSpec.describe CloudsqlRubyConnector::SqlAdminFetcher do
  let(:mock_credentials) { instance_double(CloudsqlRubyConnector::Credentials::Base) }
  let(:fetcher) { described_class.new(credentials: mock_credentials) }

  before do
    allow(mock_credentials).to receive(:access_token).with(scope: :admin).and_return("admin-token")
    allow(mock_credentials).to receive(:access_token).with(scope: :login).and_return("login-token")
  end

  describe "#fetch_metadata" do
    let(:api_url) { "https://sqladmin.googleapis.com/sql/v1beta4/projects/my-project/instances/my-instance/connectSettings" }
    let(:metadata_response) do
      {
        "kind" => "sql#connectSettings",
        "region" => "us-central1",
        "databaseVersion" => "POSTGRES_15",
        "ipAddresses" => [
          { "type" => "PRIMARY", "ipAddress" => "34.1.2.3" },
          { "type" => "PRIVATE", "ipAddress" => "10.0.0.5" }
        ],
        "serverCaCert" => {
          "cert" => "-----BEGIN CERTIFICATE-----\nMIIC...\n-----END CERTIFICATE-----"
        }
      }
    end

    before do
      stub_request(:get, api_url)
        .with(headers: { "Authorization" => "Bearer admin-token" })
        .to_return(status: 200, body: metadata_response.to_json)
    end

    it "fetches instance metadata" do
      result = fetcher.fetch_metadata(project: "my-project", region: "us-central1", instance: "my-instance")

      expect(result[:ip_addresses]).to eq({ "PRIMARY" => "34.1.2.3", "PRIVATE" => "10.0.0.5" })
      expect(result[:server_ca_cert]).to include("BEGIN CERTIFICATE")
      expect(result[:database_version]).to eq("POSTGRES_15")
    end

    it "raises on region mismatch" do
      expect do
        fetcher.fetch_metadata(project: "my-project", region: "europe-west1", instance: "my-instance")
      end.to raise_error(CloudsqlRubyConnector::ConfigurationError, /Region mismatch/)
    end

    context "with PSC instance" do
      let(:psc_response) do
        metadata_response.merge(
          "dnsNames" => [
            { "connectionType" => "PRIVATE_SERVICE_CONNECT", "dnsScope" => "INSTANCE", "name" => "abc123.xyz.sql.goog" }
          ]
        )
      end

      before do
        stub_request(:get, api_url).to_return(status: 200, body: psc_response.to_json)
      end

      it "extracts PSC DNS name" do
        result = fetcher.fetch_metadata(project: "my-project", region: "us-central1", instance: "my-instance")

        expect(result[:ip_addresses]["PSC"]).to eq("abc123.xyz.sql.goog")
      end
    end

    context "with legacy PSC using dnsName" do
      let(:legacy_psc_response) do
        metadata_response.merge(
          "pscEnabled" => true,
          "dnsName" => "legacy.sql.goog"
        )
      end

      before do
        stub_request(:get, api_url).to_return(status: 200, body: legacy_psc_response.to_json)
      end

      it "falls back to dnsName field" do
        result = fetcher.fetch_metadata(project: "my-project", region: "us-central1", instance: "my-instance")

        expect(result[:ip_addresses]["PSC"]).to eq("legacy.sql.goog")
      end
    end

    context "when API returns error" do
      before do
        stub_request(:get, api_url)
          .to_return(status: 404, body: { "error" => { "message" => "Instance not found" } }.to_json)
      end

      it "raises ConnectionError" do
        expect do
          fetcher.fetch_metadata(project: "my-project", region: "us-central1", instance: "my-instance")
        end.to raise_error(CloudsqlRubyConnector::ConnectionError, /Instance not found/)
      end
    end

    context "when no CA cert in response" do
      before do
        stub_request(:get, api_url)
          .to_return(status: 200, body: metadata_response.merge("serverCaCert" => nil).to_json)
      end

      it "raises ConnectionError" do
        expect do
          fetcher.fetch_metadata(project: "my-project", region: "us-central1", instance: "my-instance")
        end.to raise_error(CloudsqlRubyConnector::ConnectionError, /No valid CA certificate/)
      end
    end

    context "when request times out" do
      before do
        stub_request(:get, api_url).to_timeout
      end

      it "raises ConnectionError" do
        expect do
          fetcher.fetch_metadata(project: "my-project", region: "us-central1", instance: "my-instance")
        end.to raise_error(CloudsqlRubyConnector::ConnectionError, /timed out/)
      end
    end
  end

  describe "#fetch_ephemeral_cert" do
    let(:api_url) { "https://sqladmin.googleapis.com/sql/v1beta4/projects/my-project/instances/my-instance:generateEphemeralCert" }

    # Generate a real self-signed certificate for testing
    let(:test_cert) do
      key = OpenSSL::PKey::RSA.new(2048)
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = OpenSSL::X509::Name.new([%w[CN test]])
      cert.issuer = cert.subject
      cert.public_key = key.public_key
      cert.not_before = Time.now
      cert.not_after = Time.now + 3600
      cert.sign(key, OpenSSL::Digest.new("SHA256"))
      cert
    end

    let(:cert_response) do
      {
        "ephemeralCert" => {
          "cert" => test_cert.to_pem
        }
      }
    end

    before do
      stub_request(:post, api_url)
        .with(headers: { "Authorization" => "Bearer admin-token" })
        .to_return(status: 200, body: cert_response.to_json)
    end

    it "fetches ephemeral certificate for PASSWORD auth" do
      result = fetcher.fetch_ephemeral_cert(
        project: "my-project",
        instance: "my-instance",
        public_key: "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----",
        auth_type: CloudsqlRubyConnector::AuthTypes::PASSWORD
      )

      expect(result[:cert]).to include("BEGIN CERTIFICATE")
      expect(result[:expiration]).to be_a(Time)
    end

    it "includes login token for IAM auth" do
      fetcher.fetch_ephemeral_cert(
        project: "my-project",
        instance: "my-instance",
        public_key: "public-key-pem",
        auth_type: CloudsqlRubyConnector::AuthTypes::IAM
      )

      expect(WebMock).to(have_requested(:post, api_url)
        .with { |req| JSON.parse(req.body)["access_token"] == "login-token" })
    end

    context "when API returns error" do
      before do
        stub_request(:post, api_url)
          .to_return(status: 403, body: { "error" => { "message" => "Permission denied" } }.to_json)
      end

      it "raises ConnectionError" do
        expect do
          fetcher.fetch_ephemeral_cert(
            project: "my-project",
            instance: "my-instance",
            public_key: "key",
            auth_type: CloudsqlRubyConnector::AuthTypes::PASSWORD
          )
        end.to raise_error(CloudsqlRubyConnector::ConnectionError, /Permission denied/)
      end
    end

    context "when cert is missing from response" do
      before do
        stub_request(:post, api_url).to_return(status: 200, body: { "ephemeralCert" => {} }.to_json)
      end

      it "raises ConnectionError" do
        expect do
          fetcher.fetch_ephemeral_cert(
            project: "my-project",
            instance: "my-instance",
            public_key: "key",
            auth_type: CloudsqlRubyConnector::AuthTypes::PASSWORD
          )
        end.to raise_error(CloudsqlRubyConnector::ConnectionError, /Failed to retrieve ephemeral certificate/)
      end
    end
  end

  describe "custom API endpoint" do
    let(:custom_fetcher) { described_class.new(credentials: mock_credentials, api_endpoint: "https://custom.api.com") }

    it "uses custom endpoint" do
      stub_request(:get, "https://custom.api.com/sql/v1beta4/projects/p/instances/i/connectSettings")
        .to_return(status: 200, body: {
          "region" => "r",
          "ipAddresses" => [],
          "serverCaCert" => { "cert" => "cert" }
        }.to_json)

      custom_fetcher.fetch_metadata(project: "p", region: "r", instance: "i")

      expect(WebMock).to have_requested(:get, /custom\.api\.com/)
    end
  end
end
