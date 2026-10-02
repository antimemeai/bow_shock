#!/usr/bin/env python3
"""Actual Foundation fixture-to-table function; no CEF/model/effects."""
import copy
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / 'context/build/table-projection-probe'
ORIGIN = 'http://127.0.0.1:8123'


def observation(price='USD 12.00'):
    ref = dict(run_id='native-table-run', surface_id='browser-1',
        attachment_generation=2, frame_id='root-frame', document_id='loader:1',
        activation_generation=1, node_generation=1, capture_id='capture-one',
        capture_start_continuous_ns=1000000000, capture_end_continuous_ns=1000000100,
        origin=dict(kind='tuple', security_origin=ORIGIN,
            provenance='Runtime.executionContextCreated.defaultContext'))
    fields = [dict(field_id=name, status='observed', text=text, backend_node_id=node,
        visibility='layout-present-occlusion-unknown') for name, text, node in
        [('name', ' Amber ', 10), ('price', price, 11), ('note', '\u2002', 12),
         ('quantity', 'many', 13)]]
    fields += [dict(field_id='sku', status='withheld', reason='missing_field'),
        dict(field_id='private', status='withheld', reason='hidden_or_unsupported')]
    return dict(status='partial', fixture_only=True, general_observation_enabled=False,
        observation_ref=ref, fields=fields,
        coverage=dict(scope='root-only', child_frames='withheld', atomic=False,
            actionable_geometry=False))


def project(record):
    result = subprocess.run([str(PROBE)], input=json.dumps(record, ensure_ascii=False),
        text=True, capture_output=True, check=True, timeout=3)
    return json.loads(result.stdout)


class Projection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        PROBE.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['clang++', '-std=c++20', '-fobjc-arc', '-Wall', '-Wextra', '-Werror',
            '-I', str(ROOT / 'native/cef'), str(ROOT / 'tests/table_projection_probe.mm'),
            str(ROOT / 'native/cef/table_projection.mm'), '-framework', 'Foundation',
            '-o', str(PROBE)], check=True)

    def test_exact_source_states_and_provenance(self):
        batch = project(observation())
        self.assertEqual(batch['schema_version'], 'owned-product-v1')
        self.assertEqual(batch['pattern_version'], 'owned-field-ids-v1')
        self.assertTrue(batch['partial'])
        fields = {f['name']: f for f in batch['rows'][0]['fields']}
        self.assertEqual(fields['name']['state'], dict(kind='value', source=' Amber ', value='Amber'))
        self.assertEqual(fields['price']['state'], dict(kind='value', source='USD 12.00', value='12.00'))
        self.assertEqual(fields['note']['state'], dict(kind='empty'))
        self.assertEqual(fields['note']['source']['fragment'], '\u2002')
        self.assertEqual(fields['sku']['state'], dict(kind='missing'))
        self.assertEqual(fields['private']['state'], dict(kind='inaccessible'))
        self.assertEqual(fields['quantity']['state']['kind'], 'invalid')
        self.assertEqual(fields['quantity']['state']['source'], 'many')
        ref = fields['name']['source']['observation']
        self.assertEqual(ref['security_origin'], ORIGIN)
        self.assertEqual(ref['capture_start_ns'], 1000000000)
        self.assertEqual(ref['capture_end_ns'], 1000000100)
        self.assertEqual(fields['name']['source']['node_id'], 10)
        self.assertNotIn('fragment', fields['private']['source'])
        self.assertIsNone(fields['private']['source']['node_id'])

    def test_ambiguity_preserves_literal_candidates(self):
        fields = project(observation('USD 12.00 / USD 14.00'))['rows'][0]['fields']
        price = next(f for f in fields if f['name'] == 'price')
        self.assertEqual(price['state'], dict(kind='ambiguous', candidates=['USD 12.00', 'USD 14.00']))
        self.assertEqual(price['source']['fragment'], 'USD 12.00 / USD 14.00')

    def test_currency_is_explicit_and_decimal_is_exact(self):
        for raw, expected in [('USD 9007199254740993.01', '9007199254740993.01'),
                              ('USD 00012.00', '12.00')]:
            price = project(observation(raw))['rows'][0]['fields'][1]
            self.assertEqual(price['state']['value'], expected)
        for raw in ['$12.00', 'EUR 12.00', 'USD 1.2', 'USD -1.00', 'USD 1e2']:
            with self.subTest(raw=raw):
                price = project(observation(raw))['rows'][0]['fields'][1]
                self.assertEqual(price['state']['kind'], 'invalid')

    def test_private_fragment_is_never_copied(self):
        record = observation()
        record['fields'][-1] = dict(field_id='private', status='observed',
            text='PRIVATE_MARKER', backend_node_id=20, visibility='layout-present-occlusion-unknown')
        batch = project(record)
        self.assertNotIn('PRIVATE_MARKER', json.dumps(batch))
        self.assertEqual(batch['rows'][0]['fields'][-1]['state'], dict(kind='inaccessible'))

    def test_quantity_uses_exact_ascii_integer_rule(self):
        for raw, kind, normalized in [('0007', 'value', '7'),
            ('18446744073709551615', 'value', '18446744073709551615'),
            ('18446744073709551616', 'invalid', None), ('-1', 'invalid', None),
            ('١٢', 'invalid', None), (' ', 'empty', None)]:
            with self.subTest(raw=raw):
                record = observation()
                next(f for f in record['fields'] if f['field_id'] == 'quantity')['text'] = raw
                quantity = project(record)['rows'][0]['fields'][4]
                self.assertEqual(quantity['state']['kind'], kind)
                self.assertEqual(quantity['source']['fragment'], raw)
                if normalized is not None:
                    self.assertEqual(quantity['state']['value'], normalized)

    def test_invalid_native_identity_and_shape_deny(self):
        mutations = [lambda r: r.update(status='failed'),
            lambda r: r.update(fixture_only=False),
            lambda r: r.update(general_observation_enabled=True),
            lambda r: r['observation_ref'].update(run_id='other-run'),
            lambda r: r['observation_ref'].update(surface_id='bad\nsurface'),
            lambda r: r['observation_ref'].update(frame_id='bad\rframe'),
            lambda r: r['observation_ref'].update(document_id='bad\0document'),
            lambda r: r['observation_ref'].update(capture_id='bad\ncapture'),
            lambda r: r['observation_ref']['origin'].update(security_origin='http://other.test'),
            lambda r: r['observation_ref']['origin'].update(provenance='URL'),
            lambda r: r['observation_ref'].update(node_generation=True),
            lambda r: r['observation_ref'].update(capture_end_continuous_ns=999),
            lambda r: r['observation_ref'].update(capture_end_continuous_ns=4000000001),
            lambda r: r['observation_ref'].update(capture_end_continuous_ns=1 << 63),
            lambda r: r['fields'].append(copy.deepcopy(r['fields'][0])),
            lambda r: r['fields'].pop(),
            lambda r: r['fields'][0].update(backend_node_id=True),
            lambda r: r['fields'][0].update(backend_node_id=1 << 63),
            lambda r: r['fields'][0].update(text='x'*2049),
            lambda r: r['coverage'].update(actionable_geometry=True),
            lambda r: r['coverage'].update(scope='all-frames')]
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                record = observation(); mutation(record)
                self.assertEqual(project(record), dict(error='unavailable'))


if __name__ == '__main__':
    unittest.main()
