# frozen_string_literal: true

RSpec.describe CloudsqlRubyConnector::Connector do
  describe "#initialize" do
    it "parses instance connection name" do
      connector = described_class.new("my-project:us-central1:my-instance")
      expect(connector.project).to eq("my-project")
      expect(connector.region).to eq("us-central1")
      expect(connector.instance_name).to eq("my-instance")
    end

    it "raises for invalid connection name" do
      expect do
        described_class.new("invalid-name")
      end.to raise_error(CloudsqlRubyConnector::ConfigurationError, /Invalid instance connection name/)
    end

    it "raises for empty connection name" do
      expect do
        described_class.new("")
      end.to raise_error(CloudsqlRubyConnector::ConfigurationError, /Invalid instance connection name/)
    end

    it "raises for connection name with too many parts" do
      expect do
        described_class.new("a:b:c:d")
      end.to raise_error(CloudsqlRubyConnector::ConfigurationError, /Invalid instance connection name/)
    end

    it "defaults to PUBLIC IP type" do
      connector = described_class.new("p:r:i")
      expect(connector.ip_type).to eq("PUBLIC")
    end

    it "defaults to PASSWORD auth type" do
      connector = described_class.new("p:r:i")
      expect(connector.auth_type).to eq("PASSWORD")
    end

    it "accepts custom IP type" do
      connector = described_class.new("p:r:i", ip_type: "PRIVATE")
      expect(connector.ip_type).to eq("PRIVATE")
    end

    it "accepts custom auth type" do
      connector = described_class.new("p:r:i", auth_type: "IAM")
      expect(connector.auth_type).to eq("IAM")
    end

    it "normalizes IP type from symbol" do
      connector = described_class.new("p:r:i", ip_type: :private)
      expect(connector.ip_type).to eq("PRIVATE")
    end

    it "normalizes auth type from symbol" do
      connector = described_class.new("p:r:i", auth_type: :iam)
      expect(connector.auth_type).to eq("IAM")
    end

    it "normalizes IP type from lowercase string" do
      connector = described_class.new("p:r:i", ip_type: "private")
      expect(connector.ip_type).to eq("PRIVATE")
    end

    it "accepts PSC IP type" do
      connector = described_class.new("p:r:i", ip_type: "PSC")
      expect(connector.ip_type).to eq("PSC")
    end

    it "accepts custom credentials" do
      mock_creds = instance_double(CloudsqlRubyConnector::Credentials::Base)
      connector = described_class.new("p:r:i", credentials: mock_creds)

      # Connector should use provided credentials
      expect(connector.instance_variable_get(:@credentials)).to eq(mock_creds)
    end
  end

  describe "#close" do
    it "can be called multiple times" do
      connector = described_class.new("p:r:i")
      expect { connector.close }.not_to raise_error
      expect { connector.close }.not_to raise_error
    end

    it "clears cached connection info" do
      connector = described_class.new("p:r:i")
      connector.instance_variable_set(:@cached_info, { test: "data" })

      connector.close

      expect(connector.instance_variable_get(:@cached_info)).to be_nil
    end
  end

  describe "#ip_address" do
    let(:mock_credentials) { instance_double(CloudsqlRubyConnector::Credentials::Base) }
    let(:mock_fetcher) { instance_double(CloudsqlRubyConnector::SqlAdminFetcher) }
    let(:connector) { described_class.new("project:region:instance", credentials: mock_credentials) }

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

    before do
      allow(mock_credentials).to receive(:access_token).and_return("token")
      allow(CloudsqlRubyConnector::SqlAdminFetcher).to receive(:new).and_return(mock_fetcher)

      allow(mock_fetcher).to receive_messages(fetch_metadata: {
                                                ip_addresses: { "PRIMARY" => "34.1.2.3",
                                                                "PRIVATE" => "10.0.0.5" },
                                                server_ca_cert: test_cert.to_pem,
                                                database_version: "POSTGRES_15"
                                              }, fetch_ephemeral_cert: {
                                                cert: test_cert.to_pem,
                                                expiration: Time.now + 3600
                                              })
    end

    it "returns the IP address for the configured IP type" do
      expect(connector.ip_address).to eq("34.1.2.3")
    end

    it "returns private IP when configured" do
      private_connector = described_class.new("project:region:instance",
                                              credentials: mock_credentials,
                                              ip_type: "PRIVATE")
      expect(private_connector.ip_address).to eq("10.0.0.5")
    end

    it "raises when requested IP type is not available" do
      psc_connector = described_class.new("project:region:instance",
                                          credentials: mock_credentials,
                                          ip_type: "PSC")

      expect do
        psc_connector.ip_address
      end.to raise_error(CloudsqlRubyConnector::IpAddressError, /PSC IP address not found/)
    end
  end

  describe "#get_options" do
    let(:mock_credentials) { instance_double(CloudsqlRubyConnector::Credentials::Base) }
    let(:mock_fetcher) { instance_double(CloudsqlRubyConnector::SqlAdminFetcher) }
    let(:connector) { described_class.new("project:region:instance", credentials: mock_credentials) }

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

    before do
      allow(mock_credentials).to receive(:access_token).and_return("token")
      allow(CloudsqlRubyConnector::SqlAdminFetcher).to receive(:new).and_return(mock_fetcher)

      allow(mock_fetcher).to receive_messages(fetch_metadata: {
                                                ip_addresses: { "PRIMARY" => "34.1.2.3" },
                                                server_ca_cert: test_cert.to_pem,
                                                database_version: "POSTGRES_15"
                                              }, fetch_ephemeral_cert: {
                                                cert: test_cert.to_pem,
                                                expiration: Time.now + 3600
                                              })
    end

    it "returns connection options hash" do
      options = connector.get_options

      expect(options).to include(:stream, :ip_address, :server_ca_cert, :client_cert, :private_key)
      expect(options[:ip_address]).to eq("34.1.2.3")
      expect(options[:stream]).to be_a(Proc)
    end
  end

  describe "certificate caching" do
    let(:mock_credentials) { instance_double(CloudsqlRubyConnector::Credentials::Base) }
    let(:mock_fetcher) { instance_double(CloudsqlRubyConnector::SqlAdminFetcher) }
    let(:connector) { described_class.new("project:region:instance", credentials: mock_credentials) }

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

    before do
      allow(mock_credentials).to receive(:access_token).and_return("token")
      allow(CloudsqlRubyConnector::SqlAdminFetcher).to receive(:new).and_return(mock_fetcher)

      allow(mock_fetcher).to receive_messages(fetch_metadata: {
                                                ip_addresses: { "PRIMARY" => "34.1.2.3" },
                                                server_ca_cert: test_cert.to_pem,
                                                database_version: "POSTGRES_15"
                                              }, fetch_ephemeral_cert: {
                                                cert: test_cert.to_pem,
                                                expiration: Time.now + 3600
                                              })
    end

    it "caches connection info" do
      connector.ip_address
      connector.ip_address

      expect(mock_fetcher).to have_received(:fetch_metadata).once
      expect(mock_fetcher).to have_received(:fetch_ephemeral_cert).once
    end

    it "refreshes when certificate expires" do
      # First call with cert expiring in 1 hour
      allow(mock_fetcher).to receive(:fetch_ephemeral_cert).and_return({
                                                                         cert: test_cert.to_pem,
                                                                         expiration: Time.now + 3600
                                                                       })

      connector.ip_address

      # Simulate time passing - cert now expires in 4 minutes (less than 5 min buffer)
      connector.instance_variable_set(:@cert_expiration, Time.now + 240)

      connector.ip_address

      expect(mock_fetcher).to have_received(:fetch_metadata).twice
    end
  end

  describe "IAM user formatting" do
    let(:connector) { described_class.new("p:r:i", auth_type: "IAM") }

    it "strips .gserviceaccount.com suffix" do
      formatted = connector.send(:format_iam_user, "sa@project.iam.gserviceaccount.com")
      expect(formatted).to eq("sa@project.iam")
    end

    it "preserves user without suffix" do
      formatted = connector.send(:format_iam_user, "user@example.com")
      expect(formatted).to eq("user@example.com")
    end
  end
end
