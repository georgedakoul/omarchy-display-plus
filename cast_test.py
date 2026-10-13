#!/usr/bin/env python3
# Run: python3 cast_test.py
import importlib.machinery, os, socket, sys

sys.dont_write_bytecode = True
cast = importlib.machinery.SourceFileLoader("cast", os.path.join(os.path.dirname(__file__), "cast")).load_module()

# The Samsung TVs found nearby are sinks; our own IEs describe a source.
assert cast.is_sink([0, 0, 6, 1, 17, 28, 68, 0, 54])
assert not cast.is_sink([0, 0, 6, 0, 0x90, 0x1C, 0x44, 0, 0xC8])
assert cast.inches_of("Samsung Q60BA 55 TV") == 55 and cast.inches_of("Samsung AU7172 43 TV") == 43
assert cast.inches_of("Living room") == 0

m3 = ("wfd_video_formats: 00 00 02 10 0001FFFF 3FFFFFFF 00000FFF 00 0000 0000 11 none none, "
      "01 10 0001FFFF 3FFFFFFF 00000FFF 00 0000 0000 11 none none\r\n"
      "wfd_audio_codecs: LPCM 00000002 00, AAC 00000007 00\r\n"
      "wfd_client_rtp_ports: RTP/AVP/UDP;unicast 1028 0 mode=play\r\n")
f = cast.choose_format(cast.parse_params(m3))
assert f["video"].startswith("00 00 01 10 00000100 "), f  # constrained baseline, 1080p60
assert (f["width"], f["height"], f["fps"], f["port"], f["aac"]) == (1920, 1080, 60, 1028, True), f

# A basic 720p30 sink with LPCM only.
f = cast.choose_format(cast.parse_params(
    "wfd_video_formats: 00 00 01 01 00000021 00000000 00000000 00 0000 0000 00 none none\n"
    "wfd_audio_codecs: LPCM 00000002 00\nwfd_client_rtp_ports: RTP/AVP/UDP;unicast 19000 0 mode=play\n"))
assert (f["width"], f["fps"], f["audio"], f["port"]) == (1280, 30, "none", 19000), f

# Message framing: a request split across reads, with a body, then a reply.
a, b = socket.socketpair()
r = cast.Rtsp(a)
b.sendall(b"GET_PARAMETER rtsp://x RTSP/1.0\r\nCSeq: 2\r\nContent-Len")
b.sendall(b"gth: 5\r\n\r\nhello" + b"RTSP/1.0 200 OK\r\ncseq: 1\r\n\r\n")
assert r.read() == ("GET_PARAMETER rtsp://x RTSP/1.0", {"cseq": "2", "content-length": "5"}, "hello")
assert r.read()[0] == "RTSP/1.0 200 OK"
print("cast ok")
