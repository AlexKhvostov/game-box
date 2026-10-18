"""Inspect an AAB without modifying it: protobuf manifest and ELF page alignment.

JAR signature validation is performed separately with the installed jarsigner.
Uses only Python's standard library; no app execution or network access.
"""
import argparse
import hashlib
import json
import pathlib
import struct
import zipfile


def varint(data, pos):
    value = shift = 0
    while True:
        byte = data[pos]
        pos += 1
        value |= (byte & 127) << shift
        if byte < 128:
            return value, pos
        shift += 7
        if shift > 63:
            raise ValueError('Invalid protobuf integer')


def fields(data):
    pos = 0
    while pos < len(data):
        tag, pos = varint(data, pos)
        wire = tag & 7
        if wire == 0:
            value, pos = varint(data, pos)
        elif wire == 2:
            size, pos = varint(data, pos)
            value = data[pos:pos + size]
            pos += size
        elif wire in (1, 5):
            size = 8 if wire == 1 else 4
            value = data[pos:pos + size]
            pos += size
        else:
            raise ValueError('Unsupported protobuf wire format')
        yield tag >> 3, value


def xml_node(data):
    # android.aapt.pb.XmlNode.element=1; XmlElement name=3, attributes=4, children=5.
    element = next((v for k, v in fields(data) if k == 1), None)
    if element is None:
        return None
    node = {'name': '', 'attributes': {}, 'children': []}
    for key, value in fields(element):
        if key == 3:
            node['name'] = value.decode()
        elif key == 4:
            attr = dict(fields(value))
            node['attributes'][attr[2].decode()] = attr.get(3, b'').decode()
        elif key == 5:
            child = xml_node(value)
            if child:
                node['children'].append(child)
    return node


def verify(path):
    with zipfile.ZipFile(path) as bundle:
        assert bundle.testzip() is None, 'ZIP checksum failure'
        manifest = xml_node(bundle.read('base/manifest/AndroidManifest.xml'))
        attrs = manifest['attributes']
        assert attrs['package'] == 'com.best4u.untouch', attrs
        sdk = next(n['attributes'] for n in manifest['children'] if n['name'] == 'uses-sdk')
        assert int(sdk['minSdkVersion']) == 24, sdk
        assert int(sdk['targetSdkVersion']) >= 36, sdk
        permissions = [n['attributes']['name'] for n in manifest['children'] if n['name'] == 'uses-permission']
        assert not any(p in permissions for p in ['android.permission.ACCESS_FINE_LOCATION', 'android.permission.ACCESS_COARSE_LOCATION', 'android.permission.CAMERA', 'android.permission.RECORD_AUDIO', 'com.google.android.gms.permission.AD_ID', 'android.permission.ACCESS_ADSERVICES_AD_ID', 'android.permission.ACCESS_ADSERVICES_ATTRIBUTION', 'android.permission.ACCESS_ADSERVICES_TOPICS', 'com.google.android.providers.gsf.permission.READ_GSERVICES'])
        libs = []
        for name in bundle.namelist():
            if not name.endswith('.so') or not name.startswith('base/lib/'):
                continue
            data = bundle.read(name)
            assert data[:4] == b'\x7fELF', name
            is64 = data[4] == 2
            endian = '<' if data[5] == 1 else '>'
            phoff = struct.unpack_from(endian + ('Q' if is64 else 'I'), data, 32 if is64 else 28)[0]
            size, count = struct.unpack_from(endian + 'HH', data, 54 if is64 else 42)
            alignments = []
            for i in range(count):
                offset = phoff + i * size
                if struct.unpack_from(endian + 'I', data, offset)[0] == 1:
                    alignment = struct.unpack_from(endian + ('Q' if is64 else 'I'), data, offset + (48 if is64 else 28))[0]
                    alignments.append(alignment)
            assert alignments, name
            # 16 KB requirement applies to 64-bit native libraries.
            if is64:
                assert min(alignments) >= 16384, (name, alignments)
            libs.append({'path': name, 'bits': 64 if is64 else 32, 'minimumLoadAlignment': min(alignments)})
        app = next(n for n in manifest['children'] if n['name'] == 'application')
        metadata = {n['attributes']['name']: n['attributes'].get('value') for n in app['children'] if n['name'] == 'meta-data'}
        assert metadata['com.google.android.play.billingclient.version'] == '8.0.0', metadata
        providers = [n['attributes']['name'] for n in app['children'] if n['name'] == 'provider']
        assert not any(p in providers for p in ['com.yandex.mobile.ads.core.initializer.YandexAdsInitializeProvider', 'io.appmetrica.analytics.internal.PreloadInfoContentProvider', 'com.google.firebase.provider.FirebaseInitProvider']), providers
        assert metadata['com.yandex.mobile.ads.AUTOMATIC_SDK_INITIALIZATION'] == 'false', metadata
        assert metadata['firebase_analytics_collection_deactivated'] == 'true', metadata
        return {'artifact': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                'manifest': attrs, 'sdk': sdk, 'permissions': permissions, 'metadata': metadata, 'providers': providers,
                'nativeLibraries': libs, 'zipChecksumsVerified': True, 'elf64Supports16KB': True,
                'signature': 'See separate jarsigner verification',
                'limitations': ['AAB ELF validation is not APK ZIP alignment validation', 'Physical device and Google Play processing still required']}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('bundle', type=pathlib.Path)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    args = parser.parse_args()
    result = verify(args.bundle)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: result[k] for k in ['sha256', 'manifest', 'sdk', 'elf64Supports16KB']}, indent=2))
