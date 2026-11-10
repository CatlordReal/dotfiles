#!/usr/bin/env python3
"""Bounded read-only condition waits, as a CLI or MCP stdio tool."""
import argparse
import json
import math
import os
from pathlib import Path
import stat
import sys
import threading
import time

MAX_BYTES = 65536


def json_equal(left, right):
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(json_equal(left[key], right[key]) for key in left)
    if isinstance(left, list):
        return len(left) == len(right) and all(json_equal(a, b) for a, b in zip(left, right))
    return left == right


SCHEMA = {"type": "object", "additionalProperties": False,
          "required": ["path", "mode", "timeout_seconds"], "properties": {
    "path": {"type": "string", "description": "Authorized absolute status-file path"},
    "mode": {"enum": ["exists", "changed", "json_equals"]},
    "keys": {"type": "array", "items": {"type": "string"}},
    "expected": {},
    "timeout_seconds": {"type": "number", "minimum": 0, "maximum": 3600},
    "interval_seconds": {"type": "number", "minimum": 0.1, "maximum": 60}}}


def wait_for_file(arguments, cancel=None):
    cancel = cancel or threading.Event()
    if set(arguments) - set(SCHEMA['properties']):
        raise ValueError('Unknown argument')
    path = Path(arguments['path'])
    mode = arguments['mode']
    timeout = arguments['timeout_seconds']
    interval = arguments.get('interval_seconds', 2)
    for value, low, high in ((timeout, 0, 3600), (interval, 0.1, 60)):
        if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not low <= value <= high:
            raise ValueError('Invalid timing argument')
    keys = arguments.get('keys', [])
    if not path.is_absolute() or mode not in ('exists', 'changed', 'json_equals'):
        raise ValueError('Invalid path or mode')
    if not isinstance(keys, list) or any(not isinstance(key, str) for key in keys):
        raise ValueError('Keys must be object-key strings')
    if mode == 'json_equals' and 'expected' not in arguments:
        raise ValueError('json_equals requires expected')

    def observe():
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
        except FileNotFoundError:
            return None, False
        with os.fdopen(fd, 'rb') as stream:
            info = os.fstat(stream.fileno())
            if not stat.S_ISREG(info.st_mode):
                raise ValueError('Condition target must be a regular file')
            fingerprint = (info.st_dev, info.st_ino, info.st_mtime_ns, info.st_size)
            if mode != 'json_equals':
                return fingerprint, True
            if info.st_size > MAX_BYTES:
                raise ValueError('JSON status file exceeds 64 KiB')
            raw = stream.read(MAX_BYTES + 1)
            if len(raw) > MAX_BYTES:
                raise ValueError('JSON status file exceeds 64 KiB')
            try:
                value = json.loads(raw)
            except (ValueError, UnicodeError):
                return fingerprint, False
            for key in keys:
                if not isinstance(value, dict) or key not in value:
                    return fingerprint, False
                value = value[key]
            # JSON booleans and numbers must not compare equal accidentally.
            expected = arguments['expected']
            return fingerprint, json_equal(value, expected)

    started = time.monotonic()
    baseline = None
    first = True
    while True:
        if cancel.is_set():
            reason = 'cancelled'
            break
        if not first and time.monotonic() - started >= timeout:
            reason = 'timeout'
            break
        current, matches = observe()
        if first:
            baseline, first = current, False
        if (mode == 'changed' and current != baseline) or (mode != 'changed' and matches):
            reason = 'matched'
            break
        remaining = timeout - (time.monotonic() - started)
        if remaining <= 0:
            reason = 'timeout'
            break
        cancel.wait(min(interval, remaining))
    return {'reason': reason, 'elapsed_seconds': round(time.monotonic() - started, 3)}


def serve():
    output_lock = threading.Lock()
    active_lock = threading.Lock()
    active = {}

    def send(message):
        with output_lock:
            print(json.dumps(message), flush=True)

    def result(ident, value):
        send({'jsonrpc': '2.0', 'id': ident, 'result': value})

    def call(ident, params, cancel):
        try:
            if params.get('name') != 'wait_for_file':
                raise ValueError('Unknown tool')
            value = wait_for_file(params.get('arguments', {}), cancel)
            result(ident, {'content': [{'type': 'text', 'text': json.dumps(value)}], 'isError': False})
        except Exception as error:
            # Never return exception messages containing paths or file data.
            result(ident, {'content': [{'type': 'text', 'text': 'Condition wait failed: ' + type(error).__name__}], 'isError': True})
        finally:
            with active_lock:
                active.pop(ident, None)

    try:
        for line in sys.stdin:
            try:
                message = json.loads(line)
                ident, method = message.get('id'), message.get('method')
                params = message.get('params', {})
                if method == 'notifications/cancelled':
                    with active_lock:
                        event = active.get(params.get('requestId'))
                    if event:
                        event.set()
                elif ident is None:
                    continue
                elif method == 'initialize':
                    result(ident, {'protocolVersion': '2024-11-05', 'capabilities': {'tools': {}},
                                   'serverInfo': {'name': 'condition-wait', 'version': '1.0.0'}})
                elif method == 'ping':
                    result(ident, {})
                elif method == 'tools/list':
                    result(ident, {'tools': [{'name': 'wait_for_file',
                        'description': 'Wait without AI polling until an authorized local file condition matches or timeout. Does not wake an ended chat.',
                        'inputSchema': SCHEMA, 'annotations': {'readOnlyHint': True, 'openWorldHint': False}}]})
                elif method == 'tools/call':
                    with active_lock:
                        if ident in active or len(active) >= 8:
                            send({'jsonrpc': '2.0', 'id': ident, 'error': {'code': -32600, 'message': 'Duplicate request or wait limit reached'}})
                            continue
                        cancel = threading.Event()
                        active[ident] = cancel
                    threading.Thread(target=call, args=(ident, params, cancel), daemon=True).start()
                else:
                    send({'jsonrpc': '2.0', 'id': ident, 'error': {'code': -32601, 'message': 'Method not found'}})
            except (ValueError, TypeError, AttributeError):
                send({'jsonrpc': '2.0', 'id': None, 'error': {'code': -32700, 'message': 'Invalid request'}})
    finally:
        with active_lock:
            for event in active.values():
                event.set()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mcp', action='store_true')
    parser.add_argument('--path')
    parser.add_argument('--mode', choices=['exists', 'changed', 'json_equals'], default='exists')
    parser.add_argument('--timeout-seconds', type=float, default=60)
    parser.add_argument('--interval-seconds', type=float, default=2)
    parser.add_argument('--keys', type=json.loads, default=[])
    parser.add_argument('--expected', type=json.loads, default=argparse.SUPPRESS)
    options = parser.parse_args()
    if options.mcp:
        serve()
    else:
        if not options.path:
            parser.error('--path is required')
        try:
            value = wait_for_file({k: v for k, v in vars(options).items() if k != 'mcp'})
            print(json.dumps(value))
            sys.exit(0 if value['reason'] == 'matched' else 1)
        except Exception as error:
            print('Condition wait failed: ' + type(error).__name__, file=sys.stderr)
            sys.exit(2)
