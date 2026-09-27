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

def result_table(rows):
    return '<table class="results"><thead><th>Rnk</th><th>BIB</th><th>Rider</th><th>Time</th></thead><tbody>'+''.join(
        '<tr><td>'+rank+'</td><td>12</td><td><a href="rider/'+name.lower()+'">'+name+'</a></td><td class="time"><font>'+display+'</font><span class="hide">'+hidden+'</span></td></tr>'
        for rank,name,display,hidden in rows)+'</tbody></table>'

def results_page(gc=True):
    stage=result_table([('1','StageWinner','3:20:00','3:20:00'),('2','StageSecond',',,','0:00')])
    overall=result_table([('1','OverallWinner','21:30:00','21:30:00'),('2','OverallSecond','0:04','0:04')])
    return '<title>Fictional stage results</title><ul class="resultTabs"><li><a data-id="s">STAGE</a></li>'+('<li><a data-id="g">GC</a></li>' if gc else '')+'<li><a data-id="y">YOUTH</a></li></ul><div class="resTab" data-id="s">'+stage+'</div>'+('<div class="resTab hide" data-id="g">'+overall+'</div>' if gc else '')+'<div class="resTab hide" data-id="y">'+result_table([('1','YoungWinner','20:00:00','20:00:00')])+'</div>'

def race_info_page():
    return '<ul class="keyvalueList">'+''.join('<li><div class="title">'+k+':</div><div class="value">'+v+'</div></li>' for k,v in [('Date','27 September 2026'),('Distance','160 km'),('Avg. speed winner','48.0 km/h')])+'</ul>'

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
    def test_real_metrics_and_group_riders_without_startlist(self):
        race=pcs.parse_race(live(),'race/demo/2026/stage-2')
        self.assertEqual(race['kmToGo'],42.6)
        self.assertEqual(race['elapsed'],'3:23:01')
        self.assertEqual(race['groups'][0]['count'],1)
        self.assertTrue(race['groups'][0]['uncertain'])
        self.assertEqual(race['groups'][1]['gap'],'+1:12')
        self.assertEqual(race['groups'][0]['riders'][0]['name'],'Fictional Person')
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

class Classifications(unittest.TestCase):
    def test_gc_selected_by_tab_not_table_order(self):
        d=pcs.parse_results(results_page(),'race/demo/2026/stage-6')
        self.assertEqual([x['kind'] for x in d['classifications']],['gc','result'])
        self.assertEqual(d['classifications'][0]['rows'][0]['name'],'OverallWinner')
        self.assertEqual(d['classifications'][0]['rows'][1]['time'],'+0:04')
        self.assertNotIn('YoungWinner',json.dumps(d))
    def test_ditto_uses_hidden_numeric_gap(self):
        d=pcs.parse_results(results_page(),'race/demo/2026/stage-6')
        self.assertEqual(d['classifications'][1]['rows'][1]['time'],'+0:00')
    def test_ditto_without_hidden_uses_previous_gap(self):
        t=pcs.checked_html(result_table([('1','First','4:00:00',''),('2','Second','0:08',''),('3','Third',',,','')])).first('table')
        self.assertEqual(pcs.result_rows(t)[2]['time'],'+0:08')
    def test_one_day_final_results_never_labeled_gc(self):
        d=pcs.parse_results(result_table([('1','Winner','5:00:00','')]),'race/demo/2026/result')
        self.assertFalse(d['gcAvailable'])
        self.assertFalse(d['stageRace'])
        self.assertEqual(d['classifications'][0]['title'],'Final results')
    def test_missing_gc_stays_explicit(self):
        d=pcs.parse_results(results_page(False),'race/demo/2026/stage-1')
        self.assertFalse(d['gcAvailable'])
        self.assertEqual(d['classifications'][0]['title'],'Stage results')
    def test_empty_table_is_pending_results(self):
        d=pcs.parse_results(result_table([]),'race/demo/2026/result')
        self.assertEqual(d['classifications'][0]['rows'],[])
    def test_unavailable_results_are_not_an_empty_success(self):
        with self.assertRaises(pcs.SourceError):pcs.parse_results('<html>No results</html>','race/demo/2026/result')
    def test_finished_hint_fetches_results_and_optional_profile(self):
        with patch.object(pcs,'fetch',return_value=results_page()) as fetch:
            d=pcs.load_race('race/demo/2026/stage-6',True)
            self.assertEqual([c.args[0] for c in fetch.call_args_list],['race/demo/2026/stage-6','race/demo/2026/stage-6/live','race/demo/2026/stage-6/live/race-events'])
            self.assertTrue(d['gcAvailable'])
    def test_live_to_finished_fetches_results(self):
        with patch.object(pcs,'fetch',side_effect=[live(dict(DATA,race_status='finished')),results_page(),'<ul class="timeline3"></ul>']):
            d=pcs.load_race('race/demo/2026/stage-6')
            self.assertEqual(d['status'],'finished')
            self.assertTrue(d['gcAvailable'])
            self.assertEqual(d['elapsed'],'3:20:00')
    def test_finished_summary_uses_stage_winner_and_published_metrics(self):
        d=pcs.parse_results(results_page()+race_info_page(),'race/demo/2026/stage-6')
        self.assertEqual(d['elapsed'],'3:20:00')
        self.assertEqual(d['distance'],160)
        self.assertEqual(d['avgSpeed'],48)
        self.assertEqual(d['date'],'27 September 2026')
    def test_missing_finished_metrics_stay_unknown(self):
        d=pcs.parse_results(result_table([]),'race/demo/2026/result')
        self.assertEqual(d['elapsed'],'')
        self.assertIsNone(d['distance'])
        self.assertIsNone(d['avgSpeed'])
        self.assertEqual(d['profileState'],'unavailable')
    def test_gc_time_is_never_used_when_stage_winner_is_missing(self):
        html=results_page().replace('data-id="s">STAGE','data-id="absent">STAGE')
        d=pcs.parse_results(html,'race/demo/2026/stage-6')
        self.assertEqual(d['elapsed'],'')
        self.assertTrue(d['gcAvailable'])
    def test_profile_on_results_page_needs_no_extra_fetch(self):
        page=results_page()+live()
        with patch.object(pcs,'fetch',side_effect=[page,'<ul class="timeline3"></ul>']) as fetch:
            d=pcs.load_race('race/demo/2026/stage-6',True)
        self.assertGreater(len(d['profile']),1)
        self.assertEqual(d['profileState'],'ready')
        self.assertEqual(fetch.call_count,2)
    def test_finished_profile_fallback_never_uses_running_live_clock(self):
        with patch.object(pcs,'fetch',side_effect=[results_page()+race_info_page(),live(),'<ul class="timeline3"></ul>']):
            d=pcs.load_race('race/demo/2026/stage-6',True)
        self.assertGreater(len(d['profile']),1)
        self.assertEqual(d['elapsed'],'3:20:00')
        self.assertEqual(d['distance'],160)
        self.assertEqual(d['avgSpeed'],48)
    def test_profile_failure_does_not_lose_results_and_rejection_stops_requests(self):
        for state in ('blocked','rate-limited'):
            with self.subTest(state=state),patch.object(pcs,'fetch',side_effect=[results_page(),pcs.SourceError(state,'Rejected')]) as fetch:
                d=pcs.load_race('race/demo/2026/stage-6',True)
            self.assertEqual(d['state'],'ready')
            self.assertTrue(d['gcAvailable'])
            self.assertEqual(d['profileState'],state)
            self.assertEqual(fetch.call_count,2)
    def test_unavailable_profile_still_loads_events(self):
        with patch.object(pcs,'fetch',side_effect=[results_page(),pcs.SourceError('unavailable','No live coverage'),'<ul class="timeline3"></ul>']):
            d=pcs.load_race('race/demo/2026/stage-6',True)
        self.assertEqual(d['profileState'],'unavailable')
        self.assertEqual(d['eventsState'],'empty')
    def test_results_failure_preserves_finish_snapshot(self):
        with patch.object(pcs,'fetch',side_effect=[live(dict(DATA,race_status='finished')),pcs.SourceError('blocked','Blocked'),pcs.SourceError('blocked','Blocked')]):
            d=pcs.load_race('race/demo/2026/stage-6')
            self.assertEqual(d['status'],'finished')
            self.assertEqual(d['resultsState'],'blocked')
            self.assertEqual(d['elapsed'],'3:23:01')
    def test_group_riders_bib_and_gc_gap_not_mixed(self):
        html=live().replace('<a href="rider/fictional">Fictional Person</a>','<ul><li><div class="bib">42</div><a href="rider/fictional">Fictional Person</a><div class="gc">+20:00</div></li></ul>')
        d=pcs.parse_race(html,'race/demo/2026/result')
        self.assertEqual(d['groups'][0]['riders'][0]['bib'],'42')
        self.assertEqual(d['groups'][0]['gap'],'+0:00')
    def test_group_rider_bound(self):
        html=live().replace('<a href="rider/fictional">Fictional Person</a>',''.join('<a href="rider/f'+str(i)+'">Fictional '+str(i)+'</a>' for i in range(45)))
        d=pcs.parse_race(html,'race/demo/2026/result')
        self.assertEqual(len(d['groups'][0]['riders']),30)
        self.assertEqual(d['groups'][0]['omitted'],15)

class Events(unittest.TestCase):
    def event(self,marker,text):
        return '<li class="event"><div class="bol">'+marker+'</div><div class="stat"><span class="timeago">2m</span><div class="textCont">'+text+'</div></div></li>'
    def test_events_order_markers_and_plain_text(self):
        html='<ul class="timeline3">'+self.event('42.6','Attack by <a href="rider/fictional">Alex Veld</a>.')+self.event('43','Group caught.')+'</ul>'
        d=pcs.parse_events(html)
        self.assertEqual(d['eventsState'],'ready')
        self.assertEqual(d['events'][0],{'marker':'42.6','text':'Attack by Alex Veld.'})
        self.assertEqual(d['events'][1]['marker'],'43')
        self.assertNotIn('2m',json.dumps(d))
    def test_empty_vs_unavailable_or_changed(self):
        self.assertEqual(pcs.parse_events('<ul class="timeline3"></ul>')['eventsState'],'empty')
        for html in ['<html>Unavailable</html>','<ul class="timeline3"><li>Unknown markup</li></ul>']:
            with self.assertRaises(pcs.SourceError):pcs.parse_events(html)
    def test_finish_marker_and_long_rider_list(self):
        text='Fictional rider list '+('Alex Veld, '*40)
        d=pcs.parse_events('<ul class="timeline3">'+self.event('F',text)+'</ul>')
        self.assertEqual(d['events'][0]['marker'],'F')
        self.assertGreater(len(d['events'][0]['text']),240)
    def test_bound_and_deduplication(self):
        html='<ul class="timeline3">'+self.event('1','same')*3+''.join(self.event(str(i),'Event '+str(i)) for i in range(80))+'</ul>'
        d=pcs.parse_events(html)
        self.assertEqual(len(d['events']),60)
        self.assertEqual(sum(e['text']=='same' for e in d['events']),1)
    def test_script_and_style_not_rendered(self):
        d=pcs.parse_events('<ul class="timeline3">'+self.event('25','Attack<script>bad()</script><style>bad</style>')+'</ul>')
        self.assertEqual(d['events'][0]['text'],'Attack')
    def test_events_failure_preserves_race_metrics(self):
        with patch.object(pcs,'fetch',side_effect=[live(),pcs.SourceError('offline','Offline')]):
            d=pcs.load_race('race/demo/2026/result')
        self.assertEqual(d['state'],'ready')
        self.assertEqual(d['kmToGo'],42.6)
        self.assertEqual(d['eventsState'],'offline')
    def test_events_attached_to_finished_classification(self):
        with patch.object(pcs,'fetch',side_effect=[results_page(),live(),'<ul class="timeline3">'+self.event('F','Race finished.')+'</ul>']):
            d=pcs.load_race('race/demo/2026/stage-6',True)
        self.assertTrue(d['gcAvailable'])
        self.assertEqual(d['events'][0]['text'],'Race finished.')

class Calendar(unittest.TestCase):
    def page(self, winner=True):
        return '<input name="date" value="2026-09-28"><h4>UCI races</h4><table><tr>'+''.join('<th>'+x+'</th>' for x in ['Race','Class.','Cat.','Winner','Exp. finish'])+'</tr><tr><td><a href="race/demo/2026/stage-2">Demo stage 2</a></td><td>2.Pro</td><td>WE</td><td>'+('<a href="rider/demo">Winner</a>' if winner else '')+'</td><td>14:50 (08:50 CET)</td></tr></table><h4>National races and other disciplines</h4><table><tr><td><a href="race/gravel/2026/result">Gravel</a></td></tr></table>'
    def test_calendar_filters_other_disciplines_and_preserves_stage(self):
        result=pcs.parse_calendar(self.page(),'2026-09-28')
        self.assertEqual(len(result['races']),1)
        race=result['races'][0]
        self.assertEqual(race['path'],'race/demo/2026/stage-2')
        self.assertEqual(race['status'],'finished')
        self.assertEqual(race['eta'],'14:50 (08:50 CET)')
        self.assertEqual(race['date'],'2026-09-28')
    def test_no_winner_does_not_invent_a_finished_race(self):
        self.assertEqual(pcs.parse_calendar(self.page(False),'2026-09-28')['races'][0]['status'],'scheduled')
    def test_wrong_date_and_invalid_dates_rejected(self):
        for date in ['2026-09-27','2026-02-30','20260928','2026-09-28&extra=1']:
            with self.assertRaises(pcs.SourceError): pcs.parse_calendar(self.page(),date)
    def test_calendar_empty_and_changed_markup_differ(self):
        import re
        empty=re.sub(r'<tr><td>.*?</tr>','',self.page())
        self.assertEqual(pcs.parse_calendar(empty,'2026-09-28')['state'],'empty')
        with self.assertRaises(pcs.SourceError): pcs.parse_calendar('<input name="date" value="2026-09-28">','2026-09-28')
    def test_preview_fetches_only_normal_race_page(self):
        html='<ul class="keyvalueList">'+''.join('<li><div class="title">'+k+':</div><div class="value">'+v+'</div></li>' for k,v in [('Date','28 September 2026'),('Start time','11:12 (05:12 CET)'),('Distance','145.6 km'),('Departure','Town A'),('Arrival','Town B')])+'</ul>'
        with patch.object(pcs,'fetch',return_value=html) as fetch:
            result=pcs.load_race('race/demo/2026/stage-2',upcoming=True)
        fetch.assert_called_once_with('race/demo/2026/stage-2')
        self.assertEqual(result['startTime'],'11:12 (05:12 CET)')
        self.assertEqual(result['distance'],145.6)
        self.assertEqual(result['arrival'],'Town B')
        self.assertNotIn('events',result)
        self.assertEqual(result['profile'],[])

class Filters(unittest.TestCase):
    def test_time_trial_categories_from_explicit_source_labels(self):
        for category, name, expected in [
            ('ME','World Championships ME - ITT','ME (TT)'),
            ('WE','Team Time Trial','WE (TT)'),
            ('MJ','Stage 2a (ITT)','MJ (TT)'),
            ('WU (TT)','Race','WU (TT)'),
            ('ME+WE','Mixed Relay','ME+WE (TT)'),
            ('MU','Prologue','MU (TT)'),
            ('ME','World Championships ME - Road Race','ME'),
            ('WE','Stage 4','WE'),
            ('','Unknown','')]:
            self.assertEqual(pcs.race_metadata(category,'WC',name)['competitionCategory'],expected)
    def test_today_calendar_enriches_live_and_finished_without_losing_live_metrics(self):
        calendar=Calendar().page().replace('2026-09-28','2026-09-27')
        with patch.object(pcs,'fetch',side_effect=[HOME,calendar]): result=pcs.load_overview('2026-09-27')
        race=next(r for r in result['races'] if r['path']=='race/demo/2026/stage-2')
        self.assertEqual(race['competitionCategory'],'WE')
        self.assertEqual(race['raceClass'],'2.Pro')
        self.assertEqual(race['status'],'finished')
        self.assertEqual(race['toGo'],'42.6km')
        self.assertEqual(result['metadataState'],'ready')
    def test_calendar_adds_races_missing_from_homepage(self):
        with patch.object(pcs,'fetch',side_effect=['<ul class="hp3-livestats"></ul>',Calendar().page()]): result=pcs.load_overview('2026-09-28')
        self.assertEqual(len(result['races']),1)
        self.assertEqual(result['state'],'ready')
    def test_metadata_failure_preserves_homepage_and_reports_partial_failure(self):
        with patch.object(pcs,'fetch',side_effect=[HOME,pcs.SourceError('blocked','Rejected')]): result=pcs.load_overview('2026-09-28')
        self.assertEqual(result['state'],'ready')
        self.assertEqual(len(result['races']),2)
        self.assertEqual(result['metadataState'],'blocked')
        self.assertEqual(result['metadataError'],'Rejected')

if __name__=='__main__': unittest.main()
