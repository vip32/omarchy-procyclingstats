import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('pcs',ROOT/'bin/pcs.py')
pcs=importlib.util.module_from_spec(spec)
spec.loader.exec_module(pcs)

HOME='''<h4>LiveStats</h4><ul class="hp3-livestats"><li><a href="race/demo/2026/stage-2/live"><span class="status live">live</span><span class="title">Demo &amp; Tour | Stage 2</span><div class="togo">42.6km</div></a></li></ul>
<table class="hp-next-to-finish"><tr><td></td><td>17:20</td><td>1h</td><td><a href="race/demo/2026/stage-2">Demo tour</a></td><td>WE</td><td>2.WWT</td></tr></table>
<h4>Results today</h4><ul class="hp2-results"><li class="race"><a href="race/today/2026/result">Today's race</a></li>
<h4>Results yesterday</h4><ul class="hp2-results"><li class="race"><a href="race/yesterday/2026/result">Yesterday</a></li></ul></ul>'''
DATA={'race_status':'racing','kmtogo':42.6,'kmdone':148.2,'maxkm':190.8,'avg':43.8,'race_date':'2026-09-27',
      'keypoints':[{'title':'Test climb','type':1,'km':163.4,'lengte':2.1,'avg_perc':6.8}],
      'sl_riders':[{'ridername':'PRIVATE IN TEST'}]}
def live(data=DATA):
    return '''<title>LiveStats for Demo Tour</title><script>var data = '''+json.dumps(data)+''';</script>
<ul class="ls5b-kpi"><li><div class="racetime">3:23:01</div></li></ul>
<div class="bigProfile"><div class="xyProfile" style="clip-path: polygon(0 100%,0% 70%,50% 10%,100% 70%,100% 100%);"></div></div>
<div class="situCont"><ul><li class="group"><div class="groupname">Breakaway</div><div class="time" data-uncertain="1">+0:00??</div><a href="rider/fictional">Fictional Person</a></li><li class="group"><div class="groupname">Peloton</div><div class="time">+1:12</div></li></ul></div>'''

class Parsing(unittest.TestCase):
    def test_overview_deduplicates_live_stage_and_eta(self):
        races=pcs.parse_overview(HOME)['races']
        self.assertEqual(len(races),2)
        self.assertEqual(races[0]['name'],'Demo & Tour | Stage 2')
        self.assertEqual(races[0]['status'],'live')
        self.assertEqual(races[0]['eta'],'17:20')
        self.assertEqual(races[0]['category'],'WE · 2.WWT')
    def test_yesterday_is_not_today_even_when_nested(self):
        self.assertNotIn('yesterday',json.dumps(pcs.parse_overview(HOME)))
    def test_empty_differs_from_changed_markup(self):
        self.assertEqual(pcs.parse_overview('<ul class="hp3-livestats"></ul>')['state'],'empty')
        with self.assertRaises(pcs.SourceError) as cm: pcs.parse_overview('<html>Unexpected</html>')
        self.assertEqual(cm.exception.state,'unsupported')
    def test_challenge_and_legitimate_cloudflare_script(self):
        with self.assertRaises(pcs.SourceError) as cm: pcs.parse_overview('<title>Just a moment...</title>')
        self.assertEqual(cm.exception.state,'blocked')
        self.assertEqual(pcs.parse_overview(HOME+'<script src="/cdn-cgi/challenge-platform/scripts/jsd/main.js"></script>')['state'],'ready')
    def test_real_metrics_and_no_rider_records(self):
        race=pcs.parse_race(live(),'race/demo/2026/stage-2')
        self.assertEqual(race['kmToGo'],42.6)
        self.assertEqual(race['elapsed'],'3:23:01')
        self.assertEqual(race['groups'][0]['count'],1)
        self.assertTrue(race['groups'][0]['uncertain'])
        self.assertEqual(race['groups'][1]['gap'],'+1:12')
        self.assertNotIn('Fictional Person',json.dumps(race))
        self.assertNotIn('PRIVATE IN TEST',json.dumps(race))
        self.assertEqual(race['keypoints'][0]['gradient'],6.8)
        self.assertGreaterEqual(len(race['profile']),3)
    def test_hidden_uncertainty_marker_is_not_uncertain(self):
        race=pcs.parse_race(live().replace('data-uncertain="1"','data-uncertain="0"'),'race/demo/2026/result')
        self.assertFalse(race['groups'][0]['uncertain'])
    def test_start_timezone_and_source_time(self):
        race=pcs.parse_race(live(dict(DATA,start_time_cet='15:08',cur_ts=1790528157)),'race/demo/2026/result')
        self.assertEqual(race['start'],'15:08')
        self.assertEqual(race['startZone'],'CET')
        self.assertTrue(race['sourceAt'].endswith('+00:00'))
    def test_finished_zero_is_not_missing(self):
        race=pcs.parse_race(live(dict(DATA,race_status='finished',kmtogo=0)), 'race/demo/2026/result')
        self.assertEqual(race['kmToGo'],0)
        self.assertEqual(race['status'],'finished')
    def test_preview_zero_uses_full_distance(self):
        race=pcs.parse_race(live(dict(DATA,race_status='preview',kmtogo=0,kmdone=0)),'race/demo/2026/result')
        self.assertEqual(race['kmToGo'],190.8)
    def test_missing_fields_not_fabricated(self):
        race=pcs.parse_race(live({'race_status':'racing'}),'race/demo/2026/result')
        self.assertIsNone(race['kmToGo'])
        self.assertIsNone(race['avgSpeed'])
    def test_script_is_data_never_executed(self):
        with self.assertRaises(pcs.SourceError): pcs.parse_race('<script>var data = evil();</script>','race/demo/2026/result')
    def test_urls_restricted_to_public_race_pages(self):
        for url in ['https://evil.invalid/race/x/2026/result','//evil.invalid/race/x/2026/result','file:///etc/passwd','race/../x/2026/result','rider/a','race/x/2026/result?token=secret','--help']:
            with self.subTest(url=url),self.assertRaises(pcs.SourceError): pcs.race_path(url)
        self.assertEqual(pcs.race_path(pcs.BASE+'race/x/2026/stage-2/live/livestats'),'race/x/2026/stage-2')
    def test_numbers_reject_bad_values(self):
        for n in ['NaN','Infinity','-1',10000000,None]: self.assertIsNone(pcs.number(n))
    def test_bounded_stream_rejects_overflow_before_full_read(self):
        stream=io.BytesIO(b'a'*200)
        with self.assertRaises(pcs.SourceError): pcs.bounded_read(stream,32)
        self.assertEqual(stream.tell(),33)
    def test_redirect_origin_restricted(self):
        with self.assertRaises(pcs.SourceError): pcs.SafeRedirect().redirect_request(None,None,302,'',{},'https://evil.invalid/')
    def test_network_failure_states(self):
        for code,state in [(403,'blocked'),(429,'rate-limited'),(404,'unavailable'),(503,'error')]:
            with self.subTest(code=code),patch.object(pcs.urllib.request,'build_opener') as op:
                op.return_value.open.side_effect=pcs.urllib.error.HTTPError(pcs.BASE,code,'',{},None)
                with self.assertRaises(pcs.SourceError) as cm: pcs.fetch('')
                self.assertEqual(cm.exception.state,state)
    def test_deadline(self):
        with self.assertRaises(pcs.SourceError) as cm: pcs.deadline()
        self.assertEqual(cm.exception.state,'offline')
    def test_cli_argument_injection_rejected_as_data(self):
        result=subprocess.run([sys.executable,'-I',str(ROOT/'bin/pcs.py'),'race','--race','https://evil.invalid/'],capture_output=True,text=True,timeout=3)
        self.assertEqual(json.loads(result.stdout)['state'],'unsupported')

if __name__=='__main__': unittest.main()
