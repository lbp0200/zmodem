import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zmodem_lbp/zmodem.dart';
import 'package:zmodem_lbp/src/zmodem_frame.dart';
import 'package:zmodem_lbp/src/zmodem_parser.dart';

const _seeds = 100;
const _maxPackets = 50000;
const _maxDataSize = 65536;

void main() {
  group('Fuzz Parser bulk', () {
    for (var seed = 0; seed < _seeds; seed++) {
      test('seed $seed', () => fuzzParserBulk(seed),
          timeout: _timeout);
    }
  });

  group('Fuzz Parser byte-by-byte', () {
    for (var seed = 0; seed < _seeds; seed++) {
      test('seed $seed', () => fuzzParserByteByByte(seed),
          timeout: _timeout);
    }
  });

  group('Fuzz Core isolated', () {
    for (var seed = 0; seed < _seeds; seed++) {
      test('seed $seed', () => fuzzCoreIsolated(seed),
          timeout: _timeout);
    }
  });

  group('Fuzz Core live session', () {
    test('with random trailing data', () => fuzzCoreLive(),
        timeout: _timeout, retry: 3);
  });
}

final _timeout = Timeout(Duration(seconds: 10));

void fuzzParserBulk(int seed) {
  final random = Random(seed);
  final data = randomBytes(random);

  final parser = ZModemParser();
  parser.addData(data);
  drainParser(parser);
  expect(parser.moveNext(), isFalse);
}

void fuzzParserByteByByte(int seed) {
  final random = Random(seed);
  final data = randomBytes(random);

  final parser = ZModemParser();

  for (var i = 0; i < data.length; i++) {
    parser.addData(Uint8List.fromList([data[i]]));
    drainParser(parser);
  }

  expect(parser.moveNext(), isFalse);
}

void fuzzCoreIsolated(int seed) {
  final random = Random(seed);
  final data = randomBytes(random);

  final core = ZModemCore();
  final events = core.receive(data).toList();

  // All yielded events must be well-formed
  for (final event in events) {
    if (event is ZFileOfferedEvent) {
      event.fileInfo.pathname; // must not throw
    } else if (event is ZFileDataEvent) {
      event.data; // must not throw
    }
  }

  // Core must still be functional after random data
  expect(core.hasDataToSend, isFalse);
  core.finishSession();
  expect(core.hasDataToSend, isTrue);
}

void fuzzCoreLive() {
  final random = Random(42);
  final server = ZModemCore();
  final client = ZModemCore();

  // Normal handshake
  server.initiateSend();
  client.receive(server.dataToSend()).toList();
  server.receive(client.dataToSend()).toList();
  server.offerFile(ZModemFileInfo(pathname: 'fuzz', length: 100));
  final events = client.receive(server.dataToSend()).toList();

  if (events.whereType<ZFileOfferedEvent>().isEmpty) return;

  client.acceptFile();
  server.receive(client.dataToSend()).toList();

  // Send file data then fuzz the response
  server.sendFileData(randomBytes(random, 256));
  final rawFuzz = server.dataToSend();
  client.receive(rawFuzz).toList();

  // Finish sending and consume
  final offset = random.nextInt(1000);
  server.finishSending(offset);
  client.receive(server.dataToSend()).toList();

  // Clean shutdown
  server.finishSession();
  client.receive(server.dataToSend()).toList();
}

Uint8List randomBytes(Random random, [int? maxSize]) {
  final size = random.nextInt((maxSize ?? _maxDataSize) + 1);
  final bytes = Uint8List(size);
  for (var i = 0; i < size; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

void drainParser(ZModemParser parser) {
  var count = 0;
  while (parser.moveNext()) {
    if (++count >= _maxPackets) {
      throw StateError('Infinite loop: exceeded $_maxPackets packets');
    }
    final packet = parser.current;
    if (packet is ZModemHeader) {
      packet.type;
      packet.p0;
      packet.p1;
      packet.p2;
      packet.p3;
    } else if (packet is ZModemDataPacket) {
      packet.type;
      packet.data.length;
    }
  }
}
