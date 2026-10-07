"""Persistent profile cache tests use an isolated XDG directory and fictional data."""
import base64
import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
from test_pcs import pcs, ROOT, race_info_page


class CourseCache(unittest.TestCase):
    path='race/fictional/2026/result'

    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.env=patch.dict(os.environ,{'XDG_CACHE_HOME':self.temp.name})
        self.env.start();self.addCleanup(self.env.stop)
        self.directory=Path(self.temp.name)/'omarchy-procyclingstats/courses-v1'
        self.value={'state':'ready','distance':180,'elevationGain':2450,'country':'VE','profile':[[0,80],[50,10],[100,80]],
                    'fetchedAt':'2026-10-05T12:00:00+00:00','profileFetchedAt':'2026-10-05T12:00:00+00:00',
                    'elapsed':'DO NOT CACHE','events':[{'text':'DO NOT CACHE'}],'groups':[{'name':'DO NOT CACHE'}]}

    def filename(self,path=None):
        return self.directory/(hashlib.sha256((path or self.path).encode()).hexdigest()+'.json')

    def test_profile_and_distance_survive_new_process_without_live_fields(self):
        pcs.cached_course(self.path,self.value)
        result=json.loads(subprocess.check_output([sys.executable,'-I',str(ROOT/'bin/pcs.py'),'course-cache','--race',self.path],text=True))
        self.assertEqual(result['profile'],self.value['profile'])
        self.assertEqual(result['distance'],180)
        self.assertEqual(result['elevationGain'],2450)
        self.assertEqual(result['country'],'VE')
        self.assertEqual(result['fetchedAt'],self.value['fetchedAt'])
        self.assertNotIn('events',result)
        self.assertNotIn('elapsed',result)
        self.assertNotIn('groups',result)
        self.assertEqual(self.filename().stat().st_mode&0o777,0o600)
        self.assertEqual(self.directory.stat().st_mode&0o777,0o700)

    def test_live_profile_refresh_preserves_total_ascent(self):
        pcs.cached_course(self.path,self.value)
        live=dict(self.value);del live['elevationGain']
        live['elevation']=620;live['country']=''
        pcs.cached_course(self.path,live)
        self.assertEqual(pcs.cached_course(self.path)['elevationGain'],2450)
        self.assertNotIn('elevation',pcs.cached_course(self.path))
        self.assertEqual(pcs.cached_course(self.path)['country'],'VE')

    def test_invalid_country_cannot_enter_cache(self):
        for country in ['https://example.com/flag.png','ve','VENEZUELA',True,['VE']]:
            with self.subTest(country=country),self.assertRaises(ValueError):
                pcs.course_cache_value(dict(self.value,country=country),self.path)

    def test_invalid_ascent_cannot_enter_cache(self):
        for gain in [-1,100001,True,'2450',float('nan')]:
            with self.subTest(gain=gain),self.assertRaises(ValueError):
                pcs.course_cache_value(dict(self.value,elevationGain=gain),self.path)
        self.assertEqual(pcs.course_cache_value(dict(self.value,elevationGain=0),self.path)['elevationGain'],0)
        self.assertIsNone(pcs.course_cache_value(dict(self.value,elevationGain=None),self.path)['elevationGain'])

    def test_image_roundtrip_revalidates_mime_and_dimensions(self):
        fixture=json.loads((ROOT/'demo/fixtures/example.json').read_text())
        image=next(v['profileImage'] for v in fixture['details'].values() if v.get('profileImage'))
        pcs.cached_course(self.path,dict(self.value,profile=[],profileImage=image,profileImageWidth=999999))
        restored=pcs.cached_course(self.path)
        self.assertEqual(restored['profileImage'],image)
        self.assertLessEqual(restored['profileImageWidth'],4096)
        self.assertEqual(restored['profileState'],'ready')

    def test_seven_day_expiry_and_reads_do_not_extend_retention(self):
        now=time.time()
        with patch.object(pcs.time,'time',return_value=now):pcs.cached_course(self.path,self.value)
        with patch.object(pcs.time,'time',return_value=now+6*86400):
            self.assertEqual(pcs.cached_course(self.path)['cacheSavedAt'],now)
        with patch.object(pcs.time,'time',return_value=now+7*86400):
            self.assertEqual(pcs.cached_course(self.path),{})
        self.assertFalse(self.filename().exists())

    def test_expired_and_abandoned_files_pruned_during_access(self):
        pcs.cached_course(self.path,self.value)
        old=self.filename();os.utime(old,(1,1))
        partial=self.directory/('.tmp-'+'a'*32);partial.write_text('interrupted')
        unrelated=self.directory/'keep.txt';unrelated.write_text('unrelated')
        pcs.cached_course('race/new/2026/result',self.value)
        self.assertFalse(old.exists());self.assertFalse(partial.exists())
        self.assertEqual(unrelated.read_text(),'unrelated')

    def test_cache_caps_entry_count_and_total_bytes(self):
        with patch.object(pcs,'CACHE_MAX_ENTRIES',2):
            for name in ['one','two','three']:pcs.cached_course(f'race/{name}/2026/result',self.value)
        self.assertEqual(len(list(self.directory.glob('*.json'))),2)
        self.assertFalse(self.filename('race/one/2026/result').exists())
        with patch.object(pcs,'CACHE_MAX_BYTES',self.filename('race/three/2026/result').stat().st_size+20):
            pcs.cached_course('race/four/2026/result',self.value)
        self.assertEqual(len(list(self.directory.glob('*.json'))),1)

    def test_corrupt_oversized_foreign_future_and_invalid_geometry_are_misses(self):
        pcs.cached_course(self.path,self.value)
        record=json.loads(self.filename().read_text())
        variants=['not json','x'*(pcs.CACHE_ENTRY_BYTES+1),
                  json.dumps(dict(record,path='race/foreign/2026/result')),
                  json.dumps(dict(record,savedAt=time.time()+86400)),
                  json.dumps(dict(record,course=dict(self.value,profile=[[0,float('nan')],[100,80]]))),
                  json.dumps(dict(record,course=dict(self.value,profile=[],profileImage='https://evil.invalid/image.png')))]
        for bad in variants:
            with self.subTest(bad=bad[:40]):
                self.filename().write_text(bad)
                self.assertEqual(pcs.cached_course(self.path),{})

    def test_failed_refresh_preserves_good_disk_snapshot_and_age(self):
        pcs.cached_course(self.path,self.value)
        before=self.filename().read_bytes()
        pcs.cached_course(self.path,{'state':'blocked','error':'Rejected'})
        pcs.cached_course(self.path,dict(self.value,profileError='Rejected'))
        self.assertEqual(self.filename().read_bytes(),before)

    def test_partial_atomic_write_preserves_previous_entry(self):
        pcs.cached_course(self.path,self.value)
        before=self.filename().read_bytes()
        with patch.object(pcs.os,'replace',side_effect=OSError('disk full')):
            pcs.cached_course(self.path,dict(self.value,distance=190))
        self.assertEqual(self.filename().read_bytes(),before)
        self.assertEqual(list(self.directory.glob('.tmp-*')),[])

    def test_symlink_entry_and_directory_are_not_followed(self):
        pcs.cached_course(self.path,self.value)
        outside=Path(self.temp.name)/'outside';outside.write_text('untouched')
        self.filename().unlink();self.filename().symlink_to(outside)
        self.assertEqual(pcs.cached_course(self.path),{})
        pcs.cached_course(self.path,self.value)
        self.assertEqual(outside.read_text(),'untouched')
        self.assertFalse(self.filename().is_symlink())
        self.filename().unlink();(self.directory/'.lock').unlink();self.directory.rmdir()
        target=Path(self.temp.name)/'elsewhere';target.mkdir()
        self.directory.symlink_to(target,target_is_directory=True)
        self.assertEqual(pcs.cached_course(self.path),{})
        pcs.cached_course(self.path,self.value)
        self.assertEqual(list(target.iterdir()),[])

    def test_missing_or_unwritable_cache_is_optional(self):
        self.assertEqual(pcs.cached_course(self.path),{})
        with patch.object(pcs.os,'open',side_effect=PermissionError('read-only cache')):
            self.assertEqual(pcs.cached_course(self.path),{})
            self.assertEqual(pcs.cached_course(self.path,self.value),{})
        self.assertEqual(pcs.cached_course('../../elsewhere',self.value),{})

    def invoke(self,args):
        output=io.StringIO()
        with patch.object(sys,'argv',['pcs.py']+args),contextlib.redirect_stdout(output):pcs.main()
        return json.loads(output.getvalue())

    def test_actual_course_and_race_cli_write_only_successful_profiles(self):
        with patch.object(pcs,'load_course',return_value=self.value.copy()):
            result=self.invoke(['course','--race',self.path])
        self.assertEqual(result['state'],'ready')
        self.assertEqual(pcs.cached_course(self.path)['distance'],180)
        with patch.object(pcs,'load_race',return_value=dict(self.value,distance=190)):
            self.invoke(['race','--race',self.path])
        self.assertEqual(pcs.cached_course(self.path)['distance'],190)

    def test_cache_cli_is_network_free_and_does_not_fake_a_refresh(self):
        pcs.cached_course(self.path,self.value)
        with patch.object(pcs,'fetch',side_effect=AssertionError('must not fetch')),patch.object(pcs,'fetch_bytes',side_effect=AssertionError('must not fetch')):
            result=self.invoke(['course-cache','--race',self.path])
            empty=self.invoke(['course-cache','--race','race/missing/2026/result'])
        self.assertEqual(result['fetchedAt'],self.value['fetchedAt'])
        self.assertEqual(empty['state'],'empty')
        self.assertNotIn('fetchedAt',empty)

    def test_saved_html_does_not_write_live_cache(self):
        html=Path(self.temp.name)/'course.html';html.write_text(race_info_page())
        result=self.invoke(['course','--race',self.path,'--html',str(html)])
        self.assertTrue(result['savedPage'])
        self.assertFalse(self.directory.exists())
