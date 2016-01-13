require 'uri'
require 'yaml'

module Licensee
  class InvalidLicense < ArgumentError; end
  class License
    class << self
      # All license objects defined via Licensee (via choosealicense.com)
      #
      # Options:
      # - :hidden - boolean, return hidden licenses (default: false)
      # - :featured - boolean, return only (non)featured licenses (default: all)
      #
      # Returns an Array of License objects.
      def all(options = {})
        options = { hidden: false, featured: nil }.merge(options)
        output = licenses.dup
        output.reject!(&:hidden?) unless options[:hidden]
        return output if options[:featured].nil?
        output.select { |l| l.featured? == options[:featured] }
      end

      def keys
        @keys ||= license_files.map do |license_file|
          File.basename(license_file, '.txt').downcase
        end + ['other']
      end

      def find(key, options = {})
        options = { hidden: true }.merge(options)
        all(options).find { |license| license.key == key.downcase }
      end
      alias_method :[], :find
      alias_method :find_by_key, :find

      def license_dir
        dir = File.dirname(__FILE__)
        File.expand_path '../../vendor/choosealicense.com/_licenses', dir
      end

      def license_files
        @license_files ||= Dir.glob("#{license_dir}/*.txt")
      end

      private

      def licenses
        @licenses ||= keys.map { |key| new(key) }
      end
    end

    attr_reader :key

    YAML_DEFAULTS = {
      'featured' => false,
      'hidden'   => false,
      'variant'  => false
    }.freeze

    HIDDEN_LICENSES = %w(other no-license).freeze

    include Licensee::ContentHelper

    def initialize(key)
      @key = key.downcase
    end

    # Path to vendored license file on disk
    def path
      @path ||= File.expand_path "#{@key}.txt", Licensee::License.license_dir
    end

    # License metadata from YAML front matter
    def meta
      @meta ||= if parts && parts[1]
        meta = if YAML.respond_to? :safe_load
          YAML.safe_load(parts[1])
        else
          YAML.load(parts[1])
        end
        YAML_DEFAULTS.merge(meta)
      end
    end

    # Returns the human-readable license name
    def name
      meta.nil? ? key.capitalize : meta['title']
    end

    def nickname
      meta['nickname'] if meta
    end

    def name_without_version
      /(.+?)(( v?\d\.\d)|$)/.match(name)[1]
    end

    def featured?
      return YAML_DEFAULTS['featured'] unless meta
      meta['featured']
    end
    alias_method :featured, :featured?

    def hidden?
      return true if HIDDEN_LICENSES.include?(key)
      return YAML_DEFAULTS['hidden'] unless meta
      meta['hidden']
    end

    # The license body (e.g., contents - frontmatter)
    def content
      @content ||= parts[2] if parts && parts[2]
    end
    alias_method :to_s, :content
    alias_method :text, :content
    alias_method :body, :content

    def url
      URI.join(Licensee::DOMAIN, "/licenses/#{key}/").to_s
    end

    def ==(other)
      !other.nil? && key == other.key
    end

    private

    # Raw content of license file, including YAML front matter
    def raw_content
      return if key == 'other' # A pseudo-license with no content
      @raw_content ||= if File.exist?(path)
        File.open(path).read
      else
        fail Licensee::InvalidLicense, "'#{key}' is not a valid license key"
      end
    end

    def parts
      return unless raw_content
      @parts ||= raw_content.match(/\A(---\n.*\n---\n+)?(.*)/m).to_a
    end
  end
end
