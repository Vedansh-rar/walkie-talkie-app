// Walkie-Talkie Intercom relay.
//
// This is deliberately dumb: it has no idea what a "channel" or a
// "participant" is in any human sense. It only knows how to read a few
// fixed-position fields out of the same binary packet format the app uses
// locally (see lib/protocol/packet.dart), and forward bytes between the
// sockets that share a channel tag. All the actual intercom logic (who's
// online, who's talking, presence timeouts) lives in the Dart client,
// exactly like it does for the WiFi transport — this server just replaces
// "the local WiFi network" with "the internet" as the thing that carries
// packets between phones that can't reach each other directly.
//
// Wire format for messages a client SENDS to this server (not used for
// messages the server sends out — see below):
//   [0]      routing marker: 0x00 = broadcast, 0x01 = targeted ("whisper")
//   [1..8]   target sender id (8 ASCII bytes) — only present if marker is 0x01
//   [..]     the packet bytes, exactly as Packet.encode() produces them
//
// Messages this server SENDS to clients are always bare packet bytes (the
// envelope above is stripped), so the receiving app's normal packet
// decoder handles them with no special casing.
//
// Packet header (see packet.dart for the authoritative definition):
//   [0]      packet type
//   [1..4]   channel tag, uint32 little-endian
//   [5..12]  sender id, 8 ASCII bytes
//   [13..]   payload
//
// Run locally:   npm install && node server.js
// Deploy: see ../README.md's "Deploy the relay" section.
'use strict';

const { WebSocketServer, WebSocket } = require('ws');

const PORT = process.env.PORT || 8080;
const PACKET_HEADER_LENGTH = 13;

const wss = new WebSocketServer({ port: PORT });

function readChannelTag(packetBytes) {
  // uint32 little-endian at byte offset 1.
  return (
    packetBytes[1] |
    (packetBytes[2] << 8) |
    (packetBytes[3] << 16) |
    (packetBytes[4] << 24)
  ) >>> 0;
}

function readSenderId(packetBytes) {
  return packetBytes.toString('ascii', 5, 13);
}

function makeByePacket(channelTag, senderId) {
  const buf = Buffer.alloc(PACKET_HEADER_LENGTH);
  buf[0] = 2; // PacketType.bye, see packet.dart
  buf.writeUInt32LE(channelTag, 1);
  buf.write(senderId, 5, 8, 'ascii');
  return buf;
}

function forward(fromWs, channelTag, targetSenderId, packetBytes) {
  for (const client of wss.clients) {
    if (client === fromWs) continue;
    if (client.readyState !== WebSocket.OPEN) continue;
    if (client.channelTag !== channelTag) continue;
    if (targetSenderId !== null && client.senderId !== targetSenderId) continue;
    client.send(packetBytes);
  }
}

wss.on('connection', (ws) => {
  ws.channelTag = null;
  ws.senderId = null;

  ws.on('message', (data) => {
    if (!Buffer.isBuffer(data) || data.length < 1) return;

    const marker = data[0];
    let packetBytes;
    let targetSenderId = null;

    if (marker === 0x01) {
      if (data.length < 1 + 8 + PACKET_HEADER_LENGTH) return;
      targetSenderId = data.toString('ascii', 1, 9);
      packetBytes = data.subarray(9);
    } else {
      if (data.length < 1 + PACKET_HEADER_LENGTH) return;
      packetBytes = data.subarray(1);
    }

    ws.channelTag = readChannelTag(packetBytes);
    ws.senderId = readSenderId(packetBytes);

    forward(ws, ws.channelTag, targetSenderId, packetBytes);
  });

  ws.on('close', () => {
    if (ws.channelTag !== null && ws.senderId !== null) {
      forward(ws, ws.channelTag, null, makeByePacket(ws.channelTag, ws.senderId));
    }
  });

  ws.on('error', () => {
    // 'close' fires after 'error' for the same socket, so cleanup still
    // happens there — nothing extra to do here.
  });
});

console.log(`Walkie-Talkie relay listening on port ${PORT}`);
