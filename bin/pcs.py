#!/usr/bin/python3
"""Bounded PCS HTML adapter with a local course cache. No credentials or challenge bypass."""
import argparse
import base64
import fcntl
import hashlib
import os
import secrets
import stat
from contextlib import contextmanager
import struct
import datetime as dt
from html.parser import HTMLParser
import json
import math
from pathlib import Path
import re
import signal
import socket
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = 'https://www.procyclingstats.com/'
MAX_BYTES = 2_000_000
MAX_OUTPUT = 512_000
MAX_IMAGE_BYTES = 256_000
REQUEST_DEADLINE = None
CACHE_RETENTION = 7 * 86400
CACHE_MAX_ENTRIES = 100
CACHE_MAX_BYTES = 32 * 1024 * 1024
CACHE_ENTRY_BYTES = 384_000

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
    def text(self, limit=240):
        parts, stack = [], list(reversed(self.children))
        while stack:
            n = stack.pop()
            if isinstance(n, str):
                parts.append(n)
            elif n.tag not in ('script', 'style'):
                stack.extend(reversed(n.children))
        return clean(' '.join(parts),limit)

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
    # PCS now also publishes flattened race URLs. Keep one canonical cache key.
    flat = re.fullmatch(r'/race/([a-z0-9-]+)-(\d{4})-(result|gc|stage-\d+[a-z]?)(?:/(?:live|results|result|livestats))*', url.path)
    path = '/race/'+'/'.join(flat.groups()) if flat else url.path
    if not re.fullmatch(r'/race/[a-z0-9-]+/\d{4}/(?:result|gc|stage-\d+[a-z]?)(?:/(?:live|result|livestats))*', path):
        raise SourceError('unsupported', 'Select a PCS race result or stage link.')
    bits = path.strip('/').split('/')
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

def race_metadata(category, race_class, name):
    category = clean(category).upper().replace(' ', '')
    is_tt = '(TT)' in category or bool(re.search(r'\b(?:ITT|TTT|TT|PROLOGUE)\b|TIME[ -]TRIAL|MIXED[ -]RELAY', name.upper()))
    base = category.replace('(TT)', '')
    code = base + (' (TT)' if is_tt else '') if base in ('ME','WE','MU','WU','MJ','WJ','ME+WE') else ''
    return dict(competitionCategory=code, raceClass=clean(race_class))

def load_overview(date):
    result = parse_overview(fetch(''))
    try:
        calendar = parse_calendar(fetch('races.php?p=uci&s=today&date='+date), date)
        by_path = {r['path']: r for r in calendar['races']}
        merged = []
        for race in result['races']:
            meta = by_path.pop(race['path'], None)
            if meta:
                for key in ('competitionCategory','raceClass','category','date'):
                    race[key] = meta[key]
                if meta['status'] == 'finished': race['status'] = 'finished'
            merged.append(race)
        merged.extend(by_path.values())
        order = {'live':0,'upcoming':1,'scheduled':2,'finished':3}
        result['races'] = sorted(merged,key=lambda r:order.get(r['status'],4))[:60]
        result['state'] = 'ready' if result['races'] else 'empty'
        result['metadataState'] = 'ready'
        result['metadataFetchedAt'] = dt.datetime.now(dt.timezone.utc).isoformat()
    except SourceError as e:
        result.update(metadataState=e.state, metadataError=e.message)
    return result

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
            race.update(race_metadata(txt(cells[4]) if len(cells)>4 else '',txt(cells[5]) if len(cells)>5 else '',race['name']))
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
                race = races.setdefault(path,dict(path=path,toGo='',profile=[],eta='',category=''))
                race.update(name=txt(a),status='finished')
    if not recognized:
        raise SourceError('unsupported', 'PCS page format changed; today’s races could not be read.')
    order = {'live':0,'upcoming':1,'scheduled':2,'finished':3}
    return {'state':'ready' if races else 'empty', 'races':sorted(races.values(),key=lambda r:order[r['status']])[:60]}

def calendar_date(value):
    if not re.fullmatch(r'\d{4}-\d{2}-\d{2}', value):
        raise SourceError('unsupported', 'Use an ISO calendar date.')
    try:
        return dt.date.fromisoformat(value).isoformat()
    except ValueError:
        raise SourceError('unsupported', 'Use a valid calendar date.') from None

def parse_calendar(html, date):
    date = calendar_date(date)
    doc = checked_html(html)
    selected = next((n.attrs.get('value') for n in doc.nodes('input') if n.attrs.get('name') == 'date'), None)
    if selected != date:
        raise SourceError('unsupported', 'PCS did not return the requested race date.')
    races, recognized, in_uci = {}, False, False
    for n in doc.nodes():
        if n.tag in ('h3', 'h4'):
            in_uci = txt(n).lower() == 'uci races'
        if n.tag != 'table' or not in_uci:
            continue
        headers = [txt(h).lower() for h in n.nodes('th')]
        if not {'race', 'winner', 'cat.', 'class.', 'exp. finish'}.issubset(headers):
            continue
        recognized = True
        for row in n.nodes('tr'):
            cells = [c for c in row.children if isinstance(c, Node) and c.tag == 'td']
            if len(cells) != len(headers):
                continue
            values = dict(zip(headers, cells))
            a, path = race_link(values['race'])
            if not path:
                continue
            winner = any(a.attrs.get('href', '').startswith('rider/') for a in values['winner'].nodes('a'))
            races[path] = dict(path=path, name=txt(a), date=date,
                status='finished' if winner else 'scheduled', profile=[], toGo='',
                category=' · '.join(filter(None, [txt(values['cat.']), txt(values['class.'])])),
                eta=txt(values['exp. finish']))
            races[path].update(race_metadata(txt(values['cat.']),txt(values['class.']),txt(a)))
    if not recognized:
        raise SourceError('unsupported', 'PCS calendar format changed; races could not be read.')
    return dict(state='ready' if races else 'empty', date=date, races=list(races.values())[:60])

def load_archive(date, direction):
    """Three dated calendars per request; the shared service drives pagination."""
    cursor=dt.date.fromisoformat(calendar_date(date))
    step=-1 if direction=='recent' else 1
    races={}
    scanned=[]
    for _ in range(3):
        day=cursor.isoformat()
        try:
            page=parse_calendar(fetch('races.php?p=uci&s=today&date='+day),day)
        except SourceError as e:
            return dict(state=e.state,error=e.message,races=list(races.values()),dates=scanned,nextDate=day)
        scanned.append(day)
        for race in page['races']:
            # Dates are traversed nearest first. A multi-day race keeps its nearest entry.
            races.setdefault(race['path'],race)
        cursor+=dt.timedelta(days=step)
    return dict(state='ready' if races else 'empty',races=list(races.values()),dates=scanned,nextDate=cursor.isoformat())

def race_info(doc):
    values = {}
    for group in doc.nodes('ul', 'keyvalueList'):
        for row in group.nodes('li'):
            key = txt(row.first(cls='title')).rstrip(':').lower()
            values[key] = txt(row.first(cls='value'))
    for group in doc.nodes(cls='unitInfo'):
        for label in group.nodes('div','bold'):
            siblings=label.parent.children
            following=siblings[siblings.index(label)+1:]
            parts=[]
            for node in following:
                if isinstance(node,Node) and node.tag=='br': break
                parts.append(txt(node) if isinstance(node,Node) else node)
            values[txt(label).rstrip(': ').lower()]=clean(' '.join(parts))
    return values

def metric(value, maximum=10000):
    match = re.match(r'^(\d+(?:[.,]\d+)?)\b', value)
    return number(match[1].replace(',', '.'), maximum) if match else None

def selected_stage(doc,path):
    if not path.endswith('/gc'): return ''
    navigation=doc.first(cls='resultTabs') or doc.first(cls='unitTabs')
    stage_path=''
    if navigation:
        for a in navigation.nodes('a'):
            label=txt(a).upper()
            if path.endswith('/gc') and label=='STAGE':
                try:
                    href=a.attrs.get('href','')
                    # PCS sometimes points the Stage tab at a secondary award
                    # for that same stage. Its explicit stage prefix still
                    # identifies the course; discard only a plain-text suffix.
                    linked_stage=re.fullmatch(r'(?:https://www\.procyclingstats\.com/)?(race/[a-z0-9-]+-\d{4}-stage-\d+[a-z]?)-[a-z][a-z-]*',href)
                    candidate=race_path(linked_stage[1] if linked_stage else href)
                    if candidate.rsplit('/',1)[0]==path.rsplit('/',1)[0] and re.fullmatch(r'stage-\d+[a-z]?',candidate.rsplit('/',1)[1]):
                        stage_path=candidate
                except SourceError:
                    pass
    return stage_path

def stage_links(doc,path):
    """Use published links only, confined to this edition; never guess stage URLs."""
    edition=path.rsplit('/',1)[0]
    stages={}
    for node in doc.nodes():
        if node.tag not in ('option','a'): continue
        value=node.attrs.get('value' if node.tag=='option' else 'href','')
        try: candidate=race_path(value)
        except (SourceError,ValueError): continue
        tail=candidate.rsplit('/',1)[-1]
        match=re.fullmatch(r'stage-(\d{1,2})([a-z]?)',tail)
        if not match or candidate.rsplit('/',1)[0]!=edition: continue
        # Navigation anchors must say Stage; avoid collecting unrelated links
        # in result tables or editorial stories about other stages.
        if node.tag=='a' and not re.match(r'^stage\s+\d',txt(node),re.I): continue
        stages[candidate]=dict(path=candidate,label='Stage '+match[1]+match[2])
    return sorted(stages.values(),key=lambda v:(int(re.search(r'stage-(\d+)',v['path'])[1]),v['path']))[:32]

def race_date(value):
    value=clean(value)
    try: return dt.date.fromisoformat(value)
    except ValueError: pass
    months={name:i+1 for i,name in enumerate(('January','February','March','April','May','June','July','August','September','October','November','December'))}
    match=re.fullmatch(r'(\d{1,2}) ([A-Za-z]+) (\d{4})',value)
    try: return dt.date(int(match[3]),months[match[2]],int(match[1])) if match else None
    except (ValueError,KeyError): return None

def image_path(value):
    url=urllib.parse.urlsplit(urllib.parse.urljoin(BASE,value))
    if url.scheme!='https' or url.netloc!='www.procyclingstats.com' or url.query or url.fragment or not re.fullmatch(r'/images/profiles/[a-z0-9/_-]+\.(?:png|jpg|jpeg)',url.path):
        raise SourceError('unsupported','Only PCS course-profile images are supported.')
    return url.path.lstrip('/')

def course_fields(doc,path):
    stage=selected_stage(doc,path)
    target=stage if path.endswith('/gc') else path
    image=''
    if target:
        prefix=target.removeprefix('race/').replace('/','-')+'-'
        for node in doc.nodes('img'):
            try: candidate=image_path(node.attrs.get('src',''))
            except SourceError: continue
            if candidate.rsplit('/',1)[-1].startswith(prefix):
                image=candidate
                break
    points=profile(doc)
    return dict(profile=points,profileImagePath=image,stagePath=stage,stages=stage_links(doc,path),
        profileLabel=stage.rsplit('/',1)[-1].replace('stage-','Stage ') if stage else '',
        profileState='ready' if points else 'pending' if image else 'unavailable',
        profileFetchedAt=dt.datetime.now(dt.timezone.utc).isoformat() if points else '')

def image_dimensions(data):
    if data.startswith(b'\x89PNG\r\n\x1a\n') and len(data)>=45 and data[8:16]==b'\x00\x00\x00\x0dIHDR' and data.endswith(b'\x00\x00\x00\x00IEND\xaeB`\x82'):
        width,height=struct.unpack('>II',data[16:24]);mime='image/png'
    elif data.startswith(b'\xff\xd8') and data.endswith(b'\xff\xd9'):
        offset=2; width=height=0;mime='image/jpeg'
        while offset+4<=len(data):
            if data[offset]!=255: break
            marker=data[offset+1];offset+=2
            if marker==255:offset-=1;continue
            if marker in (0xD9,0xDA):break
            length=int.from_bytes(data[offset:offset+2],'big')
            if length<2 or offset+length>len(data):break
            if marker in (0xC0,0xC1,0xC2) and length>=8:
                height,width=struct.unpack('>HH',data[offset+3:offset+7]);break
            offset+=length
    else: raise SourceError('unsupported','PCS did not return a PNG or JPEG profile.')
    if not (0<width<=4096 and 0<height<=2048 and width*height<=4_000_000):
        raise SourceError('unsupported','PCS profile dimensions are unsupported.')
    return mime,width,height

def attach_image(result,path):
    if result.get('profile') or not result.get('profileImagePath'): return result
    try:
        data=fetch_bytes(image_path(result['profileImagePath']),MAX_IMAGE_BYTES,'image/png,image/jpeg',race_path(path))
        mime,width,height=image_dimensions(data)
        result.update(profileImage='data:'+mime+';base64,'+base64.b64encode(data).decode('ascii'),
            profileImageWidth=width,profileImageHeight=height,profileState='ready',
            profileFetchedAt=dt.datetime.now(dt.timezone.utc).isoformat())
    except SourceError as e:result.update(profileState=e.state,profileError=e.message)
    return result


def course_cache_value(value,path):
    """Allow only regenerable course data across the disk/UI boundary."""
    if not isinstance(value,dict) or value.get('state')!='ready' or value.get('profileError'):
        raise ValueError('No successful course snapshot')
    points=value.get('profile') or []
    if not isinstance(points,list) or len(points)>220 or any(
        not isinstance(p,list) or len(p)!=2 or any(type(n) not in (int,float) or not math.isfinite(n) or not 0<=n<=100 for n in p) for p in points):
        raise ValueError('Invalid course geometry')
    out=dict(state='ready',path=path,profile=points,profileState='ready')
    image=value.get('profileImage') or ''
    if not points and image:
        if not isinstance(image,str) or len(image)>350000:
            raise ValueError('Invalid course image')
        match=re.fullmatch(r'data:(image/(?:png|jpeg));base64,([A-Za-z0-9+/=]+)',image)
        if not match:raise ValueError('Invalid course image')
        data=base64.b64decode(match[2],validate=True)
        if len(data)>MAX_IMAGE_BYTES:raise ValueError('Oversized course image')
        mime,width,height=image_dimensions(data)
        if mime!=match[1]:raise ValueError('Mismatched image type')
        out.update(profileImage=image,profileImageWidth=width,profileImageHeight=height)
    if len(points)<2 and not out.get('profileImage'):raise ValueError('No course profile')
    distance=value.get('distance')
    if distance is not None:
        if type(distance) not in (int,float) or not math.isfinite(distance) or not 0<distance<=10000:
            raise ValueError('Invalid course distance')
        out['distance']=distance
    stage=value.get('stagePath') or ''
    if stage:
        stage=race_path(stage)
        if stage.rsplit('/',1)[0]!=path.rsplit('/',1)[0] or not re.fullmatch(r'stage-\d+[a-z]?',stage.rsplit('/',1)[1]):
            raise ValueError('Unrelated course stage')
        out['stagePath']=stage
    out['profileLabel']=clean(value.get('profileLabel',''),80)
    for key in ('fetchedAt','profileFetchedAt'):
        if value.get(key):out[key]=clean(value[key],40)
    return out


@contextmanager
def course_cache_directory():
    """Private, locked cache; all entry IO stays relative to its open descriptor."""
    base=Path(os.environ.get('XDG_CACHE_HOME') or Path.home()/'.cache')
    if not base.is_absolute():base=Path.home()/'.cache'
    base.mkdir(mode=0o700,parents=True,exist_ok=True)
    parent=os.open(base,os.O_RDONLY|os.O_DIRECTORY|os.O_CLOEXEC)
    lock=None
    try:
        for name in ('omarchy-procyclingstats','courses-v1'):
            try:os.mkdir(name,0o700,dir_fd=parent)
            except FileExistsError:pass
            child=os.open(name,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW|os.O_CLOEXEC,dir_fd=parent)
            info=os.fstat(child)
            if info.st_uid!=os.getuid() or info.st_mode&0o077:
                os.close(child);raise OSError('Course cache is not private')
            os.close(parent);parent=child
        lock=os.open('.lock',os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW|os.O_CLOEXEC|os.O_NONBLOCK,0o600,dir_fd=parent)
        info=os.fstat(lock)
        if not stat.S_ISREG(info.st_mode) or info.st_uid!=os.getuid() or info.st_mode&0o077:raise OSError('Invalid cache lock')
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        yield parent
    finally:
        if lock is not None:os.close(lock)
        os.close(parent)


def prune_course_cache(directory,now):
    entries=[]
    with os.scandir(directory) as scan:
        for entry in scan:
            if not re.fullmatch(r'[0-9a-f]{64}\.json|\.tmp-[0-9a-f]{32}',entry.name):continue
            info=entry.stat(follow_symlinks=False)
            if not stat.S_ISREG(info.st_mode) or info.st_uid!=os.getuid():continue
            if entry.name.startswith('.tmp-') or info.st_size>CACHE_ENTRY_BYTES or now-info.st_mtime>=CACHE_RETENTION or info.st_mtime>now+60:
                os.unlink(entry.name,dir_fd=directory)
            else:entries.append((info.st_mtime,entry.name,info.st_size))
    entries.sort()
    total=sum(e[2] for e in entries)
    while len(entries)>CACHE_MAX_ENTRIES or total>CACHE_MAX_BYTES:
        _,name,size=entries.pop(0)
        os.unlink(name,dir_fd=directory);total-=size


def cached_course(path,value=None):
    """Best-effort cache: misses, damage and unwritable disks never block PCS."""
    try:
        path=race_path(path)
        name=hashlib.sha256(path.encode('utf-8')).hexdigest()+'.json'
        now=time.time()
        with course_cache_directory() as directory:
            prune_course_cache(directory,now)
            if value is not None:
                snapshot=course_cache_value(value,path)
                data=json.dumps(dict(version=1,path=path,savedAt=now,course=snapshot),ensure_ascii=True,separators=(',',':')).encode('ascii')
                if len(data)>CACHE_ENTRY_BYTES:return {}
                temporary='.tmp-'+secrets.token_hex(16)
                try:
                    fd=os.open(temporary,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW|os.O_CLOEXEC,0o600,dir_fd=directory)
                    with os.fdopen(fd,'wb') as stream:stream.write(data)
                    os.replace(temporary,name,src_dir_fd=directory,dst_dir_fd=directory)
                finally:
                    try:os.unlink(temporary,dir_fd=directory)
                    except FileNotFoundError:pass
                prune_course_cache(directory,now)
                return {}
            fd=os.open(name,os.O_RDONLY|os.O_NOFOLLOW|os.O_CLOEXEC|os.O_NONBLOCK,dir_fd=directory)
            with os.fdopen(fd,'rb') as stream:
                info=os.fstat(stream.fileno())
                if not stat.S_ISREG(info.st_mode) or info.st_uid!=os.getuid() or info.st_mode&0o077 or info.st_size>CACHE_ENTRY_BYTES:return {}
                data=stream.read(CACHE_ENTRY_BYTES+1)
            if len(data)>CACHE_ENTRY_BYTES:return {}
            record=json.loads(data)
            if not isinstance(record,dict) or record.get('version')!=1 or record.get('path')!=path:return {}
            saved=record.get('savedAt')
            if type(saved) not in (int,float) or not math.isfinite(saved) or not 0<=now-saved<CACHE_RETENTION:
                os.unlink(name,dir_fd=directory);return {}
            return dict(course_cache_value(record.get('course'),path),cacheSavedAt=saved)
    except (OSError,ValueError,TypeError,RecursionError,SourceError):
        return {}

def parse_course(html,path):
    doc=checked_html(html)
    info=race_info(doc)
    course=course_fields(doc,path)
    if not info.get('date') and not course['profile'] and not course['profileImagePath']:
        raise SourceError('unsupported','PCS course information could not be read.')
    return dict(state='ready',path=path,distance=metric(info.get('distance','')),**course)

def load_course(path):
    return attach_image(parse_course(fetch(path),path),path)

def parse_preview(html, path):
    doc = checked_html(html)
    values = race_info(doc)
    if not values.get('date'):
        raise SourceError('unsupported', 'PCS race preview could not be read.')
    return dict(state='ready', path=path, status='upcoming', date=values['date'],
        startTime=values.get('start time', ''), distance=metric(values.get('distance', '')),
        departure=values.get('departure', ''), arrival=values.get('arrival', ''),
        **course_fields(doc,path))

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
    if distance is None and done is not None and remaining is not None and done+remaining>0:
        distance=round(done+remaining,1)
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
            riders=[]
            seen=set()
            for a in g.nodes('a'):
                href=a.attrs.get('href','')
                if not href.startswith('rider/') or href in seen: continue
                seen.add(href)
                row=a.parent
                while row is not g and row.parent and row.tag != 'li': row=row.parent
                bib=txt(row.first(cls='bib')) if row is not g else ''
                if len(riders)<30: riders.append(dict(name=txt(a),bib=clean(bib,8),id=clean(href,160)))
            count=len(seen)
            groups.append(dict(label=label,gap=gap[0] if gap else '',count=count,riders=riders,
                               omitted=max(0,count-len(riders)),
                               uncertain=(gap_node.attrs['data-uncertain']=='1') if gap_node is not None and 'data-uncertain' in gap_node.attrs else '??' in raw))
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
                elapsed=value('racetime'),start=clean(data.get('start_time_cet')) or value('starttime'),startZone='CET' if data.get('start_time_cet') else 'local',elevation=number(value('elevation_todo')),
                groups=groups,stages=stage_links(doc,path),keypoints=keypoints[:40],profile=profile(doc.first(cls='bigProfile') or doc),
                sourceAt=dt.datetime.fromtimestamp(data['cur_ts'],dt.timezone.utc).isoformat()
                if number(data.get('cur_ts'),4102444800) is not None else '')

def result_rows(table):
    """Read header-selected columns; hidden numeric times resolve PCS ditto marks."""
    headers=[txt(h).lower() for h in table.nodes('th')]
    if 'rider' not in headers: return []
    if 'time' in headers: time_index=headers.index('time')
    elif 'timelag' in headers: time_index=len(headers)-1-headers[::-1].index('timelag')
    else: return []
    rider_index=headers.index('rider')
    bib_index=headers.index('bib') if 'bib' in headers else -1
    rows=[]
    previous_gap=None
    for tr in table.nodes('tr'):
        cells=[c for c in tr.children if isinstance(c,Node) and c.tag=='td']
        if len(cells)<=max(rider_index,time_index): continue
        a=next((a for a in cells[rider_index].nodes('a') if a.attrs.get('href','').startswith('rider/')),None)
        if not a: continue
        rank=clean(txt(cells[0]),8)
        time_cell=cells[time_index]
        hidden=time_cell.first(cls='hide')
        raw=txt(hidden) or txt(time_cell.first('font')) or txt(time_cell)
        timing=re.search(r'(?<![0-9])([+]?\d{1,3}:\d{2}(?::\d{2})?(?:[.,]\d+)?)',raw)
        if timing:
            time_text=timing[1]
            if rank=='1': display=time_text.lstrip('+'); previous_gap='0:00'
            else: display='+'+time_text.lstrip('+'); previous_gap=time_text.lstrip('+')
        elif raw.strip() in (',,','s.t.','same time') and previous_gap is not None:
            display='+'+previous_gap
        else:
            display='—'
        rows.append(dict(rank=rank,name=txt(a),bib=txt(cells[bib_index]) if bib_index>=0 else '',time=display))
        if len(rows)>=200: break
    return rows

def parse_results(html,path):
    doc=checked_html(html)
    navigation=doc.first(cls='resultTabs') or doc.first(cls='unitTabs')
    tabs={}
    stage_path=selected_stage(doc,path)
    if navigation:
        for a in navigation.nodes('a'):
            label=txt(a).upper()
            if label in ('GC','STAGE','RESULT','RESULTS'):
                tabs[a.attrs.get('data-id',a.attrs.get('data-navid',''))]='gc' if label=='GC' else 'result'
    containers={}
    for node in doc.nodes():
        if set(node.attrs.get('class','').split()) & {'resTab','resultCont'}:
            containers.setdefault(node.attrs.get('data-id',node.attrs.get('data-navid')),node)
    classifications=[]
    stage=path.split('/')[-1].startswith('stage-') or path.endswith('/gc')
    for tab_id,kind in tabs.items():
        container=containers.get(tab_id)
        table=container.first('table','results') if container else None
        if table is None: continue
        classifications.append(dict(kind=kind,title='General classification' if kind=='gc' else 'Stage results' if stage else 'Final results',rows=result_rows(table)))
    if not classifications:
        # A standalone one-day results page has no GC, and must never be labeled GC.
        table=doc.first('table','results')
        if table is None: raise SourceError('unavailable','PCS has not published results for this race yet.')
        is_gc=path.endswith('/gc')
        classifications=[dict(kind='gc' if is_gc else 'result',title='General classification' if is_gc else 'Stage results' if stage else 'Final results',rows=result_rows(table))]
    classifications.sort(key=lambda c:0 if c['kind']=='gc' else 1)
    info=race_info(doc)
    # The selected stage's winner time is independent of the GC's accumulated time.
    winner=next((r for c in classifications if c['kind']=='result' for r in c['rows'] if r['rank']=='1'),{})
    elapsed=winner.get('time','')
    if elapsed=='—': elapsed=''
    course=course_fields(doc,path)
    points=course['profile']
    return dict(state='ready',path=path,name=txt(doc.first('title')),status='finished',
                classifications=classifications,gcAvailable=any(c['kind']=='gc' for c in classifications),
                stageRace=stage,stagePath=stage_path,stages=stage_links(doc,path),groups=[],profile=points,keypoints=[],date=info.get('date',''),
                distance=metric(info.get('distance','')),elapsed=elapsed,
                avgSpeed=metric(info.get('avg. speed winner',''),150),
                profileState='ready' if points else 'unavailable',
                profileFetchedAt=dt.datetime.now(dt.timezone.utc).isoformat() if points else '',
                profileImagePath=course['profileImagePath'],
                profileLabel=course['profileLabel'])

def attach_finished_profile(result,path):
    if result['profile'] or result.get('profileImage') or result.get('profileImagePath'): return result
    try:
        doc=checked_html(fetch(path+'/live'))
        course=doc.first(cls='bigProfile')
        result['profile']=profile(course) if course else []
        result['profileState']='ready' if result['profile'] else 'unavailable'
        if result['profile']: result['profileFetchedAt']=dt.datetime.now(dt.timezone.utc).isoformat()
    except SourceError as e:
        result.update(profileState=e.state,profileError=e.message)
    return result

def parse_events(html):
    doc=checked_html(html)
    timeline=next((n for n in doc.nodes('ul') if any(c.startswith('timeline') for c in n.attrs.get('class','').split())),None)
    if timeline is None:
        raise SourceError('unavailable','Race events are not available on PCS for this race.')
    events=[]
    seen=set()
    for row in timeline.children:
        if not isinstance(row,Node) or row.tag!='li': continue
        content=row.first(cls='textCont')
        if content is None: continue
        text=content.text(900)
        text=re.sub(r'\s+([.,;!?])',r'\1',text)
        if not text: continue
        marker=clean(txt(row.first(cls='bol')),24)
        key=(marker,text)
        if key in seen: continue
        seen.add(key)
        events.append(dict(marker=marker,text=text))
        if len(events)>=60: break
    if not events and any(isinstance(n,Node) and n.tag=='li' for n in timeline.children):
        raise SourceError('unsupported','PCS race-events format changed; updates could not be read.')
    return dict(eventsState='ready' if events else 'empty',events=events,
                eventsFetchedAt=dt.datetime.now(dt.timezone.utc).isoformat())

def attach_events(result,path):
    try:
        result.update(parse_events(fetch(path+'/live/race-events')))
    except SourceError as e:
        result.update(eventsState=e.state,eventsError=e.message)
    return result

def load_race(path,finished=False,upcoming=False,stage=False):
    page=None
    navigation=[]
    preview=None
    if stage:
        page=fetch(path)
        navigation=stage_links(checked_html(page),path)
        try:
            published=parse_results(page,path)
            finished=any(c['rows'] for c in published['classifications'])
        except SourceError as e:
            if e.state not in ('unavailable','unsupported'): raise
        if not finished:
            try: preview=parse_preview(page,path)
            except SourceError as e:
                if e.state not in ('unavailable','unsupported'): raise
            date=race_date(preview.get('date','')) if preview else None
            if date and date>dt.date.today():
                return attach_image(preview,path)

    if upcoming:
        return attach_image(parse_preview(fetch(path),path),path)
    if finished:
        result=attach_image(parse_results(page if page is not None else fetch(path),path),path)
        # GC is an aggregate, not a course. Only follow the same race's explicit
        # Stage tab; never guess a /gc/live endpoint or another race's stage.
        course_path=result.get('stagePath') if path.endswith('/gc') else path
        if not course_path:
            result.update(eventsState='unavailable',events=[])
            return result
        result=attach_finished_profile(result,course_path)
        if result['profileState'] in ('blocked','rate-limited'):
            result.update(eventsState=result['profileState'],eventsError='Event refresh deferred after PCS rejected the profile request.')
            return result
        return attach_events(result,course_path)
    try: result=parse_race(fetch(path+'/live'),path)
    except SourceError as e:
        if not stage or not preview or e.state not in ('unavailable','unsupported'): raise
        # Without timing or results, a past/current page is not proof of a finish.
        preview.update(status='unknown',eventsState='unavailable',eventsError='Race events are not available on PCS for this stage.')
        return attach_image(preview,path)
    if navigation: result['stages']=navigation
    if result['status']=='finished':
        # LiveStats clocks can keep advancing after the finish. Never label that
        # clock as the winner's time, even if the published results request fails.
        result['elapsed']=''
        try:
            results=parse_results(fetch(path),path)
            result.update({k:results[k] for k in ('classifications','gcAvailable','stageRace','stages')})
            result['elapsed']=results['elapsed']
            for key in ('distance','avgSpeed','date'):
                if results[key] is not None and results[key]!='': result[key]=results[key]
            if results['profile']: result['profile']=results['profile']
            result['profileState']='ready' if result['profile'] else 'unavailable'
            result['profileFetchedAt']=dt.datetime.now(dt.timezone.utc).isoformat() if result['profile'] else ''
            result.update({k:results[k] for k in ('profileImagePath','profileLabel','stagePath')})
            result=attach_image(result,path)
        except SourceError as e:
            result['resultsError']=e.message
            result['resultsState']=e.state
    if result.get('profileState') in ('blocked','rate-limited'):
        result.update(eventsState=result['profileState'],eventsError='Event refresh deferred after PCS rejected the profile request.')
        return result
    return attach_events(result,path)

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

def fetch_bytes(path,limit=MAX_BYTES,accept="text/html",referer=""):
    remaining=REQUEST_DEADLINE-time.monotonic() if REQUEST_DEADLINE is not None else 10
    if remaining<=0:raise SourceError('offline','PCS request timed out.')
    headers={'User-Agent':'Omarchy-ProCyclingStats/0.1 (personal race overview)', 'Accept':accept, 'Accept-Encoding':'identity'}
    if referer:headers['Referer']=BASE+referer
    request=urllib.request.Request(BASE+path,headers=headers)
    try:
        with urllib.request.build_opener(SafeRedirect()).open(request,timeout=min(10,remaining)) as response:
            return bounded_read(response,limit)
    except urllib.error.HTTPError as e:
        e.close()
        if e.code in (401,403): raise SourceError('blocked','PCS blocks automated access. Open PCS in your browser.') from None
        if e.code == 429: raise SourceError('rate-limited','PCS rate limit reached. Retrying in 15 minutes.') from None
        if e.code == 404: raise SourceError('unavailable','PCS has no LiveStats page for this race.') from None
        raise SourceError('error',f'PCS returned HTTP {e.code}.') from None
    except (urllib.error.URLError,TimeoutError,socket.timeout,OSError):
        raise SourceError('offline','Could not reach PCS. Check your connection and retry.') from None

def fetch(path):
    return fetch_bytes(path).decode('utf-8',errors='replace')

def deadline(*_):
    raise SourceError('offline','PCS request timed out.')

def main():
    global REQUEST_DEADLINE
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=['overview','calendar','archive','race','events','course','course-cache'])
    parser.add_argument('--race',default='')
    parser.add_argument('--date',default='')
    parser.add_argument('--direction',choices=['recent','upcoming'],default='recent')
    parser.add_argument('--upcoming',action='store_true',help='Read the published pre-race information')
    parser.add_argument('--stage',action='store_true',help='Resolve a published stage as results, live race or preview')
    parser.add_argument('--finished',action='store_true',help='Read published results and stage GC instead of LiveStats')
    parser.add_argument('--html',type=Path,help='Parse a saved public page offline; no network request')
    args=parser.parse_args()
    signal.signal(signal.SIGALRM,deadline)
    REQUEST_DEADLINE=time.monotonic()+18
    signal.alarm(18)
    try:
        path=race_path(args.race) if args.mode in ('race','events','course','course-cache') else ''
        date=calendar_date(args.date) if args.mode in ('calendar','archive') else ''
        if args.html:
            with args.html.open('rb') as stream: html=bounded_read(stream).decode('utf-8',errors='replace')
            result=parse_course(html,path) if args.mode=='course' else parse_calendar(html,date) if date else parse_events(html) if args.mode=='events' else (parse_preview(html,path) if args.upcoming else parse_results(html,path) if args.finished else parse_race(html,path)) if path else parse_overview(html)
        elif args.mode=='course-cache':
            result=cached_course(path) or {'state':'empty'}
        elif args.mode=='course':
            result=load_course(path)
        elif args.mode=='archive':
            result=load_archive(date,args.direction)
        else:
            result=parse_calendar(fetch('races.php?p=uci&s=today&date='+date),date) if date else parse_events(fetch(path+'/live/race-events')) if args.mode=='events' else load_race(path,args.finished,args.upcoming,args.stage) if path else load_overview(calendar_date(args.date or dt.date.today().isoformat()))
        if args.mode!='course-cache':result['fetchedAt']=dt.datetime.now(dt.timezone.utc).isoformat()
        if not args.html and args.mode in ('race','course'):cached_course(path,result)
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
