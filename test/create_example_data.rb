#!/usr/bin/env ruby
# frozen_string_literal: true

require 'wikidata_position_history'

def store(id, dir, query)
  output = Pathname.new('test/example-data/') + dir + "#{id}.json"
  sparql = query.send(:sparql)
  res = QueryService::Query.new(sparql).send(:result)
  output.write res
end

id = ARGV.first or abort "Usage: #{$PROGRAM_NAME} <Qid>"
report = WikidataPositionHistory::Report.new(id).report

store(id, 'metadata', WikidataPositionHistory::SPARQL::OriginQuery.new(id))
store(id, 'mandates', report.send(:sparql))
store(id, 'biodata', report.send(:biodata_sparql))
