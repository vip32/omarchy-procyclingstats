#!/usr/bin/python3
"""Bounded, read-only PCS HTML adapter. No credentials or challenge bypass."""
import argparse
import datetime as dt
from html.parser import HTMLParser
import json
import math
from pathlib import Path
import re
import signal
import socket
import sys
import urllib.error
import urllib.parse
import urllib.request

BASE = 'https://www.procyclingstats.com/'
MAX_BYTES = 2_000_000
MAX_OUTPUT = 180_000

class SourceError(Exception):
    def __init__(self, state, message):
        self.state, self.message = state, message

class Node:
    def __init__(self, tag='', attrs=(), parent=None):
        self.tag, self.attrs, self.parent, self.children = tag, dict(attrs), parent, []
    def nodes(self, tag=None, cls=None):
        stack = list(reversed(self.children))
        while stack:
            n = stack.pop()
            if isinstance(n, str):
                continue
            if (not tag or n.tag == tag) and (not cls or cls in n.attrs.get('class', '').split()):
                yield n
            stack.extend(reversed(n.children))
    def first(self, tag=None, cls=None):
        return next(self.nodes(tag, cls), None)
    def text(self):
        parts, stack = [], list(reversed(self.children))
        while stack:
            n = stack.pop()
            if isinstance(n, str):
                parts.append(n)
            elif n.tag not in ('script', 'style'):
                stack.extend(reversed(n.children))
        return clean(' '.join(parts))

class Tree(HTMLParser):
    def __init__(self, html):
        super().__init__(convert_charrefs=True)
        self.root = self.current = Node()
        self.count = 0
        self.feed(html)
    def handle_starttag(self, tag, attrs):
        self.count += 1
        if self.count > 60000:
            raise SourceError('unsupported', 'PCS page is too complex.')
        n = Node(tag, attrs, self.current)
        self.current.children.append(n)
        if tag not in ('area','base','br','col','embed','hr','img','input','link','meta','param','source','track','wbr'):
            self.current = n
    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        self.handle_endtag(tag)
    def handle_endtag(self, tag):
        n = self.current
        while n.parent:
            if n.tag == tag:
                self.current = n.parent
                break
            n = n.parent
    def handle_data(self, data):
        self.current.children.append(data)

def clean(value, limit=240):
    return re.sub(r'\s+', ' ', str('' if value is None else value)).strip()[:limit]

def txt(n):
    return n.text() if n else ''

def number(value, maximum=10000):
    try:
        result = float(value)
        return round(result, 1) if math.isfinite(result) and 0 <= result <= maximum else None
    except (ValueError, TypeError):
        return None

def race_path(value):
    url = urllib.parse.urlsplit(urllib.parse.urljoin(BASE, value))
    if url.scheme != 'https' or url.netloc != 'www.procyclingstats.com' or url.query or url.fragment:
        raise SourceError('unsupported', 'Only public PCS road race links are supported.')
    if not re.fullmatch(r'/race/[a-z0-9-]+/\d{4}/(?:result|stage-\d+[a-z]?)(?:/(?:live|result|livestats))*', url.path):
        raise SourceError('unsupported', 'Select a PCS race result or stage link.')
    bits = url.path.strip('/').split('/')
    return '/'.join(bits[:4])

def race_link(n):
    for a in n.nodes('a'):
        try:
            return a, race_path(a.attrs.get('href', ''))
        except SourceError:
            pass
    return None, ''

def checked_html(html):
    if len(html.encode('utf-8')) > MAX_BYTES:
        raise SourceError('unsupported', 'PCS response exceeded the size limit.')
    if 'cf-chl-' in html or '<title>Just a moment' in html:
        raise SourceError('blocked', 'PCS requires browser verification. Open PCS in your browser.')
    return Tree(html).root

def profile(n):
    for el in n.nodes():
        style = el.attrs.get('style', '')
        if 'clip-path' not in style:
            continue
        m = re.search(r'polygon\(([^)]+)\)', style)
        if not m:
            continue
        points = []
        for x,y in re.findall(r'(\d+(?:\.\d+)?)%\s+(\d+(?:\.\d+)?)%', m[1]):
            x,y=float(x),float(y)
            if 0 <= x <= 100 and 0 <= y <= 100:
                points.append([x,y])
        if len(points) > 2:
            # The polygon's first/last un-percented points close the area; skip them.
            stride = max(1, math.ceil(len(points)/220))
            return points[::stride]
    return []

def parse_overview(html):
    doc = checked_html(html)
    races = {}
    recognized = False
    for live in doc.nodes('ul', 'hp3-livestats'):
        recognized = True
        for li in live.children:
            if not isinstance(li, Node) or li.tag != 'li':
                continue
            a,path = race_link(li)
            if not path:
                continue
            state = txt(li.first(cls='status')).lower()
            state = 'live' if state in ('live','racing') else ('finished' if state in ('finished','finish') else 'upcoming')
            races[path] = dict(path=path, name=txt(li.first(cls='title')) or txt(a), status=state,
                               toGo=txt(li.first(cls='togo')), profile=profile(li), category='', eta='')
    for table in doc.nodes('table'):
        if not {'hp-next-to-finish','next-to-finish'} & set(table.attrs.get('class','').split()):
            continue
        recognized = True
        for row in table.nodes('tr'):
            cells = [c for c in row.children if isinstance(c,Node) and c.tag=='td']
            if len(cells) < 4:
                continue
            a,path = race_link(cells[3])
            if not path:
                continue
            race = races.setdefault(path, dict(path=path,name=txt(a),status='scheduled',toGo='',profile=[]))
            race.update(eta=txt(cells[1]), category=' · '.join(txt(x) for x in cells[4:6]))
    # PCS has occasionally nested yesterday's list inside today's list. Walk in
    # document order and stop at the next section heading, not every descendant.
    today = False
    for n in doc.nodes():
        if n.tag in ('h3','h4'):
            label = n.text().lower()
            if label == 'results today':
                recognized, today = True, True
            elif today:
                today = False
        if today and n.tag == 'li' and 'race' in n.attrs.get('class','').split():
            a,path = race_link(n)
            if path:
                races[path] = dict(path=path,name=txt(a),status='finished',toGo='',profile=[],eta='',category='')
    if not recognized:
        raise SourceError('unsupported', 'PCS page format changed; today’s races could not be read.')
    order = {'live':0,'upcoming':1,'scheduled':2,'finished':3}
    return {'state':'ready' if races else 'empty', 'races':sorted(races.values(),key=lambda r:order[r['status']])[:60]}

def parse_race(html, path):
    doc = checked_html(html)
    data = {}
    for m in re.finditer(r'\b(?:var|let|const)\s+data\s*=\s*(?=\{)', html):
        try:
            candidate,_ = json.JSONDecoder().raw_decode(html[m.end():])
            if isinstance(candidate,dict) and 'race_status' in candidate:
                data = candidate
                break
        except (ValueError,RecursionError):
            pass
    kpi = doc.first(cls='ls5b-kpi')
    if not kpi and not data:
        raise SourceError('unsupported', 'LiveStats are not available for this race, or PCS changed its page format.')
    def value(cls, key=''):
        el = kpi.first(cls=cls) if kpi else None
        return clean(el.attrs.get('data-value', el.text())) if el else clean(data.get(key))
    status = value('race_status','race_status').lower()
    status = {'racing':'live','preview':'upcoming','finished':'finished'}.get(status,'unknown')
    distance = number(data.get('maxkm'))
    done, remaining = number(value('kmdone','kmdone')), number(value('kmtogo','kmtogo'))
    if status == 'upcoming' and distance is not None and remaining == 0:
        remaining = distance
    groups = []
    situation = doc.first(cls='situCont')
    if situation:
        for i,g in enumerate(situation.nodes(cls='group')):
            if i >= 12: break
            gap_node=g.first(cls='time')
            raw=txt(gap_node)
            gap=re.search(r'\+\d{1,2}:\d{2}(?::\d{2})?',raw)
            label=txt(g.first(cls='groupname')) or ('Front of race' if i==0 else 'Group '+str(i+1))
            count=sum(1 for a in g.nodes('a') if a.attrs.get('href','').startswith('rider/'))
            groups.append(dict(label=label,gap=gap[0] if gap else '',count=count,
                               uncertain='??' in raw or (gap_node is not None and gap_node.attrs.get('data-uncertain')=='1')))
    keypoints=[]
    for kp in (data.get('keypoints') or [])[:120]:
        if not isinstance(kp,dict) or kp.get('type') not in (1,2,3) or not kp.get('title'): continue
        km=number(kp.get('km'))
        if km is None: continue
        keypoints.append(dict(name=clean(kp['title'],100),km=km,kind='Climb' if kp.get('type')==1 else 'Sprint',
                              length=number(kp.get('lengte')),gradient=number(kp.get('avg_perc'),40)))
    keypoints.sort(key=lambda k:k['km'])
    header=txt(doc.first('title')).removeprefix('LiveStats for ')
    return dict(state='ready',path=path,name=header,status=status,date=clean(data.get('race_date'),10),
                kmToGo=remaining,kmDone=done,distance=distance,avgSpeed=number(value('avg_speed','avg'),150),
                elapsed=value('racetime'),start=value('starttime','start_time_cet'),elevation=number(value('elevation_todo')),
                groups=groups,keypoints=keypoints[:40],profile=profile(doc.first(cls='bigProfile') or doc),
                sourceAt=dt.datetime.fromtimestamp(data['cur_ts'],dt.timezone.utc).isoformat()
                if number(data.get('cur_ts'),4102444800) is not None else '')

class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        u=urllib.parse.urlsplit(newurl)
        if u.scheme != 'https' or u.netloc != 'www.procyclingstats.com':
            raise SourceError('unsupported','PCS redirected outside its public site.')
        return super().redirect_request(req,fp,code,msg,headers,newurl)

def bounded_read(stream, limit=MAX_BYTES):
    chunks, size = [], 0
    while True:
        part = stream.read(min(32768,limit+1-size))
        if not part: break
        size += len(part)
        if size > limit: raise SourceError('unsupported','PCS response exceeded the size limit.')
        chunks.append(part)
    return b''.join(chunks)

def fetch(path):
    request=urllib.request.Request(BASE+path, headers={'User-Agent':'Omarchy-ProCyclingStats/0.1 (personal race overview)', 'Accept':'text/html', 'Accept-Encoding':'identity'})
    try:
        with urllib.request.build_opener(SafeRedirect()).open(request,timeout=10) as response:
            return bounded_read(response).decode('utf-8',errors='replace')
    except urllib.error.HTTPError as e:
        e.close()
        if e.code in (401,403): raise SourceError('blocked','PCS blocks automated access. Open PCS in your browser.') from None
        if e.code == 429: raise SourceError('rate-limited','PCS rate limit reached. Retrying in 15 minutes.') from None
        if e.code == 404: raise SourceError('unavailable','PCS has no LiveStats page for this race.') from None
        raise SourceError('error',f'PCS returned HTTP {e.code}.') from None
    except (urllib.error.URLError,TimeoutError,socket.timeout,OSError):
        raise SourceError('offline','Could not reach PCS. Check your connection and retry.') from None

def deadline(*_):
    raise SourceError('offline','PCS request timed out.')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=['overview','race'])
    parser.add_argument('--race',default='')
    parser.add_argument('--html',type=Path,help='Parse a saved public page offline; no network request')
    args=parser.parse_args()
    signal.signal(signal.SIGALRM,deadline)
    signal.alarm(18)
    try:
        path=race_path(args.race) if args.mode=='race' else ''
        if args.html:
            with args.html.open('rb') as stream: html=bounded_read(stream).decode('utf-8',errors='replace')
        else:
            html=fetch(path+'/live' if path else '')
        result=parse_race(html,path) if path else parse_overview(html)
        result['fetchedAt']=dt.datetime.now(dt.timezone.utc).isoformat()
        result['savedPage']=bool(args.html)
    except SourceError as e:
        result={'state':e.state,'error':e.message}
    except (OSError,ValueError,RecursionError):
        result={'state':'error','error':'Could not read the PCS response.'}
    signal.alarm(0)
    output=json.dumps(result,ensure_ascii=True,separators=(',',':'))
    if len(output)>MAX_OUTPUT: output=json.dumps({'state':'unsupported','error':'Parsed response exceeded the size limit.'})
    print(output)

if __name__=='__main__': main()
