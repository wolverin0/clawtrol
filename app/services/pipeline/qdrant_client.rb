# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Pipeline
  class QdrantClient
    QDRANT_URL = ENV.fetch("QDRANT_URL", "http://192.168.100.186:6333")
    OLLAMA_URL = ENV.fetch("OLLAMA_URL", "http://192.168.100.155:11434")
    EMBEDDING_MODEL = ENV.fetch("EMBEDDING_MODEL", "qwen3-embedding:8b")
    COLLECTION_NAME = ENV.fetch("QDRANT_COLLECTION", "clawdeck")

    TIMEOUT = 10

    def search(query_text, limit: 5)
      embedding = generate_embedding(query_text)
      return [] unless embedding

      search_qdrant(embedding, limit: limit)
    rescue StandardError => e
      Rails.logger.warn("[Pipeline::QdrantClient] search failed: #{e.class}: #{e.message}")
      []
    end

    private

    def generate_embedding(text)
      uri = URI.parse("#{OLLAMA_URL}/api/embed")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      req = Net::HTTP::Post.new(uri.path, { "Content-Type" => "application/json" })
      req.body = { model: EMBEDDING_MODEL, input: text.truncate(500) }.to_json

      res = http.request(req)
      return nil unless res.code.to_i == 200

      data = JSON.parse(res.body)
      embeddings = data["embeddings"] || data["embedding"]
      embeddings.is_a?(Array) ? embeddings.first : embeddings
    rescue StandardError => e
      Rails.logger.warn("[Pipeline::QdrantClient] embedding failed: #{e.class}: #{e.message}")
      nil
    end

    def search_qdrant(embedding, limit:)
      uri = URI.parse("#{QDRANT_URL}/collections/#{COLLECTION_NAME}/points/search")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      req = Net::HTTP::Post.new(uri.path, { "Content-Type" => "application/json" })
      req.body = {
        vector: embedding,
        limit: limit,
        with_payload: true
      }.to_json

      res = http.request(req)
      return [] unless res.code.to_i == 200

      data = JSON.parse(res.body)
      results = data["result"] || []

      results.map do |r|
        payload = r["payload"] || {}
        {
          score: r["score"],
          content: payload["content"] || payload["text"],
          source: payload["source"] || payload["file"],
          project: payload["project"]
        }
      end
    rescue StandardError => e
      Rails.logger.warn("[Pipeline::QdrantClient] qdrant search failed: #{e.class}: #{e.message}")
      []
    end
  end
end
