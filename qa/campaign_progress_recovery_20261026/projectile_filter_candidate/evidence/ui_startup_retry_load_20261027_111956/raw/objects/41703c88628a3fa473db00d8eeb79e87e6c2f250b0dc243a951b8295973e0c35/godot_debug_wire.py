"""Bounded object-free Godot 4 debugger wire codec for an owned loopback test process."""
import struct

MAX_PACKET = 8 << 20
MAX_ITEMS = 100_000
MAX_DEPTH = 32
FLAG_64 = 1 << 16


class WireError(ValueError):
    pass


def encode(value, depth=0):
    if depth > MAX_DEPTH:
        raise WireError("Variant nesting limit")
    if value is None:
        return struct.pack("<I", 0)
    if type(value) is bool:
        return struct.pack("<II", 1, int(value))
    if type(value) is int:
        if -(1 << 31) <= value < (1 << 31):
            return struct.pack("<Ii", 2, value)
        if -(1 << 63) <= value < (1 << 63):
            return struct.pack("<Iq", 2 | FLAG_64, value)
        raise WireError("Integer outside signed Godot Variant range")
    if type(value) is float:
        return struct.pack("<Id", 3 | FLAG_64, value)
    if type(value) is str:
        data = value.encode("utf-8")
        if len(data) > MAX_PACKET:
            raise WireError("String size limit")
        return struct.pack("<II", 4, len(data)) + data + b"\0" * (-len(data) % 4)
    if type(value) is list:
        if len(value) > MAX_ITEMS:
            raise WireError("Array item limit")
        return struct.pack("<II", 28, len(value)) + b"".join(encode(item, depth + 1) for item in value)
    raise WireError("Outbound debugger commands only support scalar values and untyped Arrays")


def decode(packet):
    if not 4 <= len(packet) <= MAX_PACKET:
        raise WireError("Packet size limit")
    offset = 0
    items = 0

    def take(size):
        nonlocal offset
        if size < 0 or offset + size > len(packet):
            raise WireError("Truncated Variant")
        result = packet[offset:offset + size]
        offset += size
        return result

    def integer():
        return struct.unpack("<I", take(4))[0]

    def value(depth):
        nonlocal items
        items += 1
        if depth > MAX_DEPTH or items > MAX_ITEMS:
            raise WireError("Variant structure limit")
        header = integer()
        kind, flags = header & 0xFFFF, header >> 16
        if kind == 0 and flags == 0:
            return None
        if kind == 1 and flags == 0:
            raw = integer()
            if raw not in (0, 1):
                raise WireError("Noncanonical debugger Bool")
            return bool(raw)
        if kind == 2 and flags in (0, 1):
            return struct.unpack("<q" if flags else "<i", take(8 if flags else 4))[0]
        if kind == 3 and flags in (0, 1):
            return struct.unpack("<d" if flags else "<f", take(8 if flags else 4))[0]
        if kind == 4 and flags == 0:
            size = integer()
            text = take(size).decode("utf-8", errors="strict")
            take(-size % 4)
            return text
        if kind == 28 and flags == 0:
            count = integer() & 0x7FFFFFFF
            if count > MAX_ITEMS or count * 4 > len(packet) - offset:
                raise WireError("Invalid debugger Array length")
            return [value(depth + 1) for _ in range(count)]
        if kind == 30 and flags == 0:
            count = integer()
            if count > MAX_ITEMS or count * 4 > len(packet) - offset:
                raise WireError("Invalid debugger PackedInt32Array length")
            return list(struct.unpack("<" + "i" * count, take(count * 4)))
        if kind == 34 and flags == 0:
            count = integer()
            if count > MAX_ITEMS or count * 4 > len(packet) - offset:
                raise WireError("Invalid debugger PackedStringArray length")
            output = []
            for _ in range(count):
                size = integer()
                text = take(size).decode("utf-8", errors="strict")
                take(-size % 4)
                output.append(text.removesuffix("\0"))
            return output
        raise WireError("Unsupported/identity-bearing debugger Variant header: " + str(header))

    result = value(0)
    if offset != len(packet):
        raise WireError("Trailing Variant bytes")
    return result


class DebugConnection:
    ALLOWED = {"get_stack_dump", "continue", "breakpoint"}

    def __init__(self, connection):
        if connection.getpeername()[0] != "127.0.0.1":
            raise WireError("Owned debugger connection must be loopback")
        self.connection = connection
        self.buffer = bytearray()

    def _fill(self, count):
        while len(self.buffer) < count:
            chunk = self.connection.recv(min(count - len(self.buffer), 65536))
            if not chunk:
                raise EOFError("Owned debugger connection closed")
            self.buffer.extend(chunk)

    def receive(self):
        self._fill(4)
        size = struct.unpack("<I", self.buffer[:4])[0]
        if not 4 <= size <= MAX_PACKET:
            raise WireError("Debugger packet length refused")
        self._fill(size + 4)
        packet = bytes(self.buffer[4:size + 4])
        del self.buffer[:size + 4]
        message = decode(packet)
        if type(message) is not list or len(message) != 3 or type(message[0]) is not str or type(message[1]) is not int or type(message[2]) is not list:
            raise WireError("Debugger envelope shape refused")
        return message, packet

    def command(self, name, thread_id, parameters=None):
        if name not in self.ALLOWED or type(thread_id) is not int:
            raise WireError("Debugger command refused")
        values = [] if parameters is None else parameters
        if type(values) is not list:
            raise WireError("Debugger parameters must be an Array")
        if name in {"continue", "get_stack_dump"} and values:
            raise WireError("Unexpected debugger command parameters")
        if name == "breakpoint" and not (len(values) == 3 and type(values[0]) is str and values[0].startswith("res://")
                                          and type(values[1]) is int and values[1] > 0 and type(values[2]) is bool):
            raise WireError("Breakpoint parameters refused")
        packet = encode([name, thread_id, values])
        if len(packet) > MAX_PACKET:
            raise WireError("Outbound packet limit")
        self.connection.sendall(struct.pack("<I", len(packet)) + packet)


def stack_frames(data):
    if type(data) is not list or not data or type(data[0]) is not int or data[0] < 3 or data[0] % 3 or len(data) != data[0] + 1:
        raise WireError("Debugger stack frame shape refused")
    frames = []
    for index in range(1, len(data), 3):
        source, line, function = data[index:index + 3]
        if type(source) is not str or type(line) is not int or line <= 0 or type(function) is not str:
            raise WireError("Debugger frame type refused")
        frames.append({"source": source, "line": line, "function": function})
    return frames
