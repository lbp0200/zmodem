import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:zmodem_lbp/src/zmodem_frame.dart';
import 'package:zmodem_lbp/src/zmodem_parser.dart';
import 'package:zmodem_lbp/src/consts.dart' as consts;

void main() async {
  final session1Data = await File('test/fixture/session1.bin').readAsBytes();

  group('ZModemParser', () {
    test('works', () async {
      final parser = ZModemParser();
      parser.addData(session1Data);

      checkHeader(parser, consts.ZSINIT, 0, 0, 0, 64);
      parser.expectDataSubpacket();
      checkData(parser, consts.ZCRCW, 2);
      checkHeader(parser, consts.ZFILE, 0, 0, 0, 0);
      parser.expectDataSubpacket();
      checkData(parser, consts.ZCRCW, 26);
      checkHeader(parser, consts.ZDATA, 0, 0, 0, 0);
      parser.expectDataSubpacket();
      checkData(parser, consts.ZCRCG, 107);
      parser.expectDataSubpacket();
      checkData(parser, consts.ZCRCE, 0);
      checkHeader(parser, consts.ZEOF, 107, 0, 0, 0);
      checkHeader(parser, consts.ZFIN, 0, 0, 0, 0);
    });

    test('works byte by byte', () {
      final parser = ZModemParser();

      for (final byte in session1Data) {
        parser.addData(Uint8List.fromList([byte]));
      }

      checkHeader(parser, consts.ZSINIT, 0, 0, 0, 64);
      parser.expectDataSubpacket();
      checkData(parser, consts.ZCRCW, 2);
      checkHeader(parser, consts.ZFILE, 0, 0, 0, 0);
      parser.expectDataSubpacket();
      checkData(parser, consts.ZCRCW, 26);
      checkHeader(parser, consts.ZDATA, 0, 0, 0, 0);
      parser.expectDataSubpacket();
      checkData(parser, consts.ZCRCG, 107);
      parser.expectDataSubpacket();
      checkData(parser, consts.ZCRCE, 0);
      checkHeader(parser, consts.ZEOF, 107, 0, 0, 0);
      checkHeader(parser, consts.ZFIN, 0, 0, 0, 0);
    });
  });
}

void checkHeader(
  ZModemParser parser,
  int type,
  int p0,
  int p1,
  int p2,
  int p3,
) {
  expect(parser.moveNext(), isTrue);
  final h = parser.current as ZModemHeader;
  expect(h.type, type);
  expect(h.p0, p0);
  expect(h.p1, p1);
  expect(h.p2, p2);
  expect(h.p3, p3);
}

void checkData(ZModemParser parser, int type, int length) {
  expect(parser.moveNext(), isTrue);
  final dp = parser.current as ZModemDataPacket;
  expect(dp.type, type);
  expect(dp.data.length, length);
}
