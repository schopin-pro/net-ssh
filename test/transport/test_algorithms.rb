require_relative '../common'
require 'logger'
require 'net/ssh/transport/algorithms'

module Transport
  class TestAlgorithms < NetSSHTest
    include Net::SSH::Transport::Constants

    def test_allowed_packets
      (0..255).each do |type|
        packet = stub("packet", type: type)
        case type
        when 1..4, 6..19, 21..49 then assert(Net::SSH::Transport::Algorithms.allowed_packet?(packet), "#{type} should be allowed during key exchange")
        else assert(!Net::SSH::Transport::Algorithms.allowed_packet?(packet), "#{type} should not be allowed during key exchange")
        end
      end
    end

    def test_constructor_should_build_default_list_of_preferred_algorithms
      assert_equal ed_ec_host_keys + %w[ssh-rsa-cert-v01@openssh.com ssh-rsa-cert-v00@openssh.com ssh-rsa rsa-sha2-256 rsa-sha2-512], algorithms[:host_key]
      assert_equal x25519_kex + ec_kex + %w[diffie-hellman-group-exchange-sha256 diffie-hellman-group14-sha256 diffie-hellman-group14-sha1], algorithms[:kex]
      assert_equal %w[aes256-ctr aes192-ctr aes128-ctr], algorithms[:encryption]
      assert_equal %w[hmac-sha2-512-etm@openssh.com hmac-sha2-256-etm@openssh.com hmac-sha2-512 hmac-sha2-256 hmac-sha1], algorithms[:hmac]
      assert_equal %w[none zlib@openssh.com zlib], algorithms[:compression]
      assert_equal %w[], algorithms[:language]
    end

    def test_constructor_should_build_complete_list_of_algorithms_with_append_all_supported_algorithms
      assert_equal ed_ec_host_keys + %w[ssh-rsa-cert-v01@openssh.com ssh-rsa-cert-v00@openssh.com ssh-rsa rsa-sha2-256 rsa-sha2-512 ssh-dss], algorithms(append_all_supported_algorithms: true)[:host_key]
      assert_equal x25519_kex + ec_kex + %w[diffie-hellman-group-exchange-sha256 diffie-hellman-group14-sha256 diffie-hellman-group14-sha1 diffie-hellman-group-exchange-sha1 diffie-hellman-group1-sha1], algorithms(append_all_supported_algorithms: true)[:kex]
      assert_equal %w[aes256-ctr aes192-ctr aes128-ctr aes256-cbc aes192-cbc aes128-cbc rijndael-cbc@lysator.liu.se blowfish-ctr blowfish-cbc cast128-ctr cast128-cbc 3des-ctr 3des-cbc idea-cbc none], algorithms(append_all_supported_algorithms: true)[:encryption]
      assert_equal %w[hmac-sha2-512-etm@openssh.com hmac-sha2-256-etm@openssh.com hmac-sha2-512 hmac-sha2-256 hmac-sha1 hmac-sha2-512-96 hmac-sha2-256-96 hmac-sha1-96 hmac-ripemd160 hmac-ripemd160@openssh.com hmac-md5 hmac-md5-96 none], algorithms(append_all_supported_algorithms: true)[:hmac]
      assert_equal %w[none zlib@openssh.com zlib], algorithms(append_all_supported_algorithms: true)[:compression]
      assert_equal %w[], algorithms[:language]
    end

    def test_constructor_should_set_client_and_server_prefs_identically
      %w[encryption hmac compression language].each do |key|
        assert_equal algorithms[key.to_sym], algorithms[:"#{key}_client"], key
        assert_equal algorithms[key.to_sym], algorithms[:"#{key}_server"], key
      end
    end

    def test_constructor_with_preferred_host_key_type_should_put_preferred_host_key_type_first
      assert_equal %w[ssh-dss] + ed_ec_host_keys + %w[ssh-rsa-cert-v01@openssh.com ssh-rsa-cert-v00@openssh.com ssh-rsa rsa-sha2-256 rsa-sha2-512], algorithms(host_key: "ssh-dss", append_all_supported_algorithms: true)[:host_key]
    end

    def test_constructor_with_known_hosts_reporting_known_host_key_should_use_that_host_key_type
      Net::SSH::KnownHosts.expects(:search_for).with(
        "net.ssh.test,127.0.0.1",
        { user_known_hosts_file: "/dev/null", global_known_hosts_file: "/dev/null" }
      ).returns([stub("key", ssh_type: "ssh-dss")])
      assert_equal %w[ssh-dss] + ed_ec_host_keys + %w[ssh-rsa-cert-v01@openssh.com ssh-rsa-cert-v00@openssh.com ssh-rsa rsa-sha2-256 rsa-sha2-512], algorithms[:host_key]
    end

    def ed_host_keys
      if Net::SSH::Authentication::ED25519Loader::LOADED
        %w[ssh-ed25519-cert-v01@openssh.com ssh-ed25519]
      else
        []
      end
    end

    def ec_host_keys
      %w[ecdsa-sha2-nistp521-cert-v01@openssh.com
         ecdsa-sha2-nistp384-cert-v01@openssh.com
         ecdsa-sha2-nistp256-cert-v01@openssh.com
         ecdsa-sha2-nistp521
         ecdsa-sha2-nistp384
         ecdsa-sha2-nistp256]
    end

    def ed_ec_host_keys
      ed_host_keys + ec_host_keys
    end

    def test_constructor_with_unrecognized_host_key_type_should_return_whats_supported
      assert_equal ed_ec_host_keys + %w[ssh-rsa-cert-v01@openssh.com ssh-rsa-cert-v00@openssh.com ssh-rsa rsa-sha2-256 rsa-sha2-512 ssh-dss],
                   algorithms(host_key: "bogus ssh-rsa", append_all_supported_algorithms: true)[:host_key]
    end

    def ec_kex
      %w[ecdh-sha2-nistp521 ecdh-sha2-nistp384 ecdh-sha2-nistp256]
    end

    def x25519_kex
      if Net::SSH::Transport::Kex::Curve25519Sha256Loader::LOADED
        %w[curve25519-sha256 curve25519-sha256@libssh.org]
      else
        []
      end
    end

    def test_constructor_with_preferred_kex_should_put_preferred_kex_first
      assert_equal %w[diffie-hellman-group1-sha1] + x25519_kex + ec_kex + %w[diffie-hellman-group-exchange-sha256 diffie-hellman-group14-sha256 diffie-hellman-group14-sha1 diffie-hellman-group-exchange-sha1],
                   algorithms(kex: "diffie-hellman-group1-sha1", append_all_supported_algorithms: true)[:kex]
    end

    def test_constructor_with_unrecognized_kex_should_not_raise_exception
      assert_equal %w[diffie-hellman-group1-sha1] + x25519_kex + ec_kex + %w[diffie-hellman-group-exchange-sha256 diffie-hellman-group14-sha256 diffie-hellman-group14-sha1 diffie-hellman-group-exchange-sha1],
                   algorithms(kex: %w[bogus diffie-hellman-group1-sha1], append_all_supported_algorithms: true)[:kex]
    end

    def test_constructor_with_preferred_kex_supports_additions
      assert_equal x25519_kex + ec_kex + %w[diffie-hellman-group-exchange-sha256 diffie-hellman-group14-sha256 diffie-hellman-group14-sha1 diffie-hellman-group-exchange-sha1 diffie-hellman-group1-sha1],
                   algorithms(kex: %w[+diffie-hellman-group1-sha1])[:kex]
    end

    def test_constructor_with_preferred_kex_supports_removals_with_wildcard
      assert_equal x25519_kex + ec_kex + %w[diffie-hellman-group-exchange-sha256 diffie-hellman-group14-sha256],
                   algorithms(kex: %w[-diffie-hellman-group*-sha1 -diffie-hellman-group-exchange-sha1])[:kex]
    end

    def test_constructor_with_preferred_encryption_should_put_preferred_encryption_first
      assert_equal %w[aes256-cbc aes256-ctr aes192-ctr aes128-ctr aes192-cbc aes128-cbc rijndael-cbc@lysator.liu.se blowfish-ctr blowfish-cbc cast128-ctr cast128-cbc 3des-ctr 3des-cbc idea-cbc none], algorithms(encryption: "aes256-cbc", append_all_supported_algorithms: true)[:encryption]
    end

    def test_constructor_with_multiple_preferred_encryption_should_put_all_preferred_encryption_first
      assert_equal %w[aes256-cbc 3des-cbc idea-cbc aes256-ctr aes192-ctr aes128-ctr aes192-cbc aes128-cbc rijndael-cbc@lysator.liu.se blowfish-ctr blowfish-cbc cast128-ctr cast128-cbc 3des-ctr none], algorithms(encryption: %w[aes256-cbc 3des-cbc idea-cbc], append_all_supported_algorithms: true)[:encryption]
    end

    def test_constructor_with_unrecognized_encryption_should_keep_whats_supported
      assert_equal %w[aes256-cbc aes256-ctr aes192-ctr aes128-ctr aes192-cbc aes128-cbc rijndael-cbc@lysator.liu.se blowfish-ctr blowfish-cbc cast128-ctr cast128-cbc 3des-ctr 3des-cbc idea-cbc none], algorithms(encryption: %w[bogus aes256-cbc], append_all_supported_algorithms: true)[:encryption]
    end

    def test_constructor_with_preferred_encryption_supports_additions
      # There's nothing we can really append to the set since the default algos
      # are frozen so this is really just testing that it doesn't do anything
      # unexpected.
      assert_equal %w[aes256-ctr aes192-ctr aes128-ctr aes256-cbc aes192-cbc aes128-cbc rijndael-cbc@lysator.liu.se blowfish-ctr blowfish-cbc cast128-ctr cast128-cbc 3des-ctr 3des-cbc idea-cbc none],
                   algorithms(encryption: %w[+3des-cbc])[:encryption]
    end

    def test_constructor_with_preferred_encryption_supports_removals_with_wildcard
      assert_equal %w[aes256-ctr aes192-ctr aes128-ctr cast128-ctr],
                   algorithms(encryption: %w[-rijndael-cbc@lysator.liu.se -blowfish-* -3des-* -*-cbc -none])[:encryption]
    end

    def test_constructor_with_preferred_hmac_should_put_preferred_hmac_first
      assert_equal %w[hmac-md5-96 hmac-sha2-512-etm@openssh.com hmac-sha2-256-etm@openssh.com hmac-sha2-512 hmac-sha2-256 hmac-sha1 hmac-sha2-512-96 hmac-sha2-256-96 hmac-sha1-96 hmac-ripemd160 hmac-ripemd160@openssh.com hmac-md5 none], algorithms(hmac: "hmac-md5-96", append_all_supported_algorithms: true)[:hmac]
    end

    def test_constructor_with_multiple_preferred_hmac_should_put_all_preferred_hmac_first
      assert_equal %w[hmac-md5-96 hmac-sha1-96 hmac-sha2-512-etm@openssh.com hmac-sha2-256-etm@openssh.com hmac-sha2-512 hmac-sha2-256 hmac-sha1 hmac-sha2-512-96 hmac-sha2-256-96 hmac-ripemd160 hmac-ripemd160@openssh.com hmac-md5 none], algorithms(hmac: %w[hmac-md5-96 hmac-sha1-96], append_all_supported_algorithms: true)[:hmac]
    end

    def test_constructor_with_unrecognized_hmac_should_ignore_those
      assert_equal %w[hmac-sha2-512-etm@openssh.com hmac-sha2-256-etm@openssh.com hmac-sha2-512 hmac-sha2-256 hmac-sha1 hmac-sha2-512-96 hmac-sha2-256-96 hmac-sha1-96 hmac-ripemd160 hmac-ripemd160@openssh.com hmac-md5 hmac-md5-96 none],
                   algorithms(hmac: "unknown hmac-md5-96", append_all_supported_algorithms: true)[:hmac]
    end

    def test_constructor_with_preferred_hmac_supports_additions
      assert_equal %w[hmac-sha2-512-etm@openssh.com hmac-sha2-256-etm@openssh.com hmac-sha2-512 hmac-sha2-256 hmac-sha1 hmac-sha2-512-96 hmac-sha2-256-96 hmac-sha1-96 hmac-ripemd160 hmac-ripemd160@openssh.com hmac-md5 hmac-md5-96],
                   algorithms(hmac: %w[+hmac-md5-96 -none])[:hmac]
    end

    def test_constructor_with_preferred_hmac_supports_removals_with_wildcard
      assert_equal %w[hmac-sha2-512-etm@openssh.com hmac-sha2-256-etm@openssh.com hmac-sha2-512 hmac-sha2-256 hmac-sha2-512-96 hmac-sha2-256-96 hmac-ripemd160 hmac-ripemd160@openssh.com],
                   algorithms(hmac: %w[-hmac-sha1* -hmac-md5* -none])[:hmac]
    end

    def test_constructor_with_preferred_compression_should_put_preferred_compression_first
      assert_equal %w[zlib none zlib@openssh.com], algorithms(compression: "zlib", append_all_supported_algorithms: true)[:compression]
    end

    def test_constructor_with_multiple_preferred_compression_should_put_all_preferred_compression_first
      assert_equal %w[zlib@openssh.com zlib none], algorithms(compression: %w[zlib@openssh.com zlib],
                                                              append_all_supported_algorithms: true)[:compression]
    end

    def test_constructor_with_general_preferred_compression_should_put_none_last
      assert_equal %w[zlib@openssh.com zlib none], algorithms(
        compression: true, append_all_supported_algorithms: true
      )[:compression]
    end

    def test_constructor_with_unrecognized_compression_should_return_whats_supported
      assert_equal %w[none zlib zlib@openssh.com], algorithms(compression: %w[bogus none zlib], append_all_supported_algorithms: true)[:compression]
    end

    def test_constructor_with_host_key_append_to_default
      default_host_keys = Net::SSH::Transport::Algorithms::ALGORITHMS[:host_key]
      assert_equal default_host_keys, algorithms(host_key: '+ssh-dss')[:host_key]
    end

    def test_constructor_with_host_key_removals_with_wildcard
      assert_equal ed_host_keys + %w[ecdsa-sha2-nistp521-cert-v01@openssh.com ecdsa-sha2-nistp384-cert-v01@openssh.com ecdsa-sha2-nistp256-cert-v01@openssh.com ecdsa-sha2-nistp521 ecdsa-sha2-nistp384 ecdsa-sha2-nistp256], algorithms(host_key: %w[-ssh-rsa* -ssh-dss -rsa-sha*])[:host_key]
    end

    def test_initial_state_should_be_neither_pending_nor_initialized
      assert !algorithms.pending?
      assert !algorithms.initialized?
    end

    def test_key_exchange_when_initiated_by_server
      transport.expect do |_t, buffer|
        assert_kexinit(buffer)
        install_mock_key_exchange(buffer)
      end

      install_mock_algorithm_lookups
      algorithms.accept_kexinit(kexinit)

      assert_exchange_results
    end

    def test_key_exchange_when_initiated_by_client
      state = nil
      transport.expect do |_t, buffer|
        assert_kexinit(buffer)
        state = :sent_kexinit
        install_mock_key_exchange(buffer)
      end

      algorithms.rekey!
      assert_equal state, :sent_kexinit
      assert algorithms.pending?

      install_mock_algorithm_lookups
      algorithms.accept_kexinit(kexinit)

      assert_exchange_results
    end

    def test_key_exchange_when_server_does_not_support_preferred_kex_should_fallback_to_secondary
      kexinit kex: "diffie-hellman-group14-sha1"
      transport.expect do |_t, buffer|
        assert_kexinit(buffer)
        install_mock_key_exchange(buffer, kex: Net::SSH::Transport::Kex::DiffieHellmanGroup1SHA1)
      end
      algorithms.accept_kexinit(kexinit)
    end

    def test_key_exchange_when_server_does_not_support_any_preferred_kex_should_raise_error
      kexinit kex: "something-obscure"
      transport.expect { |_t, buffer| assert_kexinit(buffer) }
      assert_raises(Net::SSH::Exception) { algorithms.accept_kexinit(kexinit) }
    end

    def test_allow_when_not_pending_should_be_true_for_all_packets
      (0..255).each do |type|
        packet = stub("packet", type: type)
        assert algorithms.allow?(packet), type.to_s
      end
    end

    def test_allow_when_pending_should_be_true_only_for_packets_valid_during_key_exchange
      transport.expect!
      algorithms.rekey!
      assert algorithms.pending?

      (0..255).each do |type|
        packet = stub("packet", type: type)
        case type
        when 1..4, 6..19, 21..49 then assert(algorithms.allow?(packet), "#{type} should be allowed during key exchange")
        else assert(!algorithms.allow?(packet), "#{type} should not be allowed during key exchange")
        end
      end
    end

    def test_exchange_with_zlib_compression_enabled_sets_compression_to_standard
      algorithms compression: 'zlib'

      transport.expect do |_t, buffer|
        assert_kexinit(buffer, compression_client: 'zlib', compression_server: 'zlib')
        install_mock_key_exchange(buffer)
      end

      install_mock_algorithm_lookups
      algorithms.accept_kexinit(kexinit)

      assert_equal :standard, transport.client_options[:compression]
      assert_equal :standard, transport.server_options[:compression]
    end

    def test_exchange_with_zlib_at_openssh_dot_com_compression_enabled_sets_compression_to_delayed
      algorithms compression: 'zlib@openssh.com'

      transport.expect do |_t, buffer|
        assert_kexinit(buffer, compression_client: 'zlib@openssh.com', compression_server: 'zlib@openssh.com')
        install_mock_key_exchange(buffer)
      end

      install_mock_algorithm_lookups
      algorithms.accept_kexinit(kexinit)

      assert_equal :delayed, transport.client_options[:compression]
      assert_equal :delayed, transport.server_options[:compression]
    end

    # Verification for https://github.com/net-ssh/net-ssh/issues/483
    def test_that_algorithm_undefined_doesnt_throw_exception
      # Create a logger explicitly with DEBUG logging
      string_io = StringIO.new(String.new)
      debug_logger = Logger.new(string_io)
      debug_logger.level = Logger::DEBUG

      # Create our algorithm instance, with our logger sent to the underlying transport instance
      alg = algorithms(
        {},
        logger: debug_logger
      )

      # Here are our two lists - "ours" and "theirs"
      #
      # [a,b] overlap
      # [d]   "unsupported" values
      ours = %w[a b c]
      theirs = %w[a b d]

      ## Hit the method directly
      alg.send(
        :compose_algorithm_list,
        ours,
        theirs
      )

      assert string_io.string.include?(%(unsupported algorithm: `["d"]'))
    end

    def test_host_key_format
      algorithm_types = %w[
        ssh-rsa ssh-dss ecdsa-sha2-nistp256 ecdsa-sha2-nistp384 ecdsa-sha2-nistp521
      ]

      algorithm_types
        .map { |t| [t, [0, 1].map { |n| "#{t}-cert-v0#{n}@openssh.com" }.push(t)] }
        .each do |type, host_keys|
          host_keys.each do |hk|
            algorithms(host_key: hk).instance_eval { @host_key = hk }
            assert_equal type, algorithms.host_key_format
          end
        end
    end

    private

    def install_mock_key_exchange(buffer, options = {})
      kex = options[:kex] || Net::SSH::Transport::Kex::DiffieHellmanGroupExchangeSHA256

      Net::SSH::Transport::Kex::MAP.each do |_name, klass|
        next if klass == kex

        klass.expects(:new).never
      end

      kex.expects(:new)
         .with(algorithms, transport,
               client_version_string: Net::SSH::Transport::ServerVersion::PROTO_VERSION,
               server_version_string: transport.server_version.version,
               server_algorithm_packet: kexinit.to_s,
               client_algorithm_packet: buffer.to_s,
               need_bytes: 32,
               minimum_dh_bits: nil,
               logger: nil)
         .returns(stub("kex", exchange_keys: { shared_secret: shared_secret, session_id: session_id, hashing_algorithm: hashing_algorithm }))
    end

    def install_mock_algorithm_lookups(options = {})
      params = { shared: shared_secret.to_ssh, hash: session_id, digester: hashing_algorithm }
      Net::SSH::Transport::CipherFactory.expects(:get)
                                        .with(options[:client_cipher] || "aes256-ctr", params.merge(iv: key("A"), key: key("C"), encrypt: true))
                                        .returns(:client_cipher)

      Net::SSH::Transport::CipherFactory.expects(:get)
                                        .with(options[:server_cipher] || "aes256-ctr", params.merge(iv: key("B"), key: key("D"), decrypt: true))
                                        .returns(:server_cipher)

      Net::SSH::Transport::HMAC.expects(:get).with(options[:client_hmac] || "hmac-sha2-256", key("E"), params).returns(:client_hmac)
      Net::SSH::Transport::HMAC.expects(:get).with(options[:server_hmac] || "hmac-sha2-256", key("F"), params).returns(:server_hmac)
    end

    def shared_secret
      @shared_secret ||= OpenSSL::BN.new("1234567890", 10)
    end

    def session_id
      @session_id ||= "this is the session id"
    end

    def hashing_algorithm
      OpenSSL::Digest::SHA1
    end

    def key(salt)
      hashing_algorithm.digest(shared_secret.to_ssh + session_id + salt + session_id)
    end

    def cipher(type, options = {})
      Net::SSH::Transport::CipherFactory.get(type, options)
    end

    def kexinit(options = {})
      @kexinit ||= P(:byte, KEXINIT,
                     :long, rand(0xFFFFFFFF), :long, rand(0xFFFFFFFF), :long, rand(0xFFFFFFFF), :long, rand(0xFFFFFFFF),
                     :string, options[:kex] || "diffie-hellman-group-exchange-sha256,diffie-hellman-group-exchange-sha1,diffie-hellman-group14-sha256,diffie-hellman-group14-sha1,diffie-hellman-group1-sha1",
                     :string, options[:host_key] || "ssh-rsa,ssh-dss",
                     :string, options[:encryption_client] || "aes256-ctr,aes128-cbc,3des-cbc,blowfish-cbc,cast128-cbc,aes192-cbc,aes256-cbc,rijndael-cbc@lysator.liu.se,idea-cbc",
                     :string, options[:encryption_server] || "aes256-ctr,aes128-cbc,3des-cbc,blowfish-cbc,cast128-cbc,aes192-cbc,aes256-cbc,rijndael-cbc@lysator.liu.se,idea-cbc",
                     :string, options[:hmac_client] || "hmac-sha2-256,hmac-sha1,hmac-md5,hmac-sha1-96,hmac-md5-96",
                     :string, options[:hmac_server] || "hmac-sha2-256,hmac-sha1,hmac-md5,hmac-sha1-96,hmac-md5-96",
                     :string, options[:compression_client] || "none,zlib@openssh.com,zlib",
                     :string, options[:compression_server] || "none,zlib@openssh.com,zlib",
                     :string, options[:language_client] || "",
                     :string, options[:language_server] || "",
                     :bool, options[:first_kex_follows])
    end

    def assert_kexinit(buffer, options = {})
      assert_equal KEXINIT, buffer.type
      assert_equal 16, buffer.read(16).length
      assert_equal options[:kex] || (x25519_kex + ec_kex + %w[diffie-hellman-group-exchange-sha256 diffie-hellman-group14-sha256 diffie-hellman-group14-sha1]).join(','), buffer.read_string
      assert_equal options[:host_key] || (ed_ec_host_keys + %w[ssh-rsa-cert-v01@openssh.com ssh-rsa-cert-v00@openssh.com ssh-rsa rsa-sha2-256 rsa-sha2-512]).join(','), buffer.read_string
      assert_equal options[:encryption_client] || 'aes256-ctr,aes192-ctr,aes128-ctr', buffer.read_string
      assert_equal options[:encryption_server] || 'aes256-ctr,aes192-ctr,aes128-ctr', buffer.read_string
      assert_equal options[:hmac_client] || 'hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,hmac-sha1', buffer.read_string
      assert_equal options[:hmac_server] || 'hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,hmac-sha1', buffer.read_string
      assert_equal options[:compression_client] || 'none,zlib@openssh.com,zlib', buffer.read_string
      assert_equal options[:compression_server] || 'none,zlib@openssh.com,zlib', buffer.read_string
      assert_equal options[:language_client] || '', buffer.read_string
      assert_equal options[:language_server] || '', buffer.read_string
      assert_equal options[:first_kex_follows] || false, buffer.read_bool
    end

    def assert_exchange_results
      assert algorithms.initialized?
      assert !algorithms.pending?
      assert !transport.client_options[:compression]
      assert !transport.server_options[:compression]
      assert_equal :client_cipher, transport.client_options[:cipher]
      assert_equal :server_cipher, transport.server_options[:cipher]
      assert_equal :client_hmac, transport.client_options[:hmac]
      assert_equal :server_hmac, transport.server_options[:hmac]
    end

    def algorithms(algorithms_options = {}, transport_options = {})
      @algorithms ||= Net::SSH::Transport::Algorithms.new(
        transport(transport_options),
        algorithms_options
      )
    end

    def transport(transport_options = {})
      @transport ||= MockTransport.new(
        {
          user_known_hosts_file: '/dev/null',
          global_known_hosts_file: '/dev/null'
        }.merge(transport_options)
      )
    end
  end
end
