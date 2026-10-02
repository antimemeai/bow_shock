#!/usr/bin/python3
"""Owned synthetic stdio peer for the native join; never certifies inference."""
import json
import os
from pathlib import Path
import sys
import time

if sys.argv[1:] == ['--version']:
    print('codex-cli 0.160.0', flush=True)
    raise SystemExit(0)
assert sys.argv[1:4] == ['app-server', '--stdio', '--strict-config']
base = Path(sys.argv[0]).resolve().parent
with (base / 'peer-pids').open('a') as stream:
    stream.write(str(os.getpid()) + '\n')
thread = 'owned-thread-' + str(os.getpid())
turn = 'owned-turn-' + str(os.getpid())


def emit(value):
    if 'method' in value and 'id' not in value:
        value['emittedAtMs'] = 1
    print(json.dumps(value, separators=(',', ':')), flush=True)


for line in sys.stdin:
    request = json.loads(line)
    method = request['method']
    if method == 'initialized':
        continue
    if method == 'initialize':
        value = {'userAgent': 'owned-native-fixture', 'platformFamily': 'unix',
                 'platformOs': 'macos', 'codexHome': os.environ['CODEX_HOME']}
    elif method == 'account/read':
        value = {'requiresOpenaiAuth': True, 'account': {'type': 'chatgpt', 'email': None, 'planType': 'pro'},
                 'workspaceRouting': {'chatgptAccountId': 'owned-fixture-account',
                                      'backendOrigin': 'https://chatgpt.com', 'accountRoutingOverride': 'NO_CONSTRAINT'}}
    elif method == 'account/rateLimits/read':
        value = {'accountId': 'owned-fixture-account', 'rateLimits': {}}
    elif method == 'thread/start':
        p = request['params']
        assert p['model'] == 'fixture-model' and p['sandbox'] == 'read-only' and p['ephemeral'] is True
        assert p['cwd'] == str(base) and p['approvalPolicy'] == 'never' and p['approvalsReviewer'] == 'user'
        value = {'model': 'fixture-model', 'modelProvider': 'openai', 'cwd': str(base),
                 'approvalPolicy': 'never', 'approvalsReviewer': 'user', 'sandbox': {'type': 'readOnly', 'networkAccess': False},
                 'runtimeWorkspaceRoots': [str(base)], 'activePermissionProfile': None, 'multiAgentMode': 'explicitRequestOnly',
                 'thread': {'id': thread, 'ephemeral': True, 'cliVersion': '0.160.0', 'turns': []}}
        for status in ('starting', 'ready'):
            emit({'method': 'mcpServer/startupStatus/updated', 'params': {
                'threadId': thread, 'name': 'owned-fixture-server', 'status': status,
                'error': None, 'failureReason': None}})
        if (base / 'peer-control-loss-mode').exists():
            (base / 'peer-before-export').write_text(str(os.getpid()))
            while True:
                time.sleep(.01)
    elif method == 'turn/start':
        p = request['params']
        assert p['threadId'] == thread
        prompt = json.loads(p['input'][0]['text'])
        evidence = prompt['page_evidence']
        assert [f['candidate_id'] for f in evidence] == ['r0f0', 'r0f1']
        assert [f['field']['name'] for f in evidence] == ['name', 'price']
        assert 'BS_PRIVATE_MARKER' not in json.dumps(prompt)
        staged_export = base / 'peer-export.tmp'
        staged_export.write_text(json.dumps(prompt, indent=2))
        staged_export.replace(base / 'peer-export.json')
        if (base / 'peer-stop-mode').exists():
            while True:
                time.sleep(.01)
        scope = {'threadId': thread, 'turnId': turn, 'itemId': 'owned-reasoning'}
        emit({'method': 'mcpServer/startupStatus/updated', 'params': {
            'threadId': thread, 'name': 'owned-fixture-server', 'status': 'failed',
            'error': 'IGNORED_MCP_MARKER', 'failureReason': 'reauthenticationRequired'}})
        emit({'method': 'item/reasoning/summaryPartAdded', 'params': {**scope, 'summaryIndex': 0}})
        emit({'method': 'item/reasoning/summaryTextDelta',
              'params': {**scope, 'summaryIndex': 0, 'delta': 'IGNORED_REASONING_MARKER'}})
        emit({'method': 'item/reasoning/textDelta',
              'params': {**scope, 'contentIndex': 0, 'delta': 'IGNORED_REASONING_MARKER'}})
        text = json.dumps({'request_id': prompt['request_id'], 'candidate_ids': ['r0f0', 'r0f1'],
                           'no_match': False, 'explanation': 'Use the two supplied literal fields.'})
        item = {'type': 'agentMessage', 'id': 'owned-final', 'text': text, 'phase': 'final_answer'}
        # Exercise genuine protocol ordering: actual pipe events precede ACK.
        emit({'method': 'item/completed', 'params': {'threadId': thread, 'turnId': turn,
                                                    'completedAtMs': 1, 'item': item}})
        emit({'method': 'turn/completed', 'params': {'threadId': thread,
             'turn': {'id': turn, 'status': 'completed', 'error': None, 'items': [item], 'itemsView': 'summary'}}})
        emit({'id': request['id'], 'result': {'turn': {'id': turn, 'status': 'inProgress', 'items': []}}})
        continue
    else:
        raise AssertionError(method)
    emit({'id': request['id'], 'result': value})
