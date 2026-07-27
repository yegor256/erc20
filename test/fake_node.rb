# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2025 Yegor Bugayenko
# SPDX-License-Identifier: MIT

require 'em-websocket'
require 'json'
require_relative '../lib/erc20/erc20'

# A fake Ethereum node with Websockets, to be started by tests as
# +ruby fake_node.rb <port> <replies.json> <received.txt>+.
#
# It listens to the given TCP port and answers incoming JSON messages with
# pre-canned ones: the first message of a connection gets the first group of
# replies, the second one gets the second group, and so on. When the groups
# are exhausted, the node stays silent. Every message that arrives is
# appended to the given file, one per line.
class ERC20::FakeNode
  def initialize(port, replies, received)
    @port = port
    @replies = replies
    @received = received
  end

  def start
    EventMachine.run do
      EventMachine::WebSocket.run(host: '127.0.0.1', port: @port) do |ws|
        seen = 0
        ws.onmessage do |msg|
          File.open(@received, 'a') { |f| f.puts(msg) }
          (@replies[seen] || []).each do |reply|
            # rubocop:disable Style/Send
            ws.send(JSON.dump(reply))
            # rubocop:enable Style/Send
          end
          seen += 1
        end
      end
    end
  end
end

ERC20::FakeNode.new(Integer(ARGV[0]), JSON.parse(File.read(ARGV[1])), ARGV[2]).start
